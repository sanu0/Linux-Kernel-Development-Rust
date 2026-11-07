// enums_demo.rs — M1W1D4. Structs, enums, pattern matching, and derive.
//
//   rustc enums_demo.rs -o enums
//   ./enums 3       run only section 3 — predict it first, then look
//   ./enums         run every section
//
// Everything in this file COMPILES. The errors live in enum_errors.rs.

fn banner(n: u32, title: &str) {
    println!("\n──── {}. {} ────", n, title);
}

// ─────────────────────────────────────────────────────────────────
// 1. Three shapes of struct, and the two kinds of function in an impl.

struct Register {
    name: &'static str,
    offset: u32,
    value: u32,
}

struct Irq(u32); // tuple struct: one unnamed field, read as .0

struct PoweredOff; // unit struct: no data at all

impl Register {
    // Associated function: no self. Called as Register::new(...).
    fn new(name: &'static str, offset: u32) -> Self {
        Register { name, offset, value: 0 }
    }

    // Method: takes &self, so it can read. Called as reg.describe().
    fn describe(&self) -> String {
        format!("{} at offset {:#x} holds {:#x}", self.name, self.offset, self.value)
    }

    // Method: takes &mut self, so it can change the struct.
    fn write(&mut self, v: u32) {
        self.value = v;
    }
}

fn s1_structs() {
    banner(1, "Struct shapes, associated functions, methods");
    let mut ctrl = Register::new("CTRL", 0x10);
    println!("{}", ctrl.describe());
    ctrl.write(0xbeef);
    println!("{}", ctrl.describe());

    let irq = Irq(42);
    println!("tuple struct: irq number {}", irq.0);

    let _off = PoweredOff;
    println!("unit struct: PoweredOff carries no data at all");
}

// ─────────────────────────────────────────────────────────────────
// 2. The magic-number problem, and the enum that fixes it.

// The C way: a state is just a number, with names for some of the values.
const STATE_UNINIT: u8 = 0;
const STATE_PROBING: u8 = 1;
const STATE_READY: u8 = 2;

fn describe_number(state: u8) -> &'static str {
    if state == STATE_UNINIT {
        "uninitialized"
    } else if state == STATE_PROBING {
        "probing"
    } else if state == STATE_READY {
        "ready"
    } else {
        "??? not a real state"
    }
}

// The Rust way: the type itself lists every possible state.
enum State {
    Uninitialized,
    Probing,
    Ready,
}

fn describe_enum(state: State) -> &'static str {
    match state {
        State::Uninitialized => "uninitialized",
        State::Probing => "probing",
        State::Ready => "ready",
    }
}

fn s2_magic_numbers() {
    banner(2, "Magic numbers vs an enum");
    println!("number 2       -> {}", describe_number(2));
    println!("number 42      -> {}", describe_number(42)); // nothing stops this
    for s in [State::Uninitialized, State::Probing, State::Ready] {
        println!("enum variant   -> {}", describe_enum(s));
    }
    // describe_enum(42) would not compile: 42 is not a State.
}

// ─────────────────────────────────────────────────────────────────
// 3. Variants can carry data — a different shape for each one.

enum Event {
    Probe,                // no data
    ProbeOk { irq: u32 }, // named fields, like a struct
    ProbeFailed(i32),     // one unnamed field, like a tuple struct
    Suspend,
    Resume,
    Remove,
}

fn describe_event(e: &Event) -> String {
    match e {
        Event::Probe => String::from("probe started"),
        Event::ProbeOk { irq } => format!("probe succeeded, irq {}", irq),
        Event::ProbeFailed(code) => format!("probe failed with error {}", code),
        Event::Suspend => String::from("suspend"),
        Event::Resume => String::from("resume"),
        Event::Remove => String::from("remove"),
    }
}

fn s3_data_in_variants() {
    banner(3, "Enum variants can carry data");
    let events = [
        Event::Probe,
        Event::ProbeOk { irq: 42 },
        Event::ProbeFailed(-19),
        Event::Suspend,
        Event::Resume,
        Event::Remove,
    ];
    for e in &events {
        println!("{}", describe_event(e));
    }
}

// ─────────────────────────────────────────────────────────────────
// 4. match: every case must be handled; patterns can test and bind.

fn classify(code: i32) -> &'static str {
    match code {
        0 => "success",
        -12 => "out of memory (ENOMEM)",
        -19 => "no such device (ENODEV)",
        -22 => "invalid argument (EINVAL)",
        c if c < 0 => "some other error",
        _ => "positive: not an error code",
    }
}

fn s4_match() {
    banner(4, "match: exhaustive, with a guard and a catch-all");
    for code in [0, -12, -19, -22, -5, 7] {
        println!("{} -> {}", code, classify(code));
    }
}

// ─────────────────────────────────────────────────────────────────
// 5. Option and Result are ordinary enums from the standard library.

fn find_irq(name: &str) -> Option<u32> {
    match name {
        "uart0" => Some(33),
        "eth0" => Some(42),
        _ => None,
    }
}

fn s5_option_result() {
    banner(5, "Option and Result are ordinary enums");
    for name in ["eth0", "gpu9"] {
        match find_irq(name) {
            Some(irq) => println!("{} uses irq {}", name, irq),
            None => println!("{} has no irq", name),
        }
    }
    let r: Result<u32, i32> = Err(-19);
    match r {
        Ok(v) => println!("got {}", v),
        Err(code) => println!("error {} — {}", code, classify(code)),
    }
}

// ─────────────────────────────────────────────────────────────────
// 6. Shorter forms: if let, let else, while let.

fn irq_or_zero(name: &str) -> u32 {
    // let else: take the value out, or leave the function right now.
    let Some(irq) = find_irq(name) else {
        return 0;
    };
    irq
}

fn s6_short_forms() {
    banner(6, "if let, let else, while let");

    if let Some(irq) = find_irq("uart0") {
        println!("if let:    uart0 uses irq {}", irq);
    }

    println!("let else:  eth0 -> {}, gpu9 -> {}", irq_or_zero("eth0"), irq_or_zero("gpu9"));

    let mut queue = vec!["probe", "init", "start"];
    while let Some(job) = queue.pop() {
        println!("while let: running {}", job);
    }
    println!("queue empty now: {}", queue.is_empty());
}

// ─────────────────────────────────────────────────────────────────
// 7. derive: ask the compiler to write common trait implementations.

#[derive(Debug, Clone, Copy, PartialEq, Default)]
struct Version {
    major: u8,
    minor: u8,
}

// What derive(PartialEq) writes for you, done by hand:
struct HandVersion {
    major: u8,
    minor: u8,
}

impl PartialEq for HandVersion {
    fn eq(&self, other: &Self) -> bool {
        self.major == other.major && self.minor == other.minor
    }
}

fn s7_derive() {
    banner(7, "What derive gives you");
    let v = Version { major: 7, minor: 2 };
    let w = v; // Copy: v is duplicated, not moved, so v is still usable
    let d = Version::default(); // Default: every field set to zero

    println!("Debug:          {:?}", v);
    println!("pretty Debug:   {:#?}", d);
    println!("Copy:           v still usable after `let w = v;` -> {:?}", v);
    println!("PartialEq:      v == w is {}, v == d is {}", v == w, v == d);
    println!("Clone:          {:?}", v.clone());

    let a = HandVersion { major: 7, minor: 2 };
    let b = HandVersion { major: 7, minor: 2 };
    println!("hand-written ==: {}", a == b);
}

// ─────────────────────────────────────────────────────────────────
// 8. A device state machine as one enum. Illegal moves return an error.

#[derive(Debug, Clone, Copy, PartialEq)]
enum DeviceState {
    Uninitialized,
    Probing,
    Ready { irq: u32 },
    Suspended { irq: u32 },
    Removed,
}

impl DeviceState {
    // Transitions take `self` by value: the old state is used up (Day 1).
    fn probe(self) -> Result<DeviceState, String> {
        match self {
            DeviceState::Uninitialized => Ok(DeviceState::Probing),
            other => Err(format!("cannot probe while {:?}", other)),
        }
    }

    fn probe_done(self, irq: u32) -> Result<DeviceState, String> {
        match self {
            DeviceState::Probing => Ok(DeviceState::Ready { irq }),
            other => Err(format!("cannot finish probing while {:?}", other)),
        }
    }

    fn suspend(self) -> Result<DeviceState, String> {
        match self {
            DeviceState::Ready { irq } => Ok(DeviceState::Suspended { irq }),
            other => Err(format!("cannot suspend while {:?}", other)),
        }
    }

    fn resume(self) -> Result<DeviceState, String> {
        match self {
            DeviceState::Suspended { irq } => Ok(DeviceState::Ready { irq }),
            other => Err(format!("cannot resume while {:?}", other)),
        }
    }

    fn remove(self) -> Result<DeviceState, String> {
        match self {
            DeviceState::Ready { .. } | DeviceState::Suspended { .. } => Ok(DeviceState::Removed),
            other => Err(format!("cannot remove while {:?}", other)),
        }
    }

    // No catch-all here, on purpose: add a new state and this stops compiling
    // until you decide whether the new state may do I/O.
    fn can_do_io(&self) -> bool {
        match self {
            DeviceState::Uninitialized => false,
            DeviceState::Probing => false,
            DeviceState::Ready { .. } => true,
            DeviceState::Suspended { .. } => false,
            DeviceState::Removed => false,
        }
    }
}

fn legal_life_cycle() -> Result<DeviceState, String> {
    let s = DeviceState::Uninitialized;
    println!("  {:?}", s);
    let s = s.probe()?;
    println!("  {:?}", s);
    let s = s.probe_done(42)?;
    println!("  {:?}  can do I/O: {}", s, s.can_do_io());
    let s = s.suspend()?;
    println!("  {:?}  can do I/O: {}", s, s.can_do_io());
    let s = s.resume()?;
    println!("  {:?}", s);
    let s = s.remove()?;
    println!("  {:?}", s);
    Ok(s)
}

fn s8_enum_state_machine() {
    banner(8, "A device state machine as an enum");
    println!("a legal life cycle:");
    match legal_life_cycle() {
        Ok(end) => println!("finished in state {:?}", end),
        Err(e) => println!("stopped: {}", e),
    }

    println!("illegal moves are caught — but only when the program runs:");
    match DeviceState::Uninitialized.suspend() {
        Ok(s) => println!("  suspended?? {:?}", s),
        Err(e) => println!("  {}", e),
    }
    match DeviceState::Removed.probe() {
        Ok(s) => println!("  probed?? {:?}", s),
        Err(e) => println!("  {}", e),
    }
}

// ─────────────────────────────────────────────────────────────────
// 9. Making illegal moves impossible: one struct per state ("typestate").
//
// Each state is its own type, and each type only has the methods that are
// legal from that state. A transition takes `self` by value, so the old state
// is used up and cannot be touched again.

struct Uninitialized;
struct Probing;
struct Ready {
    irq: u32,
}
struct Suspended {
    irq: u32,
}
struct Removed;

impl Uninitialized {
    fn probe(self) -> Probing {
        println!("  Uninitialized -> Probing");
        Probing
    }
}

impl Probing {
    fn done(self, irq: u32) -> Ready {
        println!("  Probing -> Ready (irq {})", irq);
        Ready { irq }
    }
}

impl Ready {
    fn suspend(self) -> Suspended {
        println!("  Ready -> Suspended");
        Suspended { irq: self.irq }
    }

    fn remove(self) -> Removed {
        println!("  Ready -> Removed");
        Removed
    }
}

impl Suspended {
    fn resume(self) -> Ready {
        println!("  Suspended -> Ready (irq {})", self.irq);
        Ready { irq: self.irq }
    }

    fn remove(self) -> Removed {
        println!("  Suspended -> Removed");
        Removed
    }
}

fn s9_typestate() {
    banner(9, "Typestate: illegal moves do not even compile");
    let dev = Uninitialized;
    let dev = dev.probe();
    let dev = dev.done(42);
    let dev = dev.suspend();
    let dev = dev.resume();
    let _gone: Removed = dev.remove();

    println!("  a second device, removed while suspended:");
    let dev2 = Uninitialized.probe().done(7).suspend();
    let _gone2: Removed = dev2.remove();

    // Uninitialized.suspend();   // error: there is no `suspend` on `Uninitialized`
    println!("  removed — and no type has a method to bring it back");
}

// `./enums 3` runs only section 3; plain `./enums` runs them all.
// How this works is Option and match — exactly today's topic.
fn wanted(section: &str) -> bool {
    match std::env::args().nth(1) {
        Some(arg) => arg == section,
        None => true,
    }
}

fn main() {
    println!("=== structs, enums, and pattern matching ===");

    if wanted("1") { s1_structs(); }
    if wanted("2") { s2_magic_numbers(); }
    if wanted("3") { s3_data_in_variants(); }
    if wanted("4") { s4_match(); }
    if wanted("5") { s5_option_result(); }
    if wanted("6") { s6_short_forms(); }
    if wanted("7") { s7_derive(); }
    if wanted("8") { s8_enum_state_machine(); }
    if wanted("9") { s9_typestate(); }

    println!("\n=== now go read enum_errors.rs ===");
}

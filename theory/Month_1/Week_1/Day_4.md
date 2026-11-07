# M1W1D4 — Structs, Enums, and Pattern Matching

> **What you need to know already:** Rust up to structs, plus Days 1–3 — ownership, borrowing, and
> the kernel tree. Anything new is explained in a **🆕 New Rust** box at the moment it first appears.
>
> **Time:** about 90 minutes, including running every example. No kernel builds today.

Every device a driver controls is always in some **state**: not set up yet, starting up, working,
asleep, unplugged. A huge share of kernel bugs come from code that does something in the wrong state —
sending data to a device that is asleep, or touching one that has already been removed.

C keeps track of states with plain numbers. Rust gives you a better tool: the **enum**, together with
**`match`**, which forces you to handle every possible state. By the end of today you will have built a
device state machine two ways — the second one so strict that an illegal state change does not even
compile.

As always, **predict each example's output before you run it.**

| Part | What you will learn | Time |
|---|---|---|
| Before you start | Set up the example programs | 5 min |
| 1 | Structs and `impl`, quickly | 5 min |
| 2 | Enums: a value that is one of several things | 15 min |
| 3 | `match`, and its shorter forms | 20 min |
| 4 | `#[derive]`: traits the compiler writes for you | 10 min |
| 5 | A device state machine as an enum | 15 min |
| 6 | Making illegal state changes impossible | 10 min |
| Your turn | Write your own state machine, and check yourself | 10 min |

---

## Before You Start (5 minutes)

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_4/enums_demo.rs .
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_4/enum_errors.rs .
rustc enums_demo.rs -o enums
```

If you see `rustc: command not found`, run `export PATH="$HOME/.cargo/bin:$PATH"` and try again.

The demo has nine sections, and you run one at a time: `./enums 3` runs section 3, and `./enums` runs
them all.

`enum_errors.rs` holds five errors, each between `/*` and `*/`, like Day 2's error file. The parts
below tell you when to uncomment each one. Uncomment **one block at a time**, compile with
`rustc enum_errors.rs -o ee`, read the whole message, fix it, and put the `/*` and `*/` back. After a
fix, you may see warnings such as "function is never used" — nothing calls these practice functions,
so that is expected. Only lines starting with `error` mean something is still wrong.

---

## Part 1 — Structs and `impl`, Quickly (5 minutes)

You already know structs, so this is a short reminder of the three shapes and the kinds of function an
`impl` block can hold. Section 1 of the demo uses all of them:

```rust
struct Register {          // named fields
    name: &'static str,
    offset: u32,
    value: u32,
}

struct Irq(u32);           // tuple struct: one unnamed field, read as .0

struct PoweredOff;         // unit struct: no data at all

impl Register {
    fn new(name: &'static str, offset: u32) -> Self {
        Register { name, offset, value: 0 }
    }

    fn describe(&self) -> String {
        format!("{} at offset {:#x} holds {:#x}", self.name, self.offset, self.value)
    }

    fn write(&mut self, v: u32) {
        self.value = v;
    }
}
```

`new` has no `self`, so it is an **associated function**, called as `Register::new(...)`. `describe`
takes `&self`, so it is a **method** that can read the struct. `write` takes `&mut self`, so it can
change it. Two small things you may not have seen: `Register { name, offset, value: 0 }` is shorthand
for `name: name, offset: offset` when the variable has the same name as the field, and `{:#x}` prints a
number in hexadecimal with `0x` in front.

> **▶ Try it.** Run `./enums 1`.

```text
──── 1. Struct shapes, associated functions, methods ────
CTRL at offset 0x10 holds 0x0
CTRL at offset 0x10 holds 0xbeef
tuple struct: irq number 42
unit struct: PoweredOff carries no data at all
```

There is a fourth kind of method you met on Day 1: one that takes `self` **by value**, which uses the
value up. Remember that one — it becomes very important in Part 6.

---

## Part 2 — Enums: A Value That Is One of Several Things (15 minutes)

### The problem with storing a state as a number

Here is how the kernel's C code describes the states of a network PHY chip, in your tree's
`include/linux/phy.h` (with its comments removed):

```c
enum phy_state {
	PHY_DOWN = 0,
	PHY_READY,
	PHY_HALTED,
	PHY_ERROR,
	PHY_UP,
	PHY_RUNNING,
	PHY_NOLINK,
	PHY_CABLETEST,
};
```

It looks like a list of states, but in C an `enum` is really just a set of names for numbers:
`PHY_DOWN` is 0, `PHY_READY` is 1, and so on. Underneath, a variable of this type is an ordinary
integer, and C will let you store 42 in it. Nothing stops it, and nothing checks whether every piece of
code handles every state.

Section 2 of the demo copies the C style, with numbers and names for them:

```rust
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
```

Calling `describe_number(42)` compiles happily. The function has to carry an extra branch for values
that are not states at all, and every other function that takes a state has to remember to do the
same.

### The Rust way

> **🆕 New Rust — `enum`**
>
> An **enum** is a type whose value is exactly **one** of a fixed list of **variants**. You name a
> variant with the enum's name, two colons, and the variant: `State::Ready`. A value of type `State`
> can only ever be one of the listed variants — never 42, never anything else.

```rust
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
```

There is no "not a real state" branch, because there is no such thing. `describe_enum(42)` does not
compile: 42 is a number, not a `State`. (`match` is explained properly in Part 3. For now, read it as
"look at `state`, and give back the answer for whichever variant it is".)

> **▶ Try it.** Predict what `describe_number(42)` prints, then run `./enums 2`.

```text
──── 2. Magic numbers vs an enum ────
number 2       -> ready
number 42      -> ??? not a real state
enum variant   -> uninitialized
enum variant   -> probing
enum variant   -> ready
```

### Variants can carry data

This is where Rust's enums go far beyond C's. Each variant can hold its **own** data, in its own
shape:

```rust
enum Event {
    Probe,                // no data
    ProbeOk { irq: u32 }, // named fields, like a struct
    ProbeFailed(i32),     // one unnamed field, like a tuple struct
    Suspend,
    Resume,
    Remove,
}
```

A successful probe carries the interrupt number it found. A failed probe carries an error code. The
others carry nothing. An `irq` only exists when the probe succeeded, so there is no way to read an
interrupt number from a failed probe by mistake.

A useful way to remember the difference: a **struct** holds *this and that and that* — all of its
fields at once. An **enum** holds *this or that or that* — exactly one variant at a time.

> **▶ Try it.** Run `./enums 3`.

```text
──── 3. Enum variants can carry data ────
probe started
probe succeeded, irq 42
probe failed with error -19
suspend
resume
remove
```

The `-19` is not random. It is how the kernel spells `ENODEV`, "no such device" — kernel functions
return negative error numbers like this.

### You have been using enums since Day 1

`Option` and `Result` are not special parts of the language. They are ordinary enums, defined in Rust's
standard library like this:

```rust
enum Option<T> {
    Some(T),
    None,
}

enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

> **🆕 New Rust — the `<T>` in `Option<T>`**
>
> `T` and `E` are placeholders for "any type". `Option<u32>` is an `Option` whose `Some` holds a `u32`;
> `Result<u32, i32>` holds a `u32` when it is `Ok` and an `i32` when it is `Err`. Writing your own types
> with placeholders like this is called **generics**, and it is Week 2. Today you only need to read
> them.

> **▶ Try it.** Run `./enums 5`.

```text
──── 5. Option and Result are ordinary enums ────
eth0 uses irq 42
gpu9 has no irq
error -19 — no such device (ENODEV)
```

### How kernel Rust turns a C number into a real enum

The kernel's Rust PHY code, `rust/kernel/net/phy.rs`, has its own Rust enum for the same eight PHY
states. But the C side still stores a number, so when Rust reads the state, it has to convert. Here is
the real code from your tree:

```rust
match state {
    bindings::phy_state_PHY_DOWN => DeviceState::Down,
    bindings::phy_state_PHY_READY => DeviceState::Ready,
    bindings::phy_state_PHY_HALTED => DeviceState::Halted,
    bindings::phy_state_PHY_ERROR => DeviceState::Error,
    bindings::phy_state_PHY_UP => DeviceState::Up,
    bindings::phy_state_PHY_RUNNING => DeviceState::Running,
    bindings::phy_state_PHY_NOLINK => DeviceState::NoLink,
    bindings::phy_state_PHY_CABLETEST => DeviceState::CableTest,
    _ => DeviceState::Error,
}
```

Look at the last line. Because the C value is just a number, it *could* be something that is not one
of the eight states, and Rust insists that case is handled too. Once the conversion is done, every
driver written in Rust works with a real `DeviceState` and never sees a bad number again. This is the
kernel's three-layer design from Week 0 in miniature: a little careful code at the boundary, and safety
everywhere after it.

---

## Part 3 — `match`, and Its Shorter Forms (20 minutes)

### `match` must handle every variant

`match` looks at a value and runs the one **arm** whose pattern fits. Each arm is a pattern, then `=>`,
then the result. Like `if`, a whole `match` produces a value.

Its most important rule: **a `match` must handle every possible variant.** This is called being
**exhaustive**, and it is the reason enums are so useful for states.

> **▶ Try it.** In `enum_errors.rs`, uncomment block 1 and compile. It is a `match` that forgets one
> of the three power states.

```rust
enum Power {
    On,
    Off,
    Suspended,
}

fn may_do_io(p: Power) -> bool {
    match p {
        Power::On => true,
        Power::Off => false,
    }
}
```

```text
error[E0004]: non-exhaustive patterns: `Power::Suspended` not covered
  --> enum_errors.rs:32:11
   |
32 |     match p {
   |           ^ pattern `Power::Suspended` not covered
   |
note: `Power` defined here
  --> enum_errors.rs:25:6
   |
25 | enum Power {
   |      ^^^^^
...
28 |     Suspended,
   |     --------- not covered
   = note: the matched value is of type `Power`
help: ensure that all possible cases are being handled by adding a match arm with a wildcard pattern or an explicit pattern as shown
   |
34 ~         Power::Off => false,
35 ~         Power::Suspended => todo!(),
```

Read how much it tells you. It names the missing variant, points at the line in the enum where that
variant is defined, and even shows you the arm to add. (`todo!()` is a placeholder that stops the
program if it is ever reached — fine while writing, never fine in finished kernel code.)

Now think about what this means over time. Months later, someone adds a fourth power state. **Every
`match` on that enum, anywhere in the code, stops compiling** until someone decides what the new state
should do there. In C, the new number would silently fall through every `switch` statement that did not
expect it.

Fix block 1 by adding the arm `Power::Suspended => false,`, check that it compiles, and put the `/*` and
`*/` back.

### Patterns can test values and pull data out

> **🆕 New Rust — patterns**
>
> The left side of each arm is a **pattern**. A few kinds you will use constantly:
>
> - `Event::ProbeOk { irq }` matches that variant and puts its data in a new variable `irq`.
> - `Ready { .. }` matches the variant and ignores all its fields.
> - `A | B` matches either one.
> - `c if c < 0` is a **guard**: it matches only when the extra condition is true.
> - `_` matches anything at all, and is used as a catch-all, usually as the last arm.

Section 4 uses a few of them to name kernel error numbers:

```rust
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
```

An `i32` has billions of possible values, so the compiler cannot ask you to list them all. The last two
arms make the `match` exhaustive: every negative number not listed above is caught by the guard, and
everything else by `_`.

> **▶ Try it.** What does `classify(-5)` return? And `classify(7)`? Run `./enums 4`.

```text
──── 4. match: exhaustive, with a guard and a catch-all ────
0 -> success
-12 -> out of memory (ENOMEM)
-19 -> no such device (ENODEV)
-22 -> invalid argument (EINVAL)
-5 -> some other error
7 -> positive: not an error code
```

**Be careful with `_` on enums.** On a number, a catch-all is necessary. On a state enum, it is often a
trap: `_ =>` also catches every variant someone adds *in the future*, so the compiler will no longer
point out the places that need updating. On state enums, prefer listing every variant.

### Three shorter forms

Sometimes a full `match` is more than you need. Rust has three shorter forms, all shown in section 6.

**`if let`** — when you only care about one variant:

```rust
if let Some(irq) = find_irq("uart0") {
    println!("if let:    uart0 uses irq {}", irq);
}
```

Read it as "if this is a `Some`, call the value inside `irq` and run the block." If it is `None`,
nothing happens.

**`let else`** — take the value out, or leave right now:

```rust
fn irq_or_zero(name: &str) -> u32 {
    let Some(irq) = find_irq(name) else {
        return 0;
    };
    irq
}
```

If the value is a `Some`, `irq` gets the number and the function carries on. If not, the `else` block
runs, and it **must** leave — with `return`, for example. This reads cleanly, keeps the normal path
unindented, and is very common in kernel Rust: your tree uses it at least 24 times in `rust/kernel/`
and the drivers. For example, in the Binder driver:

```rust
let Some(info) = node_refs.by_handle.get_mut(&handle) else {
```

**`while let`** — keep looping as long as the pattern matches:

```rust
let mut queue = vec!["probe", "init", "start"];
while let Some(job) = queue.pop() {
    println!("while let: running {}", job);
}
```

`pop()` removes the last item of a list and returns it as `Some(item)`, or `None` when the list is
empty. So the loop runs once per item and stops by itself.

> **▶ Try it.** In which order will the three jobs run? Think about which end `pop()` takes from. Then
> run `./enums 6`.

```text
──── 6. if let, let else, while let ────
if let:    uart0 uses irq 33
let else:  eth0 -> 42, gpu9 -> 0
while let: running start
while let: running init
while let: running probe
queue empty now: true
```

`pop()` takes from the **end**, so the last job added runs first.

---

## Part 4 — `#[derive]`: Traits the Compiler Writes for You (10 minutes)

You met `#[derive(Debug)]` in the structs chapter, and `Clone` on Day 1. Here is what is really going
on, and what the common derives give you.

Printing with `{:?}`, comparing with `==`, and copying with `.clone()` are all **traits** — the same
idea as `Drop` on Day 1: a set of methods a type promises to have. Writing those methods by hand for
every struct would be tedious, so `#[derive(...)]` asks the compiler to write them for you.

| Derive | What it gives you |
|---|---|
| `Debug` | Printing with `{:?}`, and pretty multi-line printing with `{:#?}` |
| `Clone` | A `.clone()` method that makes a copy |
| `Copy` | Assignment copies instead of moving — allowed only if every field is `Copy`, and never with `Drop` (Day 1) |
| `PartialEq` | `==` and `!=`, comparing field by field |
| `Eq` | A promise that equality always behaves sensibly (true for integers; not for floats, where "not a number" is not equal to itself) |
| `Default` | `Type::default()`, which builds a value with every field zero or empty |

Section 7 uses five of them:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Default)]
struct Version {
    major: u8,
    minor: u8,
}
```

> **▶ Try it.** Will `v == d` be true? Run `./enums 7`.

```text
──── 7. What derive gives you ────
Debug:          Version { major: 7, minor: 2 }
pretty Debug:   Version {
    major: 0,
    minor: 0,
}
Copy:           v still usable after `let w = v;` -> Version { major: 7, minor: 2 }
PartialEq:      v == w is true, v == d is false
Clone:          Version { major: 7, minor: 2 }
hand-written ==: true
```

### What derive actually writes

There is no magic. Here is what `#[derive(PartialEq)]` writes for you, done by hand in section 7:

```rust
impl PartialEq for HandVersion {
    fn eq(&self, other: &Self) -> bool {
        self.major == other.major && self.minor == other.minor
    }
}
```

It compares every field, joined with `&&`. That is the whole thing. `derive(Debug)` similarly writes
code that prints the type's name and each field — which is exactly the `Version { major: 7, minor: 2 }`
you see above.

> **▶ Try it.** Uncomment block 4, then block 5 (one at a time). Block 4 prints a struct with `{:?}`
> without deriving `Debug`; block 5 compares with `==` without deriving `PartialEq`.

```text
error[E0277]: `Version` doesn't implement `Debug`
help: consider annotating `Version` with `#[derive(Debug)]`
```

```text
error[E0369]: binary operation `==` cannot be applied to type `Version`
help: consider annotating `Version` with `#[derive(PartialEq)]`
```

Rust never guesses how to print or compare your types — but the compiler tells you exactly which line to
add. The Rust code in your tree has about 600 `#[derive(...)]` lines, and in `rust/kernel/` and the
drivers one of the most common is `#[derive(Copy, Clone, Debug, PartialEq)]`.

---

## Part 5 — A Device State Machine as an Enum (15 minutes)

Now put it together. A device goes through these states, and only these changes are allowed:

```text
Uninitialized ──probe──▶ Probing ──probe_done(irq)──▶ Ready ◀──resume───┐
                                                        │                │
                                                        ├──suspend──▶ Suspended
                                                        │                │
                                                        └──remove──▶ Removed ◀──remove
```

Anything else — suspending a device that was never set up, probing one that has been removed — is a
bug. Section 8 builds this as one enum:

```rust
#[derive(Debug, Clone, Copy, PartialEq)]
enum DeviceState {
    Uninitialized,
    Probing,
    Ready { irq: u32 },
    Suspended { irq: u32 },
    Removed,
}
```

Notice that the interrupt number lives **only** in the states where it means something. In C you would
likely have a struct with an `int irq` that always exists — and nothing stops code from reading it while
the device is still uninitialized.

Each allowed change is a method. Here is one:

```rust
impl DeviceState {
    fn suspend(self) -> Result<DeviceState, String> {
        match self {
            DeviceState::Ready { irq } => Ok(DeviceState::Suspended { irq }),
            other => Err(format!("cannot suspend while {:?}", other)),
        }
    }
}
```

Three things to see in it. It takes `self` **by value**, so the old state is used up (Day 1) and you
get a new one back. It returns a `Result`, so an illegal change becomes an `Err` that the caller must
deal with. And the `other =>` arm is a catch-all that gives a name to whatever state it was, so the
error message can say which.

There is also one function with **no** catch-all, on purpose:

```rust
fn can_do_io(&self) -> bool {
    match self {
        DeviceState::Uninitialized => false,
        DeviceState::Probing => false,
        DeviceState::Ready { .. } => true,
        DeviceState::Suspended { .. } => false,
        DeviceState::Removed => false,
    }
}
```

If someone adds a new state, this function stops compiling until they decide whether the new state may
do input and output. That decision is too important to leave to a default.

Here is a full legal life cycle. It combines several things you already know — moves, shadowing and `?`:

```rust
fn legal_life_cycle() -> Result<DeviceState, String> {
    let s = DeviceState::Uninitialized;
    let s = s.probe()?;
    let s = s.probe_done(42)?;
    let s = s.suspend()?;
    let s = s.resume()?;
    let s = s.remove()?;
    Ok(s)
}
```

Each line uses up the old state and gives the new one the same name, `s`. If any change were illegal,
`?` would return the error straight away.

> **▶ Try it.** What will `DeviceState::Uninitialized.suspend()` give back? Run `./enums 8`.

```text
──── 8. A device state machine as an enum ────
a legal life cycle:
  Uninitialized
  Probing
  Ready { irq: 42 }  can do I/O: true
  Suspended { irq: 42 }  can do I/O: false
  Ready { irq: 42 }
  Removed
finished in state Removed
illegal moves are caught — but only when the program runs:
  cannot suspend while Uninitialized
  cannot probe while Removed
```

This is already far safer than numbers. But look at the heading of the last part of the output: illegal
moves are caught **when the program runs**. The code `DeviceState::Uninitialized.suspend()` compiled
without complaint. You only find the mistake if that line actually runs — and in a driver, the wrong
line might only run on one customer's hardware, once a month.

Can we do better?

---

## Part 6 — Making Illegal State Changes Impossible (10 minutes)

Yes — by making each state its **own type**. This is called the **typestate** pattern, and it uses
nothing you have not already learned: structs, `impl` blocks, and methods that take `self` by value.

```rust
struct Uninitialized;
struct Probing;
struct Ready { irq: u32 }
struct Suspended { irq: u32 }
struct Removed;

impl Uninitialized {
    fn probe(self) -> Probing { /* ... */ }
}

impl Probing {
    fn done(self, irq: u32) -> Ready { /* ... */ }
}

impl Ready {
    fn suspend(self) -> Suspended { /* ... */ }
    fn remove(self) -> Removed { /* ... */ }
}

impl Suspended {
    fn resume(self) -> Ready { /* ... */ }
    fn remove(self) -> Removed { /* ... */ }
}
```

Each type has **only** the methods that are legal from that state. `Uninitialized` has `probe` and
nothing else. `Removed` has no methods at all, so there is nothing you can do with a removed device. The
state diagram from Part 5 is now written directly into the types.

> **▶ Try it.** Run `./enums 9`.

```text
──── 9. Typestate: illegal moves do not even compile ────
  Uninitialized -> Probing
  Probing -> Ready (irq 42)
  Ready -> Suspended
  Suspended -> Ready (irq 42)
  Ready -> Removed
  a second device, removed while suspended:
  Uninitialized -> Probing
  Probing -> Ready (irq 7)
  Ready -> Suspended
  Suspended -> Removed
  removed — and no type has a method to bring it back
```

The second device is written as a chain: `Uninitialized.probe().done(7).suspend()`. Each call uses up
one state and hands the next to the following call.

### Now try to break it

> **▶ Try it.** Uncomment block 2 in `enum_errors.rs`. It tries to probe a device that is already
> probing.

```text
error[E0599]: no method named `probe` found for struct `Probing` in the current scope
  --> enum_errors.rs:58:22
   |
47 | struct Probing;
   | -------------- method `probe` not found for this struct
...
58 |     let _again = dev.probe();
   |                      ^^^^^ method not found in `Probing`
```

The illegal move is not an `Err` at run time any more. It is a **compile error**. The program cannot be
built, so it can never run on anyone's hardware.

> **▶ Try it.** Now uncomment block 3. It changes state, then tries to use the **old** state again.

```text
error[E0382]: use of moved value: `dev`
  --> enum_errors.rs:80:18
   |
78 |     let dev = Uninitialized;
   |         --- move occurs because `dev` has type `Uninitialized`, which does not implement the `Copy` trait
79 |     let _probing = dev.probe();
   |                        ------- `dev` moved due to this method call
80 |     let _twice = dev.probe();
   |                  ^^^ value used here after move
   |
note: `Uninitialized::probe` takes ownership of the receiver `self`, which moves `dev`
```

This is Day 1 doing the work. `probe` takes `self` by value, so calling it **moved** the old state into
the method, and the old state no longer exists. You cannot accidentally keep using a device that you
already moved on from. The compiler even points at the `self` in `probe` as the reason.

### Which one should you use?

| | Enum state machine | Typestate |
|---|---|---|
| An illegal change is caught | when the program runs (`Err`) | when you compile |
| Storing "the device, in whatever state it is in" in one variable | easy — it is one type | harder — each state is a different type |
| Best when | the state changes because of things that happen at run time, like hardware events | the order of steps is fixed and known while writing the code, like a setup sequence |

Both patterns appear in real kernel Rust. The rule of thumb: if you can know the order while writing
the code, let the compiler enforce it with typestate; if it depends on what happens at run time, use an
enum and let `match` make sure every state is handled.

---

## Your Turn (10 minutes)

Write your own state machine, from scratch, in a file called `my_link_state.rs`. It models a network
link:

```text
Down ──plug──▶ Negotiating ──link_up(speed)──▶ Up { speed }
  ▲                 │                              │
  └─────unplug──────┴──────────unplug──────────────┘
```

Write an enum `LinkState` with three variants: `Down`, `Negotiating`, and `Up` carrying a `speed`
(`u32`, in Mb/s). Give it three methods that take `self` and return `Result<LinkState, String>`: `plug`,
`link_up(speed)` and `unplug`. Add a `describe(&self) -> String` method that uses a `match` with **no**
catch-all. In `main`, go through a legal sequence, print each state with `describe`, and then try one
illegal move and print its error.

**Then** add a fourth variant, `Testing` (for a cable test), to the enum, and compile. Read where the
compiler says you must deal with it, and handle it there.

<details>
<summary>One possible solution, and its output</summary>

```rust
#[derive(Debug)]
enum LinkState {
    Down,
    Negotiating,
    Up { speed: u32 },
}

impl LinkState {
    fn plug(self) -> Result<LinkState, String> {
        match self {
            LinkState::Down => Ok(LinkState::Negotiating),
            other => Err(format!("cannot plug in while {:?}", other)),
        }
    }

    fn link_up(self, speed: u32) -> Result<LinkState, String> {
        match self {
            LinkState::Negotiating => Ok(LinkState::Up { speed }),
            other => Err(format!("cannot bring the link up while {:?}", other)),
        }
    }

    fn unplug(self) -> Result<LinkState, String> {
        match self {
            LinkState::Negotiating | LinkState::Up { .. } => Ok(LinkState::Down),
            other => Err(format!("cannot unplug while {:?}", other)),
        }
    }

    fn describe(&self) -> String {
        match self {
            LinkState::Down => String::from("no cable"),
            LinkState::Negotiating => String::from("talking to the other end"),
            LinkState::Up { speed } => format!("up at {} Mb/s", speed),
        }
    }
}

fn run() -> Result<LinkState, String> {
    let s = LinkState::Down;
    println!("{}", s.describe());
    let s = s.plug()?;
    println!("{}", s.describe());
    let s = s.link_up(1000)?;
    println!("{}", s.describe());
    let s = s.unplug()?;
    println!("{}", s.describe());
    Ok(s)
}

fn main() {
    if let Err(e) = run() {
        println!("error: {}", e);
    }
    match LinkState::Down.link_up(100) {
        Ok(s) => println!("?? {:?}", s),
        Err(e) => println!("{}", e),
    }
}
```

```text
no cable
talking to the other end
up at 1000 Mb/s
no cable
cannot bring the link up while Down
```

After adding `Testing`, the compiler points straight at `describe` — the one `match` without a
catch-all:

```text
error[E0004]: non-exhaustive patterns: `&LinkState::Testing` not covered
  --> link2.rs:32:15
   |
32 |         match self {
   |               ^^^^ pattern `&LinkState::Testing` not covered
```

(Your file name and line numbers will differ. It says `&LinkState::Testing` with an `&` because
`describe` matches on `&self`, a reference.) Handle it
by adding an arm such as `LinkState::Testing => String::from("running a cable test"),`. Notice that the
three transition methods did not complain: their `other =>` catch-alls quietly accepted the new state.
That is the trade-off from Part 3, seen in your own code.

</details>

Save your file and run the check:

```bash
cp my_link_state.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_4/
bash ~/LKD_RUST/codes/sync_to_repo.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/check_day4.sh
```

---

## Checking Yourself

Using the code from today, answer without running anything:

1. What does `DeviceState::Suspended { irq: 42 }.resume()` give back?
2. What does `DeviceState::Probing.remove()` give back?
3. In the typestate version, does `Ready { irq: 1 }.resume()` compile?
4. A list holds `[1, 2, 3]`. In what order does `while let Some(x) = list.pop()` see the numbers?
5. Which derive lets you write `a == b` for your own struct?

<details>
<summary>Answers</summary>

1. `Ok(DeviceState::Ready { irq: 42 })` — resuming is legal from `Suspended`, and the interrupt number
   carries over.
2. `Err("cannot remove while Probing")` — removing is only legal from `Ready` or `Suspended`.
3. No. `Ready` has only `suspend` and `remove`. Calling `resume` is `E0599`: no such method.
4. 3, then 2, then 1 — `pop` takes from the end.
5. `PartialEq`.

</details>

---

## Common Confusions

**"A C enum and a Rust enum are the same thing."** No. A C enum is a set of names for numbers, and the
variable can hold any number. A Rust enum value is always exactly one of its variants, and each variant
can carry its own data.

**"`_ =>` is a harmless way to finish a `match`."** On numbers it is necessary. On a state enum it hides
every variant added in the future, so the compiler can no longer show you what to update.

**"`if let` checks every variant."** It only checks one. Everything else is silently ignored — which is
exactly what you want sometimes, and a bug at other times.

**"The `else` in `let else` can do anything."** It must leave the surrounding code — usually with
`return`. If it could carry on, the variable would have no value.

**"`derive` is magic."** It writes ordinary code you could write yourself — for `PartialEq`, a comparison
of every field joined with `&&`.

**"`Copy` is free to add."** It is only allowed when every field is `Copy`, and never on a type that has
`Drop`. It also changes what assignment means: the value is duplicated instead of moved.

**"The enum state machine stops illegal changes."** It reports them, at run time. Only the typestate
version stops them from being written at all.

---

## My Notes

### The errors I caused on purpose

| Block | Error code | What the message told me | How I fixed it |
|---|---|---|---|
| 1 | `E0004` | | |
| 2 | `E0599` | | |
| 3 | `E0382` | | |
| 4 | `E0277` | | |
| 5 | `E0369` | | |

### My link state machine

What the compiler told me when I added `Testing`, and which methods did **not** complain:

### In my own words

What is the difference between a struct and an enum?

Why is a state stored as a plain number risky?

When would I choose typestate over an enum state machine?

### What I still do not understand

---

## Done When

You can explain the difference between an associated function and a method, and name the three ways a
method can take `self`.

You can explain why storing a state as a number is risky, and how an enum removes that risk — including
why the kernel's Rust PHY code needs a catch-all when it converts the C number.

You can write an enum whose variants carry different data, and you know that `Option` and `Result` are
ordinary enums.

You know that a `match` must cover every variant, you have read the `E0004` message, and you can explain
why `_ =>` is risky on a state enum.

You can use `if let`, `let else` and `while let`, and say when each one fits.

You can name the common derives and what each gives you, and explain what `derive(PartialEq)` actually
writes.

You can explain the difference between the enum state machine and the typestate version, and you have
seen an illegal typestate move fail to compile.

You wrote `my_link_state.rs`, added a fourth state, and followed the compiler to the `match` that needed
updating.

---

## Further Reading

**The Rust Book, Chapter 6 ("Enums and Pattern Matching")** covers enums, `Option`, `match` and
`if let` in more depth. **Chapter 19 ("Patterns and Matching")** lists every kind of pattern, including
`let else`.

**`rustc --explain E0004`** — the long explanation of the error you will see most often when working
with enums.

---

## If You Have More Time (optional)

**Read the real conversion.** Open `rust/kernel/net/phy.rs` in your tree, find `pub enum DeviceState`
near the top and `fn state` a little further down, and compare them with `enum phy_state` in
`include/linux/phy.h`.

**Add a state to the typestate version.** Add a `Resuming` struct between `Suspended` and `Ready`, so
that `resume` goes to `Resuming` and a new method takes `Resuming` to `Ready`. Notice how the compiler
guides you to every place that must change.

---

## 📖 Revision — Read This First When You Come Back

### The day as a story

Every device is always in some state, and many kernel bugs are code doing something in the wrong state.
C stores states as numbers: even a C `enum` is just names for integers, so a variable can hold a value
that is not a state at all, and nothing checks that every state is handled.

A Rust **enum** is a type whose value is exactly one of a fixed list of variants, and each variant can
carry its own data — a struct is *this and that*, an enum is *this or that*. `Option` and `Result` are
ordinary enums. When the kernel's Rust code reads a state from C, it converts the number into a real
enum once, at the boundary, with a catch-all for impossible numbers.

**`match`** must handle every variant. Forgetting one is error `E0004`, which names the missing variant —
so adding a variant later makes every `match` that needs updating stop compiling. Patterns can pull data
out, use `|` and guards, and `_` catches anything; but `_` on a state enum hides future variants. `if
let` handles one variant, `let else` takes a value out or leaves, and `while let` loops while a pattern
matches.

**`#[derive]`** asks the compiler to write common traits: `Debug` for printing, `Clone` and `Copy` for
copying, `PartialEq` for `==`, `Default` for a zero value. It writes ordinary code you could write by
hand.

A **state machine as an enum** stores the state in one type, with each change as a method that takes
`self` and returns a `Result`; illegal changes become errors at run time. The **typestate** pattern goes
further: each state is its own struct with only its legal methods, so an illegal change is a compile
error (`E0599`), and because each change takes `self` by value, the old state cannot be used again
(`E0382`).

### If you remember only five things

1. **A struct is *this and that*; an enum is *this or that*** — and its variants can carry data.
2. **A `match` must cover every variant** — the compiler names anything you forgot.
3. **Avoid `_ =>` on state enums** — it hides variants added later.
4. **`#[derive]` writes ordinary code for you** — `Debug`, `Clone`, `Copy`, `PartialEq`, `Default`.
5. **Typestate turns illegal state changes into compile errors**, and moves stop you reusing an old state.

### Quick recall

Answer each one out loud before opening the answers.

1. What is the difference between an associated function and a method?
2. Why can a C enum variable hold a value that is not one of its states?
3. What does it mean that an enum variant can carry data?
4. What error do you get when a `match` forgets a variant, and what does it tell you?
5. Why is `_ =>` risky on a state enum?
6. What must the `else` block in `let else` do?
7. In what order does `while let Some(x) = list.pop()` visit `[1, 2, 3]`?
8. What does `derive(PartialEq)` actually write?
9. When is an illegal move caught in the enum state machine, and when in typestate?
10. Why can you not use the old state after a typestate transition?

<details>
<summary>Answers</summary>

1. An associated function has no `self` and is called with `::`, like `Register::new`. A method takes
   `self`, `&self` or `&mut self` and is called with `.`.
2. In C, an enum is just a set of names for integers; underneath, the variable is an ordinary number.
3. Each variant can hold its own fields, in its own shape — like `ProbeOk { irq: u32 }` or
   `ProbeFailed(i32)`.
4. `E0004`, "non-exhaustive patterns". It names the missing variant, points at where it is defined, and
   suggests an arm to add.
5. It also catches any variant added in the future, so the compiler can no longer point out where the
   new variant needs handling.
6. It must leave the surrounding code, usually with `return`.
7. 3, 2, 1 — `pop` takes from the end.
8. A method that compares every field, joined with `&&`.
9. In the enum version, at run time, as an `Err`. In typestate, at compile time — the method does not
   exist on that state's type (`E0599`).
10. The transition takes `self` by value, so the old state is moved into the method and no longer
    exists (`E0382`).

</details>

### The code, in order

```bash
cd ~/rust-scratch
rustc enums_demo.rs -o enums
./enums 1        # struct shapes, associated functions, methods
./enums 2        # magic numbers vs an enum
./enums 3        # variants carrying data
./enums 5        # Option and Result are enums
./enums 4        # match: guards and catch-alls
./enums 6        # if let, let else, while let
./enums 7        # derive
./enums 8        # the enum state machine
./enums 9        # typestate

rustc enum_errors.rs -o ee       # uncomment blocks 1, 4, 5, 2, 3 as the parts tell you
rustc my_link_state.rs -o mine && ./mine
```

---

**Next:** M1W1D5 — Kernel Build System Basics and Reading Real C. You will learn how `Kconfig` options
and `Makefile` lines decide what gets built — the lines you searched on Day 3 — add a configuration
option of your own, and read a real C driver line by line.

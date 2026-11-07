// enum_errors.rs — M1W1D4. Five errors about enums, typestate and derive.
//
//   rustc enum_errors.rs -o ee && ./ee
//
// This file compiles as it is, because every error sits inside /* ... */.
// For each one:
//   1. remove the /* and */ around ONE block
//   2. predict the error before compiling
//   3. compile, and read EVERY line of the message
//   4. fix it, then put the /* and */ back before moving on
//
// Each block is complete on its own, so only ever uncomment one at a time.

fn main() {
    println!("enum_errors.rs — uncomment one block at a time\n");
    println!("  1. E0004  a match that forgets a variant");
    println!("  2. E0599  an illegal state change (typestate)");
    println!("  3. E0382  using an old state after a state change");
    println!("  4. E0277  printing with {{:?}} without derive(Debug)");
    println!("  5. E0369  comparing with == without derive(PartialEq)");
}

// ═════════════════════════════════════════════════════════════════
// ERROR 1 — E0004: a match that forgets a variant
/*
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
*/
// Why: a match must handle every variant. Forgetting one is a compile error,
// not a bug that waits for the day the device happens to be suspended.
// Fix hint: add the missing arm. Avoid `_ =>` here — it would also silently
// swallow any variant someone adds in the future.

// ═════════════════════════════════════════════════════════════════
// ERROR 2 — E0599: an illegal state change (typestate)
/*
struct Uninitialized;
struct Probing;

impl Uninitialized {
    fn probe(self) -> Probing {
        Probing
    }
}

fn error_2() {
    let dev = Uninitialized;
    let dev = dev.probe();
    let _again = dev.probe();
}
*/
// Why: `dev` is now a Probing, and Probing has no `probe` method. Probing a
// device that is already probing is not a legal move, so it cannot be written.
// Fix hint: delete the second probe, or decide it should exist and add it.

// ═════════════════════════════════════════════════════════════════
// ERROR 3 — E0382: using an old state after a state change
/*
struct Uninitialized;
struct Probing;

impl Uninitialized {
    fn probe(self) -> Probing {
        Probing
    }
}

fn error_3() {
    let dev = Uninitialized;
    let _probing = dev.probe();
    let _twice = dev.probe();
}
*/
// Why: probe takes `self` by value, so the first call MOVED the old state into
// it (Day 1). The old state no longer exists, so you cannot change it again.
// Fix hint: use the new state, not the old one.

// ═════════════════════════════════════════════════════════════════
// ERROR 4 — E0277: printing with {:?} without derive(Debug)
/*
struct Version {
    major: u8,
    minor: u8,
}

fn error_4() {
    let v = Version { major: 7, minor: 2 };
    println!("{:?}", v);
}
*/
// Why: {:?} needs the type to implement the Debug trait, and nobody wrote one.
// Fix hint: the compiler tells you the one line to add above the struct.

// ═════════════════════════════════════════════════════════════════
// ERROR 5 — E0369: comparing with == without derive(PartialEq)
/*
struct Version {
    major: u8,
    minor: u8,
}

fn error_5() {
    let a = Version { major: 7, minor: 2 };
    let b = Version { major: 7, minor: 2 };
    if a == b {
        println!("same");
    }
}
*/
// Why: Rust does not guess what "equal" means for your type. == needs the
// PartialEq trait, written by hand or by derive.
// Fix hint: #[derive(PartialEq)] above the struct.

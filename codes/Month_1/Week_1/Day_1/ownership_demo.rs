// ownership_demo.rs — M1W1D1. Ownership, moves, Copy, Clone, and Drop order.
//
// Deliberately a USERSPACE program, not a kernel module. The rules are identical,
// and here the edit->run loop is one second instead of a five-minute rebuild and
// boot. Port the ideas to the kernel once you can predict the output.
//
//   rustc ownership_demo.rs -o /tmp/ownership_demo && /tmp/ownership_demo
//
// No Cargo, no crates — same constraint the kernel works under.
//
// BEFORE YOU RUN IT: read each section and write down the order you expect.
// Getting a prediction wrong is the point; that is where the learning is.

use std::mem;

/// A value that announces its own destruction.
/// Holding a &'static str keeps it free of any allocation of its own.
struct Noisy(&'static str);

impl Drop for Noisy {
    // Called automatically. You never invoke this yourself — in fact you cannot.
    fn drop(&mut self) {
        println!("      drop: {}", self.0);
    }
}

impl Noisy {
    fn new(name: &'static str) -> Self {
        println!("      make: {}", name);
        Noisy(name)
    }
}

fn banner(n: u32, title: &str) {
    println!("\n{}. {}", n, title);
}

// ─────────────────────────────────────────────────────────────────
// 1. Values are dropped at the end of their scope, in REVERSE order.
fn scope_end() {
    banner(1, "End of scope, reverse declaration order");
    let _first = Noisy::new("first");
    let _second = Noisy::new("second");
    let _third = Noisy::new("third");
    println!("      -- end of function --");
    // third, second, first
}

// ─────────────────────────────────────────────────────────────────
// 2. An inner scope drops its values at its own closing brace.
fn nested_scope() {
    banner(2, "Nested scope drops early");
    let _outer = Noisy::new("outer");
    {
        let _inner = Noisy::new("inner");
        println!("      -- leaving inner block --");
    }
    println!("      -- back in outer, inner is already gone --");
}

// ─────────────────────────────────────────────────────────────────
// 3. Assignment MOVES. There is still only one value, so only one drop.
fn moves() {
    banner(3, "Move: one value, one owner, one drop");
    let a = Noisy::new("a");
    let b = a; // 'a' is now invalid. Using it is a COMPILE error, not a crash.
    println!("      moved a -> b, no drop happened during the move");
    // Uncomment to see the borrow checker stop a use-after-move:
    // println!("{}", a.0);
    //   error[E0382]: borrow of moved value: `a`
    let _ = &b;
}

// ─────────────────────────────────────────────────────────────────
// 4. Passing by value moves ownership INTO the function.
fn consume(n: Noisy) {
    println!("      consume() received {}", n.0);
    // n is dropped here, at the end of the callee, not the caller.
}

fn move_into_function() {
    banner(4, "Move into a function: it drops there, not here");
    let x = Noisy::new("x");
    consume(x);
    println!("      back in caller; x is already gone");
}

// ─────────────────────────────────────────────────────────────────
// 5. Early return drops exactly what is alive at that moment.
//    This is the whole `goto err_unlock` replacement, in miniature.
fn early_return(fail_after: u32) {
    banner(5, &format!("Early return with fail_after={}", fail_after));
    let _step1 = Noisy::new("step1");
    if fail_after == 1 {
        println!("      -- bailing out after step1 --");
        return; // only step1 is live, so only step1 drops
    }

    let _step2 = Noisy::new("step2");
    if fail_after == 2 {
        println!("      -- bailing out after step2 --");
        return; // step2 then step1
    }

    let _step3 = Noisy::new("step3");
    println!("      -- completed all three --");
    // step3, step2, step1
}

// ─────────────────────────────────────────────────────────────────
// 6. Copy types are duplicated, not moved. No Drop is involved.
fn copy_types() {
    banner(6, "Copy: integers are duplicated, both stay usable");
    let a: i32 = 42;
    let b = a; // a copy, not a move
    println!("      a = {}, b = {}  (both still valid)", a, b);

    // A type can NEVER be both Copy and Drop. If it needs cleanup, silently
    // duplicating it would mean cleaning up twice. Uncommenting this fails:
    //   #[derive(Clone, Copy)]
    //   struct Bad(u32);
    //   impl Drop for Bad { fn drop(&mut self) {} }
    //   error[E0184]: the trait `Copy` cannot be implemented for this type;
    //                 the type has a destructor
}

// ─────────────────────────────────────────────────────────────────
// 7. Clone is explicit duplication: two values means two drops.
#[derive(Clone)]
struct Tag(String);

impl Drop for Tag {
    fn drop(&mut self) {
        println!("      drop: Tag({})", self.0);
    }
}

fn clones() {
    banner(7, "Clone: an explicit second value, so a second drop");
    let original = Tag(String::from("original"));
    let copy = original.clone();
    println!("      two independent Tags now exist: {} / {}", original.0, copy.0);
    // copy, then original
}

// ─────────────────────────────────────────────────────────────────
// 8. Shadowing does NOT drop the shadowed value early.
fn shadowing() {
    banner(8, "Shadowing: the old value lives until end of scope");
    let v = Noisy::new("shadowed");
    println!("      the name v refers to: {}", v.0);
    let v = Noisy::new("shadowing");
    println!("      the name v now refers to: {}", v.0);
    println!("      but BOTH values are still alive — only the name was reused");
    // shadowing, then shadowed — still reverse declaration order
}

// ─────────────────────────────────────────────────────────────────
// 9. Drop can be suppressed. Leaking is safe in Rust — just usually wrong.
fn forgetting() {
    banner(9, "mem::forget suppresses Drop entirely");
    let kept = Noisy::new("kept");
    let leaked = Noisy::new("leaked");
    mem::forget(leaked); // destructor never runs
    println!("      forgot 'leaked'; only 'kept' will drop");
    let _ = &kept;
}

// ─────────────────────────────────────────────────────────────────
// 10. Collections drop their elements in order, front to back.
fn collections() {
    banner(10, "Vec drops its elements front to back");
    let v = vec![Noisy::new("elem0"), Noisy::new("elem1"), Noisy::new("elem2")];
    println!("      -- vec about to go out of scope --");
    let _ = &v;
}

fn main() {
    println!("=== ownership, moves, and Drop ===");
    println!("(predict each section before reading its output)");

    scope_end();
    nested_scope();
    moves();
    move_into_function();
    early_return(1);
    early_return(2);
    early_return(0);
    copy_types();
    clones();
    shadowing();
    forgetting();
    collections();

    println!("\n=== done ===");
}

// borrow_demo.rs — M1W1D2. Borrowing: who may look at a value, and when.
//
//   rustc borrow_demo.rs -o borrow
//   ./borrow 3      run only section 3 — predict it first, then look
//   ./borrow        run every section
//
// Everything in this file COMPILES — these are the shapes the borrow checker
// allows. The shapes it rejects live in borrow_errors.rs.

fn banner(n: u32, title: &str) {
    println!("\n──── {}. {} ────", n, title);
}

// ─────────────────────────────────────────────────────────────────
// 1. Why borrowing exists: passing by value MOVES, and the caller loses it.

fn length_by_value(s: String) -> usize {
    s.len()
} // s is dropped here — the caller's String is gone

fn length_by_reference(s: &String) -> usize {
    s.len()
} // s is only a borrow — nothing is dropped, the caller still owns the String

fn s1_why_borrowing() {
    banner(1, "Why borrowing exists");

    let a = String::from("moved away");
    let n = length_by_value(a);
    println!("by value:     len {} — but 'a' is now unusable", n);

    let b = String::from("still mine");
    let n = length_by_reference(&b);
    println!("by reference: len {} — and b is still '{}'", n, b);
}

// ─────────────────────────────────────────────────────────────────
// 2. Shared references (&T): as many readers as you like.
fn s2_shared() {
    banner(2, "Shared references (&T): many readers, no writers");

    let data = String::from("hello");
    let r1 = &data;
    let r2 = &data;
    let r3 = &data;

    println!("three readers agree: {} / {} / {}", r1, r2, r3);
    println!("and the owner can still read it too: {}", data);
    // {:p} prints the address a reference points at.
    println!("same address? {:p} {:p}", r1, r2);
}

// ─────────────────────────────────────────────────────────────────
// 3. Exclusive references (&mut T): exactly one, and it can change the value.
fn push_suffix(s: &mut String) {
    s.push_str("-modified");
}

fn s3_exclusive() {
    banner(3, "Exclusive references (&mut T): one writer, no other access");

    let mut data = String::from("original");
    println!("before: {}", data);
    push_suffix(&mut data);
    println!("after:  {}", data);
}

// ─────────────────────────────────────────────────────────────────
// 4. A borrow ends at its LAST USE, not at the end of the block.
fn s4_last_use() {
    banner(4, "A borrow ends at its last use");

    let mut v = vec![1, 2, 3];
    let first = &v[0];                      // the borrow starts here
    println!("first element is {}", first); // ...and ends here, at its last use
    v.push(4);                              // allowed: the borrow is already over
    println!("after push: {:?}", v);
    // Swap the println! and the push above and this stops compiling. Try it.
}

// ─────────────────────────────────────────────────────────────────
// 5. Slices: a pointer and a length, joined into one value.
fn sum(xs: &[i32]) -> i32 {
    let mut total = 0;
    for x in xs {
        total += x;
    }
    total
}

fn s5_slices() {
    banner(5, "Slices: pointer and length that CANNOT disagree");

    let v = vec![10, 20, 30, 40, 50];
    println!("whole:      {:?}  sum {}", &v[..], sum(&v));
    println!("from 1:     {:?}  sum {}", &v[1..], sum(&v[1..]));
    println!("first two:  {:?}  sum {}", &v[..2], sum(&v[..2]));
    println!("middle:     {:?}  sum {}", &v[1..4], sum(&v[1..4]));

    let s = &v[1..4];
    println!("the slice itself reports len {}", s.len());

    let arr = [1, 2, 3];
    println!("from a plain array: sum {}", sum(&arr));
}

// ─────────────────────────────────────────────────────────────────
// 6. Out of range: get() answers "nothing there" instead of crashing.
fn s6_bounds() {
    banner(6, "Bounds checking");

    let v = vec![1, 2, 3];
    match v.get(10) {
        Some(x) => println!("v[10] = {}", x),
        None => println!("v.get(10) = None (no panic, no corruption)"),
    }
    println!("v.get(1)  = {:?}", v.get(1));
    println!("v.len()   = {}", v.len());
    // v[10] would panic. In the kernel a panic stops the machine, which is why
    // kernel code prefers get() and handles the None.
}

// ─────────────────────────────────────────────────────────────────
// 7. Changing values through a mutable slice, and splitting one in two.
fn double_all(xs: &mut [i32]) {
    for x in xs {
        *x *= 2; // x is a reference to one number; *x is the number itself
    }
}

fn s7_mutable_slices() {
    banner(7, "Mutable slices and split_at_mut");

    let mut v = vec![1, 2, 3, 4];
    double_all(&mut v);
    println!("doubled: {:?}", v);

    // Two &mut into the same Vec are forbidden — but two into halves that
    // cannot overlap are fine, and split_at_mut gives you exactly that.
    let (left, right) = v.split_at_mut(2);
    left[0] = 100;
    right[0] = 200;
    println!("after split_at_mut: {:?}", v);
}

// ─────────────────────────────────────────────────────────────────
// 8. A reference does not own, so when a borrow ends, nothing is dropped.
struct Noisy(&'static str);

impl Noisy {
    fn new(name: &'static str) -> Self {
        println!("      make: {}", name);
        Noisy(name)
    }
}

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("      drop: {}", self.0);
    }
}

fn s8_references_dont_own() {
    banner(8, "References do not own: no drop when a borrow ends");

    let owner = Noisy::new("the value");
    {
        let borrowed = &owner;
        println!("      borrowed it: {}", borrowed.0);
        println!("      -- borrow scope ending, expect NO drop --");
    }
    println!("      still alive: {}", owner.0);
    println!("      -- function ending, NOW expect the drop --");
}

// ─────────────────────────────────────────────────────────────────
// 9. Where Day 1 meets Day 2: a lock guard.
//
// lock() hands out a guard holding the ONLY (exclusive) borrow of the counter,
// and the guard's Drop releases the lock. So you cannot forget to unlock, and
// you cannot touch the counter while the guard is alive.

struct Counter {
    value: i32,
}

// <'a> gives the guard's borrow a name, so the compiler can check the guard
// never outlives the counter. Lifetimes are Week 3: read it as "borrows a Counter".
struct CounterGuard<'a> {
    counter: &'a mut Counter,
}

impl Counter {
    fn lock(&mut self) -> CounterGuard<'_> {
        println!("      [lock acquired]");
        CounterGuard { counter: self }
    }
}

impl CounterGuard<'_> {
    fn get(&self) -> i32 {
        self.counter.value
    }

    fn set(&mut self, v: i32) {
        self.counter.value = v;
    }
}

impl Drop for CounterGuard<'_> {
    fn drop(&mut self) {
        println!("      [lock released]");
    }
}

fn s9_lock_guard() {
    banner(9, "Lock guards: ownership + exclusivity = safe locking");

    let mut counter = Counter { value: 41 };
    {
        let mut guard = counter.lock();
        println!("      read through guard: {}", guard.get());
        guard.set(42);
        // println!("{}", counter.value);   // error: the guard has the only borrow
        println!("      wrote through guard: {}", guard.get());
        println!("      -- guard going out of scope --");
    }
    println!("      after the block, counter.value is {}", counter.value);
}

// `./borrow 3` runs only section 3; plain `./borrow` runs them all.
// How this works (Option and match) is W1D4 material — ignore it for today.
fn wanted(section: &str) -> bool {
    match std::env::args().nth(1) {
        Some(arg) => arg == section,
        None => true,
    }
}

fn main() {
    println!("=== borrowing: who may look at it, and when ===");

    if wanted("1") { s1_why_borrowing(); }
    if wanted("2") { s2_shared(); }
    if wanted("3") { s3_exclusive(); }
    if wanted("4") { s4_last_use(); }
    if wanted("5") { s5_slices(); }
    if wanted("6") { s6_bounds(); }
    if wanted("7") { s7_mutable_slices(); }
    if wanted("8") { s8_references_dont_own(); }
    if wanted("9") { s9_lock_guard(); }

    println!("\n=== now go read borrow_errors.rs ===");
}

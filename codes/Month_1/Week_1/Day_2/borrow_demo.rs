// borrow_demo.rs — M1W1D2. Borrowing, references, and what the borrow checker allows.
//
//   rustc borrow_demo.rs -o /tmp/borrow_demo && /tmp/borrow_demo
//
// This file contains only code that COMPILES. It shows the legal shapes, so you
// can see what borrowing buys you. The illegal shapes live in borrow_errors.rs,
// and reading those error messages is the other half of today.
//
// Predict each section's output before you run it, same as yesterday.

use std::fmt;

fn banner(n: u32, title: &str) {
    println!("\n──── {}. {} ────", n, title);
}

// ─────────────────────────────────────────────────────────────────
// 1. The problem borrowing solves.
//
// Yesterday: passing a value MOVES it. So a function that only wants to read
// something would take it away from you forever. That is absurd, and borrowing
// is the fix.

fn length_by_value(s: String) -> usize {
    s.len()
    // s is dropped here - the caller's String is GONE
}

fn length_by_reference(s: &String) -> usize {
    s.len()
    // s is only a borrow. Nothing is dropped. The caller still owns the String.
}

fn s1_why_borrowing() {
    banner(1, "Why borrowing exists");

    let a = String::from("moved away");
    let n = length_by_value(a);
    println!("by value:     len {} — but 'a' is now unusable", n);
    // println!("{}", a);   // error[E0382]: borrow of moved value

    let b = String::from("still mine");
    let n = length_by_reference(&b);
    println!("by reference: len {} — and b is still '{}'", n, b);
}

// ─────────────────────────────────────────────────────────────────
// 2. Shared references: as many as you like, all read-only.
fn s2_shared() {
    banner(2, "Shared references (&T): many readers, no writers");

    let data = String::from("hello");

    let r1 = &data;
    let r2 = &data;
    let r3 = &data;

    println!("three readers agree: {} / {} / {}", r1, r2, r3);
    println!("and the owner can still read it too: {}", data);

    // All four names refer to the SAME bytes. No copying happened.
    println!("same address? {:p} {:p}", r1, r2);
}

// ─────────────────────────────────────────────────────────────────
// 3. Exclusive references: exactly one, and it can write.
fn push_suffix(s: &mut String) {
    s.push_str("-modified");
}

fn s3_exclusive() {
    banner(3, "Exclusive references (&mut T): one writer, no other access");

    let mut data = String::from("original");
    println!("before: {}", data);

    push_suffix(&mut data); // hand out the one exclusive borrow
    println!("after:  {}", data); // borrow is over, owner can read again

    // While a &mut exists you cannot make ANY other reference, not even a
    // read-only one. That is the aliasing rule, and it is the whole point.
}

// ─────────────────────────────────────────────────────────────────
// 4. Non-lexical lifetimes: a borrow ends at its LAST USE.
//
// This is why code that looks like it should be rejected compiles fine, and it
// is the main reason the borrow checker feels inconsistent to beginners.
fn s4_nll() {
    banner(4, "Non-lexical lifetimes: borrows end at last use");

    let mut v = vec![1, 2, 3];

    let first = &v[0]; // immutable borrow starts
    println!("first element is {}", first); // ...and ENDS here, at its last use

    v.push(4); // legal! the borrow above is already over
    println!("after push: {:?}", v);

    // Swap the two lines above and it stops compiling, because then the borrow
    // would still be live across the push. Try it.
}

// ─────────────────────────────────────────────────────────────────
// 5. Slices: a pointer and a length, welded into one value.
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

    // A slice knows its own length. There is no way to pass a length that
    // disagrees with the data, because they are the same value.
    let s = &v[1..4];
    println!("the slice itself reports len {}", s.len());

    // An array works too - a slice does not care where the memory came from.
    let arr = [1, 2, 3];
    println!("from a plain array: sum {}", sum(&arr));
}

// ─────────────────────────────────────────────────────────────────
// 6. Bounds are checked. Out of range is a panic, never silent corruption.
fn s6_bounds() {
    banner(6, "Bounds checking");

    let v = vec![1, 2, 3];

    // get() returns Option instead of panicking - the kernel-friendly way
    match v.get(10) {
        Some(x) => println!("v[10] = {}", x),
        None => println!("v.get(10) = None (no panic, no corruption)"),
    }

    println!("v.get(1)  = {:?}", v.get(1));
    println!("v.len()   = {}", v.len());

    // v[10] would panic with "index out of bounds". In USERSPACE that kills the
    // process. In the KERNEL a panic stops the machine - which is why kernel
    // code prefers get() and handles the None.
}

// ─────────────────────────────────────────────────────────────────
// 7. Mutable slices, and splitting one into two non-overlapping halves.
fn double_all(xs: &mut [i32]) {
    for x in xs.iter_mut() {
        *x *= 2; // *x to write THROUGH the reference
    }
}

fn s7_mutable_slices() {
    banner(7, "Mutable slices and split_at_mut");

    let mut v = vec![1, 2, 3, 4];
    double_all(&mut v);
    println!("doubled: {:?}", v);

    // Two &mut into the same Vec is forbidden. But two &mut into PROVABLY
    // non-overlapping halves is fine - and this is how the standard library
    // expresses that.
    let (left, right) = v.split_at_mut(2);
    left[0] = 100;
    right[0] = 200;
    println!("after split_at_mut: {:?}", v);
}

// ─────────────────────────────────────────────────────────────────
// 8. A reference does not own, so dropping one frees nothing.
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("      drop: {}", self.0);
    }
}

fn s8_references_dont_own() {
    banner(8, "References do not own: no drop when a borrow ends");

    let owner = Noisy::new_named("the value");
    {
        let borrowed = &owner;
        println!("      borrowed it: {}", borrowed.0);
        println!("      -- borrow scope ending, expect NO drop --");
    }
    println!("      still alive: {}", owner.0);
    println!("      -- function ending, NOW expect the drop --");
}

impl Noisy {
    fn new_named(name: &'static str) -> Self {
        println!("      make: {}", name);
        Noisy(name)
    }
}

// ─────────────────────────────────────────────────────────────────
// 9. Where Day 1 and Day 2 meet: the lock guard pattern.
//
// A lock hands you a guard. The guard gives EXCLUSIVE access to the data, and
// the guard's Drop releases the lock. Ownership (Day 1) plus exclusivity
// (Day 2) is exactly what makes kernel locking safe.

struct FakeLock<T> {
    data: T,
}

struct FakeGuard<'a, T> {
    lock: &'a mut FakeLock<T>,
}

impl<T> FakeLock<T> {
    fn new(data: T) -> Self {
        FakeLock { data }
    }

    // Returning a guard that borrows self EXCLUSIVELY means the compiler will
    // not let anyone else touch the lock while the guard is alive.
    fn lock(&mut self) -> FakeGuard<'_, T> {
        println!("      [lock acquired]");
        FakeGuard { lock: self }
    }
}

impl<T> FakeGuard<'_, T> {
    fn get(&self) -> &T {
        &self.lock.data
    }
    fn set(&mut self, v: T) {
        self.lock.data = v;
    }
}

impl<T> Drop for FakeGuard<'_, T> {
    fn drop(&mut self) {
        println!("      [lock released]");
    }
}

fn s9_lock_guard() {
    banner(9, "Lock guards: ownership + exclusivity = safe locking");

    let mut lock = FakeLock::new(41);

    {
        let mut guard = lock.lock();
        println!("      read through guard: {}", guard.get());
        guard.set(42);
        println!("      wrote through guard: {}", guard.get());
        println!("      -- guard going out of scope --");
    } // guard drops here, releasing the lock

    println!("      after the block, value is {}", lock.lock().get());

    // You CANNOT forget to unlock, because unlocking is the guard's destructor.
    // You CANNOT use the data without the guard, because the data is behind it.
    // That is Day 1 and Day 2 combined, and it is how kernel Mutex works.
}

// Bonus: Display for Noisy so {} works on it
impl fmt::Display for Noisy {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

fn main() {
    println!("=== borrowing: who may look at it, and when ===");

    s1_why_borrowing();
    s2_shared();
    s3_exclusive();
    s4_nll();
    s5_slices();
    s6_bounds();
    s7_mutable_slices();
    s8_references_dont_own();
    s9_lock_guard();

    println!("\n=== now go read borrow_errors.rs ===");
}

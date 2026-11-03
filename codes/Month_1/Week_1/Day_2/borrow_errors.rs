// borrow_errors.rs — M1W1D2. Five borrow-checker errors, made on purpose.
//
//   rustc borrow_errors.rs -o be && ./be
//
// This file compiles as it is, because every error sits inside /* ... */.
// For each one:
//   1. remove the /* and */ around ONE block
//   2. predict the error before compiling
//   3. compile, and read EVERY line of the message
//   4. fix it, then put the /* and */ back before moving on
//
// Reading an error you caused yourself, while you still remember what you
// wrote, is the fastest way to learn to read rustc.

fn main() {
    println!("borrow_errors.rs — uncomment one block at a time\n");
    println!("  1. E0502  reading and changing at the same time");
    println!("  2. E0499  two writers at once");
    println!("  3. E0106  returning a reference to something that is about to die");
    println!("  4. E0596  changing something you said would not change");
    println!("  5. E0505  giving away something that is still borrowed");
}

// ═════════════════════════════════════════════════════════════════
// ERROR 1 — E0502: reading and changing at the same time
/*
fn error_1() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];      // a shared borrow of v starts
    v.push(4);              // push needs an exclusive borrow — conflict
    println!("{}", first);  // the shared borrow is still used here
}
*/
// Why: push() may move the list to a bigger piece of memory and free the old
// one. `first` points into the old memory, so it would point at freed memory.
// Fix hint: finish using `first` before the push.

// ═════════════════════════════════════════════════════════════════
// ERROR 2 — E0499: two writers at once
/*
fn error_2() {
    let mut s = String::from("hi");
    let a = &mut s;
    let b = &mut s;
    a.push('!');
    b.push('?');
}
*/
// Why: two exclusive borrows alive together means two writers that do not
// know about each other. On several CPUs at once, that is a data race.
// Fix hint: finish using `a` before creating `b`.

// ═════════════════════════════════════════════════════════════════
// ERROR 3 — E0106: returning a reference to something that is about to die
/*
fn error_3() -> &String {
    let s = String::from("local");
    &s
}
*/
// Why: `s` is dropped at the end of the function, so a reference to it would
// point at freed memory. Rust rejects the signature itself: there is nothing
// for the returned reference to borrow from.
// Fix hint: return the String itself, not a reference to it.

// ═════════════════════════════════════════════════════════════════
// ERROR 4 — E0596: changing something you said would not change
/*
fn error_4() {
    let s = String::from("not mut");
    let r = &mut s;
    r.push('!');
}
*/
// Why: `let` without `mut` is a promise not to change `s`. Asking for &mut
// breaks that promise.
// Fix hint: the compiler shows you exactly where to add one word.

// ═════════════════════════════════════════════════════════════════
// ERROR 5 — E0505: giving away something that is still borrowed
/*
fn consume(v: Vec<i32>) -> usize {
    v.len()
}

fn error_5() {
    let v = vec![1, 2, 3];
    let first = &v[0];
    let n = consume(v);
    println!("{} {}", first, n);
}
*/
// Why: consume() takes ownership of the list and drops it, while `first` still
// points into it. Day 1 (moves) meets Day 2 (borrows).
// Fix hint: make consume borrow instead — take `&[i32]` — and call consume(&v).

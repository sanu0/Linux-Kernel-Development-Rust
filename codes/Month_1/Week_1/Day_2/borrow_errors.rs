// borrow_errors.rs — M1W1D2. Five borrow-checker errors, on purpose.
//
// This file COMPILES AS-IS, because every error is commented out. The exercise
// is to uncomment ONE block at a time, compile, and read the whole message
// before fixing it.
//
//   rustc borrow_errors.rs -o /tmp/be && /tmp/be
//
// Why do it this way round? Because reading a compiler error you caused
// deliberately, while you still remember exactly what you wrote, teaches you
// far more than reading documentation about that error later. Learning to read
// rustc is the skill that decides whether Rust feels like a collaborator or an
// obstacle, and there is no shortcut to it.
//
// For each one: PREDICT the error before you compile. Then read every line of
// the message - rustc tells you where the borrow started, where it conflicted,
// and where the original was used later. Most compilers give you one of those.

fn main() {
    println!("borrow_errors.rs — uncomment one block at a time\n");
    println!("  1. E0502  mutable and immutable borrow overlap");
    println!("  2. E0499  two mutable borrows at once");
    println!("  3. E0106  returning a reference to a local");
    println!("  4. E0596  mutable borrow of a non-mut binding");
    println!("  5. E0505  moving a value that is still borrowed");
    println!("\nEach one has a FIX note. Try to fix it yourself first.");
}

// ═════════════════════════════════════════════════════════════════
// ERROR 1 — E0502: mutable and immutable borrow overlap
//
// The single most common borrow error, and the most important to understand.
// Predict: why can push() not be allowed here?
/*
fn error_1() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];      // immutable borrow starts
    v.push(4);              // needs a MUTABLE borrow - conflict
    println!("{}", first);  // immutable borrow still in use here
}
*/
// WHY IT IS REJECTED, and this is the part worth understanding:
// push() may need more capacity. If it does, Vec allocates a NEW buffer, copies
// the elements over, and frees the old one. `first` pointed into the old buffer.
// So `first` would be a dangling pointer to freed memory - a use-after-free.
//
// In C++ this exact code compiles and is a famous source of crashes, because
// iterators and pointers into a vector are invalidated by growth. Here it is a
// compile error.
//
// Note it is rejected even when the Vec has spare capacity and no reallocation
// would actually happen. The rule is about what push() is ALLOWED to do, not
// what it happens to do this time. The borrow checker reasons from signatures,
// never from runtime luck.
//
// FIX: finish with the borrow before mutating - move the println! above the
// push, and non-lexical lifetimes will end the borrow at its last use. Or copy
// the value out with `let first = v[0];` so nothing is borrowed at all.

// ═════════════════════════════════════════════════════════════════
// ERROR 2 — E0499: two mutable borrows at once
//
// This is the aliasing rule in its purest form.
/*
fn error_2() {
    let mut s = String::from("hi");
    let a = &mut s;    // first exclusive borrow
    let b = &mut s;    // second - forbidden
    a.push('!');
    b.push('?');
}
*/
// WHY: two live &mut to the same value means two pieces of code can write to it
// with neither knowing about the other. Single-threaded that is merely confusing;
// across CPUs it is a data race, which is undefined behaviour.
//
// This rule is what makes data races impossible in safe Rust. In a kernel where
// the same function runs simultaneously on a hundred cores, that guarantee is
// worth a great deal.
//
// FIX: use them one at a time, so the first borrow ends before the second
// begins. Or if you genuinely need two writers into one structure, they must be
// writing to non-overlapping PARTS - see split_at_mut in borrow_demo.rs.

// ═════════════════════════════════════════════════════════════════
// ERROR 3 — E0106: returning a reference to a local
//
// In C this compiles with at most a warning, and is a classic crash.
/*
fn error_3() -> &String {
    let s = String::from("local");
    &s      // s dies at the closing brace; the reference would dangle
}
*/
// WHY: `s` is owned by this function. At the closing brace it is dropped and its
// memory freed. A reference to it would point at freed memory the instant the
// caller received it.
//
// Notice WHICH error you get. Rust rejects the SIGNATURE before it even looks at
// the body: "missing lifetime specifier ... this function's return type contains
// a borrowed value, but there is no value for it to be borrowed from."
//
// That phrasing is the real lesson. A reference always borrows FROM something.
// This function has no input to borrow from and cannot borrow from its own
// locals, so there is no possible answer - hence no valid signature.
//
// This is the C bug "return a pointer to a stack variable", which has caused
// countless kernel crashes, turned into a signature that cannot be written.
//
// FIX: return the owned String instead of a reference - change `-> &String` to
// `-> String` and `&s` to `s`. Lifetimes proper are Week 3.

// ═════════════════════════════════════════════════════════════════
// ERROR 4 — E0596: mutable borrow of a non-mut binding
//
// The simplest of the five, and it catches a real class of mistake.
/*
fn error_4() {
    let s = String::from("not mut");   // no `mut`
    let r = &mut s;                    // asking to write to it anyway
    r.push('!');
}
*/
// WHY: you declared that you would not change `s`, then asked for permission to
// change it. Immutability is the default in Rust precisely so that mutation is
// visible at every point it could happen - including the declaration.
//
// The value of this error is documentation that cannot go stale. Reading a
// function body, every `let` without `mut` is a guarantee, not a hope.
//
// FIX: `let mut s = ...`. rustc even shows you exactly where to add it.

// ═════════════════════════════════════════════════════════════════
// ERROR 5 — E0505: moving a value that is still borrowed
//
// This one ties Day 1 and Day 2 together, which is why it is last.
/*
fn consume(v: Vec<i32>) -> usize {
    v.len()
}

fn error_5() {
    let v = vec![1, 2, 3];
    let first = &v[0];      // borrow of v
    let n = consume(v);     // moves v away while the borrow is alive
    println!("{} {}", first, n);
}
*/
// WHY: `consume` takes the Vec by value, so it takes ownership - and drops it at
// the end of consume. But `first` is a reference into that Vec's buffer. After
// the move the buffer is freed and `first` dangles.
//
// This is Day 1 (moves transfer ownership) meeting Day 2 (references borrow
// from an owner). You cannot move something out from under a live borrow,
// because the borrow's whole validity depends on the owner still being there.
//
// rustc suggests `v.clone()`, which would work. Think about whether you want it:
// cloning allocates and copies, and in kernel code an allocation can fail. The
// suggestion silences the error; it does not necessarily answer the design
// question.
//
// FIX: finish with `first` before moving `v`, or pass a reference with
// `consume(&v)` and change the signature to `&[i32]` so nothing moves at all.
// That second option is almost always the right one.

// ═════════════════════════════════════════════════════════════════
// NOW WRITE TWO OF YOUR OWN.
//
// Predict the error code before compiling each time.
//
//   a) Hold a reference into a Vec, then call v.clear(), then use the reference.
//   b) Take &mut to one element of an array while holding &mut to another,
//      by indexing directly rather than using split_at_mut.
//
// (b) is interesting: it is REJECTED even though the two elements genuinely do
// not overlap. The borrow checker cannot prove that two runtime indices differ,
// so it refuses. That is a real limitation, not a bug - and split_at_mut exists
// precisely because someone had to write the proof once, inside the standard
// library, using unsafe, so that you never have to.
//
// Remember that shape. In Month 5 you will write abstractions with exactly that
// job: a small audited unsafe core that hands out a safe interface.

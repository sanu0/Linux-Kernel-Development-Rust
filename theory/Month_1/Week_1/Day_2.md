# M1W1D2 — Borrowing and the Borrow Checker

> **What you need to know already:** Rust up to structs, plus yesterday's ownership — one owner,
> moves, and `drop`. Anything beyond that is explained in a **🆕 New Rust** box at the moment it first
> appears.
>
> **Time:** about 90 minutes, including running every example. No kernel builds today.

Yesterday's question was *who is responsible for cleaning this up?* Today's question is *who is allowed
to use it, and when?*

Yesterday's rules make double frees impossible. But on their own, they would make Rust almost unusable,
because handing a value to a function gives it away forever. Today you learn **borrowing**, which fixes
that, and the one rule the compiler enforces about borrows. That rule has a valuable side effect: it
makes data races impossible. In a kernel, where the same code runs on many CPUs at the same moment,
that matters a great deal.

You will also learn to read the compiler's error messages. You will cause five errors on purpose and
read every line of each one. That may sound like an odd way to spend time, but it is the most useful
skill of the week. People who read Rust's errors find the compiler helpful; people who skip them find
it frustrating.

As yesterday, **predict each example's output before you run it.**

| Part | What you will learn | Time |
|---|---|---|
| Before you start | Set up the example programs | 5 min |
| 1 | Why borrowing exists | 10 min |
| 2 | References, and the one rule | 15 min |
| 3 | Why the rule matters, and when a borrow ends | 15 min |
| 4 | Slices | 10 min |
| 5 | Where Day 1 meets Day 2: the lock guard | 5 min |
| 6 | Reading the compiler: five errors | 20 min |
| Your turn | Two errors of your own, and check yourself | 10 min |

---

## Before You Start (5 minutes)

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_2/borrow_demo.rs .
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_2/borrow_errors.rs .
rustc borrow_demo.rs -o borrow
```

If you see `rustc: command not found`, run `export PATH="$HOME/.cargo/bin:$PATH"` and try again.

Like yesterday's demo, this one has numbered sections — nine of them. You can run just one:

```bash
./borrow 3      # runs only section 3
./borrow        # runs all nine
```

The program is called `borrow` rather than `demo` so it does not overwrite yesterday's `demo`.

---

## Part 1 — Why Borrowing Exists (10 minutes)

### The problem

Suppose you want a function that tells you how long a string is. With only yesterday's rules, you
would write:

```rust
fn length_by_value(s: String) -> usize {
    s.len()
}
```

`usize` is the type Rust uses for sizes and lengths, and `s.len()` gives the length of the string.
Now use it:

```rust
let a = String::from("moved away");
let n = length_by_value(a);
```

Think about what happened, using yesterday's rules. Passing `a` to the function **moved** it. The
parameter `s` became the owner, and when the function ended, `s` went out of scope and the string was
dropped. You asked a question about your string, and now your string is gone. Using `a` afterwards is
a compile error.

You could work around it by making the function hand the string back, along with the answer. But
then every function that looks at anything would have to return it, and every caller would have to
catch it again. Nobody would want to write code like that.

What we need is a way to let a function **look at** a value without **taking** it.

### The fix: references

> **🆕 New Rust — references (`&`)**
>
> A **reference** lets you use a value without owning it. Writing `&b` creates a reference to `b`. In
> a type, `&String` means "a reference to a String". Using a value through a reference is called
> **borrowing**.

```rust
fn length_by_reference(s: &String) -> usize {
    s.len()
}

let b = String::from("still mine");
let n = length_by_reference(&b);
println!("{}", b);          // fine — b was never given away
```

The `&b` at the call creates a reference. The `&String` in the signature says "I accept a reference,
not the string itself." Nothing moved. The function used the string, returned, and `b` still owns it.

> **▶ Try it.** Predict both lines, then run `./borrow 1`.

```text
──── 1. Why borrowing exists ────
by value:     len 10 — but 'a' is now unusable
by reference: len 10 — and b is still 'still mine'
```

The word "borrow" is chosen carefully. When you borrow a book, you can read it, you must give it back,
and you are not allowed to throw it away. Rust references follow the same rules, and the compiler
checks every one of them.

### A borrow ending does not drop anything

A reference is not an owner, so when a reference goes away, nothing is cleaned up. You can see this
with yesterday's `Noisy` type:

```rust
let owner = Noisy::new("the value");
{
    let borrowed = &owner;
    println!("      borrowed it: {}", borrowed.0);
}
println!("      still alive: {}", owner.0);
```

> **▶ Try it.** Will there be a `drop` line when the inner block ends? Run `./borrow 8`.

```text
──── 8. References do not own: no drop when a borrow ends ────
      make: the value
      borrowed it: the value
      -- borrow scope ending, expect NO drop --
      still alive: the value
      -- function ending, NOW expect the drop --
      drop: the value
```

The inner block ended, and nothing was dropped. There is still exactly one owner, `owner`, and the value
dies when *it* goes out of scope. Borrowing never creates a second owner, and that is exactly why it
is safe.

---

## Part 2 — References, and the One Rule (15 minutes)

### Two kinds of reference

Rust has two kinds of reference, and the difference between them is the main subject of today.

A **shared reference**, written `&T`, lets you **read**. You can have as many of these as you like at
the same time.

An **exclusive reference**, written `&mut T`, lets you **read and change**. You can have only **one**,
and while it exists, there can be no other references to that value at all — not even read-only ones,
and not even the owner reading it directly.

(`T` here just stands for "any type": `&String`, `&i32`, and so on.)

Those two sentences combine into the one rule:

> **At any moment, a value can have either any number of shared references, or exactly one exclusive
> reference. Never both.**

You will also hear these called "immutable" and "mutable" references. "Shared" and "exclusive" are
better names, because they describe what the compiler actually guarantees.

### Many readers

```rust
let data = String::from("hello");
let r1 = &data;
let r2 = &data;
let r3 = &data;
println!("three readers agree: {} / {} / {}", r1, r2, r3);
println!("and the owner can still read it too: {}", data);
println!("same address? {:p} {:p}", r1, r2);
```

> **🆕 New Rust — `{:p}`**
>
> Inside `println!`, `{:p}` prints the memory address a reference points to, instead of the value.

```text
──── 2. Shared references (&T): many readers, no writers ────
three readers agree: hello / hello / hello
and the owner can still read it too: hello
same address? 0x7fffcbd2f1c8 0x7fffcbd2f1c8
```

Look at the addresses: they are the same. All of those names lead to the **same** string in memory.
Nothing was copied. (Your addresses will be different numbers, but the two will match each other.)

### One writer

```rust
fn push_suffix(s: &mut String) {
    s.push_str("-modified");
}

let mut data = String::from("original");
push_suffix(&mut data);
println!("after:  {}", data);
```

```text
──── 3. Exclusive references (&mut T): one writer, no other access ────
before: original
after:  original-modified
```

Two things had to be true for this to compile. The variable had to be declared `let mut`, because you
cannot let someone change a value you said would not change. And `&mut data` had to be the only
reference to `data` at that moment. Inside `push_suffix`, `push_str` adds text to the end of a string,
and because `s` is an exclusive reference, it changes the caller's string directly.

> **▶ Try it.** Run `./borrow 2` and `./borrow 3`, and check the outputs above.

### Why this rule?

Look at the three possible situations one at a time.

**Many readers, no writer, is safe.** If nobody can change the value, everyone reading it sees the same
thing, and it stays that way while they look.

**One writer and nobody else is safe.** If only one piece of code can touch the value, nothing can
surprise it. It makes a change, and the next time it looks, it sees exactly its own change.

**Any mixture is where bugs come from.** Two writers means two pieces of code changing the same memory
without knowing about each other. When they run on different CPUs at the same moment, that is called a
**data race**, and it leads to quietly corrupted data. One writer plus one reader is just as bad in a
quieter way: the reader can see the value *halfway* through a change. Imagine the writer is updating a
pointer and a length together. The reader might see the new pointer with the old length, read past the
end of the memory, and nothing in the code looks wrong.

So the rule is not the compiler being fussy. It is exactly the line between situations that are always
safe and situations that are sometimes disastrous.

**This rule is what makes data races impossible in safe Rust.** A data race needs two things touching the
same memory with at least one of them writing, and the compiler will not let you build that situation.
In a kernel running on dozens of CPUs at once, that guarantee is worth a lot.

---

## Part 3 — Why the Rule Matters, and When a Borrow Ends (15 minutes)

### The most common borrow error

You might think the rule only matters when several CPUs are involved. It matters even in simple
single-threaded code, and this example shows why. It is also the borrow error you will meet most
often, so it is worth understanding properly.

```rust
let mut v = vec![1, 2, 3];
let first = &v[0];
v.push(4);
println!("{}", first);
```

`&v[0]` is a reference to the first item in the list. This code does not compile:

```text
error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable
 --> e1.rs:4:5
  |
3 |     let first = &v[0];
  |                  - immutable borrow occurs here
4 |     v.push(4);
  |     ^^^^^^^^^ mutable borrow occurs here
5 |     println!("{}", first);
  |                    ----- immutable borrow later used here
```

Read the message carefully. It points at three lines and says what each one did: where the shared
borrow started (line 3), where an exclusive borrow clashed with it (line 4 — `push` needs to change
the list), and where the shared borrow was still used afterwards (line 5). That last line is the key:
the conflict only exists because `first` is used *after* the push.

### Why this would be a real bug

Remember from yesterday that a `Vec` keeps its items on the heap, in a piece of memory with room for a
certain number of items. When you push and that memory is already full, the `Vec` cannot just grow in
place — the memory right after it may belong to something else. So it asks for a **new, bigger** piece
of memory, copies every item across, and **frees the old piece**:

```text
before push:   v ─────▶ [ 1 | 2 | 3 ]                 old memory, full
               first ──▶  ↑ points at the 1

after push:    v ─────▶ [ 1 | 2 | 3 | 4 |   |   ]     new, bigger memory
                        [ 1 | 2 | 3 ]                 old memory — FREED
               first ──▶  ↑ still points in here
```

`first` pointed into the old memory, and that memory has now been given back. Reading through `first`
would be a **use-after-free** — yesterday's worst bug — appearing in four innocent-looking lines.
Other languages, such as C++, let exactly this code compile, and it is a famous cause of crashes.
Rust stops it before the program is built.

### The surprising part

The code is rejected **even when the list has spare room**, and no new memory would actually be needed.

That can feel unfair: you can see there is room, so nothing would move. But the compiler does not reason
about what happens to be true at runtime. It reasons about what `push` is **allowed** to do. `push`
takes an exclusive reference to the list, which means it is allowed to do anything, including moving
the list to new memory.

This is worth remembering, because it explains most of your future arguments with the compiler:

> **The borrow checker judges code by what functions are allowed to do, never by luck at runtime.**

That is what makes its guarantee worth having. A check that passed when there happened to be spare room,
and failed when there was not, would be useless.

### A borrow ends at its last use

Now something that will save you a lot of confusion. A borrow does **not** last until the end of the
block. It lasts until the reference is **used for the last time**:

```rust
let mut v = vec![1, 2, 3];
let first = &v[0];                      // the borrow starts here
println!("first element is {}", first); // ...and ends here, at its last use
v.push(4);                              // allowed: the borrow is already over
println!("after push: {:?}", v);
```

`{:?}` prints a value in a debugging format; for a list, it prints the items in square brackets.

> **▶ Try it.** This is the same code as the error above with two lines swapped. Does it compile? Run
> `./borrow 4`.

```text
──── 4. A borrow ends at its last use ────
first element is 1
after push: [1, 2, 3, 4]
```

It compiles. The name `first` still exists until the closing `}`, but it is never used after the
`println!`, so the borrow it holds has already ended when `push` happens. The compiler tracks where a
reference is actually *used*, not just where its name exists. This is called **non-lexical
lifetimes**.

This gives you a practical habit: **when you get a borrow error, look at where the borrow is last
used.** Very often, the fix is to move one line so the borrow finishes before the change begins.

> **▶ Try it.** In `borrow_demo.rs`, find `fn s4_last_use()` and swap the `println!("first element...")`
> line with the `v.push(4);` line. Compile with `rustc borrow_demo.rs -o borrow` and read the error —
> it is the same `E0502` as above. Then swap them back.

---

## Part 4 — Slices (10 minutes)

### A bug C cannot prevent

In C, a function that works on part of an array takes a pointer and a length as two separate
arguments:

```c
void process(int *buf, size_t len);
```

Nothing connects those two arguments. Nothing checks that `len` really is the length of `buf`. You can
write `process(buf, len + 1)` and it compiles without a word. Almost every buffer overflow in the
kernel's history comes down to a pointer and a length that disagreed.

### Rust's answer: the slice

> **🆕 New Rust — slices and ranges**
>
> A **slice** is a view of some items in a row, such as part of a list or an array. It is a reference,
> so it does not own the items. Its type is written `&[i32]`: "a slice of `i32`s".
>
> You make one with a **range** inside square brackets: `&v[1..4]` means items 1, 2 and 3 (the end
> number is not included). `&v[..2]` starts at the beginning, `&v[1..]` runs to the end, and `&v[..]`
> is all of it.

Under the hood, a slice is a pointer **and** a length, joined together into a single value:

```rust
fn sum(xs: &[i32]) -> i32 {
    let mut total = 0;
    for x in xs {
        total += x;
    }
    total
}
```

> **▶ Try it.** Run `./borrow 5`.

```text
──── 5. Slices: pointer and length that CANNOT disagree ────
whole:      [10, 20, 30, 40, 50]  sum 150
from 1:     [20, 30, 40, 50]  sum 140
first two:  [10, 20]  sum 30
middle:     [20, 30, 40]  sum 90
the slice itself reports len 3
from a plain array: sum 6
```

Notice that `sum` has **no length parameter**. It does not need one: the slice carries its own length.
You cannot pass the wrong length, because you never pass a length at all. The last line shows that a
slice works for a plain array too — it does not care where the items came from.

### Out of range

What if you ask for an item that is not there?

> **🆕 New Rust — `Option`: `Some` and `None`**
>
> `Option` is like yesterday's `Result`, but for "there might be nothing here". It is always one of
> two things: `Some(value)` when there is a value, or `None` when there is not. You read it with
> `match`, just like a `Result`.

```rust
let v = vec![1, 2, 3];
match v.get(10) {
    Some(x) => println!("v[10] = {}", x),
    None => println!("v.get(10) = None (no panic, no corruption)"),
}
```

```text
──── 6. Bounds checking ────
v.get(10) = None (no panic, no corruption)
v.get(1)  = Some(2)
v.len()   = 3
```

There are two ways to ask for item 10. Writing `v[10]` **panics** — the program stops. It never reads
someone else's memory, which is good, but remember from yesterday: in the kernel, a panic stops the
whole machine. Writing `v.get(10)` returns `None` instead, and you decide what to do. **Kernel code
prefers `get`** for exactly this reason.

### Changing items through a slice

> **🆕 New Rust — `*` (getting at the value behind a reference)**
>
> If `x` is a reference to a number, `*x` means "the number it points to". So `*x *= 2` doubles the
> number itself, not the reference. This is called **dereferencing**.

```rust
fn double_all(xs: &mut [i32]) {
    for x in xs {
        *x *= 2;
    }
}
```

`&mut [i32]` is an exclusive slice, so it can change the items. Looping over it gives you an exclusive
reference to each number in turn.

The rule says you cannot have two exclusive references to the same list. But sometimes you really do
want to change two different **parts** of one list at once — and if the parts cannot overlap, that is
perfectly safe. `split_at_mut` gives you exactly that:

```rust
let mut v = vec![1, 2, 3, 4];
double_all(&mut v);
let (left, right) = v.split_at_mut(2);
left[0] = 100;
right[0] = 200;
```

`split_at_mut(2)` cuts the list into two exclusive slices: items 0–1 and items 2–3. It returns them as
a pair, which `let (left, right) = ...` unpacks, just like unpacking a tuple.

> **▶ Try it.** Run `./borrow 6` and `./borrow 7`.

```text
──── 7. Mutable slices and split_at_mut ────
doubled: [2, 4, 6, 8]
after split_at_mut: [100, 4, 200, 8]
```

Two exclusive slices into one list, both in use at the same time, and the rule still holds — because
the halves cannot overlap. Keep this shape in mind. Somebody wrote `split_at_mut` once, very carefully,
and wrapped it in a safe function that nobody can misuse. In Month 5, writing safe wrappers like this
around the kernel's C code becomes your job.

---

## Part 5 — Where Day 1 Meets Day 2: The Lock Guard (5 minutes)

In C, protecting a counter with a lock looks like this:

```c
mutex_lock(&f->lock);
f->counter++;
mutex_unlock(&f->lock);
```

Locking and unlocking are two separate calls, and everything depends on you. If you return early
between them, the lock is never released and the system freezes — that is what yesterday's
`err_unlock` label was there to prevent. And nothing stops you from touching `f->counter` somewhere
else **without** taking the lock at all.

Section 9 of the demo builds the Rust version in miniature. Calling `lock()` hands you a **guard**, and
the counter can only be reached through that guard:

> **🆕 New Rust — `<'a>` and `'_`**
>
> When a struct holds a reference, Rust needs a name for that borrow, so it can check the struct never
> outlives the thing it borrows. `struct CounterGuard<'a>` gives the borrow the name `'a`, and `'_`
> means "the borrow from here". These are **lifetimes**, and they are Week 3. For today, read
> `CounterGuard<'a>` simply as "a guard that borrows a Counter".

```rust
struct CounterGuard<'a> {
    counter: &'a mut Counter,      // the guard holds the ONLY borrow of the counter
}

impl Drop for CounterGuard<'_> {
    fn drop(&mut self) {
        println!("      [lock released]");
    }
}
```

```rust
let mut counter = Counter { value: 41 };
{
    let mut guard = counter.lock();
    println!("      read through guard: {}", guard.get());
    guard.set(42);
    println!("      wrote through guard: {}", guard.get());
}
println!("      after the block, counter.value is {}", counter.value);
```

> **▶ Try it.** Run `./borrow 9`.

```text
──── 9. Lock guards: ownership + exclusivity = safe locking ────
      [lock acquired]
      read through guard: 41
      wrote through guard: 42
      -- guard going out of scope --
      [lock released]
      after the block, counter.value is 42
```

Two guarantees are working together here, one from each day.

**You cannot forget to unlock** — that is Day 1. Unlocking happens in the guard's `drop`, so it runs
when the guard goes out of scope: at the closing brace, at a `return`, at a `?`, on every path.

**You cannot touch the counter without the lock** — that is Day 2. The guard holds the *only*
(exclusive) borrow of the counter, so while the guard is alive, nothing else can reach it. In the demo
there is a commented-out line inside the block that reads `counter.value` directly. Uncomment it and
the compiler refuses:

```text
error[E0502]: cannot borrow `counter.value` as immutable because it is also borrowed as mutable
    |
221 |         let mut guard = counter.lock();
    |                         ------- mutable borrow occurs here
...
224 |         println!("{}", counter.value);
    |                        ^^^^^^^^^^^^^ immutable borrow occurs here
225 |         println!("      wrote through guard: {}", guard.get());
    |                                                   ----- mutable borrow later used here
```

In C, "this field is protected by this lock" is a comment that people have to remember. Here it is
something the compiler checks. This is how the kernel's real Rust `Mutex` works, and you will use it in
Month 3.

---

## Part 6 — Reading the Compiler: Five Errors (20 minutes)

### How to read an error message

Every borrow error has the same parts. Once you know them, the messages stop looking scary. Take the
one from Part 3:

```text
error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable
 --> e1.rs:4:5
  |
3 |     let first = &v[0];
  |                  - immutable borrow occurs here
4 |     v.push(4);
  |     ^^^^^^^^^ mutable borrow occurs here
5 |     println!("{}", first);
  |                    ----- immutable borrow later used here
```

The **first line** is a one-sentence summary, and `E0502` is a permanent code for this kind of error.
You can always run `rustc --explain E0502` for a longer explanation with examples.

The **`-->` line** gives the file, line and column where the compiler noticed the problem. That is not
always where the mistake is.

The **marked-up code lines** are the most important part, and the part people skip. Each marked line
says what role it plays. For borrow errors there are usually three: where the first borrow started,
where the clash happened, and where the first borrow was used later. Together they are the full
explanation of why the code cannot be accepted — and the last one usually points you at the fix.

Many errors also end with a **`help:`** suggestion. Read it with judgement. It is often exactly right,
but sometimes it only makes the error go away without fixing the real design problem. You will see an
example in Error 5.

### How to work through the file

Open `borrow_errors.rs`. Every error in it sits between `/*` and `*/`, so the file compiles as it is.
For each block:

1. Remove the `/*` and `*/` around that **one** block.
2. Predict the error before compiling.
3. Compile with `rustc borrow_errors.rs -o be` and read every line of the message.
4. Fix it (each block has a hint underneath), check it compiles, then put the `/*` and `*/` back.

Each block gives exactly one error. The line numbers you see will differ from the ones below, because
the code sits further down in `borrow_errors.rs`.

### Error 1 — E0502: reading and changing at the same time

This is the `Vec` and `push` example from Part 3. You already know why it is rejected: `push` might move
the list to new memory, and `first` would point at freed memory.

<details>
<summary>Fix</summary>

Finish using `first` before the push. The borrow then ends at the `println!`, before `push` needs the
list:

```rust
let mut v = vec![1, 2, 3];
let first = &v[0];
println!("{}", first);
v.push(4);
```

</details>

### Error 2 — E0499: two writers at once

```rust
let mut s = String::from("hi");
let a = &mut s;
let b = &mut s;
a.push('!');
b.push('?');
```

```text
error[E0499]: cannot borrow `s` as mutable more than once at a time
 --> e2.rs:4:13
  |
3 |     let a = &mut s;
  |             ------ first mutable borrow occurs here
4 |     let b = &mut s;
  |             ^^^^^^ second mutable borrow occurs here
5 |     a.push('!');
  |     - first borrow later used here
```

This is the rule in its purest form: two exclusive borrows alive at the same time. `a` is still in use
on line 5, after `b` was created, so for a while there are two writers.

<details>
<summary>Fix</summary>

Finish with `a` before creating `b`. Each exclusive borrow then has the string to itself:

```rust
let mut s = String::from("hi");
let a = &mut s;
a.push('!');
let b = &mut s;
b.push('?');
println!("{}", s);      // prints: hi!?
```

</details>

### Error 3 — E0106: returning a reference to something that is about to die

In C, this compiles (perhaps with a warning) and is a classic crash:

```c
int *get_value(void)
{
	int x = 42;
	return &x;      /* x disappears when the function returns */
}
```

Here is the same idea in Rust. Block 3 in `borrow_errors.rs` is this function, called `error_3`:

```rust
fn make() -> &String {
    let s = String::from("local");
    &s
}
```

```text
error[E0106]: missing lifetime specifier
 --> e3.rs:1:14
  |
1 | fn make() -> &String {
  |              ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value, but there is no value for it to be borrowed from
help: instead, you are more likely to want to return an owned value
  |
1 - fn make() -> &String {
1 + fn make() -> String {
```

Notice that Rust complains about the **first line** — the function's signature — before it even looks
at the body. The `help` line explains why, in one of the best sentences in the compiler: *there is no
value for it to be borrowed from.*

A reference always borrows **from** something. A function that returns a reference must be borrowing
from something that still exists after it returns. `s` belongs to the function and is dropped at its
closing brace, so a reference to it would point at freed memory. There is nothing valid to borrow
from, so no correct signature can be written.

<details>
<summary>Fix</summary>

Return the string itself instead of a reference to it. Ownership moves out to the caller, so nothing
is freed too early:

```rust
fn make() -> String {
    let s = String::from("local");
    s
}
```

</details>

### Error 4 — E0596: changing something you said would not change

```rust
let s = String::from("not mut");
let r = &mut s;
r.push('!');
```

```text
error[E0596]: cannot borrow `s` as mutable, as it is not declared as mutable
 --> e4.rs:3:13
  |
3 |     let r = &mut s;
  |             ^^^^^^ cannot borrow as mutable
  |
help: consider changing this to be mutable
  |
2 |     let mut s = String::from("not mut");
  |         +++
```

The simplest of the five. A `let` without `mut` is a promise that `s` will not change, and asking for
`&mut s` breaks it. Notice how good the `help` is: the `+++` marks exactly where to type `mut`.

There is a nice consequence. When you read someone else's code, every `let` without `mut` is a
guarantee the compiler enforces, not just a hope.

<details>
<summary>Fix</summary>

```rust
let mut s = String::from("now mut");
let r = &mut s;
r.push('!');
println!("{}", s);      // prints: now mut!
```

</details>

### Error 5 — E0505: giving away something that is still borrowed

```rust
fn consume(v: Vec<i32>) -> usize {
    v.len()
}

let v = vec![1, 2, 3];
let first = &v[0];
let n = consume(v);
println!("{} {}", first, n);
```

```text
error[E0505]: cannot move out of `v` because it is borrowed
 --> e5.rs:8:21
  |
6 |     let v = vec![1, 2, 3];
  |         - binding `v` declared here
7 |     let first = &v[0];
  |                  - borrow of `v` occurs here
8 |     let n = consume(v);
  |                     ^ move out of `v` occurs here
9 |     println!("{} {}", first, n);
  |                       ----- borrow later used here
  |
help: consider cloning the value if the performance cost is acceptable
```

This one joins both days together. `consume` takes the list **by value**, so it takes ownership
(Day 1) and drops the list when it finishes. But `first` is still borrowing an item inside that list
(Day 2). You cannot give a value away while someone is still borrowing it, because the borrow is only
valid as long as the owner keeps the value alive.

Look at the `help`: it suggests cloning. That would compile — but it copies the whole list just to make
the error go away, and in kernel code, copying means asking for memory, which can fail. The real
question is: does `consume` need to *own* the list at all? It only reads the length. So it should
**borrow** instead.

<details>
<summary>Fix</summary>

Make `consume` take a slice, and pass a reference. Nothing moves, so `first` stays valid:

```rust
fn consume(v: &[i32]) -> usize {
    v.len()
}

let v = vec![1, 2, 3];
let first = &v[0];
let n = consume(&v);
println!("{} {}", first, n);    // prints: 1 3
```

</details>

---

## Your Turn (10 minutes)

Now write two errors yourself, from scratch. Create a file called `my_borrow_errors.rs` with two
functions, both called from `main`:

1. `clear_while_borrowed` — make a `Vec`, take a reference to its first item, call `v.clear()` (which
   empties the list), and then print the reference.
2. `two_writers` — make an array `[1, 2, 3]`, take `&mut arr[0]` and `&mut arr[1]` as two separate
   variables, add something to each through `*`, then print the array.

**Before compiling, write down the error code you expect for each.** Then compile. Both errors will be
reported together. Then fix both — for the second one, the compiler's `help` line will point you to the
right tool.

The second one is interesting: it is rejected even though `arr[0]` and `arr[1]` genuinely do not
overlap. The compiler cannot prove that two index numbers are different, so it refuses to take the risk.

<details>
<summary>What you should see, and one way to fix both</summary>

The broken version gives:

```text
error[E0502]: cannot borrow `v` as mutable because it is also borrowed as immutable
error[E0499]: cannot borrow `arr[_]` as mutable more than once at a time
```

`clear` needs an exclusive borrow while `first` is still in use, so that is the `E0502` from Error 1.
The two `&mut` into the array are two writers, so that is `E0499`. The full message for the second one
ends with a helpful line:

```text
  = help: use `.split_at_mut(position)` to obtain two mutable non-overlapping sub-slices
```

A fixed version:

```rust
fn clear_while_borrowed() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];
    println!("first is {}", first);
    v.clear();
    println!("after clear, len is {}", v.len());
}

fn two_writers() {
    let mut arr = [1, 2, 3];
    let (left, right) = arr.split_at_mut(1);
    let a = &mut left[0];
    let b = &mut right[0];
    *a += 10;
    *b += 20;
    println!("{:?}", arr);
}

fn main() {
    clear_while_borrowed();
    two_writers();
}
```

```text
first is 1
after clear, len is 0
[11, 22, 3]
```

</details>

When both are fixed, save your file into the repository and run the check:

```bash
cp my_borrow_errors.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_2/
bash ~/LKD_RUST/codes/sync_to_repo.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_2/check_day2.sh
```

---

## Checking Yourself

Without compiling, decide whether each of these is accepted, and why.

```rust
// A
let v = vec![1, 2, 3];
let a = &v[0];
let b = &v[1];
println!("{} {}", a, b);

// B
let mut v = vec![1, 2, 3];
let a = &v[0];
v.push(4);
println!("{}", a);

// C
let mut v = vec![1, 2, 3];
let a = &v[0];
println!("{}", a);
v.push(4);

// D
let mut s = String::from("x");
let r = &mut s;
r.push('y');
println!("{}", s);

// E
let mut s = String::from("x");
let r = &mut s;
println!("{}", s);
r.push('y');
```

<details>
<summary>Answers</summary>

**A compiles.** Two shared borrows at once is exactly what the rule allows: many readers, no writer.

**B is rejected** (`E0502`). `a` is used after the `push`, so a shared borrow is still alive when the list
is changed. This is the "list might move to new memory" case.

**C compiles.** It is B with the last two lines swapped. `a` is last used before the `push`, so its borrow
has already ended. If B and C look like a trick, that is the point — the only difference is *where the
borrow is last used*.

**D compiles.** One exclusive borrow, used and finished, before `s` is read directly on the last line.

**E is rejected** (`E0502`). `r` is created, then `s` is read directly, then `r` is used again. So for a
moment there is an exclusive borrow (`r`) and a read of `s` at the same time. While an exclusive borrow
is alive, even the owner cannot read its own value.

</details>

If you got B and C right *for the right reason*, you have understood the most useful idea of today.

---

## Common Confusions

**"`&mut` just means mutable."** It means **exclusive**. The fact that no other reference can exist at
the same time — not even a read-only one — is the more important half.

**"A borrow lasts until the end of the block."** It lasts until its **last use**. When you get a borrow
error, look at where the reference is last used.

**"The owner can always read its own value."** Not while an exclusive borrow is alive. That is example E.

**"The compiler can see the list has room."** It does not look. It judges `push` by what `push` is
allowed to do.

**"When I get a borrow error, I add `.clone()`."** It usually works, and it hides the real question —
usually "should this be a borrow instead?" In kernel code, cloning also asks for memory, which can fail.

**"Two `&mut` to different array items is fine."** The compiler cannot prove two index numbers differ,
so it refuses. Use `split_at_mut`.

**"Bounds checking makes `v[i]` safe in the kernel."** A failed check is a panic, and in the kernel a
panic stops the machine. Prefer `v.get(i)` and handle the `None`.

---

## My Notes

### The five errors

| # | Error code | What the marked-up lines told me | How I fixed it |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

### My own two errors

| What I wrote | Code I predicted | Code I got | What I learned |
|---|---|---|---|
| `clear()` while borrowed | | | |
| two `&mut` into an array | | | |

### The two-line swap

What happened when I swapped the `println!` and the `push` in section 4, and why:

### In my own words

Why is "many readers or one writer" the right rule?

Why is the `push` example rejected even when the list has room?

How do `drop` and an exclusive borrow together make a lock guard safe?

### What I still do not understand

---

## Done When

You can state the one rule — many shared references or one exclusive reference, never both — and
explain why each of its three situations is safe or unsafe.

You can explain, with the memory picture, why the `push` example would be a use-after-free, and why it
is rejected even when the list has spare room.

You can explain that a borrow ends at its last use, and you have watched the same code fail and then
compile just by swapping two lines.

You can explain what a slice is and why it removes C's pointer-and-length bug, and why kernel code
prefers `get` over `[ ]`.

You can explain why `fn make() -> &String` is rejected at its signature, in the compiler's own words.

You can describe the two guarantees a lock guard gives, and which day each one comes from.

You uncommented all five errors, read every line of each message, and fixed each one — and you wrote
two of your own, predicting their codes first.

---

## Further Reading

**The Rust Book, Chapter 4.2 ("References and Borrowing") and 4.3 ("The Slice Type")** cover today
from another angle. Read them after today, to confirm what you have seen for yourself.

**`rustc --explain E0502`**, and the same for `E0499`, `E0106`, `E0596` and `E0505`. Each gives a longer
explanation with worked examples. Getting into the habit of running it is worth more than memorising
the codes.

---

## If You Have More Time (optional)

**See the real lock guard.** Run `sed -n '1,80p' ~/LKD_RUST/kernel/linux/rust/kernel/sync/lock.rs` and
look for the guard type and its `Drop`. You will not follow all of it yet — the goal is to recognise the
shape from Part 5 and know where it lives.

**See how C does it by hand.** `Documentation/dev-tools/sparse.rst` in your kernel tree describes a tool
that checks C pointer markings like `__user`. It is optional and has to be run separately — compare that
with the borrow checker, which runs on every build and cannot be skipped.

---

## 📖 Revision — Read This First When You Come Back

### The day as a story

With only ownership, passing a value to a function gives it away, so Rust adds **references**: a way to
use a value without owning it. A reference is not an owner, so when a borrow ends, nothing is dropped,
and there is still exactly one owner.

There are two kinds. A shared reference `&T` can only read, and you can have many. An exclusive
reference `&mut T` can change the value, and while it exists there can be no other reference at all —
not even the owner reading. Many readers are safe because nothing changes underneath them. One writer
alone is safe because nothing surprises it. Any mixture leads to data races and half-updated values, so
the compiler forbids it. That is why data races are impossible in safe Rust.

The rule matters even in single-threaded code. Pushing onto a full `Vec` moves its items to new memory
and frees the old memory, so a reference into the old memory would dangle. The compiler rejects that
code even when there is spare room, because it judges functions by what they are allowed to do, never
by luck. A borrow ends at its **last use**, so moving one line is often the fix.

A slice joins a pointer and a length into one value, so they can never disagree — the root of most
buffer overflows. Kernel code prefers `v.get(i)` over `v[i]`, because a failed bounds check panics and a
kernel panic stops the machine. `split_at_mut` safely gives two exclusive slices into one list,
because the halves cannot overlap.

A function cannot return a reference to its own local value: there would be nothing for the reference
to borrow from. And a lock guard combines both days: its `drop` releases the lock on every path, and its
exclusive borrow means nothing can touch the protected data without it.

### If you remember only five things

1. **Many shared references, or one exclusive reference. Never both.**
2. **`&mut` means exclusive** — even the owner cannot read while it is alive.
3. **A borrow ends at its last use**, so look there when you get an error.
4. **The compiler judges by what a function is allowed to do**, never by luck at runtime.
5. **A slice is a pointer and a length welded together**, so they cannot disagree.

### Quick recall

Answer each one out loud before opening the answers.

1. What is a reference, and what happens when a borrow ends?
2. State the one rule about borrows.
3. Why is a reader plus a writer dangerous, even without two writers?
4. Why does `push` while holding `&v[0]` count as a use-after-free?
5. Why is that code rejected even when the list has spare room?
6. When does a borrow end?
7. What two things does a slice hold, and why does that matter?
8. Why does kernel code prefer `v.get(i)` over `v[i]`?
9. Why can `fn make() -> &String` never be written correctly?
10. Name the two guarantees a lock guard gives, and which day each comes from.

<details>
<summary>Answers</summary>

1. A way to use a value without owning it. When a borrow ends, nothing is dropped — the owner still
   owns the value.
2. At any moment, a value can have many shared references or exactly one exclusive reference — never
   both.
3. The reader can see the value halfway through a change, such as a new pointer with an old length.
4. `push` may move the items to new memory and free the old memory, leaving the reference pointing at
   freed memory.
5. The compiler judges `push` by what it is allowed to do — with an exclusive borrow, it may move the
   list — not by what happens to be true at runtime.
6. At its last use, not at the end of the block (non-lexical lifetimes).
7. A pointer and a length, joined together, so a wrong length can never be passed.
8. `v[i]` panics if `i` is out of range, and a kernel panic stops the machine; `get` returns `None`
   instead.
9. A reference must borrow from something that outlives the function, and its local value is dropped
   when the function ends — there is nothing valid to borrow from.
10. It cannot be forgotten to unlock (Day 1: `drop` runs on every path), and the data cannot be touched
    without the guard (Day 2: the guard holds the only exclusive borrow).

</details>

### The code, in order

```bash
cd ~/rust-scratch
rustc borrow_demo.rs -o borrow
./borrow 1        # why borrowing exists
./borrow 8        # a borrow ending drops nothing
./borrow 2        # many shared references, same address
./borrow 3        # one exclusive reference changes the value
./borrow 4        # a borrow ends at its last use
./borrow 5        # slices carry their own length
./borrow 6        # get() returns None instead of panicking
./borrow 7        # changing through a slice; split_at_mut
./borrow 9        # the lock guard

rustc borrow_errors.rs -o be     # uncomment one block at a time, read, fix
rustc my_borrow_errors.rs -o mine && ./mine
```

---

**Next:** M1W1D3 — the kernel source tree. A change of pace after two Rust days: you will walk
`drivers/`, learn to read the `MAINTAINERS` file, find where all the Rust in the kernel lives, and build
the search habits that make a forty-million-line codebase easy to find your way around.

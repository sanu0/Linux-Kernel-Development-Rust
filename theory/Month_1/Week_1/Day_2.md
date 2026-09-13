# M1W1D2 — Borrowing and the Borrow Checker

> Yesterday's question was *who is responsible for freeing this?* Today's question is *who is allowed
> to look at it, and when?*

Yesterday you learned that every value has exactly one owner, and that handing a value to somebody
else transfers that ownership permanently. That rule is what makes double frees impossible.

It also, taken on its own, makes the language nearly unusable. Today is about the mechanism that
fixes that, and about the single rule that mechanism enforces — a rule which, as a side effect,
makes data races impossible. In a kernel where the same function runs simultaneously on a hundred
processors, that is not a small thing.

Today is also where you learn to *read the compiler*. You are going to write five borrow errors on
purpose and read every line of what `rustc` says about them. This sounds like a strange way to spend
an afternoon, but it is the highest-value hour in Week 1. Rust's errors are unusually detailed, and
the difference between a person who finds Rust productive and a person who finds it infuriating is
almost entirely whether they read the error or just look at the red text and start guessing.

As yesterday, there are no kernel builds. Plain `rustc` on a single file, one second per iteration.

**Time:** two to three hours, most of it spent reading error messages.

---

## Ownership Alone Is Too Strict

Let us start by feeling the problem, because the solution makes much more sense afterwards.

Suppose you want a function that tells you how long a string is. With only yesterday's rules, you
would write:

```rust
fn length_by_value(s: String) -> usize {
    s.len()
}
```

And then:

```rust
let a = String::from("moved away");
let n = length_by_value(a);
println!("{}", a);          // error: borrow of moved value
```

Look at what happened. You asked a question about your string, and the string is now gone. Passing
it to the function moved ownership in, the function's parameter went out of scope at the closing
brace, and your string was destroyed. To merely *read its length*.

You could work around this by having the function give the value back:

```rust
fn length_and_return(s: String) -> (String, usize) {
    let n = s.len();
    (s, n)
}
```

That works, and it is horrible. Every function that inspects anything would have to return it, every
caller would have to catch it and rebind it, and any function that looked at three things would
return a four-element tuple. Nobody would use a language that worked like this.

So there has to be a way to let somebody *look at* a value without *taking* it. That is borrowing.

---

## References: Access Without Ownership

A **reference** is a way to reach a value that somebody else owns. You write `&` to make one:

```rust
fn length_by_reference(s: &String) -> usize {
    s.len()
}

let b = String::from("still mine");
let n = length_by_reference(&b);
println!("{}", b);          // fine — b was never given away
```

The `&b` at the call site creates a reference. The `&String` in the signature says "I accept a
reference, not the thing itself." Nothing moved. The function got access, used it, and returned, and
`b` is exactly where it was.

The word "borrow" is chosen carefully, and the analogy is worth taking seriously. If you borrow a
book from somebody, you can read it, you must give it back, and you are not allowed to burn it. You
also cannot lend it onward for longer than you yourself have it. All of those things are true of
Rust references, and the compiler enforces every one.

### A reference does not own, so it frees nothing

This follows directly from yesterday, but it is worth seeing explicitly. When a reference goes out
of scope, nothing is destroyed, because the reference was never the owner:

```rust
let owner = Noisy::new_named("the value");
{
    let borrowed = &owner;
    println!("borrowed it: {}", borrowed.0);
}
println!("still alive: {}", owner.0);
```

```text
      make: the value
      borrowed it: the value
      -- borrow scope ending, expect NO drop --
      still alive: the value
      -- function ending, NOW expect the drop --
      drop: the value
```

The inner block ended and no drop happened. There is still exactly one owner, `owner`, and the value
dies when *that* goes out of scope. Rule one from yesterday is intact: borrowing does not create a
second owner, and that is precisely why it is safe.

---

## The One Rule: Either Many Readers Or One Writer

Rust has two kinds of reference, and the difference between them is the whole subject of today.

A **shared reference**, written `&T`, lets you read. You may have as many as you like at the same
time.

An **exclusive reference**, written `&mut T`, lets you read and write. You may have exactly one, and
while it exists there may be no other references at all — not even read-only ones.

Those two sentences combine into one rule:

> **At any given moment, for any given value, you may have either any number of shared references,
> or exactly one exclusive reference. Never both.**

You will also see this called the aliasing rule, and the two kinds called "immutable" and "mutable"
borrows. The words "shared" and "exclusive" are better, because they describe what the compiler
actually guarantees.

Here is many-readers working:

```rust
let data = String::from("hello");
let r1 = &data;
let r2 = &data;
let r3 = &data;
println!("{} / {} / {}", r1, r2, r3);
println!("and the owner can still read it: {}", data);
```

```text
three readers agree: hello / hello / hello
and the owner can still read it too: hello
same address? 0x7ffca92d5be8 0x7ffca92d5be8
```

Note the addresses. All of those names refer to the same bytes in memory. Nothing was copied. Four
different ways of reading one string.

And here is the single writer:

```rust
fn push_suffix(s: &mut String) {
    s.push_str("-modified");
}

let mut data = String::from("original");
push_suffix(&mut data);
println!("{}", data);        // original-modified
```

Two things had to be true for that to compile. The variable had to be declared `mut`, because you
cannot hand out permission to change something you declared you would not change. And there had to
be no other live reference to `data` at the moment `&mut data` was created.

### Why this rule, and not some other rule?

Take the three possible situations one at a time.

**Many readers and no writer is safe.** If nobody can change the value, then everybody reading it
sees the same thing, and it stays true for as long as they look. There is nothing to go wrong.

**One writer and nobody else is safe.** If exactly one piece of code can touch the value, it cannot
be surprised. It makes a change, and the next time it looks, it sees its own change and nothing
else.

**Any other combination is where bugs live.** Two writers means two pieces of code modifying the
same memory with neither aware of the other; on multiple CPUs that is a data race, which is
undefined behaviour, and in a kernel it is how subtle corruption gets into filesystems. One writer
plus one reader is just as bad in a quieter way: the reader can observe the value halfway through
being updated. If the writer is updating a pointer and a length, the reader can see the new pointer
with the old length. It reads past the end of a buffer, and nothing in the code looks wrong.

So the rule is not arbitrary, and it is not conservatism. It is the precise boundary between
combinations that are always sound and combinations that are sometimes catastrophic.

**This is the rule that makes data races impossible in safe Rust.** Not unlikely — impossible. A data
race requires two things touching the same memory with at least one writing, and the borrow checker
will not let you construct that situation. You get a compile error instead.

---

## Why The Rule Matters Even On A Single CPU

You might reasonably think that if your code is single-threaded, none of this applies to you. It
does, and here is the example that shows why. It is also the most common borrow error you will hit,
so it is worth understanding properly rather than just learning to avoid.

```rust
let mut v = vec![1, 2, 3];
let first = &v[0];
v.push(4);
println!("{}", first);
```

This is rejected:

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

Read that message properly, because it is a good example of how much `rustc` gives you. It names
three separate lines and what each one did: where the shared borrow began, where the exclusive borrow
conflicted with it, and where the shared borrow was still being used afterwards. That last one is
the important one — the error exists because the borrow is used *after* the push, which is what makes
the overlap real.

Now, why is this a genuine problem rather than the compiler being fussy?

A `Vec` is a pointer to a heap buffer, plus a length, plus a capacity. When you push and the buffer
is full, `Vec` cannot simply extend it — the memory after it belongs to something else. So it
allocates a **new, larger buffer**, copies every element across, frees the old buffer, and updates
its pointer.

Your reference `first` pointed into the old buffer. After the push, that buffer has been freed. The
reference now points at memory the allocator has taken back and may already have handed to somebody
else. Reading through it is a **use-after-free**.

This is not a hypothetical. In C++ this exact code compiles, and invalidated iterators and pointers
into a resized vector are one of the most famous sources of crashes in the language. Every C++
programmer learns this by being burned. In Rust it is four lines of compiler output.

### The part that surprises people

The code above is rejected **even if the `Vec` has spare capacity and no reallocation would actually
happen.**

That can feel unfair. You can see that the vector has room; you know nothing will move. But the
borrow checker does not reason about what happens to be true at runtime this time. It reasons about
what the *signature* of `push` allows it to do — and `push` takes `&mut self`, which means it may do
anything, including reallocating.

This is worth internalising early, because it explains most of your future arguments with the borrow
checker:

> **The borrow checker reasons from signatures and scopes, never from runtime luck.**

That is a deliberate design choice, and it is what makes the guarantee worth anything. A check that
passed when your vector happened to have room and failed when it happened not to would be useless.
The rule has to hold for all possible executions, so it is decided from the types.

---

## The Same Rule In C, And Why It Does Not Work There

It is worth knowing that the kernel already believes in this rule. It simply has no way to enforce it.

C99 added a keyword called `restrict`, which you put on a pointer to promise the compiler that
nothing else points at the same memory. This is exactly the aliasing rule, written by hand. The
problem is that it is a promise with nothing behind it. Nobody checks. If you are wrong, you have
undefined behaviour, and the compiler has already optimised on the assumption that you were right.

The kernel goes further and annotates pointers with what they are: `__user` for pointers that come
from userspace and must never be dereferenced directly, `__rcu` for pointers that may only be read
inside an RCU critical section, `__percpu` for per-CPU data. These are genuinely useful, and a tool
called `sparse` will check them for you. But `sparse` is an optional extra pass that you have to
remember to run, and the annotations are advisory — the code compiles and runs either way.

For locking, the kernel relies on documentation and review. A comment above a struct says which
fields are protected by which lock. A reviewer notices when you touch a field without holding it.
`lockdep` catches some classes of lock-ordering mistake at runtime, and `KCSAN` catches some data
races at runtime, probabilistically, if the racing code happens to run while you are watching.

Every one of those is either optional, advisory, partial, or after the fact.

The rule Rust enforces is the same rule the kernel already lives by. The difference is that in Rust
it is checked by the compiler, on every build, for all possible executions, and the answer is a
build failure rather than a corrupted filesystem six months later.

---

## Non-Lexical Lifetimes: Why Some Things That Look Wrong Compile

Now something that will save you a lot of confusion, because it explains why the borrow checker can
seem inconsistent.

A borrow does not last until the end of the enclosing scope. **It lasts until its last use.**

```rust
let mut v = vec![1, 2, 3];

let first = &v[0];               // borrow starts
println!("first is {}", first);  // ...and ends HERE, at its last use

v.push(4);                       // legal — the borrow is already over
println!("after push: {:?}", v);
```

```text
first element is 1
after push: [1, 2, 3, 4]
```

That compiles. The variable `first` is still in scope at the `push` — it exists as a name until the
end of the function — but it is never used again, so the borrow it represents has already ended. The
compiler tracks the actual *region of the program* over which a reference is live, not the block it
was declared in.

This is called non-lexical lifetimes, and it arrived in Rust 2018. Before that, borrows really did
last to the end of the scope, and code like the above was rejected. People wrote extra blocks purely
to make borrows end where they wanted.

Two practical consequences.

First, if you hit a borrow error, look at **where the value is last used**, not where it is declared.
Very often the fix is to move one line, or to reorder two statements so that the borrow finishes
before the mutation begins. In the failing example earlier, moving the `println!` above the `push`
makes it compile, because then the borrow's last use comes before the conflict.

Second, this is why the borrow checker can feel arbitrary when you are learning. Two pieces of code
that look almost identical behave differently, and the difference is invisible unless you are
thinking about last use. Once you know the rule, the inconsistency disappears.

---

## Slices: The Fix For Pointer-Plus-Length

Here is a bug that has probably caused more kernel security holes than any other single mechanism.

In C, an array is passed as a pointer, and the length travels separately:

```c
void process(int *buf, size_t len);
```

Nothing connects those two arguments. Nothing checks that `len` is the real length of `buf`. You can
write `process(buf, len + 1)` and it compiles silently. You can change the allocation size later and
forget to update the call. You can pass the length in elements where the callee expects bytes. Every
buffer overflow in the kernel's history is, at bottom, a pointer and a length that disagreed.

Rust's answer is the **slice**, written `&[T]`. A slice is a pointer and a length **as a single
value**:

```rust
fn sum(xs: &[i32]) -> i32 {
    let mut total = 0;
    for x in xs {
        total += x;
    }
    total
}
```

```text
whole:      [10, 20, 30, 40, 50]  sum 150
from 1:     [20, 30, 40, 50]  sum 140
first two:  [10, 20]  sum 30
middle:     [20, 30, 40]  sum 90
the slice itself reports len 3
from a plain array: sum 6
```

The pointer and length cannot disagree, because there is nothing to keep in sync — they are one
value, constructed together. The function does not take a length argument at all; it asks the slice.
You cannot pass the wrong length, because you cannot pass a length.

Notice also that the last line passed a plain array rather than a `Vec`. A slice does not care where
the memory came from. It is a view of a contiguous run of values, and that is all it claims to be.

### Bounds are checked, and what that means in a kernel

Indexing a slice out of range is a panic, not silent corruption:

```rust
let v = vec![1, 2, 3];
v[10]            // panics: index out of bounds
```

A panic is safe in the sense that matters — it does not read somebody else's memory. But remember
yesterday's point about what a panic costs. In userspace it kills your process. In the kernel it
stops the machine.

So kernel Rust prefers the form that does not panic:

```rust
match v.get(10) {
    Some(x) => println!("{}", x),
    None    => println!("out of range, handled"),
}
```

```text
v.get(10) = None (no panic, no corruption)
v.get(1)  = Some(2)
```

`get` returns an `Option` instead of panicking, which turns "out of range" into an ordinary case you
handle with the same machinery as every other error. This is the kernel-appropriate choice, and you
will see it constantly in real kernel Rust.

### Two writers into one buffer, done properly

The aliasing rule says you cannot have two `&mut` into the same value. But sometimes you genuinely
need to write to two different parts of one buffer — and if the parts do not overlap, that is
perfectly sound.

The standard library expresses this with `split_at_mut`:

```rust
let mut v = vec![2, 4, 6, 8];
let (left, right) = v.split_at_mut(2);
left[0] = 100;
right[0] = 200;
```

```text
after split_at_mut: [100, 4, 200, 8]
```

Two mutable slices, both live at once, into the same allocation. This is allowed because the
signature of `split_at_mut` guarantees the halves do not overlap, so the aliasing rule is respected
even though two `&mut` exist.

Keep this pattern in mind, because you will meet it again in a more important form. The borrow
checker cannot prove on its own that two arbitrary indices differ, so it refuses to let you take
`&mut` to two elements by indexing. `split_at_mut` works because somebody wrote the proof once, by
hand, inside the standard library, using `unsafe` — and wrapped it in a safe interface that cannot
be misused. A small audited unsafe core exposing a safe API is exactly what you will be building in
Month 5 when you start writing kernel abstractions. This is your first sight of the shape.

---

## Dangling References Cannot Be Written

In C, this is a classic bug:

```c
int *get_value(void)
{
	int x = 42;
	return &x;      /* x is on the stack; it is gone when we return */
}
```

Most compilers will warn, but it compiles, and it has caused real kernel crashes. The returned
pointer refers to stack space that has been reused by whatever ran next.

The Rust equivalent cannot be written at all:

```rust
fn dangle() -> &String {
    let s = String::from("local");
    &s
}
```

```text
error[E0106]: missing lifetime specifier
 --> e3.rs:1:16
  |
1 | fn dangle() -> &String {
  |                ^ expected named lifetime parameter
  |
  = help: this function's return type contains a borrowed value,
          but there is no value for it to be borrowed from
```

Pay attention to *which* error this is, because it is more interesting than you might expect. Rust
did not reject the body. It rejected the **signature**, before looking at the body at all.

The reason is in the help text, and it is the single best one-sentence explanation of references in
the language: *this function's return type contains a borrowed value, but there is no value for it to
be borrowed from.*

A reference always borrows **from** something. That is what it is. If a function returns a reference,
the thing being borrowed has to be something that outlives the call — normally one of the function's
own parameters. This function has no parameters, and it cannot borrow from its own locals, because
they die when it returns. So there is no honest signature to write, and Rust says so.

The compiler then offers you the fix, which is to return the owned `String` rather than a reference
to it. That is almost always the right answer.

You will learn to write signatures that *do* return references, connecting an output's lifetime to
an input's, in Week 3. Today it is enough to see that the whole bug class is a signature you cannot
write.

---

## Where Day 1 And Day 2 Meet: The Lock Guard

This section is the point of Week 1. Yesterday gave you ownership and automatic cleanup. Today gave
you exclusive access. Put them together and you get the pattern that makes kernel locking safe.

Think about how a mutex works in C:

```c
mutex_lock(&f->lock);
f->counter++;
mutex_unlock(&f->lock);
```

Two separate calls, and everything depends on you. Nothing stops you from returning early between
them and never unlocking — which is a deadlock, and it is exactly what the `err_unlock` label in
yesterday's `goto` ladder existed to prevent. Nothing stops you from touching `f->counter` somewhere
else in the file without taking the lock at all. The relationship between the lock and the data it
protects lives in a comment.

Now the Rust shape. Taking the lock returns a **guard**, and the data is reachable only through that
guard:

```rust
let mut guard = lock.lock();
println!("read: {}", guard.get());
guard.set(42);
```

```text
      [lock acquired]
      read through guard: 41
      wrote through guard: 42
      -- guard going out of scope --
      [lock released]
```

Two separate guarantees are working together there, and it is worth separating them.

**You cannot forget to unlock**, because unlocking is the guard's destructor. The guard goes out of
scope — at the closing brace, at a `return`, at a `?` propagating an error, on any path whatsoever —
and yesterday's rules release the lock. That is `Drop`, doing the job the `err_unlock` label did by
hand.

**You cannot touch the data without the lock**, because the data is only reachable through the guard,
and you can only obtain a guard by locking. That is today's rule: the guard holds an exclusive
borrow, so while it lives nothing else can reach the protected data. The relationship that was a
comment in C is a type here.

This is not an analogy. It is how the kernel's Rust `Mutex` and `SpinLock` actually work. When you
write real locking code in Month 3, this will be the shape of it, and you will already understand
why it is built that way.

---

## Learning To Read `rustc`

You are about to write five errors deliberately. Before you do, here is how to read one, because
they all have the same anatomy and once you see it they stop being intimidating.

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

The first line is the **summary**, and the error code after `error` is a permanent identifier — you
can always run `rustc --explain E0502` for a longer discussion with examples.

The `-->` line is where the compiler decided to complain, which is not necessarily where you went
wrong.

Then comes the part that matters most, and the part people skip: a set of **annotated source lines**,
each explaining its own role in the conflict. For a borrow error you will usually get three: where
the first borrow started, where the conflicting one happened, and where the first borrow was used
afterwards. Together they are a complete account of why the code cannot be accepted.

That third annotation is often the key to the fix. In the example above, the reason this is an error
at all is the use of `first` on line 5. Delete that line, or move it above the push, and the borrow
ends earlier and the code compiles.

Many errors also end with a `help:` suggesting a concrete change. Read those with judgement rather
than obedience. They are frequently exactly right — `E0596` will tell you precisely where to add
`mut`. But sometimes the suggestion silences the error without answering the design question, and
`E0505`'s offer to insert a `.clone()` is a good example: it works, and it also allocates, and in
kernel code an allocation can fail.

---

## The Five Errors

Now the work. Open `borrow_errors.rs`. Every error in it is commented out, so the file compiles as
it stands. Uncomment **one block at a time**, predict the error before you compile, then read the
whole message before fixing it.

Here is what each one is teaching, so you know what to look for.

**The first** is the `Vec` and `push` conflict we walked through above, giving `E0502`. The insight is
that `push` might reallocate, so a reference into the old buffer would dangle — and that it is
rejected even when reallocation would not actually happen this time, because the checker reasons
from `push`'s signature rather than from runtime luck.

**The second** is two `&mut` to the same value at once, giving `E0499`. This is the aliasing rule in
its purest form, with nothing else going on. Two live exclusive borrows means two writers with
neither aware of the other.

**The third** is returning a reference to a local, giving `E0106` — the signature error we just
looked at. The lesson is that a reference always borrows from something, and a function with nothing
to borrow from has no valid signature.

**The fourth** is taking `&mut` to a binding that was not declared `mut`, giving `E0596`. The
simplest of the five, and worth noticing for a different reason: it means that when you read a
function body, every `let` without `mut` is a guarantee the compiler is enforcing rather than a
convention somebody hoped would hold.

**The fifth** is moving a value while a reference into it is still alive, giving `E0505`. This one
ties both days together. The value is moved into a function that takes ownership and drops it, while
a reference into its buffer is still live. You cannot move something out from under a live borrow,
because the borrow's validity depends entirely on the owner still being there.

Then write two of your own, as the file suggests. The second one — trying to take `&mut` to two
different elements of an array by indexing — is the interesting one, because it is rejected even
though the two elements genuinely do not overlap. That is a real limitation of the checker rather
than a bug in your reasoning, and `split_at_mut` exists precisely because somebody had to write that
proof once by hand so nobody else ever has to.

---

## Doing The Work

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_2/borrow_demo.rs .
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_2/borrow_errors.rs .
```

If `rustc` is not found, it lives in `~/.cargo/bin` and your non-interactive shell has not picked it
up:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Start with the demo, and as yesterday, **predict each section before running it**:

```bash
rustc borrow_demo.rs -o demo && ./demo
```

Section 4 is the one to think hardest about. Then try the experiment it suggests: swap the `println!`
and the `push`, and watch it stop compiling. That single swap is non-lexical lifetimes made visible.

Then the errors, one at a time:

```bash
rustc borrow_errors.rs -o be && ./be     # compiles as-is; prints the list
$EDITOR borrow_errors.rs                  # uncomment ERROR 1 only
rustc borrow_errors.rs -o be              # read every line of the message
```

For each one, write down in your journal what the three annotated lines told you, and what you
changed to fix it. Then re-comment it and move to the next.

Finally, go and look at how the kernel does this for real:

```bash
cd "$LINUX_TREE"
sed -n '1,80p' rust/kernel/sync/lock.rs
```

You are looking for the guard type and its `Drop` implementation. That is the pattern from the
previous section, in the actual kernel source. You are not expected to follow all of it today — the
goal is to recognise the shape and know you have seen where it lives.

And save your work:

```bash
cd ~/rust-scratch
cp borrow_errors.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_2/my_borrow_errors.rs
bash ~/LKD_RUST/codes/sync_to_repo.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_2/check_day2.sh
```

---

## Checking Yourself

Without compiling anything, decide whether each of these is accepted, and why.

```rust
// A
let mut v = vec![1, 2, 3];
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

**A compiles.** Two shared borrows at once is exactly what the rule permits. Any number of readers,
as long as there is no writer.

**B is rejected** with `E0502`. The shared borrow in `a` is still used after the `push`, so it is
live across a mutation. This is the reallocation case.

**C compiles.** Identical to B except for the order of the last two lines. `a`'s last use is now
before the `push`, so under non-lexical lifetimes the borrow has already ended by the time the
mutation happens. If B and C both being on this list feels like a trick, that is the point — the
difference between them is the whole content of the NLL section.

**D compiles.** One exclusive borrow, used, and finished with before `s` is read directly on the
last line.

**E is rejected.** The exclusive borrow `r` is created, then `s` is read directly — which requires a
shared borrow — and then `r` is used again afterwards. So a shared and an exclusive borrow are live
at the same moment, which is exactly what the rule forbids. Note that reading the owner counts:
while an exclusive borrow is outstanding, even the owner cannot look.

</details>

If you got B and C both right for the right reason, you understand today's most practically useful
idea.

---

## Common Confusions

**Thinking `&mut` means "mutable" and nothing more.** It means *exclusive*. The inability to have a
second reference — even a read-only one — is the more important half, and it is where the guarantee
comes from.

**Thinking the borrow lasts until the end of the scope.** It lasts until its last use. When you hit a
borrow error, look at where the value is last used, because that is usually where the fix is.

**Reading the summary line and starting to guess.** The annotated source lines underneath tell you
where the borrow began, where the conflict was, and where the original was used later. That is the
whole explanation, and skipping it is the main reason people find Rust frustrating.

**Assuming the checker knows what you know.** It reasons from signatures and scopes. It will reject
code that is correct-in-this-case because the signature permits something dangerous in general.

**Reaching for `.clone()` as soon as a borrow error appears.** It will usually work, and it hides the
question you were being asked. Ask first whether you wanted a reference. In kernel code, cloning
also allocates, and allocation can fail.

**Forgetting that the owner counts as a reader.** While a `&mut` is alive, even reading through the
original variable is forbidden. Example E above.

**Expecting two `&mut` into different array elements to work.** The checker cannot prove two runtime
indices differ. Use `split_at_mut`, or the iterator methods, which have the proof built in.

**Thinking bounds checks make indexing safe enough in kernel code.** A failed bounds check is a
panic, and a kernel panic stops the machine. Prefer `get` and handle the `None`.

---

## My Notes

### The five errors

| # | Error code | What the three annotated lines told me | How I fixed it |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

### My own two errors

| What I wrote | Predicted code | Actual code | What I learned |
|---|---|---|---|
| | | | |
| | | | |

### The NLL experiment

What happened when you swapped the `println!` and the `push` in section 4, and why:

### In my own words

Why is many-readers-or-one-writer the right rule, rather than some other rule?

Why is the `Vec` push case rejected even when no reallocation would happen?

How do `Drop` and exclusive borrowing combine to make a lock guard safe?

### What I still do not understand

---

## Done When

You can state the aliasing rule from memory, and explain why each of its three cases — many readers,
one writer, and any mixture — is safe or unsafe.

You can explain what goes wrong in the `Vec` push example at the level of the heap buffer, and why
the code is rejected even when the vector has spare capacity.

You can explain non-lexical lifetimes, and you have watched the same code compile and then fail
purely because you swapped two lines.

You can explain what a slice is, and why a pointer and a length welded together removes a bug class
that C cannot remove. You know why kernel code prefers `get` over indexing.

You can explain why `fn dangle() -> &String` is rejected at the signature rather than in the body,
and you can say the reason in the compiler's own terms: there is no value for the return type to
borrow from.

You can describe how a lock guard combines yesterday's `Drop` with today's exclusivity, and why that
means you cannot forget to unlock and cannot reach the data without locking.

You have written all five errors deliberately, read every line of each message, and fixed each one —
plus two of your own. And you can read a `rustc` error by its anatomy rather than by guessing.

---

## Further Reading

**The Rust Book, Chapter 4.2 and 4.3** cover references and slices. Read them after today's
experiments, to confirm a model you built by observation.

**`rustc --explain E0502`**, and the same for `E0499`, `E0106`, `E0596` and `E0505`. Each gives a
longer discussion with worked examples. Getting into the habit of running this is worth more than
memorising the codes.

**`rust/kernel/sync/lock.rs`** in the kernel tree — the guard pattern in real kernel code.

**`Documentation/rust/coding-guidelines.rst`** — short, and the standard your code is judged by.

**`Documentation/dev-tools/sparse.rst`** — how the kernel checks its `__user` and `__rcu`
annotations in C. Worth a skim so you can see what the C side has to do by hand, and how much of it
is optional.

---

## Summary

Ownership alone would mean that inspecting a value takes it away from you, so Rust has references: a
way to reach a value somebody else owns. A reference does not own, so when it ends nothing is freed,
and rule one is preserved — there is still exactly one owner.

There are two kinds, and the difference is the whole subject. A shared reference `&T` lets you read,
and you may have as many as you like. An exclusive reference `&mut T` lets you write, and while it
exists there may be no other references at all, not even read-only ones, not even the owner. Many
readers is safe because nothing changes underneath them. One writer alone is safe because nothing
surprises it. Any mixture is where data races and torn reads live, so the compiler forbids it. That
is why data races are impossible in safe Rust.

The rule matters even single-threaded, and the `Vec` push example is why: growing a vector may
allocate a new buffer and free the old one, so a reference into the old buffer would dangle. It is
rejected even when no reallocation would happen, because the borrow checker reasons from signatures
and scopes rather than from runtime luck. That is what makes the guarantee worth having.

Borrows end at their **last use**, not at the end of the scope. This is non-lexical lifetimes, and it
explains why two nearly identical pieces of code can behave differently. When you hit a borrow
error, look at where the value is last used.

Slices weld a pointer and a length into one value, which removes the disagreement that underlies
every buffer overflow. Bounds are checked, and because a kernel panic stops the machine, kernel code
prefers `get` and handles the `None`. Where two writers into one buffer are genuinely sound,
`split_at_mut` provides it — a small audited `unsafe` core behind a safe interface, which is the
shape of everything you will build in Month 5.

A function cannot return a reference to its own local, and Rust rejects the signature rather than the
body, because a reference must borrow *from* something and there is nothing available. C's
return-a-pointer-to-a-stack-variable bug becomes a signature that cannot be written.

Finally, the two days combine in the lock guard. Locking returns a guard; the data is reachable only
through it; the guard's destructor releases the lock. So you cannot forget to unlock, on any path,
and you cannot touch the protected data without holding the lock. What was a comment and a review
convention in C becomes a type the compiler checks — and that is how the kernel's Rust `Mutex`
actually works.

---

**Next:** M1W1D3 — the kernel source tree. A change of pace after two dense Rust days: you will walk
`drivers/`, learn to read `MAINTAINERS`, find where all the Rust in the kernel actually lives, and
build the search habits that make a forty-million-line codebase navigable.

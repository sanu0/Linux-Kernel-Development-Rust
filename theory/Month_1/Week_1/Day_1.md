# M1W1D1 — Ownership, Moves, and Drop ✅ COMPLETED

> **What you need to know already:** Rust up to structs — variables, functions, `if` and loops,
> `struct`, and `impl` blocks with methods. Anything beyond that is explained in a **🆕 New Rust**
> box at the moment it first appears, so you never meet syntax nobody told you about.
>
> **Time:** about 90 minutes, including running every example. No kernel builds today.

Today you learn the one idea the rest of this roadmap stands on.

Device drivers, memory management, locking, DMA — everything you study over the next eighteen months
is built on what you learn today. If ownership stays fuzzy, you will spend later months fighting the
compiler without knowing why. If it becomes clear, most of the rest of Rust turns out to be this one
idea applied again and again.

The day is built around small programs. Before you run each one, you will **predict its output** —
write your guess down, then run it and compare. When your guess is wrong, that is the moment you
actually learn something, so do not skip the guessing.

| Part | What you will learn | Time |
|---|---|---|
| Before you start | Set up the example programs | 5 min |
| 1 | The problem ownership solves | 10 min |
| 2 | The three rules, and when a value dies | 15 min |
| 3 | Moves | 15 min |
| 4 | Copy and Clone | 10 min |
| 5 | Drop, and why the kernel cares | 15 min |
| 6 | How kernel Rust is different | 10 min |
| Your turn | Write one yourself, and check yourself | 10 min |

---

## Before You Start (5 minutes)

All of today happens in normal userspace Rust, not inside the kernel. The ownership rules are exactly
the same in both places, and here a program compiles in about one second instead of a five-minute
kernel rebuild.

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_1/ownership_demo.rs .
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_1/raii_probe.rs .
rustc ownership_demo.rs -o demo
```

If you see `rustc: command not found`, Rust is installed in `~/.cargo/bin` but your shell has not
been told where to look. Fix it for this terminal with:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

The demo has ten numbered sections. You can run just one of them:

```bash
./demo 3      # runs only section 3
./demo        # runs all ten
```

That way you can make a guess about section 3 without seeing the answers for the other nine.

---

## Part 1 — The Problem Ownership Solves (10 minutes)

### Two places memory lives

When your program runs, its data lives in one of two places, and the difference matters for
everything today.

The **stack** holds values whose size is known when the program is compiled — an `i32` is always 4
bytes, a `bool` is always 1. The stack is fast, and its cleanup is automatic: when a function
returns, everything it put on the stack disappears with it.

The **heap** holds things whose size is not known in advance, or can change — some text the user
typed, or a list that keeps growing. To use the heap, your program asks for a chunk of memory of the
size it needs. And here is the important part: **that chunk must be given back later.** Nothing gives
it back automatically.

A `String` uses both. Look at this line:

```rust
let s = String::from("hello");
```

The variable `s` itself sits on the stack, and it is small: just three numbers. One is the address
of the text, one is how long the text is, and one is how much room was reserved. The text itself,
the five letters, sits on the heap:

```text
   s  (on the stack)                    the heap
   ┌──────────────────┐               ┌───┬───┬───┬───┬───┐
   │ pointer     ─────┼─────────────▶ │ h │ e │ l │ l │ o │
   │ length      5    │               └───┴───┴───┴───┴───┘
   │ capacity    5    │
   └──────────────────┘
```

Remember that picture. It explains almost everything in Parts 3 and 4.

### The hard question

Somebody has to give that heap memory back, and they have to pick exactly the right moment. There
are three ways to get it wrong.

If you give it back **too early**, some other part of the program may still use it. That memory now
belongs to something else, so reading it gives you someone else's data, and writing it corrupts
someone else's data. This is called a **use-after-free**, and it is the most exploited kind of bug in
operating systems.

If you give it back **twice**, the code that manages the heap gets confused about what is free and
what is in use. This is a **double free**, and attackers have whole techniques built around it.

If you **never** give it back, your program slowly eats memory until the machine runs out. This is a
**leak**. It is the mildest of the three, but a kernel is supposed to run for years.

### Three answers

Every programming language picks one of three answers to the question "when do we give memory back?"

**C makes you do it by hand.** You call `kmalloc` to get memory and `kfree` to give it back, and it is
entirely your job to call `kfree` exactly once, after the last use, on every path through your code
— including every error path. Humans miss paths. The Linux kernel is written and reviewed by very
careful people, and studies of large C codebases keep finding the same thing: about two thirds of
serious security bugs are memory bugs like the three above.

**Java and Go use a garbage collector**, a helper that runs alongside your program, pauses it every
so often, finds memory nothing uses any more, and frees it. The kernel cannot use this. There is
nothing underneath the kernel to run such a helper — the kernel *is* the bottom. And some kernel code,
like the code that runs when a network card signals that a packet arrived, is not allowed to pause
at all.

**Rust's answer is ownership.** The compiler works out, while compiling, exactly where each value's
life ends, and writes the "give it back" code there for you. When the program runs, there is no
helper and no pausing. The cleanup code is simply sitting in the program at a place the compiler
proved is correct.

That is the whole idea, and it is worth reading twice: **the cleanup still happens; you just do not
write it, and the compiler puts it somewhere it can prove is safe.** That is why Rust was allowed
into the Linux kernel.

---

## Part 2 — The Three Rules, and When a Value Dies (15 minutes)

Ownership comes down to three rules:

1. **Every value has exactly one owner** — one variable responsible for cleaning it up.
2. **When you assign a value or pass it to a function, ownership moves.** There is still only one owner.
3. **When the owner goes out of scope, the value is dropped** — its cleanup runs.

We will look at rule 3 first, because it is the easiest to see, and rule 2 makes more sense after it.

A **scope** is the region between a `{` and its matching `}` — the body of a function, or a block
inside it. When the program leaves a scope, every value owned by a variable declared inside that
scope is **dropped**, which means its cleanup runs and any heap memory it owns is given back.

### A type that announces its own death

To watch values being dropped, we will use a small struct that prints a message when it dies:

```rust
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
```

The `impl Noisy` block should look familiar: it gives `Noisy` a `new` function that prints a message
and builds the struct. The other two pieces are new.

> **🆕 New Rust — `&'static str`**
>
> This is the type of a string literal, like `"first"`. The text is built into the program itself and
> exists for the whole time the program runs. The `'static` part is a lifetime, which you will meet
> properly in Week 3; for today, read `&'static str` as simply "a string literal".
>
> We use it so that a `Noisy` owns no heap memory of its own. That way the only interesting thing
> about it is *when it dies*.

> **🆕 New Rust — traits, and `impl Drop for Noisy`**
>
> You already know `impl Noisy { ... }`, which adds methods to `Noisy`. The line
> `impl Drop for Noisy` is a different kind of `impl`.
>
> `Drop` is a **trait**. A trait is a named set of methods that a type can promise to provide.
> Writing `impl Drop for Noisy` means "Noisy provides what the Drop trait asks for", and `Drop` asks
> for exactly one method: `drop`, which says what to do when a value dies.
>
> `Drop` is special: **the compiler calls `drop` for you, automatically**, at the moment the value
> dies. You never call it yourself. You will learn traits properly in Week 2; today you only need to
> recognise this one.

### Values die at the end of their scope, in reverse order

Here is section 1 of the demo:

```rust
fn scope_end() {
    let _first = Noisy::new("first");
    let _second = Noisy::new("second");
    let _third = Noisy::new("third");
    println!("      -- end of function --");
}
```

The `_` at the start of each name just tells the compiler "I know I never read this variable", so it
does not warn us.

> **▶ Try it.** Write down what you think this prints, including the order of the three drops. Then
> run `./demo 1`.

```text
1. End of scope, reverse declaration order
      make: first
      make: second
      make: third
      -- end of function --
      drop: third
      drop: second
      drop: first
```

Two things to notice. First, all three drops happen *after* the "end of function" line: values live
until the closing brace. Second, and more important, they die **backwards**: third, then second,
then first. Last made, first destroyed.

### Why backwards?

Think about how you got here. You made `first`. Then you made `second`, and `second` might have been
built using `first` — it might rely on it in some way. Then you made `third`, which might rely on
either of them. Later things can depend on earlier things, but earlier things cannot depend on later
ones, because the later ones did not exist yet.

So if you destroy in reverse order, then whenever a value is destroyed, everything it might rely on
is still alive. Destroy in forward order, and `first` disappears while `second` might still need it.

Picture a stack of plates: you add plates on top, and you take them off the top. The last plate you
put down is the first one you pick up.

This matters a lot in the kernel. Suppose you take a lock, and then create something that the lock
protects. You want the protected thing cleaned up while you still hold the lock, and the lock
released last. Reverse order gives you exactly that, for free.

### A block inside a function is its own scope

```rust
let _outer = Noisy::new("outer");
{
    let _inner = Noisy::new("inner");
    println!("      -- leaving inner block --");
}
println!("      -- back in outer, inner is already gone --");
```

> **▶ Try it.** Predict, then run `./demo 2`.

```text
2. Nested scope drops early
      make: outer
      make: inner
      -- leaving inner block --
      drop: inner
      -- back in outer, inner is already gone --
      drop: outer
```

`inner` dies at the inner `}`, not at the end of the function. This gives you control: if you want
something released halfway through a function, such as a lock, you put it inside a block.

### Two surprises

These two catch almost everyone, so it is better to meet them now.

**Reusing a name does not destroy the old value.** You probably met *shadowing* when learning
variables: writing `let v = ...` a second time makes a new variable with the same name.

```rust
let v = Noisy::new("shadowed");
let v = Noisy::new("shadowing");
```

You might expect the first value to die when its name is taken. It does not:

```text
8. Shadowing: the old value lives until end of scope
      make: shadowed
      the name v refers to: shadowed
      make: shadowing
      the name v now refers to: shadowing
      but BOTH values are still alive — only the name was reused
      drop: shadowing
      drop: shadowed
```

Shadowing changes which value a *name* points to. The old value still exists until the end of the
scope; you just cannot reach it any more. In the kernel this matters: if the old value was holding a
lock, the lock is still held.

**A list drops its items front to back.**

> **🆕 New Rust — `Vec` and `vec![...]`**
>
> A `Vec` is a list that can grow, like an array whose length can change. `vec![a, b, c]` creates
> one holding `a`, `b` and `c`. The items live on the heap; the `Vec` itself owns them.

```rust
let v = vec![Noisy::new("elem0"), Noisy::new("elem1"), Noisy::new("elem2")];
```

```text
10. Vec drops its elements front to back
      make: elem0
      make: elem1
      make: elem2
      -- vec about to go out of scope --
      drop: elem0
      drop: elem1
      drop: elem2
```

Forwards, not backwards. This is not a contradiction. "Reverse order" is a rule about **variables
in a scope**, where later ones may depend on earlier ones. A `Vec` is one value that holds several
items side by side, with no dependency between them, so it simply walks them in order. Fields inside
a struct work the same way, top to bottom — keep that in mind, because it comes back in Part 5.

> **▶ Try it.** Run `./demo 8` and `./demo 10` and check them against the outputs above.

---

## Part 3 — Moves (15 minutes)

### What `let b = a;` does to a String

```rust
let a = String::from("hello");
let b = a;
```

In many languages, this would give you two names for the same text. Rust does something different,
and the stack-and-heap picture from Part 1 shows why.

When `b = a` runs, the three numbers on the stack — the pointer, the length, and the capacity — are
copied into `b`. The text on the heap is **not** copied. So now two variables point at the same five
letters:

```text
   a  ┌──────────────┐
      │ pointer ─────┼───┐
      │ length  5    │   │      ┌───┬───┬───┬───┬───┐
      └──────────────┘   ├────▶ │ h │ e │ l │ l │ o │
   b  ┌──────────────┐   │      └───┴───┴───┴───┴───┘
      │ pointer ─────┼───┘
      │ length  5    │
      └──────────────┘
```

Now think about rule 3. At the end of the scope, both `a` and `b` go out of scope. If both were owners,
both would free the text. The same memory would be given back twice — a double free.

Rust prevents this with rule 2: **after `let b = a;`, ownership has moved to `b`, and `a` is no longer
usable.** There is only ever one owner, so the text is freed exactly once.

### What happens if you use `a` anyway

```rust
let a = String::from("hello");
let b = a;
println!("b = {}", b);
println!("a = {}", a);
```

This does not compile. Here is the real message:

```text
error[E0382]: borrow of moved value: `a`
 --> move_string.rs:5:24
  |
2 |     let a = String::from("hello");
  |         - move occurs because `a` has type `String`, which does not implement the `Copy` trait
3 |     let b = a;
  |             - value moved here
4 |     println!("b = {}", b);
5 |     println!("a = {}", a);
  |                        ^ value borrowed here after move
```

Learn to read these messages properly, because they are one of the best things about Rust. This one
points at three lines and tells you the whole story: where `a` was created (and why it moves instead
of being copied), which line moved it, and which line tried to use it afterwards.

Notice what kind of error this is. The double free was not caught while the program ran — **the
program was never built.** The bug cannot happen, because code containing it does not compile.

### What a move actually costs

Almost nothing. A move copies the few numbers on the stack — for a `String`, the pointer, length and
capacity — and that is all. It does not copy the text, does not ask for memory, does not give memory
back, and does not run any cleanup. Mostly, a move is the compiler updating its notes about which
variable is now responsible for the value.

You can see this with `Noisy`:

> **▶ Try it.** Predict how many `make` lines and how many `drop` lines section 3 prints. Then run
> `./demo 3`.

```text
3. Move: one value, one owner, one drop
      make: a
      moved a -> b, no drop happened during the move
      drop: a
```

**One make, one drop.** The value was created once and destroyed once. The move in between destroyed
nothing. The drop happens when `b`, the new owner, goes out of scope. The message still says `a`
because that is the text the value was created with — the value did not change, only its owner did.

### Passing a value to a function also moves it

```rust
fn consume(n: Noisy) {
    println!("      consume() received {}", n.0);
}

fn move_into_function() {
    let x = Noisy::new("x");
    consume(x);
    println!("      back in caller; x is already gone");
}
```

> **▶ Try it.** Where does the drop happen: inside `consume`, or back in `move_into_function`?
> Run `./demo 4`.

```text
4. Move into a function: it drops there, not here
      make: x
      consume() received x
      drop: x
      back in caller; x is already gone
```

The drop happens **inside `consume`**. Calling `consume(x)` moved ownership into the parameter `n`.
When `consume` finished, `n` went out of scope, and the value died there. The caller owns nothing any
more, so it has nothing to clean up.

This makes function signatures say something important. In C, if a function takes a pointer, the
signature does not tell you who is supposed to free the memory — you have to read the documentation
and hope it is correct. In Rust, `fn consume(n: Noisy)` says in the signature itself: *I am taking
this, and it is mine now.* Tomorrow you will learn how a function can look at a value *without*
taking it.

### Break it on purpose

> **▶ Try it.** Open `ownership_demo.rs`, find `fn moves()`, and remove the `//` from the line
> `// println!("{}", a.0);`. Compile with `rustc ownership_demo.rs -o demo` and read the full message.
> Then put the `//` back.

One more, which looks harmless. Put this in a new file called `loop_move.rs` and compile it:

```rust
fn consume(s: String) {
    println!("{}", s);
}

fn main() {
    let s = String::from("hi");
    for _ in 0..2 {
        consume(s);
    }
}
```

The important lines of the error:

```text
error[E0382]: use of moved value: `s`
7 |     for _ in 0..2 {
  |     ------------- inside of this loop
8 |         consume(s);
  |                 ^ value moved here, in previous iteration of loop
```

The first time round the loop, `s` is moved into `consume`. The second time round, there is nothing
left to move. The compiler sees this even though the loop only runs twice.

---

## Part 4 — Copy and Clone (10 minutes)

### Why integers do not move

```rust
let x: i32 = 5;
let y = x;
println!("x = {}, y = {}", x, y);
```

```text
x = 5, y = 5
```

No error — both work. That seems to break rule 2, but it does not. Go back to the stack-and-heap
picture: an `i32` lives **entirely on the stack**. There is nothing on the heap, so there is nothing
to give back when it dies. Copying its four bytes produces a second, complete, independent number,
and no double free is possible.

Rust marks types like this as **`Copy`**. A `Copy` type is copied when you assign it, instead of
moved. Integers, floating-point numbers, `bool` and `char` are `Copy`, and so are tuples and arrays
made only of those. Your own structs are only `Copy` if you ask for it, and only when every field is
itself `Copy`.

> **🆕 New Rust — `#[derive(...)]`**
>
> A line like `#[derive(Clone, Copy)]` above a struct asks the compiler to write some trait
> implementations for you, so you do not have to. You may have seen `#[derive(Debug)]` in the
> structs chapter; it is the same idea.

### A type can never be both Copy and Drop

Try to make a type that is `Copy` and also has a `Drop`:

```rust
#[derive(Clone, Copy)]
struct Bad(u32);

impl Drop for Bad {
    fn drop(&mut self) {}
}
```

```text
error[E0184]: the trait `Copy` cannot be implemented for this type; the type has a destructor
 --> copy_drop.rs:2:8
  |
1 | #[derive(Clone, Copy)]
  |                 ---- in this derive macro expansion
2 | struct Bad(u32);
  |        ^^^ `Copy` not allowed on types with destructors
```

The two ideas contradict each other. `Copy` says "duplicating this is harmless, there is nothing to
clean up." `Drop` says "there is cleanup to do when this dies." If a type were both, every assignment
would quietly create a second value, both would run the cleanup, and you would be cleaning up twice.

That gives you a useful shortcut when reading code: **if a type is `Copy`, it owns nothing that needs
cleaning up.**

> **▶ Try it.** In `ownership_demo.rs`, find `fn copy_types()`. Remove the `//` from the three lines
> that start with `#[derive`, `struct Bad` and `impl Drop for Bad`, and leave the two error-message
> lines below them commented. Compile, read `E0184`, then put the `//` back.

### Clone: when you really do want two

Sometimes you genuinely want a second, independent copy of a `String`. That is what `.clone()` is for:

```rust
let a = String::from("hello");
let b = a.clone();
println!("a = {}, b = {}", a, b);
```

```text
a = hello, b = hello
```

Both work, because `clone` made a **real second copy**: it asked for new heap memory and copied the
five letters into it. Now there are two separate strings, each with its own owner, and each will be
freed once.

> **▶ Try it.** Section 7 clones a struct that prints when it dies. How many drops? Run `./demo 7`.

```text
7. Clone: an explicit second value, so a second drop
      two independent Tags now exist: original / original
      drop: Tag(original)
      drop: Tag(original)
```

Two values, two drops. Rust makes you write `.clone()` out loud because it can be expensive — it
asks for memory and copies data — and Rust wants anything expensive to be visible when someone reads
the code.

In the kernel this matters even more, because **asking for memory can fail.** So when you see
`.clone()` in kernel code, always ask: what does this allocate, and what happens if that fails?

---

## Part 5 — Drop, and Why the Kernel Cares (15 minutes)

### Drop happens at a moment you can point to

With a garbage collector, you know memory will be freed *eventually*, but not when. In Rust, a value
is dropped at a specific point you can find by reading the code: its owner's closing brace. Every
time.

That reliability is what makes it safe to put important work inside `drop`. Unlocking a lock,
releasing an interrupt, returning memory — all of these can live in a `drop`, because you know
exactly when it runs. This pattern has a name you will see often: **RAII**, which stands for
"resource acquisition is initialization". The plain-words version: *when you get a resource, wrap it
in a value whose `drop` gives it back.*

You are not allowed to call `drop` yourself:

```rust
let n = Noisy("n");
n.drop();
```

```text
error[E0040]: explicit use of destructor method
11 |     n.drop();
   |       ^^^^ explicit destructor calls not allowed
help: consider using `drop` function
11 +     drop(n);
```

The reason is neat. If you could call `n.drop()`, you would still have the variable `n` afterwards,
and you could use it — a use-after-free. So Rust gives you `drop(n)` instead, a function that **takes
ownership** of `n`. The value moves into the function and dies there, and the name `n` becomes
unusable, just like any other move.

### Early return cleans up exactly what exists

```rust
fn early_return(fail_after: u32) {
    let _step1 = Noisy::new("step1");
    if fail_after == 1 {
        return;
    }

    let _step2 = Noisy::new("step2");
    if fail_after == 2 {
        return;
    }

    let _step3 = Noisy::new("step3");
}
```

The demo calls this three times: with 1, then 2, then 0.

> **▶ Try it.** For `fail_after == 1`, does `step2` get dropped? Predict all three runs, then run
> `./demo 5`.

```text
5. Early return with fail_after=1
      make: step1
      -- bailing out after step1 --
      drop: step1

5. Early return with fail_after=2
      make: step1
      make: step2
      -- bailing out after step2 --
      drop: step2
      drop: step1

5. Early return with fail_after=0
      make: step1
      make: step2
      make: step3
      -- completed all three --
      drop: step3
      drop: step2
      drop: step1
```

Three different exits, three different sets of cleanups, all correct and all in reverse order — and
there is **no cleanup code in the function at all.** When we bailed out after `step1`, `step2` was not
dropped, because it was never created. The compiler knows exactly what exists at every point.

Keep that output in mind. It is about to matter a great deal.

### The C pattern this replaces

Here is how a C driver sets up three resources. Each step can fail:

```c
static int foo_probe(struct platform_device *pdev)
{
	struct foo *f;
	int ret;

	f = kzalloc(sizeof(*f), GFP_KERNEL);
	if (!f)
		return -ENOMEM;

	ret = request_irq(f->irq, foo_isr, 0, "foo", f);
	if (ret)
		goto err_free;

	ret = foo_hw_init(f);
	if (ret)
		goto err_irq;

	return 0;

err_irq:
	free_irq(f->irq, f);
err_free:
	kfree(f);
	return ret;
}
```

The labels at the bottom form a ladder. Each label is a starting point for cleanup, and the labels
fall through into each other, so jumping to `err_irq` frees the interrupt *and then* frees the memory,
while jumping to `err_free` only frees the memory. It is a hand-written version of "clean up what
exists, in reverse order" — exactly what the compiler did for you in the last example.

It is correct C, and you will see this shape thousands of times in the kernel. The trouble is that a
human has to keep the ladder in step with the code above it, by hand, forever. Someone jumps to the
wrong label. Someone adds a fourth resource and forgets to add a rung. Someone reorders the steps and
forgets to reorder the ladder. Someone writes a plain `return` in the middle and skips the ladder
completely. Every one of those mistakes only shows up when something *fails*, which almost never
happens during testing — so the bug sits there for years.

### The same thing in Rust

Open `raii_probe.rs`. It is a pretend driver that acquires memory, then an interrupt, then a lock,
where any step can fail. It uses three new pieces of Rust, so read these boxes first.

> **🆕 New Rust — `Result`**
>
> Functions that can fail return a `Result`. A `Result` is always one of two things:
> `Ok(value)` when it worked, or `Err(error)` when it did not. The type
> `Result<Resource, String>` means "either a `Resource`, or an error message".

> **🆕 New Rust — the `?` operator**
>
> Putting `?` after a call that returns a `Result` means: *if this is an `Err`, stop and return that
> error from my function right now; if it is `Ok`, take the value out and carry on.* It is a
> one-character early return.

> **🆕 New Rust — `match` and `format!`**
>
> `match` looks at a value and runs the branch that fits it: `Ok(x) => ...` runs when it worked,
> `Err(e) => ...` when it failed. You will learn `match` properly on Day 4. `format!` works like
> `println!`, but builds a `String` instead of printing it.

Here is the heart of the file:

```rust
fn probe(fail_at: u32) -> Result<Device, String> {
    let memory = Resource::acquire("memory", fail_at == 1)?;
    let irq = Resource::acquire("irq", fail_at == 2)?;
    let lock = Resource::acquire("lock", fail_at == 3)?;
    Ok(Device { _lock: lock, _irq: irq, _memory: memory })
}
```

`Resource` is a struct whose `drop` prints `released ...`, just like `Noisy`. `main` calls `probe`
four times, failing at step 1, 2, 3, and then not at all.

> **▶ Try it.** Predict what happens when step 3 (the lock) fails: what gets released, and in which
> order? Then compile and run:
>
> ```bash
> rustc raii_probe.rs -o probe && ./probe
> ```

```text
--- probe, failing at step 1 ---
      FAILED to acquire memory
      probe returned error: could not get memory

--- probe, failing at step 2 ---
      acquired memory
      FAILED to acquire irq
      released memory
      probe returned error: could not get irq

--- probe, failing at step 3 ---
      acquired memory
      acquired irq
      FAILED to acquire lock
      released irq
      released memory
      probe returned error: could not get lock

--- probe, failing at step 0 ---
      acquired memory
      acquired irq
      acquired lock
      probe succeeded; device in use...
      released lock
      released irq
      released memory
```

Look at the failure at step 3. The memory and the interrupt had been acquired, the lock failed, and
`?` returned early. At that moment, rule 3 dropped everything that existed, in reverse order:
interrupt first, then memory. That is exactly what the C ladder's `err_irq` label did — except
nobody wrote it.

**There is no ladder in `probe`, and no cleanup code at all.** That is the most important idea of
the day:

> In C, the cleanup is written *separately* from the setup, and a human must keep the two in step.
> In Rust, the cleanup *follows automatically* from the setup.

Add a fourth resource, and its cleanup comes with it, because the cleanup lives in that resource's
own `drop`. Reorder the steps, and the cleanup order changes to match. Add an early return anywhere,
and it still cleans up correctly. None of the C mistakes can be written. This is the single biggest
reason Rust is in the kernel.

**One detail in the success case.** When the probe succeeds, the three resources live inside a
`Device` struct, and when the device is dropped they are released lock, interrupt, memory — reverse
order again. But remember from Part 2: a struct drops its fields **top to bottom**. So how does it
come out reversed? Look at the struct:

```rust
struct Device {
    _lock: Resource,
    _irq: Resource,
    _memory: Resource,
}
```

The fields are listed in reverse on purpose, so that top-to-bottom teardown releases the lock first
and the memory last. Real kernel drivers think about field order for exactly this reason.

---

## Part 6 — How Kernel Rust Is Different (10 minutes)

Most Rust you will find online is written for normal programs. Kernel Rust has three important
differences.

### There is no standard library

Normal Rust comes with a standard library, called `std`, full of useful things: files, threads,
networking, `println!`. Everything in `std` eventually asks the operating system for help. But the
kernel **is** the operating system. There is nobody underneath to ask.

So kernel Rust gets only the parts that need no operating system: `core` (numbers, `Result`, and other
basics) and `alloc` (things like lists that use heap memory). This is called `no_std`. It is also
why, in Week 0, you installed `rust-src`: the kernel build compiles `core` from source itself.

The difference you will notice first: there is no `println!`. In the kernel you write `pr_info!`, and
the message goes to the kernel log, which you read with `dmesg`.

### A panic stops the whole machine

> **🆕 New Rust — panics and `unwrap()`**
>
> A **panic** is Rust's way of saying "something impossible happened, stop right now". One common way
> to cause one is `.unwrap()`, which means "give me the value inside this `Result`, and if it is an
> error, panic."

In a normal program, a panic stops that program. The operating system cleans up, and you run it
again. In the kernel, there is nothing above you to clean up. **A panic in kernel code is a kernel
panic: the whole machine stops**, and every program running on it is lost.

So, a rule to remember from today, even though you will not write kernel code for a few weeks:
**`unwrap()` is a bug in kernel code.** Not bad style — a bug, because its failure stops the machine.
Handle the error instead, usually with `?`.

### Asking for memory can fail

> **🆕 New Rust — `Box` and `KBox`**
>
> A `Box` holds one value on the heap; when the `Box` is dropped, the heap memory is given back.
> `KBox` is the kernel's version.

In a normal program, asking for memory never fails — if the computer runs out, the program is
simply stopped. The kernel cannot treat itself that way; running low on memory is a normal situation
it must survive. So in the kernel, asking for memory returns a `Result`:

```rust
let b = KBox::new(value, GFP_KERNEL)?;
```

`GFP_KERNEL` is the same flag C code passes to `kmalloc`. It tells the memory allocator what it is
allowed to do, such as wait for memory to become free. And the `?` means that if there is no memory,
the error is passed up like any other error — and everything already acquired is cleaned up
automatically, exactly as in `raii_probe.rs`.

### When `drop` does not run

`drop` is reliable, but there are four situations where it does not run, and it is worth knowing all
four.

**You told Rust not to.** The function `mem::forget` takes a value and throws it away without running
its `drop`.

> **🆕 New Rust — `use std::mem;`**
>
> `use` makes a name from a library available in your file. `std::mem` is a part of the standard
> library with tools for working with memory, and after `use std::mem;` you can write `mem::forget`.

> **▶ Try it.** Run `./demo 9`.

```text
9. mem::forget suppresses Drop entirely
      make: kept
      make: leaked
      forgot 'leaked'; only 'kept' will drop
      drop: kept
```

This is allowed in normal Rust because leaking memory is wasteful but cannot corrupt anything.

**The code panicked.** A kernel panic stops everything, so no `drop` runs.

**The program or machine stopped.** Nothing runs after that.

**The value never went out of scope.** You have already seen this one without knowing it. In Week 0,
you built the sample modules as `=m` (loadable) instead of `=y` (built into the kernel). A built-in
module is never unloaded, so the value representing it never goes out of scope, and its `drop` never
runs. Same source code, and in one build the cleanup code simply never executes. That is Saturday's
lab.

---

## Your Turn (10 minutes)

Now write one yourself, from scratch, without copying from the demo. Typing it yourself is what makes
it stick.

Create a file called `my_drop_order.rs`. In it, write a struct called `Guard` that holds a name and
prints `release <name>` when it is dropped. Then write a function `setup` that takes a `bool`: it
creates a guard named `a`, returns early if the `bool` is true, and otherwise creates a guard named
`b`. In `main`, create a guard named `outer`, then an inner block containing **only** a guard named
`inner`. After that block has closed, call `setup(true)`, then `setup(false)`, then print
`end of main`.

```rust
fn main() {
    // 1. guard named "outer"

    {
        // 2. guard named "inner" — nothing else goes in this block
    }

    // 3. setup(true)
    // 4. setup(false)
    // 5. print "end of main"
}
```

**Before you run it**, write your predicted output as a comment at the top of the file. Then:

```bash
rustc my_drop_order.rs -o my_drop_order && ./my_drop_order
```

<details>
<summary>One possible solution, and its output</summary>

```rust
struct Guard(&'static str);

impl Drop for Guard {
    fn drop(&mut self) {
        println!("release {}", self.0);
    }
}

fn setup(fail: bool) {
    let _a = Guard("a");
    if fail {
        return;
    }
    let _b = Guard("b");
}

fn main() {
    let _outer = Guard("outer");
    {
        let _inner = Guard("inner");
    }
    setup(true);
    setup(false);
    println!("end of main");
}
```

```text
release inner
release a
release b
release a
end of main
release outer
```

`inner` dies at the end of its block. `setup(true)` makes `a` and returns early, so only `a` is
released. `setup(false)` makes `a` then `b`, and releases them in reverse. `outer` lives until the
very end of `main`, after the last print.

</details>

Save your work into the repository:

```bash
cp my_drop_order.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_1/
bash ~/LKD_RUST/codes/sync_to_repo.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_1/check_day1.sh
```

---

## Checking Yourself

Without running anything, what does this print?

```rust
fn f() {
    let a = Noisy::new("a");
    {
        let b = Noisy::new("b");
        let c = b;
    }
    let d = Noisy::new("d");
}
```

<details>
<summary>Answer</summary>

```text
make: a
make: b
drop: b
make: d
drop: d
drop: a
```

`let c = b;` is a move. It does not create a second value and does not drop anything. The value now
belongs to `c`, and `c`'s scope is the inner block, so the value dies at that inner `}`. The message
says `b` because that is the text it was created with. Then `d` is made, and at the end of the
function `d` and `a` are dropped in reverse order.

If you expected a drop at the move, re-read *What a move actually costs* in Part 3. If you expected
the value to live past the inner block, remember that it is the **owner's** scope that counts, and the
owner is `c`.

</details>

---

## Common Confusions

**"A move copies the data."** It does not. It copies the few numbers on the stack, never the heap
data, and often the compiler removes even that.

**"A move drops the old value."** It does not. There is one value, dropped once, when the *new*
owner's scope ends. If you ever see two drops, you had two values — usually from a `.clone()`.

**"Shadowing frees the old value."** It does not. Both values live until the end of the scope.

**"Everything drops in reverse."** Variables in a scope do. Items in a `Vec` and fields in a struct
drop front to back.

**"I can call `.drop()` to clean up early."** You cannot. Use `drop(value)`, or put the value in a
smaller block.

**"`drop` always runs."** Not after `mem::forget`, a kernel panic, the machine stopping, or for a value
that never leaves scope — such as a built-in module.

**"When the compiler complains, add `.clone()`."** It often works, and it hides the real question. In
kernel code it may also ask for memory, which can fail. Tomorrow you will learn the usual right
answer: borrowing.

**"`unwrap()` is fine if I am sure."** In kernel code it is a bug, because if you are wrong, the
machine stops.

---

## My Notes

### The prediction I got wrong

| Demo section | What I predicted | What happened | Why I was wrong |
|---|---|---|---|
| | | | |

### The errors I caused on purpose

| What I did | Error code | What the message taught me |
|---|---|---|
| used a String after moving it | `E0382` | |
| moved a String inside a loop | `E0382` | |
| made a type both `Copy` and `Drop` | `E0184` | |
| called `.drop()` myself | `E0040` | |

### In my own words

Why does Rust move a `String` but copy an `i32`?

Why are variables dropped in reverse order?

How does `?` together with `drop` replace the C `goto` ladder?

### What I still do not understand

---

## Done When

You can say the three ownership rules from memory, and explain why the kernel cannot use a garbage
collector.

You can draw the stack-and-heap picture of a `String`, and use it to explain why `let b = a;` moves
instead of copying, and what bug that prevents.

You can predict drop order for a scope, a nested block, a move, a function call, and an early return —
and you know the two exceptions: shadowing does not drop early, and a `Vec` drops front to back.

You can explain why a type can never be both `Copy` and `Drop`.

You ran `raii_probe.rs`, predicted the step-3 failure correctly, and can explain how `?` plus `drop`
removes the C `goto` ladder.

You can name the three ways kernel Rust differs — no `std`, panics stop the machine, memory requests
can fail — and explain why `unwrap()` is a bug in kernel code.

You wrote `my_drop_order.rs` yourself and your prediction matched the output.

---

## Further Reading

**The Rust Book, Chapter 4 ("Understanding Ownership")** covers today's ideas from another angle, with
the same stack-and-heap pictures. Read it *after* today, to confirm what you have seen for yourself.

**`samples/rust/rust_minimal.rs`** in your kernel tree is about 30 lines. Its `impl Drop` is the code
that runs when the module is unloaded.

**[rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/)** is the kernel's Rust documentation.
Look up `KBox` and `KVec` — you are only learning where things live, not what they do yet.

---

## If You Have More Time (optional)

These are outside the 90 minutes, and each is worth doing when you can.

**Find a real `goto` ladder.** In your kernel tree, run `git grep -n "err_unlock:" -- drivers/ | head`,
open one of the files, and read the whole function. Count the labels, and ask yourself how many
places you would have to change to add one more resource.

**Look at `KBox::new` in the real source.** Run
`grep -n "pub fn new" ~/LKD_RUST/kernel/linux/rust/kernel/alloc/kbox.rs` and notice that it takes an
allocation flag and returns a `Result`.

**Make your own puzzle harder.** Combine a nested block, a move, and an early return in one function.
Write your prediction first, then run it with both a true and a false argument.

---

## 📖 Revision — Read This First When You Come Back

### The day as a story

Every language must decide when memory is given back. Too early is a use-after-free, twice is a
double free, never is a leak. C makes you decide by hand on every path, and most serious kernel
security bugs are the result. A garbage collector cannot work in a kernel, because nothing runs below
the kernel and some kernel code may never pause. Rust's answer is ownership: the compiler works out
where each value's life ends and writes the cleanup there.

There are three rules. Every value has one owner. Assigning or passing a value moves ownership.
When the owner goes out of scope, the value is dropped. Variables in a scope are dropped in reverse
order, because later things may depend on earlier ones. Shadowing does not drop early, and a `Vec`
or a struct drops its contents front to back.

A `String` keeps a pointer, a length and a capacity on the stack and its text on the heap. If
`let b = a;` gave two owners, the text would be freed twice, so Rust makes `a` unusable instead. A
move costs almost nothing. Types that live entirely on the stack, like `i32`, are `Copy` and are
duplicated instead of moved; a type can never be both `Copy` and `Drop`. `.clone()` makes a real,
explicit second copy, which may ask for memory.

`drop` runs at a predictable moment, so it can safely release locks, interrupts and memory. Combined
with `?`, it replaces the C `goto` ladder: cleanup follows automatically from setup instead of being
maintained separately by hand. Kernel Rust has no `std`, a panic stops the machine (so `unwrap()` is a
bug), and asking for memory returns a `Result`.

### If you remember only five things

1. **One owner. Moved on assignment. Dropped at the end of its scope.**
2. **Reverse order for variables in a scope**; front to back inside a `Vec` or a struct.
3. **`Copy` means nothing to clean up**, which is why it can never be combined with `Drop`.
4. **`?` plus `drop` replaces `goto err_unlock`** — cleanup follows from setup.
5. **No `unwrap()` in kernel code**, because a kernel panic stops the machine.

### Quick recall

Answer each one out loud before opening the answers.

1. Name the three ways giving memory back can go wrong.
2. Why can the kernel not use a garbage collector?
3. What are the three ownership rules?
4. What does a `String` keep on the stack, and what on the heap?
5. Why does `let b = a;` make `a` unusable for a `String` but not for an `i32`?
6. In what order are three variables in one scope dropped, and why?
7. Does shadowing a variable drop the old value?
8. Why can a type never be both `Copy` and `Drop`?
9. When `probe` fails at step 3, what is released, and in what order?
10. Name the four situations where `drop` does not run.

<details>
<summary>Answers</summary>

1. Too early (use-after-free), twice (double free), never (leak).
2. Nothing runs underneath the kernel to host one, and some kernel code is not allowed to pause.
3. One owner per value; assigning or passing moves ownership; the value is dropped when the owner
   goes out of scope.
4. Stack: a pointer, a length and a capacity. Heap: the text itself.
5. Two owners of the same heap text would free it twice. An `i32` has nothing on the heap, so
   copying it is complete and safe — it is `Copy`.
6. Reverse order of creation, because later values may depend on earlier ones.
7. No. Both values live until the end of the scope; only the name was reused.
8. `Copy` says there is nothing to clean up; `Drop` says there is. Both together would mean cleaning
   up twice.
9. The interrupt, then the memory — what existed, in reverse order. The lock was never acquired.
10. After `mem::forget`; after a panic; when the machine stops; when the value never leaves scope,
    such as a module built into the kernel.

</details>

### The code, in order

```bash
cd ~/rust-scratch
rustc ownership_demo.rs -o demo
./demo 1          # end of scope, reverse order
./demo 2          # nested block
./demo 3          # move: one make, one drop
./demo 4          # move into a function
./demo 5          # early return
./demo 7          # clone: two drops
./demo 8          # shadowing
./demo 9          # mem::forget
./demo 10         # Vec order

rustc raii_probe.rs -o probe && ./probe     # the goto ladder, deleted

rustc my_drop_order.rs -o my_drop_order && ./my_drop_order
```

---

**Next:** [M1W1D2 — Borrowing and the Borrow Checker](Day_2.md). Today answered "who is responsible
for cleaning this up?" Tomorrow answers "who is allowed to *look at* it, and when?" — which is how a
function can use a value without taking it away from you.

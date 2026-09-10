# M1W1D1 — Ownership, Moves, and Drop

> **Goal:** understand the one rule the whole language is built on, and see why it deletes an entire
> category of kernel bug. By the end you will be able to predict `Drop` order before running the code.
>
> **Time:** 2-3 hours. No kernel rebuilds today — you will work in userspace, where the loop is one
> second instead of five minutes.
>
> **New to Rust syntax?** Day 1's first code block uses `struct`, `impl`, and `impl Drop for Noisy`,
> but the roadmap does not formally teach structs until W1D4 and traits until W2D1. If any of those
> look like noise, spend two hours on
> [`Day_0_Rust_Primer.md`](Day_0_Rust_Primer.md) first — it covers exactly that gap, so ownership can
> be the only new idea today.
>
> **Why this matters:** roughly two thirds of serious Linux CVEs are memory-safety bugs — use-after-free,
> double-free, buffer overflow, data race. Ownership is the mechanism that makes most of them impossible
> to write. Today is not "learning Rust syntax." It is learning the one idea the rest of the roadmap
> depends on, and understanding it properly now saves you from cargo-culting `unsafe` in Month 5.

---

## Today's Checklist

- [ ] The three ownership rules, and why they exist rather than a garbage collector
- [ ] Move semantics: why `let b = a;` makes `a` unusable
- [ ] `Copy` vs `Clone`, and why a type can never be both `Copy` and `Drop`
- [ ] `Drop`: deterministic destruction, and drop order in reverse declaration order
- [ ] Drop in nested scopes, on early return, and after a move
- [ ] **The payoff:** how RAII deletes the `goto err_unlock` ladder from C
- [ ] What kernel Rust does **not** have: no `std`, no unwinding, no infallible allocation
- [ ] When `Drop` does **not** run, and why one of those cases already bit you in Week 0
- [ ] **Code:** run `ownership_demo.rs`, predicting each section before you look
- [ ] **Read C:** find a real `goto` error ladder in the kernel and count its failure paths
- [ ] Journal: the prediction you got wrong, because that is the one you actually learned

---

## Concepts

### 1. The problem ownership solves

Every language has to answer one question: **when is it safe to free this memory?**

There are only three answers anyone has found, and they are all trade-offs:

| Approach | Who decides | Cost |
|---|---|---|
| **Manual** (C) | you | `free()` too early → use-after-free. Twice → double-free. Never → leak |
| **Garbage collection** (Java, Go) | a runtime, while your program runs | unpredictable pauses, a runtime, extra memory |
| **Ownership** (Rust) | the compiler, before your program runs | you have to convince the compiler |

The kernel cannot use the second one. There is no runtime underneath to host a collector, and a
garbage-collection pause in an interrupt handler is not a thing that can exist. So C picks manual,
and pays for it: the kernel's CVE list is substantially a list of people getting manual wrong.

Rust picks the third. **The freeing code is still there — the compiler writes it for you, at compile
time, at a place it can prove is correct.** No runtime, no pauses, no overhead. That is the whole
reason Rust is in the kernel at all.

### 2. The three rules

```text
1. Every value has exactly one owner.
2. Assigning or passing it MOVES ownership. There is still only one owner.
3. When the owner goes out of scope, the value is dropped.
```

That is it. Everything else today follows from those three lines.

Rule 3 is the one that does the work. "Goes out of scope" means a closing brace, a `return`, a `?`
that returns early, or a panic — and at every one of those points the compiler has already inserted
the cleanup.

### 3. Move: why `let b = a;` breaks `a`

```rust
let a = Noisy::new("a");
let b = a;              // 'a' is now invalid
println!("{}", a.0);    // error[E0382]: borrow of moved value: `a`
```

Coming from C this looks hostile. It is protecting you from something specific.

If both `a` and `b` owned the value, both would clean it up at end of scope — a **double free**. Rust's
answer is not to add a check at runtime; it is to make the second use fail to compile. The value moved
to `b`, so `a` is no longer a valid name for anything.

Two things worth noticing in the demo output:

```text
3. Move: one value, one owner, one drop
      make: a
      moved a -> b, no drop happened during the move
      drop: a
```

**One `make`, one `drop`.** The move itself costs nothing and destroys nothing — the value is the
same value, it just answers to a different name now. And the drop happens once, when `b`'s scope ends.

### 4. `Copy`: the exception, and why it exists

```rust
let a: i32 = 42;
let b = a;
println!("{} {}", a, b);   // both fine
```

Integers do not move. Why the inconsistency?

Because for an `i32` there is **nothing to free**. Duplicating the bits produces a second, entirely
valid, entirely independent value. There is no double-free to protect against, so the ceremony would
buy nothing and cost readability.

`Copy` means exactly: *duplicating the bytes is a valid way to produce another one of these.* It
holds for integers, `bool`, `char`, floats, shared references `&T`, and tuples and arrays of `Copy`
things. It does **not** hold for anything owning a heap allocation, a file, a lock, or a device.

**The rule that makes this click:** a type can never be both `Copy` and `Drop`.

```rust
#[derive(Clone, Copy)]
struct Bad(u32);
impl Drop for Bad { fn drop(&mut self) {} }
// error[E0184]: the trait `Copy` cannot be implemented for this type;
//               the type has a destructor
```

The compiler refuses because the two ideas contradict each other. If a type needs cleanup, silently
duplicating it means cleaning up twice. **`Copy` is a promise that there is nothing to clean up.**

### 5. `Clone`: explicit, and possibly expensive

`Clone` is the "yes, really duplicate this" escape hatch. It is a method call, never implicit, and it
can do arbitrary work — including allocating.

```text
7. Clone: an explicit second value, so a second drop
      two independent Tags now exist: original / original
      drop: Tag(original)
      drop: Tag(original)
```

Two values, two drops. That is the point: `.clone()` is visible in the source precisely so that its
cost is visible in review.

**In the kernel this matters more than in userspace.** A clone that allocates can *fail*, and kernel
Rust does not let allocation failure be an abort. So kernel collection types take an explicit
allocation flag and hand you back a `Result` rather than cloning silently. When you see `.clone()` in
kernel Rust, ask what it allocates.

### 6. `Drop`: destruction at a time you can point at

```rust
impl Drop for Noisy {
    fn drop(&mut self) {
        println!("drop: {}", self.0);
    }
}
```

You never call this. You cannot — `noisy.drop()` is a compile error, because that would let you drop
a value and then keep using it. The compiler calls it, once, at the point the owner's scope ends.

The word that matters is **deterministic**. Not "eventually", not "when the collector next runs" —
at a specific line, every time, and you can predict which. That determinism is what makes it safe to
put a mutex unlock, a refcount decrement, or a DMA unmap inside a destructor.

### 7. Drop order: reverse declaration order

Values in a scope drop **last-declared-first**, like popping a stack:

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

This is not arbitrary. Later values may have been built *from* earlier ones, so they must be torn
down first. If you declare a lock and then something the lock protects, you want the protected thing
released while the lock is still held.

The same rule, in three other situations:

**Nested scopes** — the inner block drops at its own brace:

```text
      make: outer
      make: inner
      -- leaving inner block --
      drop: inner
      -- back in outer, inner is already gone --
      drop: outer
```

**Moved into a function** — it drops in the callee, not the caller:

```text
      make: x
      consume() received x
      drop: x
      back in caller; x is already gone
```

**Shadowing does NOT drop early** — reusing a name does not destroy the old value:

```text
      the name v refers to: shadowed
      the name v now refers to: shadowing
      but BOTH values are still alive — only the name was reused
      drop: shadowing
      drop: shadowed
```

That last one surprises people. `let v = ...; let v = ...;` gives you two live values and one usable
name. Both drop at end of scope, still in reverse declaration order.

**Collections drop front to back**, not reversed — `Vec` is not a scope:

```text
      drop: elem0
      drop: elem1
      drop: elem2
```

### 8. The payoff: RAII deletes `goto err_unlock`

This is the most important section today. Everything above was setup for it.

Open almost any C kernel function that acquires more than one resource and you will find this shape:

```c
static int foo_probe(struct platform_device *pdev)
{
	struct foo *f;
	int ret;

	f = kzalloc(sizeof(*f), GFP_KERNEL);
	if (!f)
		return -ENOMEM;

	f->buf = kmalloc(BUF_SIZE, GFP_KERNEL);
	if (!f->buf) {
		ret = -ENOMEM;
		goto err_free_f;
	}

	ret = request_irq(f->irq, foo_isr, 0, "foo", f);
	if (ret)
		goto err_free_buf;

	mutex_lock(&f->lock);
	ret = foo_hw_init(f);
	if (ret)
		goto err_unlock;

	mutex_unlock(&f->lock);
	return 0;

err_unlock:
	mutex_unlock(&f->lock);
	free_irq(f->irq, f);
err_free_buf:
	kfree(f->buf);
err_free_f:
	kfree(f);
	return ret;
}
```

That descending ladder of labels is one of the most recognisable things in the kernel. It is also a
**bug farm**, and the bugs are always the same four:

| Mistake | Consequence |
|---|---|
| `goto` the wrong label | leak, or a free of something never allocated |
| Add a resource, forget a ladder rung | leak on that path only — invisible until it matters |
| Reorder the acquisitions, forget to reorder the ladder | free in the wrong order |
| Return directly instead of `goto` | everything above it leaks |

Every one of those is invisible on the happy path. They live on error paths, which are exactly the
paths nobody exercises.

**In Rust the ladder does not exist.** Not "is shorter" — is absent:

```rust
fn probe(pdev: &mut Device) -> Result<Foo> {
    let buf = KVec::with_capacity(BUF_SIZE, GFP_KERNEL)?;
    let irq = Irq::request(pdev.irq(), foo_isr)?;
    let guard = self.lock.lock();
    hw_init(&guard)?;
    Ok(Foo { buf, irq })
}
```

Each `?` means "if this failed, return the error now." And at each of those early returns, every
value constructed so far is dropped, in reverse order, automatically. The lock guard releases the
mutex. The IRQ handle frees the IRQ. The buffer frees itself.

There is no ladder to get wrong, because **the cleanup is derived from the construction order** rather
than maintained separately by hand. Add a resource and its cleanup arrives with it. Reorder them and
the teardown reorders itself.

> Look again at demo section 5 — `fail_after=1`, then `2`, then `0`. Three different exit points,
> three different sets of cleanups, all correct, and no error-handling code anywhere in the function.
> That output *is* the `goto` ladder, generated by the compiler.

### 9. What kernel Rust does not have

You are not writing the Rust in the online tutorials. Three differences, and they are not small.

**No `std`.** Only `core` and `alloc`. No `println!`, no `File`, no `HashMap` from `std`, no threads,
no sockets. This is `no_std`, and it is why Day 4 of Week 0 had you install `rust-src` — the kernel
compiles `core` itself. In kernel code you write `pr_info!` instead of `println!`.

**No unwinding.** Kernel Rust builds with `panic = abort`. In userspace a panic unwinds the stack and
runs destructors on the way out; in the kernel there is nowhere to unwind *to*. A panic is a kernel
panic — the machine stops.

The practical consequence you must internalise now: **`unwrap()` and `expect()` are bugs in kernel
code.** Not "bad style" — the failure mode is taking down the machine. You will feel the pull to
write them all through Month 2. Do not.

**No infallible allocation.** This is the biggest one. In userspace, `Box::new(x)` cannot fail — if
the allocator is out of memory, the process aborts. The kernel cannot take that attitude about
itself, so allocation returns a `Result`:

```rust
let b = KBox::new(value, GFP_KERNEL)?;              // may fail, must be handled
let mut v = KVec::with_capacity(n, GFP_KERNEL)?;
v.push(item, GFP_KERNEL)?;
```

`GFP_KERNEL` is the same allocation-context flag as C's `kmalloc(size, GFP_KERNEL)` — it says which
contexts this call may sleep in. The `?` says allocation failure is a normal outcome that propagates
like any other error.

So `KBox` and `KVec` rather than `Box` and `Vec`. Same ownership rules, fallible construction.

### 10. When `Drop` does *not* run

Four cases. Knowing them stops you trusting a destructor that was never going to fire.

**You leaked it deliberately.** `mem::forget(x)` and `ManuallyDrop` suppress the destructor:

```text
9. mem::forget suppresses Drop entirely
      make: kept
      make: leaked
      forgot 'leaked'; only 'kept' will drop
      drop: kept
```

Note that this is **safe** Rust. Leaking memory is not a safety violation — it cannot corrupt
anything. It is merely wrong.

**It panicked.** With `panic = abort` there is no unwind, so no destructors run.

**The process/machine ended.** Nothing runs at that point.

**The value never went out of scope.** And here is one you have already met:

> In Week 0 Day 4 you built the samples as `=m` rather than `=y`, and the reason given was that a
> built-in module cannot be `insmod`'d. There is a second reason, and it is a `Drop` reason: a
> module compiled into the kernel is **never unloaded**, so its module struct never goes out of
> scope, so its `Drop` never runs. Same source file, and the teardown path simply does not execute.
> That is Saturday's lab.

---

## Step-by-Step

### Phase 0 — Sync and set up a scratch area

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
rustc --version
```

**If `rustc: command not found`:** your shell has not picked up cargo's directory. It is installed at
`~/.cargo/bin`, and a distro `~/.bashrc` returns early for non-interactive shells:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Today needs **no kernel tree and no builds.** Plain `rustc` on a single file, deliberately: the
compile-run loop is about a second, and you are going to run it many times.

### Phase 1 — Predict, then run

Copy the demo across and **open it before running it**:

```bash
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_1/ownership_demo.rs .
$EDITOR ownership_demo.rs
```

Now the part that determines whether today works. For each of the ten sections, **write down the
order you expect** — on paper, in your journal, anywhere but in your head.

```bash
rustc ownership_demo.rs -o demo && ./demo
```

Compare against your predictions. **The one you got wrong is the only one you learned anything from**,
so write down which it was. For most people it is section 8 (shadowing) or section 10 (Vec order).

### Phase 2 — Break it on purpose

Reading a compile error you caused deliberately is worth more than reading three pages about it.

**Use after move.** In `moves()`, uncomment the `println!`:

```rust
println!("{}", a.0);
```

```bash
rustc ownership_demo.rs -o demo
```

Read the whole message, not just the first line:

```text
error[E0382]: borrow of moved value: `a`
  |
  |     let a = Noisy::new("a");
  |         - move occurs because `a` has type `Noisy`, which does not implement the `Copy` trait
  |     let b = a;
  |             - value moved here
  |     println!("{}", a.0);
  |                    ^^^ value borrowed here after move
```

It tells you three things: where the value was created, where it moved, and where you tried to use
it after. `rustc` errors are unusually good and you should get in the habit of reading them fully.

**`Copy` plus `Drop`.** In `copy_types()`, uncomment the `Bad` struct:

```text
error[E0184]: the trait `Copy` cannot be implemented for this type;
              the type has a destructor
```

**Now three of your own.** Try to predict the error before compiling each time:

```rust
// 1. move into a function, then use the original
let n = Noisy::new("n");
consume(n);
println!("{}", n.0);

// 2. move in a loop — why does the SECOND iteration fail?
let n = Noisy::new("n");
for _ in 0..2 {
    consume(n);
}

// 3. call drop() yourself
let n = Noisy::new("n");
n.drop();
```

Number 3 is the interesting one. Read what it suggests instead, and think about why the language
forbids the obvious spelling.

### Phase 3 — Write your own drop-order puzzle

Do not skip this. Predicting someone else's output is easier than predicting your own.

Add a function that combines three things at once — a nested scope, a move, and an early return —
and write your prediction **as a comment above it** before you run it:

```rust
fn my_puzzle(fail: bool) {
    let a = Noisy::new("a");
    {
        let b = Noisy::new("b");
        if fail {
            return;          // what drops here, and in what order?
        }
        let c = Noisy::new("c");
        let _ = (&b, &c);
    }
    let d = Noisy::new("d");
    let _ = (&a, &d);
}
```

Call it both ways. If your comment matched the output twice, you understand drop order.

### Phase 4 — Find the ladder in real C

Now go see the thing Rust deletes.

```bash
cd "$LINUX_TREE"
git grep -n "err_unlock:" -- drivers/ | head -20
```

Pick one and read the whole function:

```bash
git grep -l "goto err_unlock" -- drivers/i2c/ | head -3
```

For the one you chose, answer in your journal:

- How many `goto` labels does the error path have?
- How many distinct failure paths reach each one?
- If you added a fourth resource in the middle, how many places would you edit?
- What happens if someone adds an early `return` instead of a `goto`?

That last question is the bug class. In Rust it cannot be asked, because there is no ladder to bypass.

### Phase 5 — Connect it to kernel types

You are not writing a module today, but read the real thing so the names are familiar:

```bash
cd "$LINUX_TREE"
sed -n '1,60p' samples/rust/rust_minimal.rs
```

Find in it:

- the struct that represents the module
- `impl kernel::Module for ...` and its `init()` returning `Result<Self>`
- `impl Drop for ...` — the unload path
- the `KVec` allocation, and the `GFP_KERNEL` flag on it

Then look at how the kernel says `Box`:

```bash
grep -rn "pub fn new" rust/kernel/alloc/kbox.rs | head -5
```

Notice the signature takes a flag and returns a `Result`. That is concept 9, in the source.

### Phase 6 — Record it

```bash
cd ~/rust-scratch
cp ownership_demo.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_1/my_ownership_demo.rs
bash ~/LKD_RUST/codes/sync_to_repo.sh
```

---

## Verification

```bash
cd ~/rust-scratch
rustc ownership_demo.rs -o demo && ./demo
```

But the real check is not a command. Without running anything, can you say what this prints?

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
drop: b        <- c owns it now, and c's scope (the inner block) ends here
make: d
drop: d
drop: a
```

`let c = b;` moves — it does not create a second value and does not drop anything. The value dies at
the end of the inner block because that is where its owner `c` goes out of scope. Then `d`, then `a`,
reverse declaration order in the outer scope.
</details>

---

## Gotchas

- **Thinking a move copies or costs something.** It is a compile-time bookkeeping change. Often zero
  machine instructions.
- **Thinking a move drops the original.** It does not. One value, one drop, at the new owner's scope end.
- **Expecting shadowing to free the old value.** It does not. Both live to the end of the scope.
- **Expecting `Vec` to drop in reverse.** It drops front to back. Reverse order applies to *scopes*.
- **Trying to call `.drop()`.** Use `drop(x)`, the free function, which works by taking ownership.
- **Assuming a destructor always runs.** `mem::forget`, panic with `abort`, and never leaving scope
  all skip it. A built-in kernel module is the third case.
- **Reaching for `.clone()` to silence the borrow checker.** It compiles, and it hides the design
  question you should have answered. In kernel code it may also allocate.
- **Writing `unwrap()`.** In the kernel that is a panic, and a kernel panic is the machine stopping.
- **Expecting `Box::new` to work in kernel code.** It is `KBox::new(v, GFP_KERNEL)?` — fallible.
- **Learning ownership by rebuilding the kernel each time.** Use userspace `rustc` for the rules; the
  rules are identical and the loop is 300 times faster.

---

## My Notes

### Predictions I got wrong

| Section | Predicted | Actual | Why |
|---|---|---|---|
| | | | |
| | | | |

### The five compile errors I wrote deliberately

| What I wrote | Error code | What the message taught me |
|---|---|---|
| use after move | `E0382` | |
| `Copy` + `Drop` | `E0184` | |
| | | |
| | | |
| | | |

### My drop-order puzzle

```rust
// prediction:

```

### The C error ladder I read

| | |
|---|---|
| File and function | |
| Number of `goto` labels | |
| Distinct failure paths | |
| Places to edit to add one resource | |

### In my own words: why can a type never be both `Copy` and `Drop`?

### What I do not understand yet

---

## Done When

- [ ] You can state the three ownership rules from memory
- [ ] You can explain why ownership rather than garbage collection, in kernel terms
- [ ] You can predict drop order for nested scopes, moves, and early returns — and you tested yourself
- [ ] You know shadowing does not drop early, and `Vec` drops front to back
- [ ] You can explain why `Copy` and `Drop` are mutually exclusive
- [ ] You wrote at least five deliberate compile errors and read each message fully
- [ ] You wrote your own drop-order puzzle and predicted it correctly
- [ ] **You can explain how RAII removes the `goto err_unlock` ladder**, and you have read a real one
- [ ] You can name the three things kernel Rust lacks: `std`, unwinding, infallible allocation
- [ ] You can explain why `unwrap()` is a bug in kernel code
- [ ] You can name four situations where `Drop` does not run
- [ ] Journal filled in, especially the prediction you got wrong

---

## Reading

- **The Rust Book, Ch. 4 (Understanding Ownership)** — the canonical treatment. Read it *after* today's
  experiments, so you are confirming a model rather than building one from prose
- **`Documentation/rust/coding-guidelines.rst`** — short, and it is the standard your code is judged by
- `rust/kernel/alloc/kbox.rs` — read `KBox::new`. Fallible allocation, in the source
- `samples/rust/rust_minimal.rs` — the `Drop` impl is the module unload path
- [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/) — look up `KBox`, `KVec`, `Result`
- `Documentation/process/submitting-patches.rst` — read it this week even though you will not submit
  for a while. It sets the standard everything else is measured against

---

## 📖 The Whole Day As A Story (read this first on revision)

*Plain words, no jargon. If you only re-read one section months from now, make it this one.*

### The question every language has to answer

**When is it safe to free this memory?**

C says: you decide. Get it wrong and you have a use-after-free, which is most of the kernel's CVE list.

Java and Go say: a runtime will work it out while the program runs. The kernel cannot do that — there
is no runtime underneath, and a collection pause inside an interrupt handler is not a thing that can
exist.

Rust says: **the compiler works it out before the program runs.** The `free` is still there in the
binary; you just did not type it, and the compiler put it somewhere it can prove is correct. No
runtime, no pauses, no overhead. That is why Rust is in the kernel and Go is not.

### The three rules

```text
1. Every value has exactly one owner.
2. Assigning or passing it moves ownership. Still one owner.
3. When the owner goes out of scope, the value is dropped.
```

### Move: the thing that looks hostile at first

```rust
let b = a;              // a is now unusable
```

If both names owned it, both would free it — a double free. So Rust invalidates the old name. The
move itself is free; nothing is copied and nothing is destroyed. One value, one owner, **one** drop.

### Copy: why integers are different

An `i32` has nothing to free, so duplicating the bits is harmless. That is all `Copy` means.

And the rule that makes it click: **a type can never be both `Copy` and `Drop`.** If it needs
cleanup, silently duplicating it would clean up twice. `Copy` is a promise there is nothing to clean.

### Drop: cleanup at a time you can point at

Destructors run at a **known** point — end of scope, in **reverse declaration order**, like popping a
stack. Not "eventually." That predictability is what makes it safe to put a mutex unlock or a DMA
unmap in a destructor.

Three things that surprise people:

- **Shadowing does not free the old value.** `let v = ...; let v = ...;` gives two live values.
- **`Vec` drops front to back.** Reverse order is a *scope* rule, not a collection rule.
- **Moving into a function** means it drops in the callee, not where you created it.

### The payoff, and the reason today matters

Open any C kernel function that grabs two or more resources:

```c
	if (!f->buf) {
		ret = -ENOMEM;
		goto err_free_f;
	}
	...
err_unlock:
	mutex_unlock(&f->lock);
	free_irq(f->irq, f);
err_free_buf:
	kfree(f->buf);
err_free_f:
	kfree(f);
	return ret;
```

That ladder is everywhere in the kernel, and it is a bug farm: jump to the wrong label, add a
resource and forget a rung, reorder and forget to reorder the ladder. Every one of those bugs lives
on an error path, which is exactly the path nobody tests.

**In Rust the ladder does not exist.** Each `?` returns early, and everything built so far is dropped
in reverse order, automatically. Add a resource and its cleanup comes with it. The teardown is
*derived from* the construction rather than maintained by hand next to it.

That is the single biggest reason Rust is in the kernel. Not speed — the C is already fast. It is
that an entire class of error-path bug stops being expressible.

### Three ways kernel Rust is not the Rust in tutorials

1. **No `std`.** Only `core` and `alloc`. `pr_info!`, not `println!`.
2. **No unwinding.** A panic is a *kernel* panic. So `unwrap()` is a bug, not a style choice.
3. **No infallible allocation.** `KBox::new(v, GFP_KERNEL)?` — allocation returns a `Result`, because
   the kernel cannot abort itself when memory runs out.

### When Drop does not run

`mem::forget`, a panic under `abort`, the machine stopping, or never leaving scope.

That last one you already met: a module built `=y` instead of `=m` is never unloaded, so its `Drop`
never runs. Same source, and the teardown path simply does not execute. That is Saturday's lab.

### If you remember only four things

1. **One owner. Moved on assignment. Dropped at scope end.** Everything else follows.
2. **Reverse declaration order**, and shadowing does not drop early.
3. **RAII deletes `goto err_unlock`** — cleanup is derived from construction, not maintained beside it.
4. **Kernel Rust has no `std`, no unwinding, and no infallible allocation.** So no `unwrap()`, ever.

### The commands, in order

```bash
mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_1/ownership_demo.rs .

# predict every section BEFORE this line
rustc ownership_demo.rs -o demo && ./demo

# then break it on purpose and read the errors
#   use after move        -> E0382
#   Copy + Drop           -> E0184
#   calling .drop()       -> read what it suggests instead

# go find the thing Rust deletes
cd "$LINUX_TREE"
git grep -n "err_unlock:" -- drivers/ | head -20
```

---

**Next:** M1W1D2 — Borrowing and the borrow checker. If ownership is "who frees it", borrowing is
"who may look at it, and when". You will write five borrow-checker errors deliberately and learn to
read what `rustc` is actually telling you — the skill that decides whether Rust feels like a
collaborator or an obstacle.

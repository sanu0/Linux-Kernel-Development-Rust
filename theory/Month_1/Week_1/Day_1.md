# M1W1D1 — Ownership, Moves, and Drop

> **New to Rust syntax?** Today's code uses `struct`, `impl`, and `impl Drop for Noisy` on its first
> page, but the roadmap does not formally teach structs until W1D4 and traits until W2D1. If those
> look like noise to you, spend two hours on [`Day_0_Rust_Primer.md`](Day_0_Rust_Primer.md) first.
> Ownership should be the only new idea today.

Today you learn the one idea that the rest of this roadmap stands on.

Everything else you will study over the next eighteen months — device drivers, memory management,
locking, DMA, GPU command submission — is built on top of what you learn today. If ownership stays
fuzzy, you will spend Month 5 sprinkling `unsafe` into your code hoping the compiler stops
complaining, and you will not know whether your driver is correct. If ownership becomes second
nature, most of the rest of Rust turns out to be consequences of it.

So today is not about memorising syntax. It is about understanding one rule deeply enough that you
can predict what the compiler will do before you compile.

There are no kernel builds today. You will work in userspace, where the edit-compile-run loop takes
about one second instead of five minutes. The ownership rules are exactly the same in both places,
and there is no sense waiting five minutes to learn something you can learn in one second.

**Time:** two to three hours, most of it spent running small experiments and predicting their output.

---

## Why This Matters More In The Kernel Than Anywhere Else

Before we get to the rules, it is worth understanding what problem they solve, because ownership can
feel like a strange restriction until you see what it is protecting you from.

Roughly two thirds of the serious security holes found in the Linux kernel are memory-safety bugs.
Not logic errors, not design mistakes — memory bugs. Somebody freed a pointer and then used it.
Somebody freed the same pointer twice. Somebody wrote past the end of a buffer. Somebody read a
variable while another CPU was writing it.

These are not bugs written by careless people. The Linux kernel is written by some of the most
careful programmers alive, reviewed by more careful programmers, and tested by automated tools that
run continuously. The bugs happen anyway, because the problem is genuinely hard and humans do not
scale to it.

Ownership is the mechanism that makes most of those bugs impossible to write in the first place. Not
"unlikely." Not "caught by a tool if you remember to run it." Impossible, in the sense that the code
does not compile.

That is the entire reason Rust was allowed into the Linux kernel after thirty years of C. Not
because it is faster — the C is already fast. Not because it is more pleasant — that is a matter of
taste. It got in because it removes a category of bug that has been costing the kernel community
enormous amounts of time and users enormous amounts of trust.

---

## The Question Every Programming Language Has To Answer

Here is the question, and it is a surprisingly hard one:

**When is it safe to free this memory?**

Say your program asks for some memory. Later it stops needing it. That memory has to go back, or
your program grows until the machine dies. So something, somewhere, has to decide the exact moment
when nothing will ever look at that memory again.

Getting that moment wrong is catastrophic in two different directions. Free it too early and some
other part of the program is still holding a pointer to it — that pointer now points at memory that
has been handed to somebody else. Read through it and you get someone else's data. Write through it
and you corrupt someone else's data. This is a **use-after-free**, and it is the single most
exploited bug class in operating systems. Free it twice and the allocator's internal bookkeeping
gets corrupted, which is a **double free**, and attackers have built entire exploit techniques
around it. Never free it at all and you have a **leak**, which is the mildest of the three but will
still eventually take down a machine that is supposed to run for years.

Only three answers to this question have ever been found. Every language you have used picks one.

### Answer one: you decide, by hand

This is what C does. You call `kmalloc`, and later you call `kfree`, and it is entirely your job to
make sure that second call happens exactly once, after the last use, on every possible path through
your code.

The phrase doing the damage there is **every possible path**. A function with one early return and
one error case has three paths. Add another failure point and you have four. Add a loop with a
`break` and it grows again. Each of those paths needs the right cleanup, in the right order, and
nobody will tell you if you miss one. The happy path gets tested constantly because that is what
the code does all day. The error paths get tested when something goes wrong, which is to say almost
never, which is to say in production.

C gives you complete control and complete responsibility. It works, and it has built everything we
use. It also produces that CVE list.

### Answer two: a runtime figures it out while you run

This is what Java, Go, Python and C# do. A garbage collector periodically pauses your program, walks
through memory working out what is still reachable from your live variables, and frees everything
else.

It genuinely solves the problem. You cannot have a use-after-free in Java, because the collector
will not free anything you can still reach. The cost is that a piece of machinery has to be running
alongside your program forever, using memory and CPU, and stopping your program at moments it
chooses rather than moments you choose.

**The kernel cannot use this, and it is worth understanding exactly why**, because the reason is not
"it would be slow."

A garbage collector needs to pause execution to do its work safely. Now think about what "execution"
means inside a kernel. It includes the code that runs when a network packet arrives. It includes the
code that runs when a disk controller signals that a write finished. It includes the code that runs
when a timer expires. Some of that code runs in **interrupt context**, where the rules are severe:
you may not sleep, you may not be preempted, and you must finish quickly because the hardware is
waiting. There is no safe moment to say "hold on, I need to walk the heap."

And there is a second problem, more fundamental. A garbage collector is a program, and programs need
something to run them. In userspace, the collector runs because the kernel schedules it. But the
kernel *is* the bottom of the stack. There is nothing underneath it to run a collector on its
behalf. You would have to build one into the kernel itself, and it would have to be correct in
interrupt context, and at that point you have made the problem harder rather than easier.

So garbage collection is off the table. Not by preference — by structure.

### Answer three: the compiler figures it out before you run

This is Rust's answer, and it is the interesting one.

The compiler tracks, at compile time, exactly where each value's life ends. Then it inserts the
cleanup code there, into the binary, before your program ever runs. When you execute the program
there is no collector, no bookkeeping, no pauses, and no runtime checks. The `free` is simply
sitting there in the machine code, at a place the compiler proved is correct.

Read that again, because it is the whole idea. **The freeing code still exists. You just did not
type it, and the compiler put it somewhere it can prove is safe.**

That is why this approach works in a kernel when garbage collection does not. There is nothing extra
running. The generated code looks like well-written C — because it *is* what well-written C would
have been, if a human had remembered every path.

The price is that you have to convince the compiler. It will not accept code it cannot prove is
safe, even when you happen to be right. That is the trade, and it is the source of every frustrating
afternoon you will have with Rust in the next two months. It is worth it.

---

## The Three Rules

Here are the rules the whole system rests on:

1. **Every value has exactly one owner.**
2. **Assigning or passing a value moves ownership. There is still only one owner.**
3. **When the owner goes out of scope, the value is dropped.**

That is genuinely all of it. Everything for the rest of today is these three sentences worked out in
detail, and everything for the rest of the year is these three sentences applied to hardware.

Let us take them one at a time.

---

## Rule One: Every Value Has Exactly One Owner

A **value** is a thing in memory: a number, a string, a struct, a buffer. An **owner** is a variable
that is responsible for that value's cleanup.

The important word is *exactly*. Not "at least one." Not "one or more." Exactly one. At any moment,
for any value, there is precisely one variable whose job it is to clean it up.

This is the whole trick, and it is almost disappointingly simple once you see it. Double frees
happen when two pieces of code both think they should free something. If the language guarantees
that only one place ever has that responsibility, the bug cannot occur. Not "is caught" — cannot
occur.

To see ownership working, we need to be able to watch values being destroyed. So throughout today we
will use a small type that announces its own death:

```rust
struct Noisy(&'static str);

impl Drop for Noisy {
    fn drop(&mut self) {
        println!("      drop: {}", self.0);
    }
}
```

Do not worry too much about the syntax. `struct Noisy(&'static str)` says "a `Noisy` holds one piece
of text." The `impl Drop for Noisy` block says "when a `Noisy` is destroyed, print this message."
The text is a string literal baked into the program, so a `Noisy` owns no memory of its own — which
is deliberate, because it means the only interesting thing about it is *when it dies*.

We will also give it a constructor that announces birth, so you can see both ends:

```rust
impl Noisy {
    fn new(name: &'static str) -> Self {
        println!("      make: {}", name);
        Noisy(name)
    }
}
```

Now we can watch.

---

## Rule Three, Out Of Order: When Does A Value Die?

We are going to skip rule two for a moment, because rule three is easier and rule two makes more
sense once you have seen it.

Rule three says a value is dropped when its owner goes out of scope. So: what is a scope, and when
does something go out of one?

A scope is a region of code delimited by curly braces. The body of a function is a scope. A bare
block inside a function is a scope. The body of an `if`, or a loop, is a scope. When execution
leaves a scope — by reaching the closing brace, by hitting a `return`, or by an error propagating
out through `?` — every value owned by a variable declared inside that scope is destroyed.

Here is the simplest possible demonstration:

```rust
fn scope_end() {
    let _first = Noisy::new("first");
    let _second = Noisy::new("second");
    let _third = Noisy::new("third");
    println!("      -- end of function --");
}
```

Before you read on, decide what this prints.

Here is what actually happens:

```text
      make: first
      make: second
      make: third
      -- end of function --
      drop: third
      drop: second
      drop: first
```

Two things to notice.

The first is that all three drops happen *after* the "end of function" message. The values live
until the closing brace, and then all three die. Nothing was cleaned up early just because we
stopped using it.

The second is the order, and it is the more important observation. They are destroyed **backwards**
— third, then second, then first. Last created, first destroyed.

### Why backwards?

This is not an arbitrary choice, and understanding the reason will save you from being surprised
later.

Think about how you got to the end of that function. You made `first`. Then you made `second`, and
`second` might have been built using `first` — it might hold a reference to it, or a pointer into
it, or some resource derived from it. Then you made `third`, which might depend on either of them.

Later things can depend on earlier things. Earlier things cannot depend on later things, because
they did not exist yet.

So if you destroy in reverse order, then at the moment any value is destroyed, everything it could
possibly depend on is still alive. Its destructor can safely touch anything it was built from.

Destroy in forward order and that guarantee vanishes. `first` dies, and then `second`'s destructor
runs and reaches for something that is already gone.

The concrete kernel version of this: imagine you take a lock, and then create something the lock
protects. You want the protected thing cleaned up while you still hold the lock, and the lock
released afterwards. Reverse order gives you exactly that, for free, because you declared the lock
first and the protected thing second.

Think of it as a stack. Each new value is pushed on top. At the end of the scope you pop them off,
which necessarily happens top-down.

---

## Rule Two: Assignment Moves

Now the rule that will annoy you for about a week and then feel obvious forever.

In most languages, `b = a` gives you two variables referring to the same thing, or two independent
copies, depending on the language and the type. In Rust, for most types, it does something else: it
**transfers ownership** from `a` to `b`, and `a` becomes unusable.

```rust
let a = Noisy::new("a");
let b = a;
println!("{}", a.0);   // compile error
```

That third line does not compile. The compiler says:

```text
error[E0382]: borrow of moved value: `a`
  |
  |     let a = Noisy::new("a");
  |         - move occurs because `a` has type `Noisy`,
  |           which does not implement the `Copy` trait
  |     let b = a;
  |             - value moved here
  |     println!("{}", a.0);
  |                    ^^^ value borrowed here after move
```

Take a moment with that error, because `rustc` errors are unusually informative and learning to read
them properly is most of learning Rust. It tells you three separate things: where the value was
created and why it moves rather than copies, exactly which line moved it, and exactly which line
tried to use it afterwards. Most compilers would give you one of those. This gives you the whole
story.

### Why would a language do this?

Because of rule one. There must be exactly one owner.

Suppose Rust let both `a` and `b` refer to the value. At the end of the scope, both go out of scope.
Both are owners. Both run the destructor. The value is freed twice. That is a double free — one of
the two worst bugs in the C list.

Rust's solution is not to add a runtime check, or a reference count, or a flag saying "already
freed." All of those cost something at runtime. Instead it simply decides that after `let b = a`,
the name `a` no longer refers to anything. Using it is not a runtime error; it is a compile error.
The bug is not detected — it is unrepresentable.

### What actually happens at runtime during a move?

This confuses almost everyone at first, so let us be precise: **essentially nothing happens.**

A move is not a copy. It is not a deep copy. It does not allocate. It does not free. It does not run
a destructor. Depending on the type, it may copy a few bytes — for something like a `Vec`, the
pointer, length and capacity get copied, which is three machine words — and the optimizer frequently
removes even that.

What a move really is, is a **compile-time bookkeeping change**. The compiler updates its record of
which variable is responsible for cleaning up that value, and refuses to let you use the old name.
The value itself does not go anywhere. It is the same bytes, at the same address, answering to a
different name.

You can see this in the output:

```text
      make: a
      moved a -> b, no drop happened during the move
      drop: a
```

**One `make`, one `drop`.** The move produced no extra work and destroyed nothing. The value was
created once and destroyed once, which is exactly right. The drop happens at the end of `b`'s scope,
because `b` is the owner now.

### Passing to a function moves too

Handing a value to a function is the same operation as assignment, so it moves in the same way:

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

```text
      make: x
      consume() received x
      drop: x
      back in caller; x is already gone
```

Look at where the drop happens. It is *inside* `consume`, before we get back to the caller. When you
passed `x` to `consume`, you handed over ownership. The parameter `n` became the owner. When
`consume` returned, `n` went out of scope, and the value died there.

The caller no longer has anything to clean up, because the caller no longer owns anything. If you
try to use `x` after calling `consume(x)`, you get the same `E0382` error as before.

This is worth sitting with, because it changes how you read function signatures. In C, passing a
pointer tells you nothing about who frees it — you have to read the documentation, or the
implementation, or guess. In Rust, `fn consume(n: Noisy)` says in the signature itself: *I am taking
this, it is mine now, do not expect it back.* Whereas `fn look(n: &Noisy)` says: *I am only
borrowing it, you keep it.* The ownership contract is in the type, checked by the compiler, and it
cannot drift out of date the way a comment can.

---

## The Exception: Types That Copy Instead Of Moving

Now, having explained all that, here is something that appears to contradict it:

```rust
let a: i32 = 42;
let b = a;
println!("a = {}, b = {}", a, b);   // works fine, both are usable
```

No error. Both variables work. Why the inconsistency?

Because for an `i32` there is **nothing to clean up**.

Everything we said about moves was in service of one goal: making sure the cleanup happens exactly
once. But an `i32` is four bytes sitting directly in a register or on the stack. It owns no heap
allocation, holds no lock, refers to no file. When an `i32` goes out of scope, precisely nothing
needs to happen.

So duplicating the bytes is completely harmless. You get two independent, equally valid integers.
There is no shared resource to free twice, because there is no resource at all. Forcing you to write
`a.clone()` for integers would add ceremony and buy you nothing.

Rust marks these types with a trait called `Copy`, and the meaning of `Copy` is precise:

> **`Copy` means: duplicating this value's bytes produces another completely valid, completely
> independent value of this type.**

Which types are `Copy`? All the integers, `bool`, `char`, the floats, shared references (`&T`), and
structs, tuples and arrays made entirely of `Copy` things. What is *not* `Copy` is anything that
owns something: a `String`, a `Vec`, a file handle, a lock guard, a device.

### The rule that makes this click

Here is the constraint that ties the whole thing together, and it is worth committing to memory:

**A type can never be both `Copy` and `Drop`.**

Try it and the compiler refuses:

```rust
#[derive(Clone, Copy)]
struct Bad(u32);

impl Drop for Bad {
    fn drop(&mut self) {}
}
```

```text
error[E0184]: the trait `Copy` cannot be implemented for this type;
              the type has a destructor
```

Sit with why this must be true. `Copy` says duplicating the bytes is harmless. `Drop` says there is
cleanup to run when this value dies. If a type were both, then every time you assigned it you would
silently create a second value — and both of them would eventually run the destructor. Cleanup would
happen twice. That is the double free we spent this whole section preventing.

So the two ideas genuinely contradict each other, and the compiler enforces it. Which gives you a
useful shorthand for reading unfamiliar code:

> **`Copy` is a promise that there is nothing to clean up.**

When you see a type that is `Copy`, you know immediately that it owns nothing. When you see a type
that is not, you know it owns something, and you should be thinking about where its single owner is.

---

## Clone: When You Actually Do Want Two

Sometimes you genuinely want a second, independent copy of something that owns a resource. That is
what `Clone` is for.

```rust
#[derive(Clone)]
struct Tag(String);

let original = Tag(String::from("original"));
let copy = original.clone();
```

```text
      two independent Tags now exist: original / original
      drop: Tag(original)
      drop: Tag(original)
```

Two values, so two drops. That is correct and expected — there really are two `Tag`s now, each
owning its own `String`, each responsible for freeing it.

The important design decision here is that `Clone` is **explicit**. You have to write `.clone()`. It
is never implicit, never automatic, never hidden. And the reason is cost: cloning a `String` means
allocating new memory and copying the bytes. Cloning a large `Vec` might mean copying megabytes.
Rust's position is that if something might be expensive, it should be visible in the source, so that
a reader — and a reviewer — can see it.

**This matters more in the kernel than in userspace**, and here is why. Cloning usually means
allocating. In userspace, allocation basically always succeeds, and if it does not, the process
dies and the user restarts it. The kernel cannot take that attitude toward itself. Allocation in the
kernel can fail, and that failure has to be handled rather than fatal.

So kernel collection types do not have a quiet `.clone()` that might allocate behind your back.
They take an explicit allocation flag and hand you back a `Result` that you must deal with. When you
see `.clone()` in kernel Rust, the question to ask is: *what does this allocate, and what happens if
that fails?*

---

## Rule Three In Full: Drop

We have seen `Drop` in passing. Now let us look at it properly, because it is where ownership stops
being a restriction and starts being a feature.

```rust
impl Drop for Noisy {
    fn drop(&mut self) {
        println!("      drop: {}", self.0);
    }
}
```

This says: when a `Noisy` value is destroyed, run this code.

You never call `drop` yourself. In fact you *cannot* — writing `noisy.drop()` is a compile error, and
the compiler will tell you to use `drop(noisy)` instead. The reason for the prohibition is neat: if
you could call the destructor as a method, you would still have the variable afterwards, and you
could use it. The value would have been cleaned up but the name would still work — a use-after-free,
back again. So the language forbids the method call and gives you a free function that *takes
ownership*, which means the value is consumed and the name becomes unusable, exactly as with any
other move.

The word that matters about `Drop` is **deterministic**.

In a garbage-collected language, you know your object will eventually be cleaned up, but not when.
Maybe soon. Maybe at the next collection. Maybe not before the program exits. That uncertainty is
why Java has `try-with-resources` and Python has `with` — because for anything that is not plain
memory, "eventually" is not good enough.

In Rust, destruction happens at a specific, predictable point that you can identify by reading the
source. Not "eventually." At that brace, every time.

That predictability is what makes it safe to put important things inside destructors. A mutex unlock
can go in a destructor, because you know exactly when it runs. A reference count decrement can. A
DMA unmap can. An IRQ teardown can. The whole pattern — usually called RAII, "resource acquisition
is initialisation" — depends entirely on destruction being predictable, and Rust's is.

---

## Drop Order In Four Situations

We have seen the basic case. Here are four more, including two that surprise almost everyone.

### Nested scopes

An inner block is its own scope, so its values die at its own closing brace:

```rust
let _outer = Noisy::new("outer");
{
    let _inner = Noisy::new("inner");
    println!("      -- leaving inner block --");
}
println!("      -- back in outer, inner is already gone --");
```

```text
      make: outer
      make: inner
      -- leaving inner block --
      drop: inner
      -- back in outer, inner is already gone --
      drop: outer
```

Nothing surprising, but worth confirming: `inner` really does die at the inner brace, not at the end
of the function. This is how you control lifetime deliberately. If you want a lock released halfway
through a function rather than at the end, you put it in a block.

### Early return

This one is the seed of the most important idea today, so read the output carefully.

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

Called with 1, then 2, then 0:

```text
      make: step1
      -- bailing out after step1 --
      drop: step1

      make: step1
      make: step2
      -- bailing out after step2 --
      drop: step2
      drop: step1

      make: step1
      make: step2
      make: step3
      -- completed all three --
      drop: step3
      drop: step2
      drop: step1
```

Three different exit points. Three different sets of things that needed cleaning up. Every one
correct, in reverse order, with **no cleanup code written anywhere in the function**.

Notice particularly the first case. We bailed out after `step1`, and `step2` was never dropped —
because `step2` was never created. The compiler knows which values exist at each point in the
function, and cleans up exactly those.

Hold on to this. In about two pages it is going to matter a great deal.

### Shadowing does not drop early

Here is the first surprise. Rust lets you reuse a variable name:

```rust
let v = Noisy::new("shadowed");
let v = Noisy::new("shadowing");
```

You might reasonably expect the first value to be destroyed at the moment its name is taken away.
It is not:

```text
      make: shadowed
      the name v refers to: shadowed
      make: shadowing
      the name v now refers to: shadowing
      but BOTH values are still alive — only the name was reused
      drop: shadowing
      drop: shadowed
```

Both values live until the end of the scope, and they drop in reverse declaration order like
everything else.

The reason is that shadowing is a fact about **names**, not about **values**. The second `let`
creates a new variable that happens to share a name. The first variable still exists, still owns its
value, and still has a scope that runs to the closing brace. You simply have no way to refer to it
any more.

This matters in real code more than it looks. If you write `let guard = lock.lock();` and later
shadow `guard` with something else, the lock is still held. It is not released until the end of the
scope. That has caused real deadlocks.

### Collections drop front to back

The second surprise. We have said "reverse order" many times, so:

```rust
let v = vec![Noisy::new("elem0"), Noisy::new("elem1"), Noisy::new("elem2")];
```

```text
      drop: elem0
      drop: elem1
      drop: elem2
```

Forwards. Not reversed.

This is not an inconsistency once you see the distinction. Reverse order is a rule about **scopes** —
about variables declared one after another in a block, where later ones may depend on earlier ones.
A `Vec` is not a scope. It is a single value that happens to contain other values, and its elements
are peers with no dependency between them. So it walks them in the natural order, front to back.

The `Vec` itself is one owner, dropped at its scope's end like any other value. What we are watching
here is what that single drop does internally: destroy each element, then free the buffer.

---

## The Payoff: Why This Deletes `goto err_unlock`

Everything so far has been groundwork. This section is the reason today matters, and if you take one
thing away from Week 1, make it this.

Open almost any C function in the Linux kernel that acquires more than one resource, and you will
find a particular shape. Here is a representative example:

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

That descending ladder of labels at the bottom is one of the most recognisable things in the Linux
kernel. You will see it thousands of times. It is not bad code — it is the *correct* C idiom for
this problem, and a reviewer would be happy with it.

Take a moment to understand how it works, because it is genuinely clever. Each label is an entry
point into a cleanup sequence, and the labels are ordered so that jumping to any one of them
performs exactly the cleanup needed for the resources acquired up to that point, in reverse order.
Jump to `err_free_buf` and you free the buffer and then the struct. Jump to `err_unlock` and you
unlock, free the IRQ, free the buffer, then free the struct. Each label falls through into the ones
below it.

It is a hand-written implementation of reverse-order cleanup with multiple entry points. Which, if
you have been paying attention, is precisely what the compiler did for you in the early-return
example a few pages ago.

### Why this pattern produces bugs

The C version works. The problem is that it has to be maintained **by hand**, separately from the
code that acquires the resources, and every change has to be made in two places that are fifteen
lines apart.

Four things go wrong, and all four are common enough to have caused real CVEs.

You can **jump to the wrong label**. `goto err_free_buf` when you meant `err_free_f` and you free a
buffer that was never allocated. The labels have similar names, they are all right next to each
other, and the compiler cannot help you because both are perfectly valid jumps.

You can **add a resource and forget a rung**. Six months later somebody adds a fifth allocation in
the middle of the function. They add the `goto`, they add the failure check — and they forget to add
the matching `kfree` to the ladder. Now one specific error path leaks. Nobody notices, because that
path only runs when something has already gone wrong.

You can **reorder the acquisitions and forget to reorder the ladder**. Now cleanup happens in the
wrong order. If the resources were independent, you get away with it. If they were not, you get a
use-after-free that appears only on an error path.

Or somebody can **write a plain `return` instead of a `goto`**. It looks completely innocent —
`return -EINVAL;` in the middle of a function is normal-looking code. It skips the entire ladder and
leaks everything acquired so far.

What these four failures have in common is the thing that makes them dangerous: **they all live on
error paths.** The happy path is exercised constantly, so bugs there get found immediately. Error
paths run when the allocator is under pressure, or the hardware is misbehaving, or a probe fails.
Those conditions are rare, hard to reproduce, and almost never tested. So the bug sits there for
years, and then somebody works out how to trigger it deliberately, and it gets a CVE number.

### The Rust version

Here is the same function shaped in Rust:

```rust
fn probe(pdev: &mut Device) -> Result<Foo> {
    let buf = KVec::with_capacity(BUF_SIZE, GFP_KERNEL)?;
    let irq = Irq::request(pdev.irq(), foo_isr)?;
    let guard = self.lock.lock();
    hw_init(&guard)?;
    Ok(Foo { buf, irq })
}
```

There is no ladder. Not a shorter ladder — no ladder at all. There is no cleanup code in this
function whatsoever.

Here is how that works. The `?` at the end of each line means "if this returned an error, return
that error from this function immediately." So each `?` is a potential early exit, exactly like the
`return` statements in our `early_return` demo.

And at each of those exits, the compiler drops every value that currently exists, in reverse order.
If `Irq::request` fails, `buf` exists and gets dropped, which frees the buffer. If `hw_init` fails,
the lock guard drops first — releasing the mutex — then the IRQ handle drops, freeing the IRQ, then
the buffer drops.

Every one of those cleanups is exactly what the corresponding label in the C ladder did. The
compiler generated them, from the same information the C programmer used, but automatically and
without the possibility of getting it wrong.

### The property that actually matters

It is tempting to summarise this as "Rust writes your cleanup for you," but that undersells it. Here
is the real point:

**In C, the cleanup is maintained separately from the acquisition. In Rust, it is derived from it.**

That is the difference between two things that must be kept in sync by a human, and one thing.

The consequences are concrete. Add a resource in Rust and its cleanup arrives automatically, because
the cleanup lives in that resource's own `Drop` implementation rather than in a ladder somewhere
else. Reorder two acquisitions and the teardown reorders itself, because it is always the reverse of
whatever order you happened to construct in. Add an early return anywhere, and it cleans up
correctly, because there is no ladder to accidentally bypass.

None of the four C bug classes has a Rust equivalent. They are not caught. They are not warned
about. They cannot be written.

Now go back and look at the `early_return` output one more time — three exit points, three correct
cleanup sequences, zero cleanup code. **That output is the `goto` ladder**, generated by the
compiler. You have already seen the mechanism work; this section was just explaining what it
replaces.

---

## Kernel Rust Is Not The Rust In The Tutorials

Before we finish, three differences between the Rust you are learning and the Rust in most online
material. These are not small, and being clear about them now will save confusion for months.

### There is no standard library

Rust's `std` gives you files, threads, sockets, `println!`, `HashMap`, and everything else you
associate with the language. Kernel Rust has none of it.

The reason is simple once stated: `std` is a library for programs that run *on top of* an operating
system. Every part of it eventually asks the OS for something — memory, a file descriptor, a thread.
The kernel is the operating system. There is nobody underneath to ask.

What you get instead is `core`, which is the part of the standard library that needs no OS
underneath — integers, slices, `Option`, `Result`, iterators — plus `alloc`, which provides
heap-using types like `Vec` and `Box` on top of an allocator the kernel supplies itself.

This is what `no_std` means, and it is why Week 0 Day 4 had you install `rust-src`: since there is
no prebuilt `core` for "the Linux kernel with these exact compiler flags," the kernel build compiles
`core` from source every time.

In practice the difference you will feel most often is that `println!` does not exist. You write
`pr_info!` instead, which goes to the kernel log where `dmesg` can find it.

### There is no unwinding, so `unwrap()` is a bug

When a Rust program panics in userspace, it normally *unwinds*: it walks back up the call stack
running destructors, then terminates the thread. Your `Drop` implementations still run. It is an
orderly shutdown of a failed operation.

Kernel Rust is compiled with `panic = abort`. There is no unwinding, and destructors do not run.

More importantly, think about what a panic means here. In userspace, a panic kills your process. The
kernel reclaims its memory, the user sees a crash, they run it again. In the kernel, there is no
higher authority to clean up after you — you *are* the higher authority. A panic in kernel code is a
**kernel panic**. Depending on configuration the machine halts or reboots. Every running program
dies. Unsaved work is gone.

Which leads to the rule you need to absorb today, even though you will not feel its weight until
Month 2:

> **`unwrap()` and `expect()` are bugs in kernel code.**

Not poor style. Not something to clean up later. The failure mode is taking down the machine.

You will feel the pull to write them constantly, because they make the compiler stop complaining and
you are fairly sure the value is there. Resist it. If you are certain a case cannot happen, prove it
to the type system or handle it explicitly. Every `unwrap()` is a bet that you are smarter than
every future maintainer, every unusual hardware state, and every attacker.

### Allocation can fail, and you must handle it

This is the biggest practical difference.

In userspace, `Box::new(x)` cannot fail. If the system is out of memory, the allocator aborts the
process. The API does not even offer you a way to find out, because there is nothing sensible you
could do.

The kernel cannot behave that way toward itself. Running out of memory is a normal condition that
the kernel has to survive and handle gracefully — that is one of its main jobs. So kernel allocation
returns a `Result`:

```rust
let b = KBox::new(value, GFP_KERNEL)?;
let mut v = KVec::with_capacity(n, GFP_KERNEL)?;
v.push(item, GFP_KERNEL)?;
```

Two things are new there. The types are `KBox` and `KVec` rather than `Box` and `Vec`, because they
are the kernel's fallible versions. And every allocating call takes a flag like `GFP_KERNEL`, which
is the same allocation-context flag you would pass to `kmalloc` in C — it tells the allocator what
this call is allowed to do, such as whether it may sleep waiting for memory to be freed.

The `?` on each line is doing the same job as before: if allocation failed, return the error. Which
means allocation failure flows through your code as an ordinary error, using the same mechanism as
every other failure, and the same automatic cleanup applies.

The ownership rules are identical. Only the construction is fallible.

---

## When `Drop` Does Not Run

One last thing, and it is the kind of detail that saves you a confusing afternoon.

`Drop` is reliable, but it is not magic. There are four situations where a destructor does not run,
and you should know all four so you never trust a cleanup that was never going to happen.

**You suppressed it deliberately.** `mem::forget(x)` consumes a value without running its
destructor, and `ManuallyDrop` does the same thing as a wrapper type:

```text
      make: kept
      make: leaked
      forgot 'leaked'; only 'kept' will drop
      drop: kept
```

Notice this is *safe* Rust — no `unsafe` block required. That surprises people, but it is
consistent: leaking memory cannot corrupt anything or violate memory safety. It is merely wasteful.
Rust's safety guarantee is about correctness, not about tidiness.

**It panicked.** With `panic = abort`, nothing unwinds, so no destructors run anywhere.

**The program or machine stopped.** Nothing runs after that.

**The value never went out of scope.** And here is one you have already met without knowing it.

In Week 0 Day 4, you built the sample modules as `=m` rather than `=y`, and the reason given was
that a built-in module cannot be `insmod`'d — which is true. But there is a second reason, and it is
a `Drop` reason.

A module compiled into the kernel is never unloaded. It is part of the kernel image; it is there
from boot until shutdown. So the value representing that module never goes out of scope, and its
`Drop` never runs. The exact same source file, built two different ways, has a teardown path that
executes in one case and simply does not exist in the other.

That is Saturday's lab, and it is a much better demonstration of what "goes out of scope" really
means than any userspace example could be.

---

## Doing The Work

Reading about drop order is not the same as being able to predict it. This part is where the
learning actually happens, so do not skip it.

### Set up a scratch area

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_1/ownership_demo.rs .
rustc --version
```

If you get `rustc: command not found`, it is installed at `~/.cargo/bin` but your shell has not
picked it up — a distro `~/.bashrc` stops early for non-interactive shells. Fix it with:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

There is no kernel tree and no build involved today, which is deliberate. Plain `rustc` on a single
file compiles in about a second, and you are going to compile many times.

### Predict before you run

This is the single most important instruction in the file.

Open `ownership_demo.rs` and read it. It has ten sections, matching the ten things we discussed.
For each one, **write down the output you expect** — the actual order, on paper or in your journal.
Not in your head; writing it down is what forces you to commit.

Then run it:

```bash
rustc ownership_demo.rs -o demo && ./demo
```

Compare. **The section you got wrong is the only one you learned anything from today**, so make a
note of which it was. For most people it is section 8 (shadowing) or section 10 (`Vec` order),
because both contradict a reasonable guess.

### Break it on purpose

Reading a compiler error you caused deliberately, while you know exactly what you did, teaches you
far more than reading documentation about that error.

In the `moves()` function, uncomment the `println!` that uses `a` after the move, and compile. Read
the whole error, not just the first line — find where it says the value was created, where it moved,
and where you used it.

In `copy_types()`, uncomment the `Bad` struct that tries to be both `Copy` and `Drop`, and read
`E0184`.

Then write three more of your own, predicting the error each time before you compile:

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

// 3. call drop() as a method
let n = Noisy::new("n");
n.drop();
```

The second is the more interesting one. Think about what the loop is asking for: the value is moved
into `consume` on the first pass, so on the second pass there is nothing left to move. The compiler
sees this even though the loop count is a constant it could theoretically evaluate.

The third one you already know the answer to from earlier — but read what the compiler *suggests*
instead, and make sure you can explain why the language provides that spelling rather than the
obvious one.

### Write your own puzzle

Predicting someone else's code is easier than predicting your own, so write one.

Combine a nested scope, a move, and an early return in a single function, and write your prediction
as a comment above it before running:

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

Call it both ways. If your comment matched the output both times, you understand drop order well
enough to move on.

### Go and find the thing Rust deletes

Reading my example of a `goto` ladder is not the same as finding one yourself in a real driver.

```bash
cd "$LINUX_TREE"
git grep -n "err_unlock:" -- drivers/ | head -20
```

Pick one and read the entire function. Then answer, in your journal:

How many labels does the error path have? How many distinct failure points jump into it? If you were
asked to add one more resource in the middle of the function, how many separate places would you
have to edit, and what would happen if you got one of them wrong? And what would happen if somebody
added a plain `return` in the middle?

That last question is the whole argument for today, asked about real code that real people maintain.

### Look at the kernel types

You are not writing a module today, but read the real thing so the names become familiar:

```bash
sed -n '1,60p' samples/rust/rust_minimal.rs
```

Find the struct that represents the module, the `impl kernel::Module` block with its `init()`
returning a `Result`, the `impl Drop` that is the unload path, and the `KVec` allocation with its
`GFP_KERNEL` flag. You have now met every one of those ideas.

Then look at how the kernel spells `Box`:

```bash
grep -rn "pub fn new" rust/kernel/alloc/kbox.rs | head -5
```

Notice the signature takes an allocation flag and returns a `Result`. That is fallible allocation,
in the actual source.

### Save your work

```bash
cd ~/rust-scratch
cp ownership_demo.rs ~/LKD_RUST/codes/Month_1/Week_1/Day_1/my_ownership_demo.rs
bash ~/LKD_RUST/codes/sync_to_repo.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_1/check_day1.sh
```

---

## Checking Yourself

The script above verifies the demo behaves as described. But the real test is not a script, so here
is one question. Without running anything, what does this print?

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

Work it out fully before opening the answer.

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

The line `let c = b;` moves. It does not create a second value, and it does not drop anything — so
there is no drop between `make: b` and the end of the inner block. The value now belongs to `c`, and
`c`'s scope is the inner block, so the value dies at that closing brace. That is the `drop: b` you
see — the name in the message is just the text the value was created with, which never changed.

Then `d` is created, and at the end of the function `d` and `a` drop in reverse declaration order.

If you predicted a drop when `b` was moved to `c`, re-read the section on what a move does at
runtime. If you thought the value would survive past the inner block, re-read rule three: it is the
*owner's* scope that matters, and the owner is `c`.

</details>

---

## Common Confusions

A few things that catch nearly everyone, gathered in one place.

**Thinking a move copies something, or costs something.** It is a compile-time bookkeeping change.
For most types it is a few bytes at most, and often zero instructions after optimisation.

**Thinking a move drops the original.** It does not. There is one value, and it is dropped once, at
the point the new owner's scope ends. If you see two drops, you had two values — probably from a
`clone()`.

**Expecting shadowing to free the old value.** It does not. Both values live to the end of the scope.
This is a real source of deadlocks when the shadowed value was a lock guard.

**Expecting `Vec` to drop in reverse.** It drops front to back. Reverse order is a rule about scopes,
not about collections.

**Trying to call `.drop()` as a method.** Use the free function `drop(x)`. The method form is
forbidden precisely because it would leave you holding a usable name for a destroyed value.

**Assuming a destructor always runs.** `mem::forget`, a panic under `abort`, and never leaving scope
all skip it. A module built into the kernel is the third case, which is Saturday's lab.

**Reaching for `.clone()` to make the compiler stop complaining.** It will work, and it will hide
whatever design question you were actually facing. In the kernel it may also allocate, which means
it may fail. When you feel the urge to clone, first ask whether you needed a reference instead —
which is tomorrow's subject.

**Writing `unwrap()`.** In kernel code that is a panic, and a kernel panic stops the machine.

**Expecting `Box::new` to work.** In the kernel it is `KBox::new(value, GFP_KERNEL)?`.

**Trying to learn this by rebuilding the kernel each time.** The rules are identical in userspace and
the loop is hundreds of times faster. Use `rustc` on one file until you can predict the output, then
take that understanding to the kernel.

---

## My Notes

### The prediction I got wrong

| Section | What I predicted | What happened | Why I was wrong |
|---|---|---|---|
| | | | |

### The compile errors I wrote deliberately

| What I wrote | Error code | What the message taught me |
|---|---|---|
| use after move | `E0382` | |
| `Copy` plus `Drop` | `E0184` | |
| | | |

### My own drop-order puzzle, and whether I predicted it correctly

```rust

```

### The C error ladder I read

Which file and function, how many labels, how many failure paths reach it, and how many places you
would have to edit to add one more resource:

### In my own words

Why can a type never be both `Copy` and `Drop`?

Why is destruction in *reverse* declaration order rather than forward?

How does `?` plus `Drop` replace the `goto` ladder?

### What I still do not understand

---

## Done When

You are finished with today when you can do the following without looking anything up.

State the three ownership rules from memory, and explain why the kernel cannot use garbage
collection — not just "it would be slow," but the actual structural reason.

Predict drop order for nested scopes, moves, and early returns, and explain why the order is
reversed. Know that shadowing does not drop early and that `Vec` drops front to back, and be able to
say why those two are not contradictions.

Explain why a type can never be both `Copy` and `Drop`, and what that tells you about any type you
see marked `Copy`.

Describe how `?` combined with `Drop` removes the `goto err_unlock` ladder, having read a real one in
`drivers/` — and name at least two of the four ways that ladder goes wrong in practice.

Name the three things kernel Rust does not have, and explain why `unwrap()` is a bug rather than a
style preference.

Name four situations where `Drop` does not run, including the one that explains why you built the
Week 0 samples as `=m`.

And practically: you have run the demo having predicted every section, written at least five
deliberate compile errors and read each message in full, written your own puzzle and predicted it
correctly, and filled in your notes above — especially the prediction you got wrong.

---

## Further Reading

**The Rust Book, Chapter 4** is the canonical treatment of ownership. Read it *after* today's
experiments rather than before, so that you are confirming a model you built by observation rather
than trying to build one from prose.

**`Documentation/rust/coding-guidelines.rst`** in the kernel tree is short, and it is the standard
your code will be judged against.

**`rust/kernel/alloc/kbox.rs`** — read `KBox::new`. Fallible allocation, in the source, rather than
described.

**`samples/rust/rust_minimal.rs`** — the `Drop` implementation there is a module's unload path.

**[rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/)** — look up `KBox`, `KVec` and
`Result`. You are learning where things live, not what they do.

**`Documentation/process/submitting-patches.rst`** — read it this week even though you will not
submit anything for a while. It sets the standard everything else is measured against.

---

## Summary

The question every language must answer is when it is safe to free memory. C makes you answer it by
hand on every path, and the kernel's CVE list is largely the record of people getting that wrong.
Garbage collection answers it with a runtime that the kernel cannot host and cannot afford to be
paused by. Rust answers it at compile time, generating the same cleanup a careful C programmer would
have written, at points it can prove are correct — which is why it runs with no overhead and why it
was allowed into the kernel.

The mechanism is three rules. Every value has one owner. Assignment moves ownership rather than
duplicating it, which is why using a moved-from variable fails to compile and why double frees
cannot happen. When the owner's scope ends, the value is dropped, deterministically, at a point you
can identify by reading the code.

Values in a scope drop in reverse declaration order, because later values may have been built from
earlier ones and must be torn down first. Shadowing does not drop early — it renames, and both values
survive to the end of the scope. Collections drop their elements front to back, because a collection
is not a scope.

Small plain types like integers are `Copy` and duplicate instead of moving, because there is nothing
to clean up. That is what `Copy` means, and it is why a type can never be both `Copy` and `Drop`:
one says there is nothing to clean up and the other says there is.

The payoff is that `?` plus `Drop` deletes the `goto err_unlock` ladder. In C, cleanup is maintained
by hand in a separate place from acquisition, and the four ways that goes wrong all hide on error
paths nobody tests. In Rust, cleanup is *derived from* acquisition, so adding a resource brings its
cleanup with it and reordering acquisitions reorders teardown automatically. That is the single
biggest reason Rust is in the kernel.

Finally, kernel Rust is a smaller language than the tutorials teach. No `std`, so `pr_info!` instead
of `println!`. No unwinding, so a panic stops the machine and `unwrap()` is a bug. No infallible
allocation, so `KBox::new(v, GFP_KERNEL)?` and allocation failure is an ordinary error you handle.

If you remember only four things: one owner, moved on assignment, dropped at scope end. Reverse
declaration order. Cleanup derived from construction rather than maintained beside it. And no
`unwrap()`, ever.

---

**Next:** [M1W1D2 — Borrowing and the Borrow Checker](Day_2.md). Today answered "who is responsible
for freeing this." Tomorrow answers "who is allowed to look at it, and when" — and it is where you
learn to read what `rustc` is actually telling you, which decides whether Rust feels like a
collaborator or an obstacle for the rest of your career.

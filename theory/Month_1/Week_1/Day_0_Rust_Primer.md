# M1W1D0 — Rust Primer: Exactly What Day 1 Assumes

> **Goal:** be able to read Day 1's code without stumbling on syntax, so that **ownership is the only
> new idea that day**.
>
> **Time:** 2 hours. Less if you have written any C++, Java, Go or TypeScript.
>
> **Why this exists:** the roadmap starts Week 1 at ownership, but Day 1's very first code block
> contains `struct`, `impl`, and `impl Drop for Noisy` — and the roadmap does not formally teach
> structs until **W1D4** and traits until **W2D1**. That ordering is fine for the *concepts*, but it
> means Day 1 asks you to read three things before it explains them. This file closes exactly that
> gap and nothing more.

---

## What this is not

This is **not** a Rust course, and it deliberately skips most of the language.

**Not covered here, because it IS Day 1:** ownership, moves, borrowing, `Drop`. If you learn those
today you have just done Day 1 early and out of order.

**Not covered here, because the roadmap covers it properly later:** generics and trait bounds (W2D1),
lifetimes (W3), smart pointers (W4), `unsafe` (W5), pattern matching in depth (W1D4).

**Not covered here, because kernel Rust does not have it:** `async`/`await`, threads, `std::sync`,
Cargo and crates.io, the wider ecosystem. You are learning a smaller language than the tutorials
teach, and you are not behind for skipping this.

---

## Run it first

```bash
mkdir -p ~/rust-scratch && cd ~/rust-scratch
cp ~/LKD_RUST/codes/Month_1/Week_1/Day_0/primer.rs .
rustc primer.rs -o primer && ./primer
```

**If `rustc: command not found`** — it is installed at `~/.cargo/bin`, which a distro `~/.bashrc` only
adds for interactive shells:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Read the file alongside the output. The ten sections below are the same ten in the source.

---

## 1. `let`, `mut`, and types

Bindings are **immutable by default**. This is backwards from every other language you know, and it
is deliberate: mutation is the thing that causes bugs, so you say so explicitly.

```rust
let a = 5;              // inferred i32
let b: u64 = 5;         // annotated
let mut c = 10;         // without `mut`, `c += 1` is a compile error
c += 1;
```

Kernel code names integer widths explicitly, because a driver talks to hardware registers of exact
size: `u8 u16 u32 u64 usize`, and the signed `i` versions.

```rust
let reg: u32 = 0xDEAD_BEEF;      // underscores are pure readability
println!("{:#x}", reg);          // 0xdeadbeef
```

Format specifiers worth knowing now: `{}` display, `{:?}` debug, `{:#?}` pretty debug, `{:#x}` hex
with prefix.

## 2. Functions, and expressions vs statements

```rust
fn add(x: i32, y: i32) -> i32 {
    x + y        // NO semicolon — this IS the return value
}
```

**The semicolon is significant.** An expression without a semicolon evaluates to a value; add a
semicolon and it becomes a statement that discards its value. Writing `x + y;` in the function above
is a compile error, because the function then returns nothing.

`return x + y;` is legal and sometimes clearer for early exits, but idiomatic Rust omits it at the end.

This catches everyone exactly once. When you see `expected i32, found ()`, you left a semicolon on
the last line.

## 3. Control flow is expressions too

```rust
let parity = if n % 2 == 0 { "even" } else { "odd" };
```

There is no ternary operator because `if` already produces a value. Both arms must have the **same
type** — `if n > 0 { 1 } else { "negative" }` will not compile.

```rust
for i in 0..3 { }        // 0,1,2   — excludes the end
for i in 0..=3 { }       // 0,1,2,3 — includes it
```

## 4. Structs, in three shapes

```rust
struct Device { id: u32, name: String }     // named fields — the common one
struct Register(u32, u32);                  // tuple struct — fields are .0 and .1
struct Marker;                              // unit struct — no data, just a type
```

```rust
let d = Device { id: 1, name: String::from("uart0") };
println!("{}", d.id);

let r = Register(0x1000, 0xFF);
println!("{:#x}", r.0);
```

**Day 1 uses a tuple struct** — `struct Noisy(&'static str)` — which is why you will see `self.0`
there. It means "the one field."

## 5. `impl`: associated functions vs methods

An `impl` block attaches behaviour to a type. There are two kinds of thing in it, and the difference
is whether it takes `self`.

```rust
impl Counter {
    fn new() -> Self { Counter { n: 0 } }        // ASSOCIATED FN — no self
    fn get(&self) -> u32 { self.n }              // METHOD — reads
    fn bump(&mut self) -> u32 { self.n += 1; self.n }  // METHOD — mutates
    fn into_total(self) -> u32 { self.n }        // METHOD — consumes
}
```

| Form | Means | Called as |
|---|---|---|
| no `self` | associated function, like a static method | `Counter::new()` |
| `&self` | borrows immutably; can read | `c.get()` |
| `&mut self` | borrows mutably; can modify | `c.bump()` |
| `self` | takes ownership; consumes the value | `c.into_total()` |

**`Self`** (capital S) is an alias for the type being implemented. `-> Self` in `new()` means
`-> Counter`.

Note the two call syntaxes: `::` for associated functions, `.` for methods.

That last row — taking `self` by value — is the one that will make sense tomorrow. It consumes the
value, so you cannot use it afterwards. Why anyone would want that is Day 1's subject.

## 6. Traits — the shape you must recognise

**This is the most important section for Day 1.**

A trait is a set of methods a type promises to provide. Think of it as an interface.

```rust
trait Describe {
    fn label(&self) -> String;                  // REQUIRED — implementors must write it

    fn describe(&self) -> String {              // DEFAULT — free, but overridable
        format!("<{}>", self.label())
    }
}

impl Describe for Device {
    fn label(&self) -> String { format!("device#{}", self.id) }
    // describe() not written, so the default is used
}
```

Read `impl Describe for Device` as: **"Device provides what the Describe trait requires."**

Output from the primer:

```text
device#7  -> <device#7>        <- default describe()
reg@0x2000 -> [[reg@0x2000]]   <- Register overrode it
```

That is all you need today. Generics, trait bounds and `dyn Trait` are W2D1.

**Why this matters right now:** Day 1's second code block is

```rust
impl Drop for Noisy {
    fn drop(&mut self) { println!("drop: {}", self.0); }
}
```

which is exactly this shape. `Drop` is a trait, and Day 1's whole subject is that the **compiler**
calls it for you when a value dies. You never call it yourself — in fact you cannot.

## 7. `#[derive(...)]`

An attribute that tells the compiler to write a trait implementation for you.

```rust
#[derive(Debug, Clone, PartialEq)]
struct Point { x: i32, y: i32 }
```

| Derive | Gives you |
|---|---|
| `Debug` | printing with `{:?}` and `{:#?}` |
| `Clone` | an explicit `.clone()` method |
| `Copy` | implicit duplication instead of moving — **Day 1's subject** |
| `PartialEq` | `==` and `!=` |
| `Default` | `Point::default()`, all fields zeroed/empty |

The most common beginner error in Rust is forgetting `Debug`:

```text
error[E0277]: `Point` doesn't implement `Debug`
   = note: add `#[derive(Debug)]` to `Point`
```

Recognise it now and you will save yourself ten minutes tomorrow.

## 8. `Option`, `Result`, and `?` — recognition only

W1D4 covers these properly. You need to *recognise* them today because Day 1's theory mentions them.

```rust
enum Option<T> { Some(T), None }             // a value, or nothing
enum Result<T, E> { Ok(T), Err(E) }          // a value, or an error
```

Rust has **no null**. A thing that might be absent is `Option<T>`, and the compiler forces you to
handle the `None` case. That entire bug class is gone.

```rust
match find_even(&v) {
    Some(n) => println!("found {}", n),
    None    => println!("nothing"),
}

if let Some(n) = find_even(&v) {   // when you only care about one case
    println!("found {}", n);
}
```

**The `?` operator** — on `Err`, return that error immediately from the current function:

```rust
fn halve_twice(x: i32) -> Result<i32, String> {
    let a = halve(x)?;    // if Err, halve_twice returns it right here
    let b = halve(a)?;
    Ok(b)
}
```

```text
halve_twice(8) = Ok(2)
halve_twice(6) = Err("3 is odd")     <- 6 halved to 3, then 3 is odd
halve_twice(5) = Err("5 is odd")     <- failed on the first call
```

Hold onto `?`. Day 1 argues that `?` plus `Drop` is what deletes C's `goto err_unlock` ladder, and
that argument is the whole point of the day.

## 9. `&str` vs `String`

Two string types, and the difference is ownership.

| | What it is | Allocates? |
|---|---|---|
| `&str` | a **view** of text someone else owns | no |
| `String` | text this value **owns** and must free | yes |

```rust
let literal: &'static str = "baked into the binary";
let owned:   String       = String::from("allocated at runtime");

fn shout(s: &str) -> String { s.to_uppercase() }
shout(&owned)     // &String coerces to &str automatically
```

`'static` means "lives for the whole program," which is true of every string literal — it is in the
binary's read-only data.

**Day 1 uses `&'static str` deliberately**, so its demo type owns no allocation of its own and the
only interesting thing about it is *when it gets dropped*.

In the kernel there is no `String`. There is `CStr`/`CString` and formatting macros, because every
allocation must be fallible.

## 10. `Vec` and slices

```rust
let mut v: Vec<i32> = Vec::new();
v.push(10);
let w = vec![1, 2, 3];             // the vec! macro

for x in &v { print!("{} ", x); }  // iterate by reference
let total: i32 = v.iter().sum();

let slice: &[i32] = &v[1..];       // a slice
```

A **slice** is a pointer and a length travelling together as one value. That is the direct fix for
C's most reliable bug: a pointer and a length that disagree. They cannot disagree here, because
they are the same value.

In the kernel this is `KVec`, and `push()` takes an allocation flag and returns a `Result`, because
kernel allocation can fail and must be handled.

---

## Self-test

Read this and answer without running it:

```rust
struct Counter { n: u32 }

impl Counter {
    fn new() -> Self { Counter { n: 0 } }
    fn bump(&mut self) -> u32 { self.n += 1; self.n }
}

impl Drop for Counter {
    fn drop(&mut self) { println!("final: {}", self.n); }
}
```

1. What does `Self` refer to in `new()`?
2. Why does `bump` take `&mut self` while `new` takes no `self` at all?
3. How would you call each one?
4. What is `impl Drop for Counter` declaring, and who calls `drop`?
5. What must be true of the caller's binding for `bump()` to be allowed?

<details>
<summary>Answers</summary>

1. `Counter`. `Self` is an alias for the type being implemented.
2. `bump` modifies `self.n`, so it needs mutable access. `new` has no instance to act on yet — it
   *creates* one, which makes it an associated function rather than a method.
3. `Counter::new()` with `::`, and `c.bump()` with `.`.
4. That `Counter` implements the `Drop` trait — code to run when a `Counter` is destroyed. **The
   compiler** calls it, automatically, when the value goes out of scope. You cannot call it yourself.
5. It must be declared `let mut c = ...`. Calling `&mut self` methods on a non-`mut` binding is a
   compile error.

</details>

If any answer was shaky, re-read that section. If all five were comfortable, Day 1's syntax will be
invisible and you can spend the day on ownership, which is the point.

---

## Done When

- [ ] `primer.rs` compiles and runs, and you read the source alongside the output
- [ ] You can explain why a trailing semicolon changes what a function returns
- [ ] You can name the four `self` forms and what each permits
- [ ] You can read `impl Trait for Type` and say what it declares
- [ ] You know what `#[derive(Debug)]` buys you and what the error looks like without it
- [ ] You can read `Option`, `Result`, and `?` without looking them up
- [ ] You can state the difference between `&str` and `String` in one sentence
- [ ] All five self-test questions answered comfortably

---

## Reading (optional, if a section felt thin)

- **The Rust Book Ch. 3** — variables, types, functions, control flow
- **Ch. 5** — structs and `impl`. Sections 5.1 and 5.3 are the relevant ones
- **Ch. 10.2** — traits. Read only up to "Traits as Parameters"; the rest is W2D1
- **Ch. 6** — enums, `Option`, `match`. Skim; W1D4 does this properly
- **Rust by Example** — if you prefer running code to reading prose

Deliberately **not** recommended today: Ch. 4 (Ownership). That is Day 1, and reading it now means
doing Day 1 twice, badly.

---

**Next:** [M1W1D1 — Ownership, Moves, and Drop](Day_1.md). One rule, three consequences, and the
reason an entire class of kernel error-path bug stops being expressible.

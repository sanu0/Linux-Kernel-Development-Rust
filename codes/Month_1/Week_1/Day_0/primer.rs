// primer.rs — M1W1D0. Exactly the Rust syntax that Day 1 assumes, and nothing more.
//
//   rustc primer.rs -o /tmp/primer && /tmp/primer
//
// This is NOT a Rust course. It covers the ten things you must be able to read
// without stumbling before M1W1D1, because Day 1 uses them on its first page but
// the roadmap does not formally teach them until W1D4 and W2D1.
//
// Deliberately absent: ownership, moves, borrowing, Drop. Those ARE Day 1 — the
// point of this file is that they should be the only new ideas that day.

use std::fmt;

fn banner(n: u32, title: &str) {
    println!("\n──── {}. {} ────", n, title);
}

// ─────────────────────────────────────────────────────────────────
// 1. let, mut, and type annotations
fn s1_bindings() {
    banner(1, "let and mut");

    let a = 5;              // inferred as i32
    let b: u64 = 5;         // annotated
    let mut c = 10;         // mutable: WITHOUT mut, reassigning is a compile error
    c += 1;

    println!("a={} b={} c={}", a, b, c);

    // Kernel code is explicit about integer width, because a driver talks to
    // hardware registers with exact sizes. u8/u16/u32/u64/usize, i8..i64.
    let reg: u32 = 0xDEAD_BEEF;   // underscores are just readability
    println!("reg = {:#x}  ({} bits set)", reg, reg.count_ones());
}

// ─────────────────────────────────────────────────────────────────
// 2. Functions, and the fact that Rust is expression-based
fn add(x: i32, y: i32) -> i32 {
    x + y // NO semicolon = this is the return value
}

fn add_explicit(x: i32, y: i32) -> i32 {
    return x + y; // legal, but idiomatic Rust omits it at the end
}

fn s2_functions() {
    banner(2, "Functions and implicit return");
    println!("add(2,3)         = {}", add(2, 3));
    println!("add_explicit(2,3)= {}", add_explicit(2, 3));

    // A semicolon turns an expression into a statement and discards its value.
    // Removing the semicolon after `x + y` above would break the function.
    // This trips up everyone once.
}

// ─────────────────────────────────────────────────────────────────
// 3. Control flow is also expressions
fn s3_control_flow() {
    banner(3, "if/match as expressions");

    let n = 7;

    // `if` produces a value, so there is no ternary operator in Rust.
    let parity = if n % 2 == 0 { "even" } else { "odd" };
    println!("{} is {}", n, parity);

    // Both arms must have the SAME type. This is a compile error:
    //   let bad = if n > 0 { 1 } else { "negative" };

    for i in 0..3 {
        print!("{} ", i); // 0..3 excludes 3; 0..=3 includes it
    }
    println!();

    let mut k = 0;
    while k < 3 {
        k += 1;
    }
    println!("k ended at {}", k);
}

// ─────────────────────────────────────────────────────────────────
// 4. Structs: three shapes
struct Device {
    // named-field struct — the common one
    id: u32,
    name: String,
}

struct Register(u32, u32); // tuple struct — fields are .0 and .1

struct Marker; // unit struct — no data, used purely as a type

fn s4_structs() {
    banner(4, "Structs");

    let d = Device { id: 1, name: String::from("uart0") };
    println!("device {} is {}", d.id, d.name);

    let r = Register(0x1000, 0xFF);
    println!("register at {:#x}, mask {:#x}", r.0, r.1);

    let _m = Marker;

    // Day 1 uses a tuple struct:  struct Noisy(&'static str);
    // so `self.0` there is "the one field".
}

// ─────────────────────────────────────────────────────────────────
// 5. impl blocks: associated functions vs methods
struct Counter {
    n: u32,
}

impl Counter {
    // ASSOCIATED FUNCTION — no self. Called as Counter::new().
    // `Self` is an alias for the type being implemented.
    fn new() -> Self {
        Counter { n: 0 }
    }

    // METHOD taking &self — reads, cannot modify. Called as c.get().
    fn get(&self) -> u32 {
        self.n
    }

    // METHOD taking &mut self — may modify. Requires the caller's binding be mut.
    fn bump(&mut self) -> u32 {
        self.n += 1;
        self.n
    }

    // METHOD taking self BY VALUE — consumes the counter.
    // Why you would ever want this is Day 1's subject.
    fn into_total(self) -> u32 {
        self.n
    }
}

fn s5_impl() {
    banner(5, "impl: associated functions and methods");

    let mut c = Counter::new(); //  :: for associated functions
    c.bump(); //  .  for methods
    c.bump();
    println!("after two bumps, get() = {}", c.get());

    let total = c.into_total(); // c is consumed here
    println!("into_total() = {}", total);
    // println!("{}", c.get());  // error: c was moved — that is Day 1
}

// ─────────────────────────────────────────────────────────────────
// 6. Traits — you only need to READ these today
//
// A trait is a set of methods a type promises to provide. This is the single
// most important shape to recognise, because Day 1 opens with
//     impl Drop for Noisy { ... }
// which reads as: "Noisy provides what the Drop trait requires."

trait Describe {
    fn label(&self) -> String; // REQUIRED: implementors must write this

    fn describe(&self) -> String {
        // DEFAULT: implementors get this free, and may override it
        format!("<{}>", self.label())
    }
}

impl Describe for Device {
    fn label(&self) -> String {
        format!("device#{}", self.id)
    }
    // describe() not written, so the default is used
}

impl Describe for Register {
    fn label(&self) -> String {
        format!("reg@{:#x}", self.0)
    }
    fn describe(&self) -> String {
        format!("[[{}]]", self.label()) // overriding the default
    }
}

fn s6_traits() {
    banner(6, "Traits: impl Trait for Type");

    let d = Device { id: 7, name: String::from("spi0") };
    let r = Register(0x2000, 0x0F);

    println!("{}  -> {}", d.label(), d.describe()); // default describe
    println!("{} -> {}", r.label(), r.describe()); // overridden describe

    // Day 1's `impl Drop for Noisy` is this exact shape. Drop is a trait the
    // COMPILER calls for you when a value dies — you never call it yourself.
}

// ─────────────────────────────────────────────────────────────────
// 7. #[derive(...)] — the compiler writes the impl for you
#[derive(Debug, Clone, PartialEq)]
struct Point {
    x: i32,
    y: i32,
}

fn s7_derive() {
    banner(7, "#[derive(...)]");

    let p = Point { x: 1, y: 2 };
    let q = p.clone(); // from Clone

    println!("Debug  : {:?}", p); // {:?} needs Debug
    println!("pretty : {:#?}", p); // {:#?} is multi-line Debug
    println!("equal  : {}", p == q); // from PartialEq

    // Without #[derive(Debug)], `{:?}` is a compile error. That is the most
    // common beginner error message in Rust, so recognise it now.
    //   error[E0277]: `Point` doesn't implement `Debug`
}

// ─────────────────────────────────────────────────────────────────
// 8. Option and Result — recognition only; W1D4 covers them properly
fn find_even(v: &[i32]) -> Option<i32> {
    for &x in v {
        if x % 2 == 0 {
            return Some(x);
        }
    }
    None
}

fn halve(x: i32) -> Result<i32, String> {
    if x % 2 == 0 {
        Ok(x / 2)
    } else {
        Err(format!("{} is odd", x))
    }
}

// The ? operator: on Err, return it immediately from THIS function.
// Day 1 explains why this deletes C's `goto err_unlock` ladder.
fn halve_twice(x: i32) -> Result<i32, String> {
    let a = halve(x)?; // if Err, halve_twice returns that Err right here
    let b = halve(a)?;
    Ok(b)
}

fn s8_option_result() {
    banner(8, "Option, Result, and ?");

    let v = [1, 3, 4, 7];
    match find_even(&v) {
        Some(n) => println!("found even: {}", n),
        None => println!("no even number"),
    }

    // if let: match on one case only
    if let Some(n) = find_even(&[1, 3]) {
        println!("unreachable, found {}", n);
    } else {
        println!("if let: nothing found");
    }

    println!("halve_twice(8)  = {:?}", halve_twice(8));
    println!("halve_twice(6)  = {:?}", halve_twice(6)); // 6->3, then 3 is odd
    println!("halve_twice(5)  = {:?}", halve_twice(5)); // fails immediately
}

// ─────────────────────────────────────────────────────────────────
// 9. &str vs String
fn shout(s: &str) -> String {
    s.to_uppercase()
}

fn s9_strings() {
    banner(9, "&str vs String");

    let literal: &'static str = "baked into the binary";
    let owned: String = String::from("allocated at runtime");

    println!("&str   : {}", literal);
    println!("String : {}", owned);
    println!("shout  : {}", shout(&owned)); // &String coerces to &str

    // &str    = a VIEW of text someone else owns. No allocation.
    // String  = text this value OWNS and must free.
    // 'static = "lives for the whole program", which is true of literals.
    //
    // Day 1 uses `&'static str` precisely so its demo type owns no allocation
    // and the only interesting thing is when it is dropped.
    //
    // In the kernel: no String. There is CString/CStr and formatting macros,
    // because every allocation must be fallible.
}

// ─────────────────────────────────────────────────────────────────
// 10. Vec, slices, and iteration
fn s10_collections() {
    banner(10, "Vec and slices");

    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);

    let w = vec![1, 2, 3]; // vec! macro, same thing

    println!("v = {:?}, len {}", v, v.len());
    println!("w = {:?}", w);

    for x in &v {
        // iterate by reference
        print!("{} ", x);
    }
    println!();

    let total: i32 = v.iter().sum();
    println!("sum = {}", total);

    let slice: &[i32] = &v[1..]; // a slice: pointer + length, together
    println!("slice from index 1 = {:?}", slice);

    // A slice is the fix for C's "pointer and length that disagree" bug class:
    // they cannot disagree, because they are one value.
    //
    // In the kernel: KVec, and push() takes an allocation flag and can fail.
}

// Bonus: implementing Display, so a type can be printed with {}
impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
    }
}

fn main() {
    println!("=== Rust primer: exactly what M1W1D1 assumes ===");

    s1_bindings();
    s2_functions();
    s3_control_flow();
    s4_structs();
    s5_impl();
    s6_traits();
    s7_derive();
    s8_option_result();
    s9_strings();
    s10_collections();

    banner(11, "Bonus: Display lets you use {}");
    println!("Point prints as {}", Point { x: 3, y: 4 });

    println!("\n=== if all of that read easily, you are ready for Day 1 ===");
}

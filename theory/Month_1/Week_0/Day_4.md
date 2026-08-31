# M1W0D4 — The Rust Toolchain

> **Goal:** get `make LLVM=1 rustavailable` to say yes, enable `CONFIG_RUST`, build a Rust-enabled
> kernel, and load a Rust kernel module — watching it print into `dmesg`.
>
> **Time:** 2-3 hours, including one full config-change rebuild.
>
> **Why this matters:** everything for the last three days has been C infrastructure. Today the
> roadmap's actual subject arrives. By the end you will have compiled Rust code *into an operating
> system kernel* and executed it in ring 0. That is a genuinely small club to join, and every project
> from here builds on the toolchain you set up today.

---

## Today's Checklist

- [ ] Install `rustup` and the toolchain version your tree demands, plus `rust-src`, `rustfmt`, `clippy`
- [ ] Pin the toolchain to the kernel tree so you never fight version drift
- [ ] Install `bindgen-cli` at the version your tree demands
- [ ] Get `make LLVM=1 rustavailable` to print **"Rust is available!"**
- [ ] Read `Documentation/rust/quick-start.rst` — the authoritative document
- [ ] Enable `CONFIG_RUST` **without destroying your virtme options**
- [ ] Enable the sample modules, build, and boot
- [ ] Load `rust_minimal` and see it in `dmesg`
- [ ] Read the source of the module you just ran
- [ ] Wire up `rust-analyzer` and build the local `rustdoc`
- [ ] Journal: the exact versions that worked

---

## Concepts

### 1. Ask the kernel what it needs — don't guess

Every kernel version needs particular tool versions. Rather than trusting a guide — including this one —
just ask your own tree:

```bash
scripts/min-tool-version.sh rustc      # 1.85.0
scripts/min-tool-version.sh bindgen    # 0.71.1
scripts/min-tool-version.sh llvm       # 17.0.1
```

These are **minimums**, not exact versions. Newer is usually fine — you already have LLVM 21 where 17 is
the floor.

"Usually" is doing a lot of work in that sentence, though. Which brings us to the next bit.

### 2. Why versions matter more here than in normal Rust

Rust releases a new version every six weeks, and normal Rust code barely notices — the language works
hard at not breaking old code.

Kernel Rust is more delicate, for two reasons:

**It uses experimental features.** Some of what the kernel needs isn't finished yet. Unfinished features
can change or disappear in the next release.

**bindgen's output shifts between versions.** bindgen reads C headers and writes Rust. Different versions
write it slightly differently — different names, different layouts — and the kernel's code is written
expecting one particular style.

So we **pin the version to this folder**. Upgrade Rust globally next month and this kernel still builds,
because the pin is per-directory.

### 3. Why `rustup` and not `apt`

Yesterday `apt` was the right answer for virtme-ng. Today it isn't. Two things we need that `apt` won't
give us reliably: a **specific version**, and a component called **`rust-src`**.

`rustup` handles both. It keeps several Rust versions side by side and can lock one to a single folder.

The rule isn't "always use apt." It's *use whichever tool lets you control the thing whose version
actually matters*.

### 4. Why `rust-src` — the surprising one

When you write normal Rust and use `Vec` or `Option`, that code comes from Rust's **standard library**.
You don't write it; it ships with Rust.

And it ships **already compiled** — for Linux on x86, for Windows, for Mac. Building a normal program
just glues that pre-built library onto your code.

**The kernel can't use any of them**, because every one assumes there's an operating system underneath.
The standard library asks the OS for memory. It asks the OS to print. But the kernel *is* the operating
system — there's nobody underneath to ask.

Think of it as a toolbox that arrives pre-assembled for a particular workshop. Rust ships pre-assembled
toolboxes for "Linux desktop," "Windows," "Mac." Nobody ships one labelled *"inside the Linux kernel,
built with these exact flags"* — far too specific, and there are endless variations.

So the kernel takes the **plans** and builds its own. **`rust-src` is the plans** — the actual source
code of Rust's standard library. Without it there's nothing to build from and the kernel build fails
straight away.

What gets built, and what doesn't:

| Part | Built? | What it is |
|---|---|---|
| `core` | ✓ | the basics — numbers, slices, `Option`, `Result`, iterators. Needs no OS |
| `alloc` | ✓ | the parts needing memory — `Vec`, `Box`. The kernel supplies its own allocator |
| `compiler_builtins` | ✓ | tiny low-level helpers the compiler assumes exist |
| `std` | **✗** | files, threads, sockets, `println!` — all need an OS |

That last row is what `no_std` means: you get `core` and `alloc`, never `std`.

You'll see it happen:

```text
RUSTC L core.o
RUSTC L compiler_builtins.o
```

Your kernel build compiling Rust's standard library, in the middle of building an operating system. Not
a figure of speech.

### 5. There is no Cargo, and there never will be

If you've written normal Rust, this is the biggest adjustment. No `Cargo.toml`. No `cargo build`. No
pulling crates from the internet. Ever.

Kbuild calls `rustc` directly instead. Three reasons, none negotiable:

- **A kernel build must work offline** and produce the same result every time.
- **Every line shipped in the kernel gets read by a human.** You can't pull in a stranger's code because
  it was convenient.
- **Kbuild already runs the build.** Two build systems fighting over one tree ends badly.

When the kernel genuinely needs an outside crate, it gets **vendored** — copied into the tree and
reviewed like any other kernel code. `rust/pin-init/` is one. Version 7.2 brought in `zerocopy` the same
way.

What this means for you: `cargo add` is not something you'll ever do here. Need functionality? Write it,
or wrap the C that already exists.

### 6. The gate: `make LLVM=1 rustavailable`

One command decides whether Rust can be enabled at all. It runs a script that checks six things:

1. Is `rustc` installed, and new enough?
2. Is `bindgen` installed, and new enough?
3. Can it find **`libclang`**? (bindgen needs it to read C)
4. Is `rust-src` there, so `core` can be built?
5. Does Rust support the target the kernel wants?
6. Does `rustc`'s built-in LLVM match the C compiler's LLVM?

That last one is why `LLVM=1` appears on every build command from today on. `rustc` has LLVM inside it,
and `clang` *is* LLVM. Build the C half with GCC and the Rust half with rustc, and you have two separate
code generators making separate decisions about optimisation and stack layout. When that goes wrong the
errors are horrible. Using LLVM for both keeps one thing in charge — and it's the setup the
Rust-for-Linux developers actually test.

### 7. How Rust and C talk to each other

Three layers, and the direction matters: **Rust wraps C**, not the other way round.

```text
C headers (include/)                     the real kernel API
      │
      ▼  bindgen, using libclang to read the C
rust/bindings/                           machine-written, raw, ALL unsafe
      │
      ▼  rustc
rust/kernel/                             hand-written safe wrappers - unsafe lives HERE
      │
      ▼  rustc
drivers/, samples/rust/                  your code - ideally zero unsafe
      │
      ▼  linked with all the C objects
vmlinux
```

Each arrow is a `RUSTC` line in your build output.

The layering is the whole design. `rust/bindings/` is generated and unsafe by nature. `rust/kernel/` is
where humans carefully wrap that in something safe. Your driver then uses only the safe layer — and
should contain no `unsafe` at all.

### 8. Why `CONFIG_RUST` is greyed out right now

You found the reason yourself on Day 2, in `init/Kconfig`:

```
config RUST
	bool "Rust support"
	depends on HAVE_RUST
	depends on RUST_IS_AVAILABLE
	...
```

`RUST_IS_AVAILABLE` is set by the script from concept 6. No `rustc` installed means it's false, which
means the option can't be selected — it doesn't even appear as something you could switch on.

Install the toolchain, that flips to true, and the option unlocks. That's the entire mechanism.

Those `depends on !X` lines below it are worth a second look too. They're an honest list of kernel
features Rust doesn't get along with yet — `RANDSTRUCT`, certain `MODVERSIONS` setups, some LTO and BTF
combinations, and `KASAN` unless you're using Clang. That's the "Rust coverage is still incomplete"
caveat, written as code instead of prose.

### 9. `samples/rust/` is the rest of your roadmap, already on disk

Your tree ships 16 working Rust examples. Look at what they actually are:

| Sample | Demonstrates | You meet this in |
|---|---|---|
| `rust_minimal.rs` | the smallest possible module | **today** |
| `rust_print_main.rs` | logging, `pr_info!` and friends | Month 3 |
| `rust_misc_device.rs` | misc device, file ops, ioctl | **Month 3 (KModKit)** |
| `rust_debugfs.rs`, `rust_debugfs_scoped.rs` | exposing state via debugfs | Month 5 |
| `rust_configfs.rs` | userspace-created objects | Month 6 (BlockForge) |
| `rust_driver_pci.rs` | a PCI driver | **Month 4 (VirtToy)** |
| `rust_driver_platform.rs` | platform bus + device tree | Month 5 |
| `rust_driver_i2c.rs`, `rust_i2c_client.rs` | I2C driver | **Month 5 (SensorRS)** |
| `rust_dma.rs` | DMA allocations | Month 5 (DMAForge) |
| `rust_driver_usb.rs` | USB driver | later — new, and moving fast |
| `rust_driver_faux.rs`, `rust_driver_auxiliary.rs` | simpler bus types | Month 4 |
| `rust_soc.rs` | SoC-level driver | Month 5 |

Sit with that table for a minute. **The first half of this roadmap is already in that folder, as working
code you can read.** When you write your own PCI driver in Month 4, `rust_driver_pci.rs` is the first
file you'll open. Today you only load the simplest one — but you'll work through most of these over the
next five months.

And `rust/kernel/` has **78 modules** in it. That's the safe-wrapper layer from concept 7, and it's where
you'll spend the next 18 months.

### 10. What a Rust kernel module looks like

`rust_minimal.rs` is about 30 lines and it will look odd at first. Here's what to expect:

**No `main()`.** A module isn't a program you run — it's code the kernel loads into itself. So there's no
starting point in the usual sense.

**`module! { ... }` does the paperwork.** The kernel expects a pile of boilerplate from every module:
metadata, a license declaration, pointers to the load and unload functions. In C you write all of that
by hand. This macro generates it.

**`init()` returns a `Result`.** Loading can fail, and failure is just a return value. Hand back an error
and the kernel cleanly refuses to load your module — no half-loaded state.

**`Drop` is the unload path.** A C module needs an explicit exit function. In Rust, unloading runs your
destructor, so cleanup happens automatically and in the right order. That teardown discipline you'd have
to maintain by hand in C is enforced by the language.

**`no_std` applies.** No `println!`, no `std::String`, and memory allocation is something you ask for and
might be refused.

You won't fully understand it today, and you don't need to. Recognising the *shape* is the goal.

---

## Step-by-Step

### Phase 0 — Sync and confirm where you are

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

cd "$LINUX_TREE"
make -s kernelversion
scripts/min-tool-version.sh rustc
scripts/min-tool-version.sh bindgen
clang --version | head -1
echo "$LIBCLANG_PATH"
```

`LIBCLANG_PATH` should be `/usr/lib/llvm-21/lib` from Day 1. That is the variable that stops bindgen
failing with an unhelpful error.

Now check that nothing in your config will block `CONFIG_RUST`. Recall the `depends on !X` lines you
read in `init/Kconfig` on Day 2 — every one of those features must be **off**:

```bash
for o in MODVERSIONS RANDSTRUCT GCC_PLUGIN_RANDSTRUCT DEBUG_INFO_BTF CFI KASAN LTO; do
  grep -qE "^CONFIG_${o}=" .config && echo "BLOCKER: CONFIG_${o} is set" || echo "ok: CONFIG_${o} off"
done
for o in MODULES HAVE_RUST; do
  grep -qE "^CONFIG_${o}=y" .config && echo "ok: CONFIG_${o}=y" || echo "PROBLEM: CONFIG_${o} missing"
done
```

**Verified on this tree (7.2.0-rc7, post-Day-3 config): every blocker is off, and `MODULES=y` and
`HAVE_RUST=y` are both set.** `CONFIG_MODULES=y` matters because the samples are built as modules — you
cannot `insmod` something that is compiled in.

The practical consequence: **the only thing preventing `CONFIG_RUST` right now is the missing toolchain.**
So if it still refuses to enable after Phase 3, the cause is definitively `rustavailable`, not a hidden
config conflict. That removes one whole category of confusion from today.

> Two of those deserve a note. `CONFIG_DEBUG_INFO_BTF` is *off* in your config, which is lucky — the
> dependency is `!DEBUG_INFO_BTF || (PAHOLE_HAS_LANG_EXCLUDE && !LTO)`, so with BTF on you would need a
> recent `pahole`. Yours is v1.31 and `PAHOLE_HAS_LANG_EXCLUDE=y`, so you would have been fine anyway.
> And `CONFIG_KASAN` is off today; when you enable it in Month 3 for debugging, note the dependency is
> `!KASAN || CC_IS_CLANG` — another reason `LLVM=1` is the path of least resistance.

### Phase 1 — Install rustup and the toolchain

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
source "$HOME/.cargo/env"

# Persist it, since Day 1 did not add cargo to your shell
grep -q '.cargo/env' ~/.bashrc || echo '. "$HOME/.cargo/env"' >> ~/.bashrc
```

**First check whether you already have what you need.** The `rustup` installer gives you the current
stable toolchain, and `min-tool-version.sh` reports a **minimum** — so stable is very often new enough
already:

```bash
cd "$LINUX_TREE"
rustc --version                              # what you have
scripts/min-tool-version.sh rustc            # the floor: 1.85.0
```

If your version is at or above the floor, **you do not need to download anything else.** Just add the
missing components to the toolchain you have:

```bash
rustup component add rust-src rustfmt clippy
```

`rust-src` is the one that matters — see concept 4. `rustup` ships `rustc`, `cargo`, `clippy`, and
`rustfmt` by default but **not** `rust-src`, so this single command is usually the whole job.

<details>
<summary><b>Only if your stable is older than the floor</b> — install the exact version</summary>

```bash
RUSTC_VER="$(scripts/min-tool-version.sh rustc)"
rustup toolchain install "$RUSTC_VER"
rustup component add rust-src rustfmt clippy --toolchain "$RUSTC_VER"

# Pin this tree to that toolchain, so a later global change cannot break this build.
rustup override set "$RUSTC_VER"
```

</details>

```bash
rustc --version && cargo --version
```

> **Do not download an old toolchain you do not need.** An earlier version of this document told you to
> install exactly `1.85.0`, and on a slow or corporate network that produces a wall of
> `Connection timed out` errors — for a toolchain that was never required, because stable already
> exceeded the minimum. `rustavailable` is the only thing whose opinion counts here: if it does not
> complain about your `rustc` version, your `rustc` version is fine.
>
> **Verified on this tree:** rustc **1.98.0** against a floor of 1.85.0 passes the version check
> cleanly. The only thing `rustavailable` asked for was `bindgen`.

### Phase 2 — Install bindgen

```bash
BINDGEN_VER="$(scripts/min-tool-version.sh bindgen)"   # 0.71.1
cargo install --locked --version "$BINDGEN_VER" bindgen-cli
bindgen --version
```

`--locked` matters: it uses the versions in the crate's lockfile rather than resolving fresh ones, so
you get a reproducible build of the tool. This takes a few minutes — it is compiling bindgen from source.

### Phase 3 — The gate

```bash
cd "$LINUX_TREE"
make LLVM=1 rustavailable
```

You want exactly this:

```text
Rust is available!
```

If not, **read the message literally**. It names the tool and the problem. Common outcomes:

| Message mentions | Fix |
|---|---|
| `rustc` version | `rustup override set $(scripts/min-tool-version.sh rustc)` inside the tree |
| `bindgen` version | reinstall at the named version with `--locked` |
| `libclang` | `export LIBCLANG_PATH=/usr/lib/llvm-21/lib` (Day 1 set this — check it survived) |
| `rust-src` | `rustup component add rust-src --toolchain <ver>` |
| target not supported | check `Documentation/rust/arch-support.rst` |

Do not proceed until it passes. Nothing below will work otherwise.

### Phase 4 — Enable CONFIG_RUST without losing your virtme options

**Read this before running anything.** Your `.config` currently contains the virtio and 9p options that
`vng --kconfig` added on Day 3. If you run `make defconfig` you will throw those away and `vng` will
stop giving you a shell.

So modify the **existing** config in place:

```bash
cd "$LINUX_TREE"
cp .config .config.day3-backup        # cheap insurance

scripts/config --enable RUST
scripts/config --enable SAMPLES
scripts/config --enable SAMPLES_RUST
scripts/config --module SAMPLE_RUST_MINIMAL
scripts/config --module SAMPLE_RUST_PRINT
scripts/config --module SAMPLE_RUST_MISC_DEVICE

# Rust-specific debug help, worth having from day one
scripts/config --enable RUST_DEBUG_ASSERTIONS
scripts/config --enable RUST_OVERFLOW_CHECKS

# Re-resolve every dependency after the edits. Never skip this.
make LLVM=1 olddefconfig
```

Verify both the new options **and** that the old ones survived:

```bash
grep -E '^CONFIG_RUST=|^CONFIG_SAMPLE_RUST' .config
grep -E '^CONFIG_VIRTIO=|^CONFIG_NET_9P=' .config     # must still be there
```

If `CONFIG_RUST=y` is absent, `rustavailable` is not actually passing. Go back to Phase 3.

### Phase 5 — Build, and watch Rust compile

```bash
time make LLVM=1 -j"$(nproc)"
```

**This will be a long build** — five minutes or so, like Day 3's. A config change invalidates most of
the tree, and you are now also compiling `core`, `alloc`, the `kernel` crate, and the samples.

Watch for lines you have never seen before:

```text
RUSTC L core.o                          <- compiling the Rust standard library
BINDGEN rust/bindings/bindings_generated.rs
RUSTC L kernel.o                        <- the abstraction layer
RUSTC M samples/rust/rust_minimal.o     <- the sample module
```

That `BINDGEN` line is concept 7 happening. Afterwards, go and look at what it produced:

```bash
wc -l rust/bindings/bindings_generated.rs
head -40 rust/bindings/bindings_generated.rs
```

That file is machine-generated, raw, and entirely `unsafe`. It is the reason `rust/kernel/` exists.

> **From now on, always pass `LLVM=1`.** Mixing a GCC-built tree with an LLVM-built one causes confusing
> failures. Consider updating your `kb` alias: `alias kb='cd "$LINUX_TREE" && make LLVM=1 -j$(nproc)'`

### Phase 6 — Load your first Rust kernel module

```bash
cd "$LINUX_TREE"
ls -lh samples/rust/*.ko
```

Then boot and load it. Run this from a real terminal — `vng` needs a TTY:

```bash
vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -10; rmmod rust_minimal; dmesg | tail -5'
```

You are looking for something like:

```text
rust_minimal: Rust minimal sample (init)
rust_minimal: Am I built-in? false
...
rust_minimal: My numbers are [72, 108, 200]
rust_minimal: Rust minimal sample (exit)
```

**That is Rust code executing in kernel space.** The init message, the exit message from `Drop`, and a
`KVec` allocated with kernel memory in between.

Try the others:

```bash
vng --exec 'insmod samples/rust/rust_print.ko; dmesg | tail -20; rmmod rust_print'
```

### Phase 7 — Read the module you just ran

```bash
cat samples/rust/rust_minimal.rs
```

Find each of these and name it out loud:

- the `module! { ... }` invocation, and its `license:` field
- the struct that represents the module
- `impl kernel::Module for ...` and its `init()`
- the `-> Result<Self>` return type
- `impl Drop for ...` — the exit path
- `pr_info!` calls, and how they map to what you saw in `dmesg`

Then compare against the C module you will write later:

```bash
wc -l samples/rust/rust_minimal.rs
```

### Phase 8 — Editor support and the docs

```bash
cd "$LINUX_TREE"
make LLVM=1 rust-analyzer      # regenerates rust-project.json
make LLVM=1 rustdoc            # builds the kernel Rust API docs locally
```

The rustdoc output lands under `Documentation/output/rust/rustdoc/kernel/index.html`. Open it from
Windows — WSL paths are browsable at `\\wsl.localhost\Ubuntu\home\ksanu\...`. The same content is online
at [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/), which you will have open constantly.

Spend fifteen minutes browsing it. Look up `KVec`, `KBox`, `Error`, `Result`, `SpinLock`. You are not
learning them today — you are learning where they live.

### Phase 9 — Record it

```bash
bash ~/LKD_RUST/codes/Month_1/Week_0/Day_4/check_day4.sh
bash ~/LKD_RUST/codes/Month_1/Week_0/Day_1/record_env.sh
```

---

## Verification

```bash
cd "$LINUX_TREE"
make LLVM=1 rustavailable                     # "Rust is available!"
rustc --version; bindgen --version
grep -c '^CONFIG_RUST=y' .config              # 1
ls samples/rust/*.ko | wc -l                  # 3 or more
vng --exec 'insmod samples/rust/rust_minimal.ko && dmesg | tail -5'
```

---

## Gotchas

- **Running `make defconfig` to add `CONFIG_RUST`.** It discards your virtme options and `vng` stops
  working. Use `scripts/config` on the existing `.config`, then `make olddefconfig`.
- **Forgetting `LLVM=1` on a later build.** Half your tree built with one toolchain and half with
  another produces link errors that look like source bugs.
- **`rustup` installed but `cargo` not on `PATH` in new shells.** The installer offers to modify your
  shell config; we passed `--no-modify-path` and appended it explicitly. Verify in a fresh terminal.
- **Global toolchain vs per-tree override.** `rustup override set` is per-directory. If you get version
  errors, check `rustup show` *from inside the tree*.
- **`LIBCLANG_PATH` lost.** It is in `~/.bashrc` from Day 1. A fresh shell in a weird environment may
  not have it, and bindgen's failure message is not obvious about the cause.
- **Expecting `CONFIG_RUST` to appear before the toolchain works.** The dependency chain forbids it.
  Fix `rustavailable` first, always.
- **`cargo install bindgen-cli` without `--locked` or a version.** You get whatever is latest, which may
  be outside the kernel's supported range.
- **Thinking you can `cargo add` a crate.** You cannot. The kernel vendors what it needs.
- **Assuming a Rust module can panic safely.** It cannot. `unwrap()` in kernel code is a bug — you will
  spend Month 2 internalising this.
- **Building samples as `=y` instead of `=m`.** Built-in samples cannot be `insmod`'d or `rmmod`'d, so
  you lose the load/unload cycle that makes them useful to learn from.

---

## My Notes

### Toolchain versions that worked

| Tool | Required by tree | Installed |
|---|---|---|
| rustc | 1.85.0 | |
| bindgen | 0.71.1 | |
| LLVM / clang | 17.0.1 | |
| rust-src | — | |
| LIBCLANG_PATH | — | |

### Build

| Measurement | Value |
|---|---|
| Rust-enabled build time | |
| `bindings_generated.rs` line count | |
| Number of `.ko` files in `samples/rust/` | |
| `vmlinux` size before vs after enabling Rust | |

### The dmesg output from rust_minimal

```text
(paste it here — this is the first Rust you ran in ring 0)
```

### What `rust_minimal.rs` looks like, in my own words

### What went wrong, and how I fixed it

### What I do not understand yet

---

## Done When

- [ ] `make LLVM=1 rustavailable` prints "Rust is available!"
- [ ] Toolchain pinned to the tree with `rustup override`, and you can explain why per-tree pinning helps
- [ ] You can explain what `rust-src` is for, and why the kernel compiles `core` itself
- [ ] You can explain why the kernel does not use Cargo, and what "vendored" means
- [ ] You can draw the bindgen → `rust/kernel` → leaf-driver pipeline from memory
- [ ] You can explain why `LLVM=1` matters for Rust specifically
- [ ] `CONFIG_RUST=y` **and** the virtio options both present in `.config`
- [ ] Rust-enabled kernel built; you saw `RUSTC` and `BINDGEN` lines go past
- [ ] `rust_minimal.ko` loaded and unloaded, with its output captured
- [ ] You have read `rust_minimal.rs` and can name the `module!` macro, `init()`, and the `Drop` exit path
- [ ] `rust-analyzer` working in your editor on `rust/kernel/` code
- [ ] Local `rustdoc` built and browsed
- [ ] Journal tables filled in

---

## Reading

- **`Documentation/rust/quick-start.rst`** — the authoritative setup document. Read it properly now that
  you have done the work; it will confirm and correct your mental model
- **`Documentation/rust/general-information.rst`** — the abstractions-vs-bindings doctrine, which is the
  single most important idea in kernel Rust
- `Documentation/rust/coding-guidelines.rst` — skim today, live by it from Month 2
- `samples/rust/rust_minimal.rs` and `samples/rust/rust_print_main.rs` — read both completely
- `rust/kernel/lib.rs` — just the module list at the top. See how much surface area exists
- [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/) — bookmark it

---

## 📖 The Whole Day As A Story (read this first on revision)

*Plain words, no jargon. If you only re-read one section months from now, make it this one.*

### What today is for

Days 1-3 built a C kernel and made booting it fast. Today we **add a Rust compiler to that build** and
run Rust code inside the kernel.

### 1. The tree tells us what it needs

We didn't guess versions. We asked the kernel:

```text
rustc   >= 1.85.0
bindgen >= 0.71.1
llvm    >= 17.0.1     (we have 21)
```

Those are floors, not exact pins.

### 2. Why the version matters more here than in normal Rust

Two reasons. The kernel uses **unstable** Rust features that can change between releases. And `bindgen`
— the tool that reads C headers and writes Rust — produces slightly different output in different
versions, and the kernel's code is written against specific output.

So we pinned the toolchain **to this directory** with `rustup override`. A global Rust upgrade later
can't quietly break this kernel.

### 3. Why `rustup` and not `apt`

Yesterday `apt` was the right answer for virtme-ng. Today it isn't. We need a *specific* version plus a
component called `rust-src`, and distro packages give neither reliably.

The rule isn't "always apt" — it's *use whichever tool gives you control over the thing whose version
actually matters*.

### 4. The genuinely surprising bit

**Your kernel build compiles the Rust standard library itself.**

Normally `rustc` links a *pre-built* `core` library shipped for your platform. The kernel can't use it,
because the kernel isn't a normal platform — no OS underneath, no standard library, its own compiler
flags. Nobody ships a pre-built `core` for "x86_64 kernel with these exact settings."

So the kernel compiles `core` from source, as part of your build. That's what `rust-src` is: the
*source code* of Rust's standard library. You'll watch it go past:

```text
RUSTC L core.o
```

### 5. There is no Cargo. There never will be.

No `Cargo.toml`, no crates.io, no `cargo add`. Kbuild calls `rustc` directly.

Why: a kernel build must work offline and be reproducible, and every line shipped in the kernel gets
reviewed by a human. You can't pull in a stranger's crate because it was convenient.

When the kernel genuinely needs an external crate it is **vendored** — copied into the tree and
reviewed. `rust/pin-init/` is one of those.

### 6. How Rust and C talk to each other

Three layers, and the direction matters — **Rust wraps C**, not the reverse:

```text
C headers                    the real kernel API
    ↓  bindgen (uses libclang to read C)
rust/bindings/               machine-generated, raw, ALL unsafe
    ↓
rust/kernel/                 hand-written safe wrappers - unsafe lives HERE
    ↓
your driver                  ideally zero unsafe
```

`libclang` is why Day 1 set `LIBCLANG_PATH` — bindgen literally uses Clang's C parser as a library.

### 7. Why `CONFIG_RUST` was greyed out

On Day 2 you found this in `init/Kconfig`:

```text
depends on RUST_IS_AVAILABLE
```

A script checks whether a working Rust toolchain exists. With no `rustc` installed the answer was no, so
the option couldn't even be selected. Today you install the toolchain, the answer flips to yes, and the
option becomes available. That's the whole mechanism.

### 8. The config trap (same one as Day 3)

`make defconfig` would have given us Rust and **silently deleted the virtio options**, breaking `vng`.
So we edited the existing config in place instead:

```bash
scripts/config --enable RUST     # change one setting
make LLVM=1 olddefconfig         # re-resolve dependencies
```

Then we counted the virtio options before and after to prove they survived.

### 9. The payoff

After a ~5 minute rebuild — long because a config change invalidates most of the tree, *and* we're now
compiling `core`, `alloc`, and the whole `kernel` crate for the first time — we loaded a Rust module:

```text
rust_minimal: Rust minimal sample (init)
rust_minimal: My numbers are [72, 108, 200]
rust_minimal: Rust minimal sample (exit)
```

Init, a vector allocated with kernel memory, then a clean exit from `Drop`. **That's Rust running in
ring 0.**

### 10. `samples/rust/` is the rest of the roadmap

Sixteen samples ship in this tree, and they map almost exactly onto the months ahead: a misc device
(Month 3), a **PCI driver** (Month 4), I2C and DMA (Month 5), configfs (Month 6). When you write your
own PCI driver, `rust_driver_pci.rs` is the file you'll open first.

### If you remember only four things

1. **The tree tells you which versions it needs.** `scripts/min-tool-version.sh`, never a blog post.
2. **The kernel compiles Rust's `core` itself**, which is why `rust-src` is mandatory.
3. **No Cargo, ever.** External crates are vendored and reviewed.
4. **`unsafe` belongs in `rust/kernel/`, not in drivers.** That layering is the entire design.

### The commands, in order

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
. "$HOME/.cargo/env"

cd "$LINUX_TREE"
rustup toolchain install "$(scripts/min-tool-version.sh rustc)"
rustup component add rust-src rustfmt clippy --toolchain "$(scripts/min-tool-version.sh rustc)"
rustup override set "$(scripts/min-tool-version.sh rustc)"        # pin to THIS tree
cargo install --locked --version "$(scripts/min-tool-version.sh bindgen)" bindgen-cli

make LLVM=1 rustavailable        # the gate. must say "Rust is available!"

scripts/config --enable RUST     # edit in place - NOT make defconfig
scripts/config --module SAMPLE_RUST_MINIMAL
make LLVM=1 olddefconfig
time make LLVM=1 -j"$(nproc)"    # ~5 min: config changed + core/alloc/kernel crate

vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -10; rmmod rust_minimal'
```

**From today onward, always pass `LLVM=1`.** Mixing a GCC-built tree with an LLVM-built one produces
link errors that look like source bugs.

---

**Next:** M1W0D5 — Developer Ergonomics & Upstream Plumbing. `git send-email` verified end to end, `b4`,
`checkpatch.pl`, `get_maintainer.pl`, and subscribing to the lists. Less glamorous than today, and it is
what makes contribution possible at all — Week 0 ends with your lab genuinely complete.

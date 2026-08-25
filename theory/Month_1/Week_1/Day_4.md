# M1W1D4 — The Rust Toolchain

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

### 1. What your tree actually demands

Your kernel names its own requirements. Ask it rather than trusting any guide, including this one:

```bash
scripts/min-tool-version.sh rustc      # 1.85.0
scripts/min-tool-version.sh bindgen    # 0.71.1
scripts/min-tool-version.sh llvm       # 17.0.1
```

Those are **minimums**, not exact pins. Newer usually works — you already have LLVM 21 against a
minimum of 17. But "usually" is doing real work in that sentence, which is why the next concept exists.

### 2. Why the version matters more here than in normal Rust

Rust ships a new stable every six weeks. Userspace code copes because Rust takes backwards
compatibility seriously. Kernel Rust is more fragile than normal Rust for two reasons:

- **It uses unstable features.** The kernel needs language features not yet stabilised, and unstable
  features can change or disappear between releases.
- **`bindgen` output is version-sensitive.** bindgen generates the Rust view of C headers. A different
  bindgen version can emit different type names or layouts, and the kernel's abstractions are written
  against specific output.

So the kernel pins a floor, tests against particular versions, and `rust_is_available.sh` refuses to
proceed if you are outside the supported range. Pinning your toolchain per-tree is not paranoia; it is
how you avoid losing an evening to a toolchain upgrade you did not ask for.

### 3. Why `rustup` and not `apt install rustc`

Because you need a **specific** version and the `rust-src` component, and distro packages give you
neither reliably. `rustup` manages multiple toolchains side by side and can pin one per directory,
which is exactly the shape of the problem.

This is the opposite of yesterday's lesson with `virtme-ng`, where the distro package was the right
answer. The rule is not "always apt" — it is *use the tool that gives you version control over the
thing whose version matters*.

### 4. Why `rust-src` — the interesting one

Normally `rustc` links against a **precompiled** `core` and `std` shipped for your platform. The kernel
cannot use those, for a simple reason: it is not your platform.

The kernel builds for its own **custom target** — no operating system underneath, no standard library,
its own code-generation flags, its own ABI decisions, `no_std`. There is no prebuilt `core` for
"x86_64 kernel with these exact flags," so the kernel **compiles `core` and `alloc` from source
itself**, as part of your kernel build.

That is what `rust-src` provides: the source code of the Rust standard library. Without it the build
fails immediately, because there is nothing to compile.

You will literally see this scroll past:

```text
RUSTC L core.o
RUSTC L compiler_builtins.o
```

Your kernel build compiles the Rust standard library. That is not a metaphor.

### 5. The kernel does not use Cargo

If you come from normal Rust this is the biggest adjustment. There is no `Cargo.toml`, no `cargo build`,
no `crates.io` dependency.

Kbuild invokes `rustc` directly, one crate at a time, passing `--extern` flags by hand. The reasons are
non-negotiable from the kernel's side:

- **No network at build time.** A kernel build must be reproducible and offline.
- **No unvetted dependencies.** Every line shipped in the kernel is reviewed. You cannot pull in a crate
  because it was convenient.
- **Kbuild already owns the build.** Two build systems fighting over one tree is a bad idea.

Where the kernel genuinely needs an external crate, it is **vendored** — copied in and reviewed.
`rust/pin-init/` is a vendored crate, and 7.2 brought in `zerocopy` the same way.

Consequence for you: `cargo add` is not a thing you will ever do for kernel code. If you need
functionality, you write it or you wrap the C that already exists.

### 6. What `rust_is_available.sh` checks

`make LLVM=1 rustavailable` runs `scripts/rust_is_available.sh`, which is the gatekeeper for
`CONFIG_RUST`. It verifies:

1. `rustc` exists and meets the minimum version
2. `bindgen` exists and meets the minimum version
3. **`libclang` is findable** — bindgen links against it to parse C headers
4. `rust-src` is present, so `core` can be built
5. The target the kernel wants is supported
6. `rustc`'s bundled LLVM version is compatible with the C compiler's LLVM

Point 6 is why `LLVM=1` runs through this whole roadmap. `rustc` has LLVM built in; `clang` is LLVM. If
you compile the C half with GCC and the Rust half with rustc/LLVM, you have two independent code
generators making independent decisions about target features, sanitizers, stack protection, and LTO.
Using LLVM for both keeps one code generator in charge — and it is the configuration the
Rust-for-Linux developers actually test.

### 7. The Rust build pipeline inside the kernel

Yesterday you learned the C pipeline. Rust adds a layer in front of it:

```text
C headers (include/)
      │
      ▼  bindgen + libclang
rust/bindings/bindings_generated.rs      raw, unsafe, machine-generated
      │
      ▼  rustc
rust/kernel/  (the `kernel` crate)       safe abstractions - unsafe lives HERE
      │
      ▼  rustc
drivers/, samples/rust/                  leaf code - ideally zero unsafe
      │
      ▼  linked with the C objects
vmlinux
```

Every arrow is a `RUSTC` line in your build output. And note the direction: **Rust wraps C**, not the
reverse. The kernel is still a C program that Rust code participates in.

### 8. Why `CONFIG_RUST` currently refuses to appear

You found this yourself on Day 2, in `init/Kconfig`:

```
config RUST
	bool "Rust support"
	depends on HAVE_RUST
	depends on RUST_IS_AVAILABLE
	...
```

`RUST_IS_AVAILABLE` is set by the script in concept 6. With no `rustc` installed, it is false, so the
option cannot be selected at all — it does not even show as a togglable entry. Today you flip that
input, and the option becomes available.

Also worth re-reading those `depends on !X` lines. They are the current, honest list of kernel features
Rust does not yet coexist with — `RANDSTRUCT`, some `MODVERSIONS` configurations, certain LTO and BTF
combinations, `KASAN` unless you are using Clang. That is the "coverage is incomplete" caveat expressed
as code rather than prose.

### 9. What is in `samples/rust/` — your roadmap, already on disk

Your 7.2.0-rc7 tree ships 16 Rust samples. Look at what they are:

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

That table is worth sitting with. **The entire first half of this roadmap is present in that directory as
working reference code.** When you write your PCI driver in Month 4, `rust_driver_pci.rs` is the example
you will read first. Today you just load the simplest one; over the next five months you will work
through most of them.

And `rust/kernel/` has **78 modules** — the abstraction layer you will spend 18 months inside.

### 10. Reading a Rust kernel module

`rust_minimal.rs` is about 30 lines and it will look strange, so know what to expect:

- **No `main()`.** A module is a library the kernel loads, not a program.
- **`module! { ... }`** is a macro that generates all the plumbing C expects: the metadata section, the
  init and exit function pointers, `MODULE_LICENSE`, and so on. In C you would write these by hand.
- **`init()` returns `Result`.** Failure is a value, not a convention. Return an error and the kernel
  cleanly refuses to load the module.
- **`Drop` is the exit path.** Where a C module has an explicit `module_exit()` function, Rust runs your
  destructor. Yesterday's teardown ordering is enforced by the language.
- **`#![no_std]` is implied.** No `println!`, no `String` from `std`, no heap unless you ask fallibly.

You will not fully understand it today. Recognising the shape is the goal.

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

Install the version your tree names, plus the components:

```bash
cd "$LINUX_TREE"
RUSTC_VER="$(scripts/min-tool-version.sh rustc)"     # 1.85.0
echo "installing rustc $RUSTC_VER"

rustup toolchain install "$RUSTC_VER"
rustup component add rust-src rustfmt clippy --toolchain "$RUSTC_VER"

# Pin this tree to that toolchain. Now every rustc invocation here uses it,
# regardless of what your global default becomes later.
rustup override set "$RUSTC_VER"

rustc --version && cargo --version
```

> **Minimum vs latest.** `1.85.0` is the floor, and a newer stable will often work. Start with the floor
> because it is the version guaranteed to be tested against your tree. If you later want newer, change
> it and let `rustavailable` arbitrate — it will tell you plainly if the answer is no.

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
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/check_day4.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_1/record_env.sh
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

**Next:** M1W1D5 — Developer Ergonomics & Upstream Plumbing. `git send-email` verified end to end, `b4`,
`checkpatch.pl`, `get_maintainer.pl`, and subscribing to the lists. Less glamorous than today, and it is
what makes contribution possible at all — Week 0 ends with your lab genuinely complete.

# Activity — Hello World From Inside Your Own Rust Kernel

> **Goal:** get *your own* Rust code — not a copied sample — printing from inside a kernel you
> compiled, two different ways, and understand why the two ways differ.
>
> **When:** after Day 4. Day 4 gets `CONFIG_RUST=y` and proves the upstream samples load. This
> activity is the first code in this repo that is yours.
>
> **Time:** 30 minutes of typing, plus two kernel builds. The first Rust build is the slow one.

---

## Contents

- [The Two Things We Are Doing](#the-two-things-we-are-doing)
- [Files This Activity Uses](#files-this-activity-uses)
- [Two Gotchas, Verified](#two-gotchas-verified)
- [Part 0 — Prerequisites](#part-0--prerequisites)
- [Part 1 — Build It As A Module](#part-1--build-it-as-a-module)
- [Part 2 — Build It Into The Kernel](#part-2--build-it-into-the-kernel)
- [Side By Side](#side-by-side)
- [Experiments Worth Running](#experiments-worth-running)
- [Putting The Tree Back](#putting-the-tree-back)
- [Journal](#journal)
- [Troubleshooting](#troubleshooting)

---

## The Two Things We Are Doing

The same single source file gets built two ways, and the difference is the entire lesson.

**Part 1 — as a loadable module (`=m`).** Kbuild produces `hello_rust.ko`, a separate file. Nothing
happens until you `insmod` it. `init` runs on load, `Drop` runs on `rmmod`. This is the normal
development loop, because you can load and unload repeatedly without rebooting.

**Part 2 — compiled into the kernel (`=y`).** The code goes *inside* `vmlinux`. There is no `.ko`
at all. `init` runs during boot as an initcall, so the greeting appears in the boot log before you
ever reach a shell — this is what you were picturing when you asked about "a custom Rust kernel that
prints hello world". And because built-in code can never be unloaded, **`Drop` never runs.**

The module reports which one it is at runtime, using the `!cfg!(MODULE)` trick from
`rust_minimal.rs`. `MODULE` is a compile-time flag the build system defines only for loadable
modules, so the compiler folds it to a constant — zero runtime cost, and the same source tells you
how it was built.

---

## Files This Activity Uses

Already created for you, under version control in the repo:

| File | Role |
|---|---|
| `codes/Month_1/Week_1/Day_4/hello_rust.rs` | The module. Yours to edit — start by putting your real name in `authors` |
| `codes/Month_1/Week_1/Day_4/install_hello.sh` | Copies it into the tree and adds the Kconfig + Makefile entries. Idempotent |

Kernel Rust has thin support for out-of-tree modules, so we develop **in-tree**: the source goes
into `samples/rust/` and Kbuild treats it exactly like an upstream sample. This is what
`codes/README.md` recommends, and it is why `install_hello.sh` exists — it touches three files
inside `$LINUX_TREE`:

```text
samples/rust/hello_rust.rs   copied in, CRLF stripped
samples/rust/Kconfig         one new `config SAMPLE_RUST_HELLO` block
samples/rust/Makefile        one new obj-$(CONFIG_SAMPLE_RUST_HELLO) line
```

Those live in the kernel tree, which is not version controlled by you — so
[Putting The Tree Back](#putting-the-tree-back) matters.

---

## Two Gotchas, Verified

Both of these were confirmed on this machine, not guessed. They will waste your evening if you skip
them.

**1. Run everything from an interactive shell.** Ubuntu's default `~/.bashrc` returns early for
non-interactive shells, so `$LINUX_TREE` and `$LKDRUST_REPO` are simply *not set* if you run these
commands from an editor task, a script, or `bash -lc`. `sync_from_repo.sh` fails immediately with
`LKDRUST_REPO: Set LKDRUST_REPO to your LKD_RUST folder`. Open a normal terminal and check first:

```bash
echo "$LINUX_TREE"
echo "$LKDRUST_REPO"
```

Both must print a path. If they are empty, open a new terminal.

**2. Sync before you run anything.** The repo is on NTFS, so these files have Windows CRLF line
endings, and a shell script with `\r` at the end of every line does not merely misbehave — it fails
to parse:

```text
install_hello.sh: line 27: syntax error near unexpected token `$'do\r''
```

`sync_from_repo.sh` strips CRLF and restores the executable bit, which is exactly why it exists.
**Always run the synced copy under `~/LKD_RUST/codes/`, never the one on `/mnt/c/`.**

---

## Part 0 — Prerequisites

```bash
# Pull the repo's code into WSL, normalising line endings on the way in
bash ~/LKD_RUST/codes/sync_from_repo.sh
```

Then Day 4 proper, if you have not done it yet:

```bash
# Installs the toolchain the TREE asks for, adds rust-src and bindgen, pins the
# toolchain to this tree, and ends with the gate: make LLVM=1 rustavailable
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/install_rust_toolchain.sh

# Turns on CONFIG_RUST + the samples, without destroying Day 3's virtio/9p options
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/enable_rust_config.sh
```

Build, and prove an upstream sample loads before introducing your own code — one variable at a time:

```bash
cd "$LINUX_TREE"
time make LLVM=1 -j"$(nproc)"

vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -8; rmmod rust_minimal'
```

If `rust_minimal` loads and prints, the lab is good and anything that breaks from here is *your*
code. That is worth the extra five minutes.

> **Expect this build to be slow.** It is the first one compiling `core`, `alloc`, and the `kernel`
> crate from source, plus running `bindgen` over the C headers. Watch for `RUSTC L core.o` and
> `BINDGEN rust/bindings/bindings_generated.rs` — lines you have never seen before.

---

## Part 1 — Build It As A Module

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/install_hello.sh --module

cd "$LINUX_TREE"
make LLVM=1 -j"$(nproc)"
```

The line to watch for is your own code going through `rustc`:

```text
RUSTC [M] samples/rust/hello_rust.o
```

Then load it, read the log, and unload it:

```bash
vng --exec 'insmod samples/rust/hello_rust.ko; dmesg | tail -15; rmmod hello_rust; dmesg | tail -3'
```

Expected, roughly:

```text
hello_rust: =====================================
hello_rust:   Hello, World! From Rust, in ring 0.
hello_rust: =====================================
hello_rust: running as: a loadable module (.ko)
hello_rust:   hello 1 of 3
hello_rust:   hello 2 of 3
hello_rust:   hello 3 of 3
hello_rust: recorded 3 greetings on the kernel heap
```

and on unload:

```text
hello_rust: goodbye — greetings I recorded: [1, 2, 3]
hello_rust: hello_rust unloaded; the allocation above is freed as this struct drops
```

**That second block is the part to appreciate.** You never wrote a `kfree`. The `KVec` was released
because the struct was dropped, and the ordering was correct because the compiler guaranteed it.
The C equivalent needs an explicit free in the exit path, and forgetting it is a classic leak.

---

## Part 2 — Build It Into The Kernel

Same source, one config change:

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_4/install_hello.sh --builtin

cd "$LINUX_TREE"
make LLVM=1 -j"$(nproc)"
```

Note the build line changes from `[M]` to no marker, because it is no longer a module:

```text
RUSTC   samples/rust/hello_rust.o
```

Now **do not load anything.** Just boot:

```bash
vng --exec 'dmesg | grep -A6 "Hello, World"'
```

Your greeting is already in the boot log. Nothing insmod'd it — it ran as an initcall while the
kernel was bringing itself up. This is, precisely, a custom Rust kernel that says hello on boot.

Two things to confirm, because they are the payoff:

```bash
# cfg!(MODULE) is now false, so the module knows it is built in
vng --exec 'dmesg | grep "running as:"'

# It is not a module at all, so there is nothing to unload
vng --exec 'lsmod | grep hello_rust || echo "not a module — it is part of the kernel"'

# And therefore no goodbye, ever
vng --exec 'dmesg | grep goodbye || echo "no Drop: built-in code is never unloaded"'
```

---

## Side By Side

| | `=m` (module) | `=y` (built-in) |
|---|---|---|
| Artifact produced | `samples/rust/hello_rust.ko` | inside `vmlinux`, no separate file |
| When `init` runs | on `insmod` | during boot, as an initcall |
| When `Drop` runs | on `rmmod` | **never** |
| Shows in `lsmod` | yes | no |
| `!cfg!(MODULE)` reports | `a loadable module (.ko)` | `compiled into vmlinux` |
| Parameter name | `greetings` | `hello_rust.greetings` |
| How to set the parameter | `insmod hello_rust.ko greetings=5` | kernel command line |
| Iteration speed | fast — reload without rebooting | slow — rebuild and reboot each time |

That parameter row is a real detail, not trivia: the `module!` macro registers the parameter under a
different name depending on how you built it, because a built-in parameter has to be reachable from
the kernel command line where names must be globally unique.

---

## Experiments Worth Running

**The parameter, and the clamp.** `hello_rust.rs` clamps `greetings` to `1..=10`, because an
unclamped value taken from outside would drive the loop into an allocation storm. Prove it:

```bash
# module build
vng --exec 'insmod samples/rust/hello_rust.ko greetings=7;    dmesg | tail -14'
vng --exec 'insmod samples/rust/hello_rust.ko greetings=9999; dmesg | tail -14'   # still 10
vng --exec 'insmod samples/rust/hello_rust.ko greetings=-5;   dmesg | tail -14'   # still 1
```

For the built-in build, the parameter comes from the kernel command line instead — `vng -a` appends
boot options:

```bash
vng -a hello_rust.greetings=8 --exec 'dmesg | grep -A10 "Hello, World"'
```

**Read the metadata you declared.** Everything in the `module!` block ends up in the ELF:

```bash
modinfo samples/rust/hello_rust.ko
```

**Break it on purpose, and read the error.** Change `license: "GPL"` to `"Proprietary"`, rebuild,
and try to load it. The failure teaches you what that field actually does. Then put it back.

**Prove the toolchain is fussy.** In `init`, add `let x: Option<i32> = None; x.unwrap();` and
rebuild. It compiles. Load it and watch what a Rust panic does to a kernel. Then delete it, and
re-read why `UPSTREAM.md` calls `unwrap()` an instant reject.

---

## Putting The Tree Back

`install_hello.sh` modified three files in `$LINUX_TREE`, which is upstream Linux and not yours.
Before you `git pull` the kernel or start Day 5, get it clean:

```bash
cd "$LINUX_TREE"
git status --short                 # see exactly what you changed

git checkout samples/rust/Kconfig samples/rust/Makefile
rm -f samples/rust/hello_rust.rs
scripts/config --disable SAMPLE_RUST_HELLO
make LLVM=1 olddefconfig
```

Your source survives this, because the copy of record lives in the repo at
`codes/Month_1/Week_1/Day_4/hello_rust.rs`. Re-running `install_hello.sh` puts it back whenever you
want it. **That asymmetry is the workflow:** the kernel tree is disposable, the repo is not.

If you edited `hello_rust.rs` inside the tree rather than in the repo, push it back before you clean:

```bash
cp "$LINUX_TREE/samples/rust/hello_rust.rs" ~/LKD_RUST/codes/Month_1/Week_1/Day_4/
bash ~/LKD_RUST/codes/sync_to_repo.sh
```

---

## Journal

Worth recording in `journal/`, and the version numbers in `_internal/SETUP_LOG.md`:

- Wall time for the first Rust-enabled build, and for the incremental rebuild after only
  `hello_rust.rs` changed. The ratio is what tells you whether your loop is healthy
- The exact `rustc` and `bindgen` versions that worked
- The full `dmesg` output from both variants, pasted, not summarised
- Every error you hit and what fixed it

Then answer these in your own words, without notes:

1. Why does `Drop` never run in the built-in build? What would it even mean for it to run?
2. `cfg!(MODULE)` is evaluated at compile time. So how can one source file report two different
   answers?
3. Why does `push` take `GFP_KERNEL` when `Vec::push` in userspace takes nothing?
4. You never wrote a `kfree`. What exactly guarantees the allocation is released, and what
   guarantees it happens *after* the `goodbye` line is printed?
5. Why did we develop in-tree instead of writing an out-of-tree `Makefile`?

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `syntax error near unexpected token $'do\r'` | Running the `/mnt/c/` copy with CRLF endings | Run `sync_from_repo.sh`, then use the copy under `~/LKD_RUST/codes/` |
| `LKDRUST_REPO: Set LKDRUST_REPO...` | Non-interactive shell skipped `~/.bashrc` | Use a normal terminal; verify with `echo "$LKDRUST_REPO"` |
| `install_hello.sh` says `CONFIG_RUST is not enabled` | Day 4 not finished | Run `install_rust_toolchain.sh`, then `enable_rust_config.sh` |
| `CONFIG_SAMPLE_RUST_HELLO did not survive olddefconfig` | `CONFIG_SAMPLES_RUST` is off, so the whole `if` block is unreachable | `scripts/config --enable SAMPLES_RUST && make LLVM=1 olddefconfig` |
| Build says nothing about `hello_rust` | Makefile line missing, or config is `n` | `grep HELLO samples/rust/Makefile .config` |
| `insmod: ERROR: could not insert module: Invalid module format` | The `.ko` was built against a different tree than you booted | Rebuild and re-run `vng` from the same tree; compare `modinfo` vermagic to `uname -r` |
| `insmod` says `Operation not permitted` after a license edit | Non-GPL modules cannot use `EXPORT_SYMBOL_GPL` symbols | Set `license: "GPL"` back |
| `vng` hangs or shows nothing | It wants a real TTY | Run it from your own terminal, not an editor task |
| Greeting count ignores your parameter | You are on the built-in build, where the name is `hello_rust.greetings` | Use `vng -a hello_rust.greetings=N` |

---

**Next:** Day 5 — developer ergonomics. Run `make LLVM=1 rust-analyzer` and then open
`hello_rust.rs` in your editor; you will get real completion on `kernel::` APIs, which changes how
much of the abstraction layer you can discover on your own.

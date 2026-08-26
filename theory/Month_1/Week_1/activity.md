# Activity — Write Your Own Rust Kernel Module, By Hand

> **Goal:** you type a Rust kernel module in vim, compile it into a kernel you built, boot it, and
> read your own words in `dmesg`. Then you make it greet you during boot instead.
>
> **When:** after Day 4 (`CONFIG_RUST=y` and the upstream samples load).
>
> **Time:** about 90 minutes, in four stages. **Stage 1 alone is ~20 minutes and ends with your code
> running** — do that much even if you stop there.

---

## Contents

- [How This Activity Works](#how-this-activity-works)
- [Part 0 — Check You Are Ready](#part-0--check-you-are-ready)
- [Stage 1 — The Smallest Module That Works](#stage-1--the-smallest-module-that-works)
- [Stage 2 — Take Input From Outside](#stage-2--take-input-from-outside)
- [Stage 3 — Allocate Memory, And Give It Back](#stage-3--allocate-memory-and-give-it-back)
- [Stage 4 — Put It Inside The Kernel Itself](#stage-4--put-it-inside-the-kernel-itself)
- [Stage 5 — Save Your Work](#stage-5--save-your-work)
- [Break It On Purpose](#break-it-on-purpose)
- [Side By Side](#side-by-side)
- [Putting The Tree Back](#putting-the-tree-back)
- [Journal](#journal)
- [Troubleshooting](#troubleshooting)

---

## How This Activity Works

**You type every line yourself.** Not because typing is magic, but because the module grows in four
stages and each stage adds exactly one idea. You build and boot after every stage, so when something
breaks you know precisely which five lines caused it. That is the actual skill.

**You edit directly in the kernel tree**, at `$LINUX_TREE/samples/rust/hello_rust.rs`, not in the
repo. Three reasons:

- `make` picks it up immediately — no copy step between editing and building
- vim on ext4 gives you LF line endings for free, so the CRLF problem never arises
- it is what `codes/README.md` recommends for kernel Rust, because out-of-tree Rust module support
  is still thin

The repo copy comes at the end, in [Stage 5](#stage-5--save-your-work). The kernel tree is
disposable; the repo is the source of record.

> **There is a finished version** at `codes/Month_1/Week_1/Day_4/hello_rust.rs`. **Do not open it
> yet.** Use it at the end to diff against what you wrote — the differences are the interesting part.
> Reading it first turns a build into a copy.

---

## Part 0 — Check You Are Ready

Open a normal terminal. Not an editor task — Ubuntu's `~/.bashrc` returns early for non-interactive
shells, so your environment variables will be missing.

```bash
echo "$LINUX_TREE"          # must print a path
cd "$LINUX_TREE"
grep '^CONFIG_RUST=y' .config
```

That `grep` must print `CONFIG_RUST=y`. If it prints nothing, Day 4 is not finished — run
`install_rust_toolchain.sh` and `enable_rust_config.sh` first, and come back.

Then confirm the lab still works end to end, using a module you did not write:

```bash
vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -5; rmmod rust_minimal'
```

If that prints the sample's messages, everything below is your code's fault when it breaks. Worth
twenty seconds.

---

## Stage 1 — The Smallest Module That Works

### 1a. Create the file

```bash
cd "$LINUX_TREE"
vim samples/rust/hello_rust.rs
```

Type this. It is 18 lines and every one earns its place:

```rust
// SPDX-License-Identifier: GPL-2.0

//! My first Rust kernel module.

use kernel::prelude::*;

module! {
    type: HelloRust,
    name: "hello_rust",
    authors: ["Your Name"],
    description: "My first Rust kernel module",
    license: "GPL",
}

struct HelloRust;

impl kernel::Module for HelloRust {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("Hello, World! From Rust, in ring 0.\n");
        Ok(HelloRust)
    }
}
```

What you just wrote, in the order it matters:

- **`// SPDX-License-Identifier`** — mandatory first line in every kernel source file. `checkpatch.pl`
  rejects a patch without it.
- **`//!`** — an *inner* doc comment, documenting the file itself. Three slashes would document the
  next item instead.
- **`use kernel::prelude::*`** — there is no `std` here. This is where `module!`, `pr_info!`, and
  `Result` come from.
- **`module!`** — a macro that generates the C glue: the `init_module` symbol `insmod` looks for, and
  the `.modinfo` section `modinfo` reads. Without it the kernel has no way to find your code.
- **`license: "GPL"`** — load-bearing, not paperwork. Any other value and most of the kernel API
  becomes unavailable to you.
- **`struct HelloRust;`** — a unit struct, no fields yet. `samples/rust/rust_print_main.rs` does
  exactly this, so you are in good company.
- **`Result<Self>`** — the *kernel's* Result. Returning `Err` makes `insmod` fail with that errno.
- **`\n`** — the kernel log does not add one. Leave it off and your next message continues the same
  line.

Save and quit: `:wq`

### 1b. Tell Kconfig your module exists

```bash
vim samples/rust/Kconfig
```

Find the last line, `endif # SAMPLES_RUST`, and insert this **above** it — your entry has to be
inside the `if SAMPLES_RUST` block or it can never be selected:

```text
config SAMPLE_RUST_HELLO
	tristate "My hello world module"
	help
	  My first hand-written Rust kernel module.

	  If unsure, say N.
```

`tristate` is what gives you the three-way choice: `n` (don't build), `m` (loadable module), or `y`
(compiled into the kernel). Stage 4 is entirely about the difference between the last two.

> **On indentation:** the file uses tabs, so match it. In vim, `Ctrl-V` then `Tab` inserts a literal
> tab even if you have `expandtab` set. That said, Kconfig parses spaces fine too — do not lose ten
> minutes here.

### 1c. Tell Kbuild to compile it

```bash
vim samples/rust/Makefile
```

Add one line at the end:

```make
obj-$(CONFIG_SAMPLE_RUST_HELLO)		+= hello_rust.o
```

Read that as: *if* `CONFIG_SAMPLE_RUST_HELLO` is set, add `hello_rust.o` to the build. This is a
variable assignment, not a recipe, so spaces are fine here — the tab rule that bites people in
Makefiles applies to command lines under a target, which this is not.

Note it says `.o`, not `.rs`. Kbuild derives the source name from the object name.

### 1d. Turn it on and build

```bash
scripts/config --module SAMPLE_RUST_HELLO
make LLVM=1 olddefconfig
grep SAMPLE_RUST_HELLO .config
```

You want `CONFIG_SAMPLE_RUST_HELLO=m`. `scripts/config` only edits text; `olddefconfig` is what makes
Kconfig re-read your new entry and resolve it. If the symbol vanishes, `CONFIG_SAMPLES_RUST` is off.

```bash
make LLVM=1 -j"$(nproc)"
```

Because Day 4 already built this tree, this is incremental — a minute or two, not twenty. Watch for
your line:

```text
  RUSTC [M] samples/rust/hello_rust.o
  LD [M]  samples/rust/hello_rust.ko
```

### 1e. Run it

```bash
vng --exec 'insmod samples/rust/hello_rust.ko; dmesg | tail -3; rmmod hello_rust'
```

```text
hello_rust: Hello, World! From Rust, in ring 0.
```

**That is your code, in a kernel you compiled, in a VM.** Stop and appreciate it — every remaining
stage is a variation on this loop.

Also look at what `module!` generated for you:

```bash
modinfo samples/rust/hello_rust.ko
```

Every field you typed is in there, plus a `vermagic` string that ties the module to this exact
kernel build.

---

## Stage 2 — Take Input From Outside

Right now the module does the same thing every time. Let's let the loader choose.

```bash
vim samples/rust/hello_rust.rs
```

Add a `params` block inside `module!`, after `license`:

```rust
    license: "GPL",
    params: {
        greetings: i64 {
            default: 3,
            description: "How many times to say hello (clamped to 1..=10)",
        },
    },
```

And replace the single `pr_info!` in `init` with:

```rust
        // Never trust a parameter. This is an i64 from outside; unclamped, a large value
        // would spin the kernel log for a very long time.
        let times = (*module_parameters::greetings.value()).clamp(1, 10);

        pr_info!("Hello, World! From Rust, in ring 0.\n");
        for i in 1..=times {
            pr_info!("  hello {} of {}\n", i, times);
        }
```

Two things worth understanding before you rebuild:

`module_parameters` is a module the `module!` macro generated — you never wrote it. `.value()`
returns a *reference*, hence the `*`, because for writable parameters the value can change at
runtime.

The `.clamp(1, 10)` is the habit to build now. Every value that crosses into the kernel from outside
is untrusted input, and "outside" includes a module parameter.

```bash
make LLVM=1 -j"$(nproc)"
vng --exec 'insmod samples/rust/hello_rust.ko; dmesg | tail -6'
vng --exec 'insmod samples/rust/hello_rust.ko greetings=7; dmesg | tail -10'
vng --exec 'insmod samples/rust/hello_rust.ko greetings=9999; dmesg | tail -13'
```

The last one still prints ten. Your clamp works, and you just tested a hostile input path.

---

## Stage 3 — Allocate Memory, And Give It Back

This is the stage that shows you what kernel Rust is actually for.

```bash
vim samples/rust/hello_rust.rs
```

Give the struct a field:

```rust
struct HelloRust {
    greeted: KVec<i32>,
}
```

Build the vector inside the loop, and return it:

```rust
        let mut greeted = KVec::new();
        for i in 1..=times {
            pr_info!("  hello {} of {}\n", i, times);
            greeted.push(i as i32, GFP_KERNEL)?;
        }

        pr_info!("recorded {} greetings on the kernel heap\n", greeted.len());

        Ok(HelloRust { greeted })
```

Then add this at the end of the file, after the closing brace of the `impl kernel::Module` block:

```rust
impl Drop for HelloRust {
    fn drop(&mut self) {
        pr_info!("goodbye — greetings I recorded: {:?}\n", self.greeted);
    }
}
```

**Look hard at `greeted.push(i as i32, GFP_KERNEL)?`.** In userspace it would be `greeted.push(i)`.
Two things were added:

- **`GFP_KERNEL`** tells the allocator it is allowed to sleep waiting for memory. True here, because
  module init runs in normal process context. In an interrupt handler you would need `GFP_ATOMIC`,
  and getting it wrong is a real bug. There is no default because there is no safe default.
- **`?`** exists because kernel allocations genuinely fail and the kernel cannot respond by aborting.
  On failure this returns `Err(ENOMEM)` and `insmod` fails cleanly. Nothing panics — and kernel Rust
  must never panic.

And notice what is **not** in your `Drop`: any `kfree`. The `KVec` is released because the struct is
dropped. In C you would write that free by hand in the exit path, and forgetting it is one of the
most common kernel leaks there is.

```bash
make LLVM=1 -j"$(nproc)"
vng --exec 'insmod samples/rust/hello_rust.ko; dmesg | tail -6; rmmod hello_rust; dmesg | tail -2'
```

```text
hello_rust: recorded 3 greetings on the kernel heap
hello_rust: goodbye — greetings I recorded: [1, 2, 3]
```

Reading `self.greeted` inside `drop` is safe, and it is worth knowing why: the body of `drop` runs
*before* the struct's fields are dropped.

---

## Stage 4 — Put It Inside The Kernel Itself

So far you have built a `.ko` you load by hand. Now compile the identical source *into* `vmlinux`, so
it runs during boot.

First, make the module able to tell which it is. Add this to `init`, right after the `let times` line:

```rust
        pr_info!(
            "running as: {}\n",
            if !cfg!(MODULE) {
                "compiled into vmlinux (this line printed during boot)"
            } else {
                "a loadable module (.ko)"
            }
        );
```

`cfg!(MODULE)` is a **compile-time** constant — the build system defines `MODULE` only for loadable
modules, and the compiler folds this to a literal `true` or `false`. Zero runtime cost, and the same
source file reports two different answers depending on how it was built.

Now change one config value — no other code changes:

```bash
scripts/config --enable SAMPLE_RUST_HELLO      # =y instead of =m
make LLVM=1 olddefconfig
grep SAMPLE_RUST_HELLO .config                 # expect =y
make LLVM=1 -j"$(nproc)"
```

Notice the build line lost its `[M]`, because it is no longer a module:

```text
  RUSTC   samples/rust/hello_rust.o
```

Now **do not load anything.** Just boot:

```bash
vng --exec 'dmesg | grep -A6 "Hello, World"'
```

Your greeting is already there. Nothing insmod'd it — it ran as an initcall while the kernel brought
itself up. **This is a custom Rust kernel that says hello on boot**, which is what you asked for at
the start.

Three things to confirm, because they are the payoff:

```bash
# cfg!(MODULE) is false now
vng --exec 'dmesg | grep "running as:"'

# there is no module, so there is nothing to unload
vng --exec 'lsmod | grep hello_rust || echo "not a module — it is part of the kernel"'

# and therefore no goodbye, ever
vng --exec 'dmesg | grep goodbye || echo "no Drop: built-in code is never unloaded"'
```

That last one is the real lesson. **Built-in code is never unloaded, so its `Drop` never runs.** Sit
with that for a moment — it means a built-in driver's cleanup path is dead code, and any resource it
holds is held until power off.

The parameter moved too. Built in, there is no `insmod` to pass it to, so it comes from the kernel
command line under a namespaced name:

```bash
vng -a hello_rust.greetings=8 --exec 'dmesg | grep -A10 "Hello, World"'
```

---

## Stage 5 — Save Your Work

Your module currently exists only in a disposable kernel tree. Put it under version control.

**Diff against the reference first**, while both still exist — this is the payoff for having typed it
yourself:

```bash
diff "$LINUX_TREE/samples/rust/hello_rust.rs" \
     "$LKDRUST_REPO/codes/Month_1/Week_1/Day_4/hello_rust.rs"
```

Read every difference and decide, for each one, whether yours or the reference's is better. Some of
mine are just wordier comments. If you find something you did better, keep yours — that judgement is
the point.

Then make your version the one of record:

```bash
cp "$LINUX_TREE/samples/rust/hello_rust.rs" \
   "$LKDRUST_REPO/codes/Month_1/Week_1/Day_4/hello_rust.rs"

cd "$LKDRUST_REPO"
git diff codes/Month_1/Week_1/Day_4/hello_rust.rs    # exactly what you changed
```

Then commit. This is the first kernel code you wrote yourself; the message should say so. The old
version is not lost either way — it is in git history.

`install_hello.sh` in that same directory automates everything you just did by hand — the copy, the
Kconfig block, the Makefile line, the config switch. Now that you have done it manually once, use the
script whenever you want to re-apply your module to a fresh tree.

---

## Break It On Purpose

Every one of these teaches something a success path cannot. Do at least two.

**Make the license wrong.** Change `license: "GPL"` to `"Proprietary"`, rebuild as `=m`, and load it.
The failure tells you what that field actually does.

**Return an error from init.** Put `return Err(EINVAL);` as the first line of `init`. Rebuild, load,
and watch `insmod` fail with that exact errno. This is how a real driver refuses to probe.

**Panic on purpose.** Add `let x: Option<i32> = None; x.unwrap();` to `init`. It *compiles* — the
compiler will not save you. Load it and watch what a Rust panic does inside a kernel. Then delete it,
and re-read why `UPSTREAM.md` calls `unwrap()` an instant reject in review.

**Forget the newline.** Drop the `\n` from one `pr_info!` and look at the mangled log output.

**Load the wrong build.** Keep the old `.ko`, rebuild the kernel with any change, boot the new one,
and try to `insmod` the stale module. The `Invalid module format` error and the `vermagic` mismatch
behind it will find you again for the next eighteen months — meet it now.

---

## Side By Side

| | `=m` (module) | `=y` (built-in) |
|---|---|---|
| Artifact | `samples/rust/hello_rust.ko` | inside `vmlinux`, no separate file |
| Build line | `RUSTC [M] ...` | `RUSTC ...` |
| `init` runs | on `insmod` | during boot, as an initcall |
| `Drop` runs | on `rmmod` | **never** |
| In `lsmod` | yes | no |
| Parameter name | `greetings` | `hello_rust.greetings` |
| How to set it | `insmod hello_rust.ko greetings=5` | `vng -a hello_rust.greetings=5` |
| Iteration speed | fast — reload, no reboot | slow — rebuild and reboot |

---

## Putting The Tree Back

You edited three files in upstream Linux. Before Day 5 or any `git pull` of the kernel, get it clean:

```bash
cd "$LINUX_TREE"
git status --short                 # exactly what you touched

git checkout samples/rust/Kconfig samples/rust/Makefile
rm -f samples/rust/hello_rust.rs
scripts/config --disable SAMPLE_RUST_HELLO
make LLVM=1 olddefconfig
```

This is safe **only because you did Stage 5 first.** Your source lives in the repo now, and
`install_hello.sh` puts it back on demand. That asymmetry is the workflow: the kernel tree is
scratch space, the repo is what you keep.

---

## Journal

Record in `journal/`, and the versions in `_internal/SETUP_LOG.md`:

- Incremental rebuild time after changing only `hello_rust.rs`. This is your real loop speed
- The `dmesg` output from Stages 3 and 4, pasted whole
- Every error you hit and what fixed it — especially the deliberate ones

Then answer these without looking anything up:

1. Why does `Drop` never run in the built-in build? What would it even *mean* for it to run?
2. `cfg!(MODULE)` is evaluated at compile time. So how does one source file report two answers?
3. Why does `push` need `GFP_KERNEL` when userspace `Vec::push` needs nothing?
4. You wrote no `kfree`. What guarantees the memory is freed, and what guarantees it happens *after*
   the `goodbye` line prints?
5. What is `vermagic` for, and what would go wrong without it?

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `$LINUX_TREE` is empty | Non-interactive shell skipped `~/.bashrc` | Use a normal terminal |
| `grep '^CONFIG_RUST=y'` prints nothing | Day 4 unfinished | `install_rust_toolchain.sh`, then `enable_rust_config.sh` |
| Build never mentions `hello_rust` | Makefile line missing, or config is `n` | `grep HELLO samples/rust/Makefile .config` |
| `CONFIG_SAMPLE_RUST_HELLO` vanishes after `olddefconfig` | Your Kconfig block landed *after* `endif`, or `SAMPLES_RUST` is off | Move it above `endif # SAMPLES_RUST`; `scripts/config --enable SAMPLES_RUST` |
| `error[E0433]: failed to resolve: use of undeclared crate or module` | Missing `use kernel::prelude::*;` | Add it |
| `expected 1 argument, found 2` on `push` | Reading userspace `Vec` docs | Kernel `push` takes a GFP flag: `push(v, GFP_KERNEL)?` |
| `the ? operator can only be used in a function that returns Result` | `?` outside `init` | Only use `?` where the return type is `Result` |
| `insmod: Invalid module format` | `.ko` built against a different tree than you booted | Rebuild, then `vng` from that same tree; compare `modinfo` vermagic with `uname -r` |
| `insmod: Operation not permitted` | Non-GPL license string | Set `license: "GPL"` back |
| `vng` hangs or prints nothing | It wants a real TTY | Run it in your own terminal, not an editor task |
| Parameter ignored in the `=y` build | Built-in params are namespaced | `vng -a hello_rust.greetings=N` |
| Nothing in `dmesg` at all | Log level filtering | `vng --exec 'dmesg -n 8; ...'` |

---

**Next:** Day 5 — run `make LLVM=1 rust-analyzer`, then reopen `hello_rust.rs` in your editor. You
will get real completion on `kernel::` APIs, which changes how much of the abstraction layer you can
discover by exploring rather than by reading.

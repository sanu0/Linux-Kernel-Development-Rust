# M1W1D2 — Clone and Build Mainline ✅ COMPLETED

> **Completed:** 2026-08-15. Kernel **7.2.0-rc7** at `3eb40771c00a`, full history, 4 remotes.
> `defconfig` = 5,473 lines / 1,631 built-in / 15 modules. **0 warnings.**
> `vmlinux` 52 MB, `bzImage` 15 MB. Second build **31.8 s** with a ~99.9% ccache hit rate,
> 100% of them *direct* hits.
>
> *Still to fill in: first-build wall time in the table below.*

> **Goal:** get the Linux source onto your machine, understand what you are looking at, and compile
> the whole kernel for the first time. By the end of today you have a `bzImage` you built yourself and
> a build time you have written down. You will **not** boot it — that is tomorrow.
>
> **Time:** 2-3 hours, most of it waiting on the clone and the build.
>
> **Why this matters:** this is the artifact everything else acts on. More importantly, today is when
> the kernel stops being an abstraction and becomes a directory you can `cd` into. Almost nobody who
> talks confidently about "the kernel" has ever compiled one. After today you have, and the difference
> in how you read discussions about it is immediate.

---

## Today's Checklist

- [x] Clone mainline Linux into `$LINUX_TREE`
- [x] Add the remotes you will need later: `linux-next`, `stable`, `rust-for-linux`
- [x] Understand what full history buys you, and why a shallow clone is a trap for kernel work
- [x] Learn the top-level layout well enough to navigate without searching
- [x] `make defconfig` — and know what a defconfig actually is
- [x] `make -j18` — time it, watch the stages, read the output
- [x] Learn `make menuconfig` navigation and the `/` search
- [x] Confirm ccache took effect, and see the difference on a second build
- [x] Journal: build time, disk used, warnings, and what surprised you

---

## Concepts

### 1. The scale of what you are cloning

Linux is roughly **40 million lines** across about 90,000 files, with over 1.3 million commits and
more than 20 years of recorded history. The `.git` directory alone is around 5 GB — larger than the
working tree.

Two things follow from that:

- **The clone will take a while.** It is a one-time cost, and it is worth paying properly.
- **You will never read it all, and that is fine.** Nobody has. Kernel competence is not "knowing the
  kernel" — it is being able to find the 200 lines that matter to your problem, quickly. Today is
  partly about installing that navigation instinct.

### 2. Why you want full history (and why shallow is a trap)

`git clone --depth=1` finishes in a fraction of the time and gives you a working tree that builds
perfectly. It is still the wrong choice here, because git history is a **kernel development tool**, not
an archive:

| Operation | What it gives you | Needs history? |
|---|---|---|
| `git log -- <path>` | how this code evolved and why | yes |
| `git blame -L 100,120 <file>` | who wrote this line and in which commit | yes |
| `git show <sha>` | the reasoning in the commit message of the change that introduced a bug | yes |
| `git bisect` | which of 10,000 commits broke your boot | yes |
| `Fixes:` tags | the 12-char SHA of the commit you are fixing — mandatory in bug-fix patches | yes |
| `git describe` | which release a commit landed in | yes (tags) |

The commit message is often the *only* documentation for why a piece of code is shaped the way it is.
Cutting yourself off from it to save twenty minutes is a bad trade.

**If bandwidth genuinely forces your hand**, the modern middle ground is a **blobless partial clone**:

```bash
git clone --filter=blob:none <url>
```

That fetches every commit and tree — so `git log` and `git bisect` work fully — but downloads file
*contents* only on demand. `git blame` on old revisions will pause to fetch. It is a reasonable
compromise; a shallow clone is not.

### 3. Trees and remotes: there is no single "the kernel"

You have been thinking of Linux as one repository. In practice it is a **hierarchy of trees**, and
knowing which is which is most of understanding how kernel development works.

| Tree | What it is | Why you want it |
|---|---|---|
| **mainline** (`torvalds/linux`) | Linus's tree. The definitive answer to "what is in Linux" | your baseline; what releases are cut from |
| **linux-next** | all subsystem trees merged together nightly, for integration testing | see conflicts and breakage *before* they reach mainline; check whether something is already queued |
| **stable** | released kernels plus backported fixes (6.12.y, 6.6.y, ...) | what distributions ship; where your bug fixes may need to land |
| **rust-for-linux** | the Rust-for-Linux development tree | Rust work often appears here before mainline |
| subsystem trees | `drm-misc-next`, `rust-next`, `char-misc-next`, `drm-rust-next`, ... | where you base a patch for that subsystem |

Adding remotes now costs nothing — a remote is just a URL until you fetch it. Doing it today means
that in Month 9 when someone says "that's already in drm-rust-next," you can check in five seconds.

An important asymmetry: **you fetch from these; you never push to them.** Your contribution leaves as
email, as we discussed. `git push` has no role in your relationship with upstream.

### 4. The top-level layout

Learn this well enough that you never guess. It is the map you will use every day for 18 months.

| Directory | What lives there |
|---|---|
| `arch/` | architecture-specific code: `arch/x86/`, `arch/arm64/`, `arch/riscv/`. Boot code, page tables, atomics, syscall entry |
| `drivers/` | **60%+ of the tree.** Every device driver. `drivers/gpu/`, `drivers/net/`, `drivers/block/`, `drivers/usb/` |
| `kernel/` | the core: scheduler (`kernel/sched/`), locking (`kernel/locking/`), RCU, workqueues, time, tracing |
| `mm/` | memory management: page allocator, slab, reclaim, page cache, mmap |
| `fs/` | the VFS plus every filesystem: `fs/ext4/`, `fs/btrfs/`, `fs/proc/` |
| `net/` | the network stack: TCP/IP, netfilter, sockets |
| `block/` | the block layer: blk-mq, request queues, I/O schedulers |
| `include/` | headers. `include/linux/` is internal API; **`include/uapi/` is the permanent userspace contract** |
| `rust/` | **your home for the next 18 months.** `rust/kernel/` (safe abstractions), `rust/bindings/` (generated), `rust/helpers/`, `rust/macros/` |
| `samples/` | example code, including `samples/rust/` — your first modules will look like these |
| `scripts/` | build machinery and dev tools: `checkpatch.pl`, `get_maintainer.pl`, Kconfig itself |
| `tools/` | userspace tools shipped with the kernel: `perf`, `tools/testing/kunit/`, `tools/memory-model/` |
| `Documentation/` | the official docs. `Documentation/rust/` and `Documentation/process/` are required reading |
| `lib/` | generic library code usable by any subsystem |
| `security/` | LSMs: SELinux, AppArmor |
| `virt/` | KVM |
| `MAINTAINERS` | **who owns what.** The file that tells you where to send a patch |

The shape to notice: `drivers/` dwarfs everything else. Linux is mostly device drivers, which is
exactly why Rust was introduced there first.

### 5. What a "defconfig" actually is

The kernel has roughly **20,000 configuration options**. You are never going to set those by hand, so
every architecture ships a sane baseline:

```text
arch/x86/configs/x86_64_defconfig      <- what `make defconfig` uses on x86_64
```

`make defconfig` copies that file's choices, resolves every dependency, and writes the result to
`.config` in your build directory. `.config` is the single file that determines what gets compiled.

The config targets worth knowing:

| Target | What it does | When to use |
|---|---|---|
| `defconfig` | the architecture's shipped baseline | your first build; a known-good starting point |
| `menuconfig` | interactive ncurses editor | exploring options, reading help text |
| `olddefconfig` | keep existing `.config`, accept defaults for anything new | **after editing `.config` by script, or after pulling new commits** |
| `localmodconfig` | only modules currently loaded on *this* machine | dramatically faster builds; brittle for kernel dev |
| `allmodconfig` | build everything possible as a module | catching compile errors across the whole tree |
| `allnoconfig` | say no to everything optional | minimal builds, bisecting |
| `savedefconfig` | write out a minimal config (only non-default choices) | sharing a config in a patch or bug report |

**The rule: never hand-edit `.config`.** It contains resolved dependencies, so changing one line can
silently contradict another. Use `menuconfig`, or `scripts/config`, and always follow up with
`make olddefconfig` so dependencies are re-resolved.

### 6. What `make` actually does

`make` has one job: turn ~30,000 separate `.c` files into **one bootable file**. It does that in
stages, and the two-to-six-letter word at the start of each output line tells you which stage you are
watching. They are not noise — when a build fails, that word tells you *where*.

#### The pipeline, in order

**Step 1 — Work out what to build.** Read `.config` and turn it into something the compiler can use.
You see `SYNC`.

**Step 2 — Build the tools needed to build the kernel.** The kernel ships small helper programs that
run on *your* machine during the build. They have to be compiled first. You see `HOSTCC`.

**Step 3 — Compile every source file, one at a time.** Each `.c` becomes a `.o` ("object file" — one
file's worth of machine code, not yet runnable). This is the bulk of the time and the thousands of
lines scrolling past. You see `CC`, and from Day 4, `RUSTC` for Rust files.

**Step 4 — Bundle each directory's objects together.** Rather than hand the linker 30,000 separate
files, each directory's `.o` files get packed into one `built-in.a`. You see `AR` (short for
"archive"). Purely organisational.

**Step 5 — Link everything into one program.** The linker takes all those bundles and stitches them
into a single file called **`vmlinux`** — the complete kernel. Linking is where "this function calls
that function" gets resolved into real addresses. You see `LD`.

**Step 6 — Check the loadable modules.** Anything set to `=m` in `.config` is built separately as a
`.ko` file. `MODPOST` verifies each module only calls functions the kernel actually exports — catching
at build time what would otherwise be a load-time failure.

**Step 7 — Add extra information into the kernel.** Two things get embedded here: the **symbol table**
(explained just below) and **BTF**, a compact description of every data structure, which is what tools
like `bpftrace` read to understand kernel types. You see `NM`, `KSYMS`, `BTF`.

**Step 8 — Shrink it and make it bootable.** `vmlinux` is large and not in the format a bootloader
expects. It gets stripped of anything unnecessary, compressed, and wrapped in a small boot header. The
result is **`bzImage`**. You see `OBJCOPY`, `GZIP`/`LZO`, and finally `BUILD`.

#### Quick lookup

| You see | It means |
|---|---|
| `SYNC` | reading your `.config` |
| `HOSTCC` | building a helper tool that runs on your machine |
| `CC` | compiling one kernel C file |
| `RUSTC` | compiling one kernel Rust file (from Day 4) |
| `AR` | bundling a directory's object files together |
| `LD` | linking — combining objects into one program |
| `MODPOST` | checking that modules only use symbols the kernel exports |
| `NM` / `KSYMS` | building the kernel's internal symbol table |
| `BTF` | embedding type information for eBPF tools |
| `OBJCOPY` / `GZIP` / `LZO` | stripping and compressing |
| `BUILD` | producing the final bootable `bzImage` |

#### Why `vmlinux` gets linked more than once

You will notice `.tmp_vmlinux1`, `.tmp_vmlinux2` go by, and the kernel apparently being linked two or
three times. That is deliberate, and the reason is a genuine chicken-and-egg problem.

**The goal:** when the kernel crashes, you want it to print

```text
BUG: kernel NULL pointer dereference at start_kernel+0x42
```

rather than

```text
BUG: kernel NULL pointer dereference at 0xffffffff81000042
```

To print a *name*, the kernel needs a lookup table of "address → function name" stored **inside
itself**. That table is called **kallsyms**.

**The problem:**

1. Link the kernel — now every function has a fixed address
2. Build the name table from those addresses
3. Put the table inside the kernel — **the kernel just got bigger**
4. Everything positioned after the table has now shifted, so the addresses in the table you just built
   are wrong

**It is exactly like the index at the back of a book.** You can only write the index once the pages are
numbered — but adding twenty pages of index pushes content onto different pages, so the numbers you
just wrote are now wrong. Redo the index, and it changes length again, shifting things slightly once
more.

The build solves it by repeating: link, build table, link again with the table in place, rebuild the
table, and keep going until the addresses stop moving. Usually two or three passes.

**So:** every readable function name in a `dmesg` stack trace exists because of that loop. When you
decode your first oops on Day 12, this is the machinery you will be relying on.

### 7. vmlinux vs bzImage vs modules

Three outputs, and people conflate them constantly:

| Artifact | What it is | Used for |
|---|---|---|
| **`vmlinux`** | the uncompressed ELF kernel, with symbols and (if enabled) debug info | **debugging** — `gdb`, `addr2line`, decoding an oops, KASAN reports. Not bootable |
| **`arch/x86/boot/bzImage`** | compressed, self-extracting, with a boot header | **booting** — this is what QEMU and bootloaders take |
| **`*.ko`** | loadable kernel modules | `insmod` at runtime |

`bzImage` is "big zImage" — nothing to do with bzip2. Keep `vmlinux` around; from Day 3 onward it is
what makes crashes readable instead of hexadecimal.

### 8. Parallelism, and why bigger `-j` is not always faster

`make -j18` runs 18 compile jobs at once. Two limits bite:

- **Memory.** Each `cc` process wants roughly 200 MB - 1 GB depending on the file. 18 jobs × a heavy
  file can approach your 20 GB ceiling, and if the guest starts swapping the build gets *slower*.
- **Serialization.** Linking, `MODPOST`, and the kallsyms passes are largely single-threaded. Past a
  point you are just waiting on those regardless of `-j`.

`-j$(nproc)` is the right default. If a build ever gets killed by the OOM reaper, drop to
`-j$(($(nproc)/2))` rather than assuming the tree is broken.

### 9. What ccache will and will not do today

Your **first** build gets no benefit — the cache is empty, and ccache adds a small overhead hashing
every file. Expect roughly zero hit rate and a slightly slower-than-native build.

The payoff arrives the moment you do something you will do constantly: switch config, switch branch,
or `make clean` and rebuild. Then most files preprocess to the exact same text as before and come
straight from cache.

Watch it with `ccache -s`. Today the interesting number is `cache size` growing. From tomorrow it is
the hit rate.

Remember it caches **C only** — `rustc` has its own incremental machinery, and Rust is a small
fraction of build time anyway.

---

## Step-by-Step

### Phase 0 — Confirm yesterday actually took effect

Do this first. Everything below assumes it.

```bash
which gcc              # MUST be /usr/lib/ccache/gcc
echo "$LINUX_TREE"     # MUST be /home/ksanu/LKD_RUST/kernel/linux
df -h "$HOME" | tail -1
nproc
```

If `which gcc` says `/usr/bin/gcc`, your `PATH` edit is not active — open a new terminal. If
`$LINUX_TREE` is empty, re-check `~/.bashrc` from Day 1 Phase 7.

### Phase 1 — Clone mainline

```bash
mkdir -p "$(dirname "$LINUX_TREE")"
cd "$(dirname "$LINUX_TREE")"

time git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
```

This is the long one. Expect 10-40 minutes depending on your connection, and about 5-6 GB.

> **Bandwidth-constrained?** Use `git clone --filter=blob:none <url> linux` instead — full commit
> history, file contents fetched on demand. Do **not** use `--depth=1`; see concept 2.

> **Prefer a faster mirror?** `https://github.com/torvalds/linux.git` is an official read-only mirror
> and is often quicker. Same content. If you use it, set `origin` to the kernel.org URL afterwards so
> you are tracking the canonical tree:
> `git remote set-url origin https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git`

### Phase 2 — Add the remotes you will need later

```bash
cd "$LINUX_TREE"

git remote add next   https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
git remote add rfl    https://github.com/Rust-for-Linux/linux.git

git remote -v
```

Do **not** fetch them yet — each is another multi-GB download and you need none of it today. The URLs
are what matter.

```bash
# Confirm what you have
git log --oneline -3
make kernelversion
git describe --tags | head -1
du -sh .git
```

### Phase 3 — Meet the tree

Spend real time here. This is the navigation instinct paying for itself later.

```bash
# Top level
ls

# Relative sizes — see for yourself that drivers/ dominates
du -sh --exclude=.git */ | sort -h | tail -12

# Where the Rust lives
ls rust/
ls rust/kernel/ | head -40
ls samples/rust/

# Count the Rust footprint
find rust drivers -name '*.rs' | wc -l
```

Now find real things, using the tools you will actually use:

```bash
# Who maintains the Rust support?
scripts/get_maintainer.pl -f rust/kernel/pci.rs

# The first useful Rust driver in the kernel
ls drivers/net/phy/*rust*

# The Rust null block driver
ls drivers/block/rnull*

# Nova
ls drivers/gpu/nova-core/ 2>/dev/null || echo "not in this version yet"

# Search 40 million lines in under a second
git grep -n "pci_alloc_irq_vectors" -- rust/ | head
```

Read the commit that introduced Rust support, to see what a landmark kernel commit looks like:

```bash
git log --oneline --all --grep="Rust support" | tail -5
git log --format="%h %ad %an%n%n%B" -1 $(git log --format=%h -1 -- rust/kernel/lib.rs)
```

### Phase 4 — Configure

```bash
cd "$LINUX_TREE"
make defconfig
```

Look at what it produced:

```bash
wc -l .config
grep -c '=y'  .config     # built into the kernel image
grep -c '=m'  .config     # built as loadable modules
grep -c 'is not set' .config

# Rust is off by default in defconfig - confirm, we enable it on Day 4
grep -E '^CONFIG_RUST' .config || echo "CONFIG_RUST not set (expected today)"
```

Now learn `menuconfig`, because you will live in it:

```bash
make menuconfig
```

- **`/`** opens search — type `RUST`, press Enter. This is the single most useful key in the interface.
  The results show each option's dependencies and where it lives in the menu tree
- **`?`** on a highlighted option shows its help text and its `Kconfig` file location
- Arrow keys navigate, **Enter** descends, **Esc Esc** goes back
- **`y`/`n`/`m`** set built-in / off / module
- Exit **without saving** today — `defconfig` is what we want for the baseline

### Phase 5 — Build it

```bash
cd "$LINUX_TREE"
ccache -z                                   # zero the stats so today's numbers are clean
time make -j"$(nproc)" 2>&1 | tee ~/LKD_RUST/Month_1/Week_1/build1.log
```

Watch the stage prefixes go by — `CC`, `AR`, `LD`, `MODPOST`, `KSYMS`, `BTF`, `BUILD`. You are
watching concept 6 happen.

Expect **5-20 minutes** on 18 cores. Then:

```bash
# What you built
ls -lh vmlinux arch/x86/boot/bzImage
find . -name '*.ko' | wc -l

# Cost on disk
du -sh --exclude=.git .
df -h "$HOME" | tail -1

# Warnings — should be few or none on a clean defconfig
grep -ciE 'warning:' ~/LKD_RUST/Month_1/Week_1/build1.log

# ccache after a cold build: near-zero hits, cache populated
ccache -s | head -12
```

### Phase 6 — Prove ccache works

This is the demonstration that makes the Day 1 `PATH` line feel worthwhile.

```bash
make clean                       # deletes build output, keeps .config
time make -j"$(nproc)" > /dev/null 2>&1
ccache -s | head -12
```

The second build should be **dramatically faster**, and `ccache -s` should now show a high hit rate.
`make clean` threw away every `.o`, but the preprocessed source was unchanged, so ccache handed them
straight back.

> Note `make clean` vs `make mrproper`: `clean` removes build artifacts and keeps `.config`;
> `mrproper` removes the config too. Use `clean` almost always.

### Phase 7 — Record it

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_2/check_day2.sh
```

Then fill in the table below from what you measured.

---

## Verification

```bash
cd "$LINUX_TREE"
git log --oneline -1                        # you have history
git remote -v | wc -l                       # 4 remotes x 2 lines = 8
make kernelversion                          # e.g. 7.2.0
ls -lh vmlinux arch/x86/boot/bzImage        # both exist
ccache -s | grep -i 'hit rate'              # high after the second build
```

---

## Gotchas

- **Cloning to the wrong place.** It must be under `$LINUX_TREE` in WSL's ext4. A tree on `/mnt/c/`
  builds several times slower and loses the executable bit and symlinks it depends on.
- **`make` without a config.** If you run `make` before `make defconfig`, it starts asking you
  thousands of questions interactively. `Ctrl-C`, run `make defconfig`, try again.
- **Hand-editing `.config`.** Silently produces contradictory options. Use `menuconfig` or
  `scripts/config`, then always `make olddefconfig`.
- **Disk filling mid-build.** A defconfig build is 2-3 GB; with debug info it can be 15-25 GB.
  Check `df -h` before enabling `CONFIG_DEBUG_INFO`.
- **Build killed with no error.** Usually the OOM reaper. Retry with a lower `-j`.
- **`pahole` errors at the BTF stage.** `dwarves` missing or too old. You installed it on Day 1;
  verify with `pahole --version`.
- **Expecting the first build to benefit from ccache.** It cannot. The cache is empty. Judge ccache on
  build two.
- **Assuming `make` builds modules.** It does for the `=m` options in your config, but if you only run
  `make bzImage` you get no modules. Plain `make` is what you want.
- **Confusing `vmlinux` and `bzImage`.** QEMU can boot either, but debugging needs `vmlinux`. Don't
  delete it to save space.
- **`git gc` running mid-work.** On a fresh 5 GB clone git may decide to repack. Harmless, but it will
  make an unrelated command mysteriously take two minutes.

---

## My Notes

*(Fill this in — the numbers here are your baseline for the next 18 months.)*

### The clone

| Property | Value |
|---|---|
| Clone method (full / blobless) | |
| Clone wall time | |
| `.git` size (`du -sh .git`) | |
| Working tree + `.git` total | |
| Kernel version (`make kernelversion`) | |
| HEAD commit (`git log --oneline -1`) | |

### The build

| Property | Value |
|---|---|
| `nproc` used for `-j` | |
| **First build wall time** | |
| **Second build wall time (ccache warm)** | |
| ccache hit rate after build 2 | |
| Warnings count | |
| `vmlinux` size | |
| `bzImage` size | |
| Module count (`*.ko`) | |
| Disk used by the tree | |
| Disk free afterwards | |

### The tree

Three directories I did not expect, and what they hold:

The largest subsystem by size, and by how much:

### What went wrong, and how I fixed it

### What surprised me

---

## Done When

- [x] `$LINUX_TREE` contains a full-history clone, and `git log` shows real commits
- [x] Four remotes configured; you can say what each tree is for
- [x] You can name what lives in `arch/`, `drivers/`, `kernel/`, `mm/`, `rust/`, `include/uapi/`,
      `scripts/`, `Documentation/` **without looking**
- [x] You can explain why `include/uapi/` is different from `include/linux/`
- [x] `make defconfig` run; you can explain what a defconfig is and where it came from
- [x] You used `/` in `menuconfig` to find `RUST` and read its dependencies
- [x] `vmlinux` and `bzImage` both exist, and you can say what each is for
- [x] Second build measurably faster, with a ccache hit rate to prove it
- [x] You can explain why the build links `vmlinux` more than once
- [x] Every number in the tables above is filled in
- [x] Journal entry written

---

## Reading

- `Documentation/admin-guide/README.rst` — the kernel's own build instructions. Short, and the
  canonical source for what you did today
- `Documentation/kbuild/kconfig.rst` — config targets and what each does
- `Documentation/process/changes.rst` — minimum tool versions; check yours against it now that you
  have a tree
- Skim `MAINTAINERS` — search for `RUST` and read that entry properly. Those are the people who will
  review your patches

---

**Next:** M1W1D3 — The Fast Boot Loop. You boot what you built, get a shell inside your own kernel,
and get the edit-build-boot cycle under 60 seconds. That loop is the single biggest determinant of how
much you actually learn in the next 18 months.

# M1W1 — Mid-Week Recap (Days 1-3)

> **What this is:** a revision document, not a lesson. Days 1-3 are done; this consolidates the
> concepts, the commands, and the traps into one file you can reread before Day 4 or in three months
> when you have forgotten why `LLVM=1` is on every command line.
>
> **How to use it:** read the "Through-Line" and the three day summaries first. Then cover the answers
> in [Active Recall](#active-recall) and see what you can actually reproduce. Anything you cannot
> explain out loud, go back to the day file it came from — [`Day_1.md`](Day_1.md),
> [`Day_2.md`](Day_2.md), [`Day_3.md`](Day_3.md).
>
> **If you only have ten minutes:** [The Through-Line](#the-through-line),
> [The Twelve Ideas](#the-twelve-ideas-that-actually-matter), and
> [Command Reference](#command-reference).

---

## The Through-Line

Three days, one sentence each, and they build strictly in order:

| Day | Title | What you ended the day with |
|---|---|---|
| **D1** | Linux Development Environment | A machine that *can* build a kernel — toolchain, deps, KVM, ccache. **No source yet.** |
| **D2** | Clone and Build Mainline | A `bzImage` you compiled yourself, and a build time you wrote down. **You could not run it.** |
| **D3** | The Fast Boot Loop | A shell inside your own kernel, and the whole edit→build→boot cycle under 60 seconds. |

The arc: **capability → artifact → feedback loop.** Day 3 is the important one, because the length of
that loop silently decides how much you learn over the next 18 months. A 30-second loop makes kernel
development experimental; a 10-minute loop makes it theoretical.

Everything so far has been **C infrastructure**. Day 4 is where Rust — the actual subject — arrives.

---

## The Twelve Ideas That Actually Matter

Strip away the commands and this is what the three days were teaching:

1. **The filesystem boundary is the whole game in WSL.** Kernel work lives on ext4 (`~/...`), never on
   `/mnt/c/`. It is not a 10% difference — it is 3-10x, plus you lose the executable bit and symlinks
   the kernel tree depends on.
2. **The kernel builds its own build tools.** `flex`, `bison`, and `libncurses` do not compile kernel C
   code; they compile the *configuration system* that decides which kernel C code to compile. That is
   why their absence produces such confusing errors.
3. **`LLVM=1` is about having one code generator, not two.** `rustc`'s backend is LLVM. Compiling C with
   GCC and Rust with LLVM means two compilers making independent decisions about target features,
   sanitizers, and LTO.
4. **`bindgen` needs libclang as a *library*, not clang as a binary.** The kernel generates its Rust FFI
   declarations by parsing C headers at build time. You can have a perfect Clang install and still be
   unable to build kernel Rust.
5. **A device node existing tells you nothing about whether you can open it.** `/dev/kvm` is
   `root:kvm 660`. Every "is KVM working?" check passes and QEMU still says *Permission denied* until
   you are in the `kvm` group.
6. **ccache works because it hashes preprocessed source.** Switch branches, switch configs,
   `make clean` — the vast majority of translation units still preprocess to byte-identical text. It
   caches **C only**; Rust has its own incremental machinery.
7. **Git history is a kernel development tool, not an archive.** `blame`, `bisect`, `Fixes:` tags, and
   the commit message that is often the *only* documentation for why code is shaped that way. This is
   why `--depth=1` is a trap.
8. **There is no single "the kernel."** mainline, linux-next, stable, rust-for-linux, and dozens of
   subsystem trees. You *fetch* from all of them and *push* to none — contributions leave as email.
9. **Never hand-edit `.config`.** It contains *resolved* dependencies, so one edited line can silently
   contradict another. Use `menuconfig` or `scripts/config`, then always `make olddefconfig`.
10. **`vmlinux` is for debugging, `bzImage` is for booting.** Different artifacts, constantly conflated.
    Do not delete `vmlinux` to save space — it is what makes a crash readable instead of hexadecimal.
11. **A kernel with nowhere to go panics, and that is a successful boot.** Kernel image + root
    filesystem + init (PID 1). Have the first and none of the rest, and the panic proves everything
    worked right up to the handover.
12. **Capture every console to a file.** The one crash you fail to capture will be the interesting one.

---

## Day 1 — Linux Development Environment

**Mental model:** *WSL2 is a real Linux kernel in a lightweight VM. Your job today is to make that VM
capable, and to keep your work off the Windows filesystem.*

### Concepts

**WSL2 is not emulation.** It is a genuine Linux kernel (Microsoft's, from
[WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel)) in a Hyper-V VM. Builds run within
a few percent of native. But you will **never run your own kernel as the WSL kernel** — a broken kernel
would mean a broken WSL install. Your kernels run in QEMU guests, where a crash costs nothing.

**The two filesystems.**

| Path | What it is | Speed |
|---|---|---|
| `~/...`, `/opt`, `/usr` | ext4 inside a virtual disk (`ext4.vhdx`) WSL owns | native Linux |
| `/mnt/c/...` | Windows drive bridged over 9p/drvfs | **3-10x slower**, worst with many small files |

A kernel build touches tens of thousands of small files and does an enormous number of `stat()` calls;
every one crosses the bridge. Hence the repo's `sync_from_repo.sh` / `sync_to_repo.sh` — fast builds in
WSL, version control on Windows.

**The VHDX grows but never shrinks.** Delete build output and Linux sees free space; the VHDX stays
large on the Windows side. Reclaiming it needs a manual compact.

**Disk budget** (40 GB is the floor, not a comfortable estimate):

```text
Linux git tree, full history      ~5 GB     (.git is most of it)
One defconfig build               ~2-3 GB
One build WITH debug info         ~15-25 GB (vmlinux with full DWARF is enormous)
ccache                            up to whatever you allow (20 GB is sane)
```

You will want `CONFIG_DEBUG_INFO` on, because you cannot decode an oops or use `gdb` without it. Budget
for the debug build.

**What each dependency is for** — the part that lets you diagnose a failure in Month 3 instead of
googling the error:

| Package | Provides | Where the build uses it |
|---|---|---|
| `build-essential` | `gcc`, `g++`, `make`, libc headers | everything; the baseline C toolchain |
| `flex` / `bison` | lexer / parser generators | build the **Kconfig** parser in `scripts/kconfig/` |
| `bc` | arbitrary-precision calculator | Kbuild computes timer constants via `kernel/time/timeconst.bc` |
| `libssl-dev` | OpenSSL headers | module signing (`scripts/sign-file`), certificates |
| `libelf-dev` | ELF manipulation | **`objtool`** — validates stack usage and control flow; also BTF |
| `libncurses-dev` | terminal UI | `make menuconfig`; without it you get `make config`, which asks thousands of questions one at a time |
| `dwarves` | **`pahole`** | DWARF → **BTF** for `CONFIG_DEBUG_INFO_BTF`, the types eBPF needs |
| `cpio` | archive tool | building **initramfs** images |
| `rsync` | file sync | `make headers_install` and several install targets |
| `zstd` | compression | compressed kernel images and modules |
| `kmod` | `insmod`, `rmmod`, `modprobe`, `depmod` | loading your modules |
| `clang lld llvm` | LLVM toolchain | `LLVM=1` builds |
| `libclang-dev` | libclang **library** | `bindgen` parses C headers with it |
| `ccache` | compiler cache | see idea 6 |

**What `LLVM=1` actually switches:** not just the compiler — `clang` for `gcc`, `ld.lld` for `ld`, and
`llvm-ar` / `llvm-nm` / `llvm-objcopy` / `llvm-objdump` / `llvm-strip` for the binutils equivalents.
That is why you install `llvm` and `lld`, not just `clang`.

**The virtualization stack, three layers:**

| Layer | What it does |
|---|---|
| **Hardware** — Intel VT-x / AMD-V | a CPU mode where guest code runs directly on silicon; only privileged operations trap out |
| **Kernel** — KVM | exposes those extensions to userspace through `/dev/kvm`, as an `ioctl` interface. Create a VM, add memory, add vCPUs, run. It does **not** emulate hardware |
| **Userspace** — QEMU | emulates the hardware (disks, NICs, serial, PCI) and asks KVM to execute guest instructions |

Without KVM, QEMU falls back to **TCG**, JIT-translating guest instructions in software: correct, and
roughly **10-20x slower**. Because WSL2 is itself a VM, running KVM inside it is **nested
virtualization** — enabled by default on Windows 11 x86. Two things go wrong, neither fatal: the module
is not loaded (`sudo modprobe kvm_intel`), or the permissions are wrong (the `kvm` group). On **ARM64
Windows this cannot work at all** — WSL boots at EL1 and KVM on ARM needs EL2.

**`git config user.name` is a legal artifact, not cosmetics.** Every upstream patch carries
`Signed-off-by: Real Name <email>`, which is the **Developer's Certificate of Origin** — you are
certifying you have the right to submit the code under the kernel's license. Real name, spelled as you
would sign a document. An email you can receive mail at, because review happens by email.

### Recorded result — 2026-08-14

KVM working (`vmx` present, `/dev/kvm` as `root:kvm 660`, `kvm_intel` loaded), full LLVM 21 toolchain,
ccache intercepting, 910 GB free.

---

## Day 2 — Clone and Build Mainline

**Mental model:** *`make` turns ~30,000 `.c` files into one bootable file, in stages, and the prefix on
each output line tells you which stage you are watching.*

### Concepts

**The scale.** ~40 million lines, ~90,000 files, 1.3M+ commits, `.git` around 5 GB — larger than the
working tree. You will never read it all and nobody has. Kernel competence is finding the 200 lines
that matter to your problem, quickly.

**Why full history, and why shallow is a trap.** `--depth=1` builds perfectly and breaks every one of
these:

| Operation | What it gives you |
|---|---|
| `git log -- <path>` | how this code evolved and why |
| `git blame -L 100,120 <file>` | who wrote this line, in which commit |
| `git show <sha>` | the reasoning behind the change that introduced a bug |
| `git bisect` | which of 10,000 commits broke your boot |
| `Fixes:` tags | the 12-char SHA of the commit you are fixing — **mandatory** in bug-fix patches |
| `git describe` | which release a commit landed in |

The middle ground if bandwidth forces it is a **blobless partial clone**, `--filter=blob:none`: every
commit and tree, file *contents* on demand. `git log` and `git bisect` work fully.

**The trees.**

| Tree | What it is | Why you want it |
|---|---|---|
| **mainline** (`torvalds/linux`) | Linus's tree; the definitive "what is in Linux" | your baseline; what releases are cut from |
| **linux-next** | all subsystem trees merged nightly | see breakage before mainline; check if something is already queued |
| **stable** | released kernels + backported fixes | what distributions ship |
| **rust-for-linux** | the RfL development tree | Rust work often lands here first |
| subsystem trees | `drm-misc-next`, `rust-next`, `drm-rust-next`, ... | where you base a patch |

**The top-level layout** — learn it well enough never to guess:

| Directory | What lives there |
|---|---|
| `arch/` | architecture-specific: boot code, page tables, atomics, syscall entry |
| `drivers/` | **60%+ of the tree.** Every device driver — which is exactly why Rust was introduced here first |
| `kernel/` | the core: scheduler, locking, RCU, workqueues, time, tracing |
| `mm/` | page allocator, slab, reclaim, page cache, mmap |
| `fs/` | the VFS plus every filesystem |
| `net/` | TCP/IP, netfilter, sockets |
| `block/` | blk-mq, request queues, I/O schedulers |
| `include/` | `include/linux/` is internal API; **`include/uapi/` is the permanent userspace contract** |
| `rust/` | **your home for 18 months.** `rust/kernel/` (safe abstractions), `rust/bindings/` (generated), `rust/helpers/`, `rust/macros/` |
| `samples/` | example code, including `samples/rust/` |
| `scripts/` | `checkpatch.pl`, `get_maintainer.pl`, Kconfig itself |
| `tools/` | `perf`, KUnit runner, memory-model tooling |
| `Documentation/` | `Documentation/rust/` and `process/` are required reading |
| `MAINTAINERS` | **who owns what** — where to send a patch |

**What a defconfig is.** ~20,000 config options exist, so every architecture ships a baseline:
`arch/x86/configs/x86_64_defconfig`. `make defconfig` copies its choices, resolves every dependency,
and writes `.config` — the single file that determines what gets compiled.

| Target | What it does | When |
|---|---|---|
| `defconfig` | the architecture's shipped baseline | first build; known-good start |
| `menuconfig` | interactive ncurses editor | exploring options, reading help |
| `olddefconfig` | keep `.config`, accept defaults for anything new | **after scripted edits, or after pulling new commits** |
| `localmodconfig` | only modules currently loaded on this machine | much faster builds; brittle for kernel dev |
| `allmodconfig` | everything possible as a module | catching compile errors tree-wide |
| `allnoconfig` | no to everything optional | minimal builds, bisecting |
| `savedefconfig` | minimal config, only non-default choices | sharing a config in a patch or bug report |

**The build pipeline, and the prefix that tells you where you are:**

| Prefix | Stage |
|---|---|
| `SYNC` | reading your `.config` |
| `HOSTCC` | building a helper tool that runs on *your* machine during the build |
| `CC` | compiling one kernel C file → `.o` |
| `RUSTC` | compiling one kernel Rust file (from Day 4) |
| `AR` | bundling a directory's objects into `built-in.a` — purely organisational |
| `LD` | linking; "this function calls that" becomes real addresses |
| `MODPOST` | verifying each `.ko` only calls symbols the kernel actually exports |
| `NM` / `KSYMS` | building the kernel's internal symbol table |
| `BTF` | embedding type info for eBPF tools |
| `OBJCOPY` / `GZIP` / `LZO` | stripping and compressing |
| `BUILD` | producing the final bootable `bzImage` |

**Why `vmlinux` gets linked two or three times.** To print `start_kernel+0x42` instead of
`0xffffffff81000042`, the kernel needs an address→name table (**kallsyms**) stored *inside itself*. But
adding the table makes the kernel bigger, which shifts everything after it, which invalidates the
addresses you just recorded. **It is the index at the back of a book:** you can only write the index
once the pages are numbered, but adding twenty pages of index moves the content. So the build repeats —
link, build table, relink — until addresses stop moving. Every readable function name in a `dmesg`
stack trace exists because of that loop.

**Three outputs, constantly conflated:**

| Artifact | What it is | Used for |
|---|---|---|
| `vmlinux` | uncompressed ELF, symbols + debug info | **debugging** — `gdb`, `addr2line`, decoding an oops, KASAN. Not bootable |
| `arch/x86/boot/bzImage` | compressed, self-extracting, boot header | **booting** — what QEMU and bootloaders take |
| `*.ko` | loadable modules | `insmod` at runtime |

`bzImage` is "big zImage" — nothing to do with bzip2.

**Why a bigger `-j` is not always faster.** Memory: each `cc` wants ~200 MB-1 GB, and if the VM starts
swapping the build gets *slower*. Serialization: linking, `MODPOST`, and the kallsyms passes are largely
single-threaded. `-j$(nproc)` is the right default; if the OOM reaper kills a build, halve it rather
than assuming the tree is broken.

**ccache on build one does nothing.** The cache is empty and hashing adds slight overhead. Judge it on
build two.

### Recorded result — 2026-08-15

Kernel **7.2.0-rc7** at `3eb40771c00a`, full history, 4 remotes. `defconfig` = 5,473 lines / 1,631
built-in / 15 modules, **0 warnings**. `vmlinux` 52 MB, `bzImage` 15 MB. Second build **31.8 s** with a
~99.9% ccache hit rate, 100% of them *direct* hits.

---

## Day 3 — The Fast Boot Loop

**Mental model:** *A kernel needs an image, a root filesystem, and an init. QEMU gives you the machine;
virtme-ng conjures the last two out of your existing filesystem.*

### Concepts

**Why a VM and not your laptop.** A kernel bug does not throw an exception — it panics, hangs, or
silently corrupts memory. A VM gives you three things: crashes are free (a panic kills a process),
state is fresh every time, and it takes seconds. This is what Day 1's KVM work was *for*.

**What a kernel needs to reach userspace:**

1. a kernel image — you have `bzImage`
2. a root filesystem — somewhere `/bin`, `/etc`, `/lib` live
3. an init process — the first userspace program, PID 1

```text
QEMU loads bzImage
  -> the compressed image decompresses itself
  -> start_kernel(): memory, interrupts, scheduler, driver probing
  -> mount the root filesystem
  -> execute /sbin/init as PID 1
  -> userspace runs; you get a shell
```

The kernel's last act is executing PID 1. With no root filesystem there is nothing to execute, so it
panics — the kernel equivalent of a machine with no OS installed.

**The two "no userspace" panics, and what each tells you:**

| Panic | Means |
|---|---|
| `VFS: Unable to mount root fs on unknown-block(0,0)` | no root device at all — `(0,0)` is a null major/minor. **This is what a bare `-kernel` boot gives you**, with no `root=` and no `-initrd` |
| `No working init found` | the root filesystem *was* mounted, but contains no executable init |

The `List of all bdev filesystems:` list printed above the panic is the kernel being helpful — those are
the filesystem types it was ready to mount. It had the drivers and no device to point them at.

**initramfs, and the chicken-and-egg it solves.** To mount the root filesystem the kernel may need a
driver — NVMe, RAID, disk decryption — but that driver is a module living on the filesystem it cannot
yet mount. initramfs breaks the loop: a small compressed archive loaded into memory alongside the
kernel, unpacked into a RAM filesystem, whose init loads the drivers needed to reach the real root and
then hands over. Your distro does this every boot; `/boot/initrd.img-*` is exactly this file. For kernel
development an initramfs is often *all* you need — and that is essentially virtme-ng's trick.

**Why serial console.** Practical: it is text in your terminal, so you can scroll it, grep it, pipe it
to a file, and paste it into a bug report. A graphical console is pixels. Structural: **the serial
driver initializes very early**, long before graphics — if your kernel dies in the first two seconds,
serial is the only thing that will have printed anything. `console=ttyS0` tells the *kernel* where to
send messages; `-nographic` tells *QEMU* to wire that port to your terminal.

**The kernel command line** is how you configure a kernel before any userspace exists:

| Parameter | Effect |
|---|---|
| `console=ttyS0` | send kernel messages to the first serial port |
| `panic=1` | reboot 1s after a panic instead of hanging forever (`panic=-1` = never reboot) |
| `nokaslr` | disable address randomisation — **essential** for gdb, so addresses match your symbols |
| `loglevel=7` | show everything, including debug |
| `earlyprintk=serial` | print during very early boot, before the console is properly up |
| `init=/bin/sh` | run a shell as PID 1 instead of the normal init |
| `root=/dev/vda` | which device holds the root filesystem |

The full list is `Documentation/admin-guide/kernel-parameters.txt`. It is enormous; know it exists.

**What virtme-ng does.** It boots your kernel **using your existing WSL filesystem as the guest's
root**, shared in over virtio, with a generated in-memory init. No disk image, no initramfs to build,
no installation — your home directory, your tools, and your kernel tree are simply *there* inside the
guest. So `vng --exec ./my_test.sh` copies nothing: the script is already present because it is the
same filesystem. The one catch is that `defconfig` does not enable the virtio and 9p/virtiofs options
this needs, so you run `vng --kconfig` once to add them on top of your `.config` and rebuild.

**Why 60 seconds is the target** — the difference is not productivity, it is a different *activity*:

| Loop time | What you actually do |
|---|---|
| **30 seconds** | test every change; when it breaks you know exactly which line did it |
| **2 minutes** | batch three or four changes per test; when it breaks, you bisect your own work |
| **10 minutes** | avoid testing. Read code and hope. Debug several problems at once |

Three things keep it fast, all already in place: **ccache**, **incremental builds**, and **virtme-ng**.

### Recorded result — 2026-08-17

QEMU 10.2.1, virtme-ng 1.40 (from `apt`, not pip). Manual QEMU boot reached
`VFS: Unable to mount root fs` in **1.7 s** — a clean boot with no root filesystem, exactly as intended.
After `vng --kconfig` + rebuild (4m58s, build `#3`), `vng` gave an interactive shell: hostname
`virtme-ng`, kernel `7.2.0-rc7+`, home directory shared in.

**Two real bugs found and fixed in the material:**

- `pip3 install --user virtme-ng` fails on Ubuntu 24.04+ under **PEP 668**
  (`externally-managed-environment`): the distro owns its Python install, so `pip` is blocked from
  writing into it. Use `sudo apt install virtme-ng`; use `pipx` when a tool is not packaged; do **not**
  reach for `--break-system-packages`.
- Wrapping `vng` in bare `timeout` freezes the whole process tree in state `T`. Without `--foreground`,
  `timeout` moves the child into a new process group, QEMU then counts as a background job, and its
  terminal access raises `SIGTTOU`/`SIGTTIN` — whose default action is *stop*.

---

## Command Reference

Organised by what you are trying to do, because that is how you will look things up.

### Confirming the environment

```bash
uname -r                       # WSL2 kernel version — proves WSL2, not WSL1
cat /etc/os-release            # which Ubuntu
nproc                          # cores available to WSL (matches .wslconfig processors)
free -h                        # RAM available to WSL (matches .wslconfig memory)
df -h "$HOME"                  # free space on the Linux filesystem — want 40 GB+
df -h .                        # check the CURRENT dir's fs: must not be drvfs / 9p
which gcc                      # MUST be /usr/lib/ccache/gcc, else ccache is doing nothing
echo "$LINUX_TREE"             # where the kernel tree lives; must not be under /mnt/
echo "$LKDRUST_REPO"           # the Windows-side git repo
groups                         # must include kvm
```

From PowerShell, on the Windows side:

```powershell
wsl -l -v                                                        # confirm VERSION 2
wsl --set-version Ubuntu 2                                       # convert if it says 1
wsl --shutdown                                                   # REQUIRED to apply .wslconfig / wsl.conf
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB   # size before you allocate
(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
```

### KVM

```bash
ls -l /dev/kvm                          # want: crw-rw---- root kvm
stat -c '%A %U:%G' /dev/kvm             # same, terser
lsmod | grep kvm                        # is the module loaded?
sudo modprobe kvm_intel                 # load it (kvm_amd on AMD)
kvm-ok                                  # from cpu-checker: explains WHY kvm is unavailable
grep -o -m1 -E 'vmx|svm' /proc/cpuinfo  # vmx = Intel VT-x, svm = AMD-V
sudo usermod -aG kvm "$USER"            # the step people miss; needs wsl --shutdown to take effect
```

### git identity and defaults

```bash
git config --global user.name  "Your Real Name"    # goes into Signed-off-by; a legal artifact
git config --global user.email "your@email"        # must be an address you can receive mail at
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global pull.rebase true               # linear history; the kernel does not use merge commits
git config --global log.date iso
git config --global --list | grep -E 'user\.|init\.|pull\.'
```

### ccache

```bash
ccache --max-size=20G                              # the default few GB is too small for kernel builds
echo 'export PATH="/usr/lib/ccache:$PATH"' >> ~/.bashrc   # order is the entire trick
ls /usr/lib/ccache/                                # the compiler symlinks it installed
ccache -s                                          # statistics; watch 'cache size' then 'hit rate'
ccache -z                                          # zero the stats before a measured build
```

### Cloning and remotes

```bash
time git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
git clone --filter=blob:none <url> linux    # blobless: full history, contents on demand
# NOT --depth=1 — it breaks blame, bisect, and Fixes: tags

git remote add next   https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
git remote add rfl    https://github.com/Rust-for-Linux/linux.git
git remote -v                               # 4 remotes = 8 lines
# Do NOT fetch them; a remote is just a URL until you do

make kernelversion                          # e.g. 7.2.0
git describe --tags | head -1               # which release you are near
du -sh .git                                 # ~5 GB
```

### Navigating the tree

```bash
du -sh --exclude=.git */ | sort -h | tail -12   # see for yourself that drivers/ dominates
git grep -n "pci_alloc_irq_vectors" -- rust/    # search 40M lines in under a second
scripts/get_maintainer.pl -f rust/kernel/pci.rs # who reviews a patch to this file
find rust drivers -name '*.rs' | wc -l          # the Rust footprint
ls rust/ rust/kernel/ samples/rust/             # where you will live
git log --oneline --all --grep="Rust support"   # find landmark commits
git blame -L 100,120 <file>                     # who wrote these lines, and when
git bisect start                                # which commit broke it
```

### Configuring

```bash
make defconfig                       # the arch baseline -> .config
make menuconfig                      # interactive editor
make olddefconfig                    # re-resolve deps; ALWAYS after scripted edits or a pull
make savedefconfig                   # minimal config, for sharing in a patch
scripts/config --enable CONFIG_FOO   # scripted edit; never hand-edit .config

wc -l .config                        # how big your config is
grep -c '=y' .config                 # built into the image
grep -c '=m' .config                 # built as loadable modules
grep -E '^CONFIG_RUST' .config       # off in defconfig; enabled on Day 4
```

Inside `menuconfig`: **`/`** searches (the single most useful key — it shows dependencies and menu
location), **`?`** shows help text and the `Kconfig` file, **Enter** descends, **Esc Esc** goes back,
**`y`/`n`/`m`** set built-in / off / module.

### Building

```bash
time make -j"$(nproc)" 2>&1 | tee ~/LKD_RUST/Month_1/Week_1/build1.log
make -j"$(($(nproc)/2))"             # if the OOM reaper killed the build
make clean                           # remove build output, KEEP .config     <- use this
make mrproper                        # remove build output AND .config
make LLVM=1 <target>                 # one code generator for C and Rust

ls -lh vmlinux arch/x86/boot/bzImage # what you built
find . -name '*.ko' | wc -l          # module count
du -sh --exclude=.git .              # disk cost of the tree
grep -ciE 'warning:' build1.log      # should be ~0 on a clean defconfig
```

### Booting — raw QEMU

```bash
qemu-system-x86_64 \
  -enable-kvm \                          # use hardware virtualization; omit to force TCG
  -m 2G -smp 4 \                         # guest RAM and vCPUs
  -kernel arch/x86/boot/bzImage \        # bzImage, not vmlinux
  -append "console=ttyS0 panic=-1" \     # the kernel command line
  -nographic \                           # wire the serial port to this terminal
  -no-reboot                             # do not loop forever on panic
```

Add `| tee ~/LKD_RUST/Month_1/Week_1/boot_manual.log` to keep the output. Then:

```bash
grep -iE 'panic|Linux version|Command line' boot_manual.log
```

| Key | Effect |
|---|---|
| `Ctrl-A` then `X` | quit QEMU. **Not `Ctrl-C`** — that goes to the guest |
| `Ctrl-A` then `C` | switch to the QEMU monitor |
| `pkill qemu-system-x86_64` | the escape hatch, from another terminal |

### Booting — virtme-ng

```bash
sudo apt install -y virtme-ng    # NOT pip3 install --user (PEP 668)
vng --version

vng --kconfig                    # add virtio/9p options on top of .config — once, then rebuild
vng                              # interactive shell inside your kernel
vng --exec 'uname -r'            # run one command in the guest and return — the daily mode
vng --exec 'dmesg | tail -20'
vng --exec "insmod path/to/mod.ko; dmesg | tail; rmmod mod"

# Inside the guest, confirm it is really yours:
uname -a ; cat /proc/version ; ls ~
```

Never wrap `vng` in bare `timeout` — use `timeout --foreground`, or the process tree freezes in state
`T`.

### Measuring the loop

```bash
# The number that matters: edit -> build -> boot -> output
time ( touch kernel/sched/core.c && make -j"$(nproc)" > /dev/null 2>&1 && vng --exec 'uname -r' )

time vng --exec true      # your floor: pure boot cost, a couple of seconds
```

If it is over 60 seconds: check `which gcc` is the ccache symlink, check the tree is not under `/mnt/`,
raise `processors` in `.wslconfig`, and check `ccache -s` shows hits.

### Repo scripts

| Script | What it does |
|---|---|
| [`codes/sync_from_repo.sh`](../../../codes/sync_from_repo.sh) | repo → WSL. Also strips CRLF and restores the `+x` bit, because NTFS preserves neither |
| [`codes/sync_to_repo.sh`](../../../codes/sync_to_repo.sh) | WSL → repo, so you can commit what you wrote |
| [`Day_1/install_deps.sh`](../../../codes/Month_1/Week_1/Day_1/install_deps.sh) | every dependency + LLVM + ccache + the directory layout. Idempotent |
| [`Day_1/record_env.sh`](../../../codes/Month_1/Week_1/Day_1/record_env.sh) | dump machine + toolchain state to a file. Diff two of these when something breaks in Month 4 |
| [`Day_1/check_day1.sh`](../../../codes/Month_1/Week_1/Day_1/check_day1.sh) | verify Day 1; **fails** if `$LINUX_TREE` is under `/mnt/` |
| [`Day_2/clone_kernel.sh`](../../../codes/Month_1/Week_1/Day_2/clone_kernel.sh) | clone mainline and add the four remotes |
| [`Day_2/first_build.sh`](../../../codes/Month_1/Week_1/Day_2/first_build.sh) | `defconfig` + timed build + the numbers |
| [`Day_3/boot_manual.sh`](../../../codes/Month_1/Week_1/Day_3/boot_manual.sh) | raw QEMU boot; `--interactive` to stay in, `--debug` for `nokaslr` + `earlyprintk` |
| [`Day_3/time_loop.sh`](../../../codes/Month_1/Week_1/Day_3/time_loop.sh) | measure the edit→build→boot loop |
| `check_day2.sh` / `check_day3.sh` | per-day verification; exit code is the failure count |

Then commit from the Windows side:

```bash
git add codes theory && git commit -m "..." && git push origin main
```

---

## Consolidated Gotchas

The traps from all three days, in one place. Most of these cost somebody an evening.

**Environment**

- **`dwarves` provides `pahole`.** Searching for a package named `pahole` finds nothing, and the failure
  it causes (missing BTF) appears very late and looks unrelated.
- **`libclang-dev`, not `clang` alone.** The compiler binary is not the parsing library `bindgen` links
  against.
- **`/dev/kvm` can exist and be unusable.** Check mode and group. QEMU's *Permission denied* is a
  permissions problem, not a missing-KVM problem.
- **`groups` does not update until the VM restarts.** `usermod -aG` edits `/etc/group`, but your running
  shell keeps the group list it started with. A new terminal window is **not** enough — `wsl --shutdown`.
- **`modprobe` returns before the device node appears.** Chowning `/dev/kvm` immediately after can race
  silently. Hence the `while [ ! -e /dev/kvm ]` loop in the boot command.
- **`wsl.conf` is inside WSL; `.wslconfig` is on Windows.** Similar names, completely different scopes.
  The wrong one silently does nothing.
- **Never write a second `[boot]` section in `/etc/wsl.conf`.** INI parsers drop one of the two, with no
  error — you lose either systemd or the KVM fix, and it looks like the setting had no effect.
- **ccache's `PATH` order is the whole trick.** Not before `/usr/bin`, and ccache is installed and idle.
- **The WSL VHDX grows but does not shrink.** Watch `df -h`.

**Building**

- **Do not put the kernel tree on `/mnt/c/`.** It works, and it is slow enough to make you quit. Add a
  synced cloud folder and the sync client will try to upload ~100,000 files mid-build.
- **`make` before `make defconfig`** starts asking thousands of interactive questions. `Ctrl-C`, run
  `defconfig`, retry.
- **Hand-editing `.config`** silently produces contradictory options.
- **Build killed with no error** is almost always the OOM reaper. Lower `-j`.
- **Expecting build one to benefit from ccache.** It cannot. Judge it on build two.
- **`make bzImage` builds no modules.** Plain `make` is what you want.
- **`git gc` mid-work.** A fresh 5 GB clone may decide to repack, making an unrelated command
  mysteriously take two minutes.
- **Disk filling mid-build.** Check `df -h` before enabling `CONFIG_DEBUG_INFO` — 2-3 GB becomes 15-25.

**Booting**

- **No output at all** means you forgot `console=ttyS0` or `-nographic`. The kernel is booting fine and
  talking to a console you cannot see.
- **Treating the panic as a failure.** A root-fs panic means everything worked up to the handover.
- **`Ctrl-C` does not exit QEMU** — it goes to the guest. `Ctrl-A X`.
- **`vng` not found** after install means `~/.local/bin` is not on `PATH`.
- **`vng` boots but cannot see your files** means the virtio/9p options are missing — `vng --kconfig`
  and rebuild.
- **Forgetting `nokaslr` when debugging.** From Day 12, gdb addresses will not match your symbols.
- **Never `insmod` an experimental module on your host.** That is what the guest is for.
- **Not capturing output.** The one crash you fail to capture will be the interesting one.
- **Accepting a slow loop "for now."** It compounds over 18 months.

---

## Active Recall

Cover the answers. If you cannot answer out loud, reread the day it came from.

<details>
<summary>Why must the kernel tree live on ext4 and not <code>/mnt/c/</code>? Give three reasons.</summary>

Speed (3-10x, because a build does an enormous number of `stat()` calls on many small files, each
crossing the 9p/drvfs bridge); the executable bit and symlinks the tree depends on are not preserved on
NTFS; and inside a synced cloud folder the sync client will try to upload ~100,000 files and may swap
them for placeholders mid-build.
</details>

<details>
<summary>Why does the kernel build need <code>flex</code> and <code>bison</code>, which compile no kernel C code?</summary>

They build the **Kconfig** parser in `scripts/kconfig/`. The kernel builds its own build tools — these
compile the *configuration system* that decides which kernel C code to compile. That is why their
absence produces such confusing errors.
</details>

<details>
<summary>Two independent reasons the roadmap uses <code>LLVM=1</code>.</summary>

One code generator instead of two — `rustc`'s backend is LLVM, so building the C half with GCC means
two compilers making independent decisions about target features, sanitizers, and LTO. And `bindgen`
links against **libclang** to parse C headers and generate `rust/bindings/bindings_generated.rs`, so
libclang is not optional even in theory.
</details>

<details>
<summary><code>ls -l /dev/kvm</code> succeeds and QEMU still says <em>Permission denied</em>. Why?</summary>

The node is `root:kvm` mode `660`, so its existence says nothing about whether *you* can open it. You
need to be in the `kvm` group — `sudo usermod -aG kvm "$USER"` followed by `wsl --shutdown`, because a
running shell keeps the group list it was started with.
</details>

<details>
<summary>What exactly does ccache hash, and why is that so effective for kernel work?</summary>

The **preprocessed** source (so all `#include` content is baked in), the compiler flags, and the
compiler version. Your daily loop is switching configs, switching branches, and rebuilding after
`make clean` — operations where the vast majority of the ~30,000 translation units preprocess to
byte-identical text. It caches **C only**.
</details>

<details>
<summary>Why is <code>git clone --depth=1</code> the wrong choice here?</summary>

History is a kernel development tool, not an archive. Shallow breaks `git blame`, `git bisect`,
`git show` on old commits, `git describe`, and the `Fixes:` tags that are mandatory in bug-fix patches.
The commit message is often the only documentation for why code is shaped the way it is. If bandwidth
forces it, use `--filter=blob:none` instead.
</details>

<details>
<summary>Name the four trees you added as remotes, and what each is for.</summary>

**mainline** (`torvalds/linux`) — the definitive state of Linux and your baseline. **linux-next** — all
subsystem trees merged nightly, so you see breakage before it reaches mainline. **stable** — released
kernels plus backported fixes, what distributions ship. **rust-for-linux** — where Rust work often
appears first. You fetch from all of them and push to none.
</details>

<details>
<summary>What is in <code>include/uapi/</code>, and why does it differ from <code>include/linux/</code>?</summary>

`include/uapi/` is the **permanent userspace contract** — headers userspace compiles against, which
cannot break. `include/linux/` is internal kernel API, changeable at will.
</details>

<details>
<summary>Why does the build link <code>vmlinux</code> two or three times?</summary>

**kallsyms.** To print `start_kernel+0x42` instead of a raw address, the kernel needs an address→name
table stored inside itself — but embedding it makes the kernel bigger, shifting everything after it and
invalidating the addresses just recorded. Like an index at the back of a book: writing it changes the
page numbers. So the build links, builds the table, relinks, and repeats until addresses stop moving.
</details>

<details>
<summary><code>vmlinux</code> vs <code>bzImage</code> — which boots, which debugs, and why keep both?</summary>

`bzImage` (compressed, self-extracting, boot header) is what QEMU and bootloaders take. `vmlinux`
(uncompressed ELF with symbols and debug info) is not bootable but is what `gdb`, `addr2line`, and oops
decoding need. Deleting it to save space costs you readable crashes.
</details>

<details>
<summary>Why can a larger <code>-j</code> make a build slower?</summary>

Memory — each `cc` wants ~200 MB-1 GB, and once the VM swaps everything slows down (or the OOM reaper
kills the build). And linking, `MODPOST`, and the kallsyms passes are largely single-threaded, so past a
point you are just waiting on those.
</details>

<details>
<summary>Three things a running Linux system needs, and what happens with only the first.</summary>

A kernel image, a root filesystem, and an init process (PID 1). With only the kernel it boots completely
and then panics, because its last act is executing PID 1 and there is nothing to execute. That panic is
a successful boot.
</details>

<details>
<summary>Distinguish the two no-userspace panics.</summary>

`VFS: Unable to mount root fs on unknown-block(0,0)` — no root device at all; `(0,0)` is a null
major/minor, which is what you get passing no `root=` and no `-initrd`. `No working init found` — the
root filesystem *was* mounted but has no executable init inside it. The second means you got further.
</details>

<details>
<summary>What chicken-and-egg problem does initramfs solve?</summary>

Mounting the real root may require a driver (NVMe, RAID, decryption) that is a module living on the
filesystem you cannot yet mount. initramfs is loaded into memory alongside the kernel, unpacked into a
RAM filesystem, and its init loads the drivers needed to reach the real root, then hands over.
</details>

<details>
<summary>Two reasons kernel developers use a serial console.</summary>

Practical: it is text, so you can scroll, grep, pipe, and paste it into a bug report — a graphical
console is pixels. Structural: the serial driver initializes very early, so if the kernel dies in the
first two seconds it is the only thing that printed anything.
</details>

<details>
<summary>Which is the kernel's job and which is QEMU's: <code>console=ttyS0</code> or <code>-nographic</code>?</summary>

`console=ttyS0` is a **kernel command-line parameter** telling the kernel to send messages to the first
serial port. `-nographic` is a **QEMU** flag wiring that port to your terminal instead of opening a
window. Omit either and you see nothing while the kernel boots perfectly.
</details>

<details>
<summary>Four kernel command-line parameters and what each does.</summary>

`console=ttyS0` (messages to serial), `panic=1` (reboot 1s after panic rather than hanging; `-1` never
reboots), `nokaslr` (no address randomisation, so gdb symbols match), `loglevel=7` (everything including
debug). Also `earlyprintk=serial`, `init=/bin/sh`, `root=/dev/vda`.
</details>

<details>
<summary>What does virtme-ng do that a raw QEMU command line cannot, and what must you do once first?</summary>

It boots your kernel using your existing filesystem as the guest root, shared in over virtio, with a
generated in-memory init — no disk image, no initramfs, so your home directory and kernel tree are
already there. Once, you must run `vng --kconfig` and rebuild, because `defconfig` lacks the virtio and
9p/virtiofs options it needs.
</details>

<details>
<summary>Why does <code>pip3 install --user virtme-ng</code> fail, and what are the right responses?</summary>

**PEP 668** — the distribution owns its Python installation and `apt` packages depend on specific
library versions, so `pip` is blocked from writing into it. In order: use the distro package
(`apt install virtme-ng`); use `pipx` if the tool is not packaged, which gives each tool its own
virtualenv; do not reach for `--break-system-packages`.
</details>

<details>
<summary>Why does wrapping <code>vng</code> in bare <code>timeout</code> freeze everything?</summary>

Without `--foreground`, `timeout` puts the child in a new process group. QEMU then counts as a
background job, and its terminal access raises `SIGTTOU`/`SIGTTIN`, whose default action is *stop* — so
the whole process tree sits in state `T`.
</details>

<details>
<summary>Why does the loop time matter more than it looks?</summary>

Kernel development has no REPL — booting is the only way to know whether your code works. At 30 seconds
you test every change and know exactly which line broke it; at 10 minutes you avoid testing, read code
and hope, and debug several problems simultaneously. It is not a productivity multiplier, it is a
different activity, and it compounds over 18 months.
</details>

---

## The Numbers So Far

Your baseline. When something is mysteriously slow in Month 4, these are what you compare against.

| Measurement | Value |
|---|---|
| Toolchain | LLVM 21 (tree minimum is 17.0.1) |
| Free disk | 910 GB |
| KVM | working — `vmx`, `kvm_intel` loaded, `/dev/kvm` `root:kvm 660` |
| Kernel version | 7.2.0-rc7 at `3eb40771c00a` |
| Remotes | 4 (mainline, next, stable, rfl) |
| `defconfig` | 5,473 lines — 1,631 built-in, 15 modules |
| Build warnings | **0** |
| `vmlinux` / `bzImage` | 52 MB / 15 MB |
| Second build (ccache warm) | **31.8 s**, ~99.9% hit rate, 100% direct |
| Rebuild after `vng --kconfig` | 4m58s (config change invalidates far more than a touch) |
| Manual QEMU boot to panic | **1.7 s** |
| QEMU / virtme-ng | 10.2.1 / 1.40 |
| Guest kernel via `vng` | `7.2.0-rc7+`, hostname `virtme-ng` |

Still to fill in: **first build wall time** (`Day_2.md`), pure boot floor `time vng --exec true`, and
the measured full loop (`Day_3.md`).

---

## What Day 4 Builds On This

`Day_4.md` assumes every one of these, so confirm them before starting:

| From | What Day 4 needs it for |
|---|---|
| D1 | `libclang-dev` — `bindgen` cannot read a single header without it |
| D1 | LLVM toolchain — `make LLVM=1 rustavailable` is the day's gate |
| D2 | a working `.config` and build — you are about to add `CONFIG_RUST` to it |
| D2 | `make olddefconfig` discipline — enabling `CONFIG_RUST` **must not destroy your virtme options** |
| D3 | `vng` working — how you will load `rust_minimal` and read `dmesg` |
| D3 | a fast loop — Day 4 involves a full config-change rebuild, the slow kind |

The tree names its own requirements; ask it rather than trusting any guide:

```bash
scripts/min-tool-version.sh rustc      # 1.85.0
scripts/min-tool-version.sh bindgen    # 0.71.1
scripts/min-tool-version.sh llvm       # 17.0.1
```

---

**Next:** [M1W1D4 — The Rust Toolchain](Day_4.md). Everything so far has been C infrastructure;
tomorrow the roadmap's actual subject begins.

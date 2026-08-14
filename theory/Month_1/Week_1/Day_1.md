# M1W1D1 — Linux Development Environment

> **Goal:** turn a Windows laptop into a machine that can build the Linux kernel. By the end of today
> you have a Linux userland with every build dependency, an LLVM toolchain, hardware virtualization
> available, and a compiler cache — but **no kernel source yet**. That is tomorrow.
>
> **Time:** 1.5-2.5 hours, most of it waiting on `apt`.
>
> **Why this matters:** every single day for the next 18 months runs through this environment. A
> missing package on day one shows up as an incomprehensible build error in week six. Worse, kernel
> build failures are famously bad at telling you the real cause — a missing `libelf-dev` does not say
> "install libelf-dev", it says something about `objtool` failing 40 minutes into a build. Spending
> two hours now to get this exactly right is the highest-return time in the whole roadmap.

---

## Today's Checklist

- [ ] WSL2 Ubuntu running, with 40+ GB of free disk confirmed
- [ ] Understand *why* the working files must live on WSL's filesystem and not `/mnt/c/`
- [ ] Install the build dependencies, and know what each one is for
- [ ] Install the LLVM/Clang toolchain + `libclang-dev`, and know why Rust needs it
- [ ] Install QEMU — it is what runs every kernel you build from Day 3 onward
- [ ] Verify `/dev/kvm` exists, **and that you are in the `kvm` group**; persist across restarts if needed
- [ ] Configure `git` identity (real name — this becomes a legal signature later)
- [ ] Configure `ccache` and confirm it is on your `PATH`
- [ ] Decide and create the directory where the kernel tree will live tomorrow
- [ ] Journal: CPU count, RAM, disk free, kernel tree location, and every error you hit

---

## Concepts

### 1. What WSL2 actually is, and why it works for kernel development

WSL2 is not an emulator and not a compatibility layer. It is a **real Linux kernel running in a
lightweight virtual machine** managed by Hyper-V. When you type `uname -r` inside WSL you get a genuine
Linux version string, because there is a genuine Linux kernel there — Microsoft's, built from
[microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel).

That matters for us in three ways:

- **Building works perfectly.** The kernel build system is a pile of shell, `make`, Perl, and Python
  that assumes a Unix environment. WSL2 provides exactly that. Build times will be within a few
  percent of native Linux on the same hardware.
- **You will not run your kernel as the WSL kernel.** You *can* replace the WSL2 kernel with your own,
  but you should not — a broken kernel then means a broken WSL install. Instead you run your kernels in
  **QEMU guests** inside WSL, where a crash costs you nothing. That is what Day 3 sets up.
- **The boundary is the filesystem.** This is the one thing people get wrong, so it gets its own
  section.

### 2. Why the filesystem choice is not a detail

WSL gives you two filesystems, and they perform very differently:

| Path | What it is | Speed |
|------|-----------|-------|
| `/home/you/...`, `/opt`, `/usr` | **ext4 inside a virtual disk** (`ext4.vhdx`) that WSL owns | Native Linux speed |
| `/mnt/c/...` | Your Windows drive, bridged over a network-style protocol (9p / drvfs) | **Several times slower**, and far worse for many small files |

A kernel build touches tens of thousands of small files and does an enormous number of `stat()` calls.
Every one of those crosses the bridge if your tree is on `/mnt/c/`. The difference is not 10% — people
routinely report builds taking **3-10x longer** on `/mnt/c/`.

So the rule for this entire roadmap:

> **Kernel source, build output, and toolchains live on WSL's own filesystem (`~/...`).**
> Notes and the git repo can live on Windows. Never build on `/mnt/c/`.

This is also why the repo has `sync_from_repo.sh` / `sync_to_repo.sh` — they move *source code* between
the Windows git repo and the WSL working area, so you get fast builds and version control at the same
time.

### 3. Disk space, and where it goes

40 GB is the floor, not a generous estimate. Where it goes:

```text
Linux git tree, full history      ~5 GB     (.git is most of it)
One defconfig build               ~2-3 GB
One build with debug info         ~15-25 GB (vmlinux with full DWARF is enormous)
ccache                            up to whatever you allow (20 GB is sane)
A second architecture or config   multiply the build cost again
```

You will want `CONFIG_DEBUG_INFO` on, because you cannot decode an oops or use `gdb` without it. So
budget for the debug build, not the small one.

**WSL disk mechanics worth knowing:** WSL2 stores your Linux filesystem in a dynamically-expanding
`ext4.vhdx` file on Windows. It **grows on demand but does not shrink automatically** when you delete
files. If you fill it up with build artifacts and then `make clean`, Linux sees free space again but the
VHDX stays large on the Windows side. Reclaiming that requires a manual compact operation. Practical
consequence: keep an eye on `df -h` and do not treat disk as infinite.

### 4. What each build dependency is actually for

Most guides give you a package list to paste. Knowing what each one does is what lets you diagnose a
build failure in month three instead of googling the error.

| Package | What it provides | Where the kernel build uses it |
|---------|-----------------|-------------------------------|
| `build-essential` | `gcc`, `g++`, `make`, libc headers | Everything. The baseline C toolchain |
| `flex` | Lexical analyzer generator | Builds the **Kconfig** parser in `scripts/kconfig/`. Without it, `make menuconfig` cannot even be built |
| `bison` | Parser generator | Same — the Kconfig grammar |
| `bc` | Arbitrary-precision calculator | Kbuild computes timer constants at build time with a `bc` script (`kernel/time/timeconst.bc`) |
| `libssl-dev` | OpenSSL headers | Module signing (`scripts/sign-file`) and certificate handling |
| `libelf-dev` | ELF file manipulation | **`objtool`**, which validates every function's stack usage and control flow. Also BTF generation |
| `libncurses-dev` | Terminal UI library | `make menuconfig`. Without it you only get `make config`, which asks you thousands of questions one at a time |
| `dwarves` | Provides **`pahole`** | Converts DWARF debug info into **BTF** for `CONFIG_DEBUG_INFO_BTF` — the type information eBPF depends on |
| `cpio` | Archive tool | Building **initramfs** images |
| `rsync` | File sync | `make headers_install` and several install targets |
| `zstd` | Compression | Compressed kernel images and compressed modules (`CONFIG_MODULE_COMPRESS_ZSTD`) |
| `kmod` | `insmod`, `rmmod`, `modprobe`, `depmod` | Loading your modules |
| `git` | Version control | The kernel *is* a git repository, and `git` is a kernel development tool, not just storage |
| `ccache` | Compiler cache | See below — this one changes your daily life |

The pattern to notice: **the kernel builds its own build tools.** `flex`, `bison`, and `libncurses` are
not needed to compile kernel C code — they are needed to compile the *configuration system* that
decides which kernel C code to compile. That is why their absence produces such confusing errors.

### 5. Why LLVM/Clang, when the kernel is famously a GCC project

The kernel builds fine with GCC. We are installing Clang because of **Rust**, for two separate reasons:

**Reason one: one code generator, not two.**
`rustc`'s backend is LLVM. If you compile the C half of the kernel with GCC and the Rust half with
`rustc`/LLVM, you have two different compilers making independent decisions about target features,
sanitizer instrumentation, stack protection, and LTO. Most of the time that is fine; when it is not,
the failures are deeply unpleasant. Building the whole thing with `LLVM=1` puts one code generator in
charge of everything, and it is the configuration the Rust-for-Linux developers actually test. That is
why every kernel Rust command in this roadmap carries `LLVM=1`.

**Reason two: `bindgen` needs `libclang`.**
The kernel's Rust support does not hand-write its FFI declarations. It runs **`bindgen`** over the C
headers to generate `rust/bindings/bindings_generated.rs` automatically. `bindgen` parses C by linking
against **libclang** — the actual Clang parser as a shared library. So `libclang-dev` is not optional
even in theory: without it, `bindgen` cannot read a single kernel header, and the Rust build cannot
start.

What `LLVM=1` actually switches: not just the compiler, but the whole toolchain — `clang` instead of
`gcc`, `ld.lld` instead of `ld`, `llvm-ar`, `llvm-nm`, `llvm-objcopy`, `llvm-objdump`, `llvm-strip`
instead of the binutils equivalents. That is why we install `llvm` and `lld`, not just `clang`.

### 6. KVM, hardware virtualization, and why nesting is involved

**The hardware layer.** Modern x86 CPUs have virtualization extensions — Intel **VT-x**, AMD **AMD-V**.
These add a CPU mode where guest code runs *directly on the silicon* at near-native speed, and only
privileged operations (accessing page tables, I/O, certain registers) trap out to the hypervisor.

**The kernel layer.** **KVM** (Kernel-based Virtual Machine) is the Linux module that exposes those
extensions to userspace, through the device node **`/dev/kvm`**. It is an `ioctl` interface: create a
VM, add memory, add vCPUs, run. That is genuinely all it is — KVM does not emulate hardware.

**The userspace layer.** QEMU does the hardware emulation (disks, network cards, serial ports, PCI) and
asks KVM to execute the guest's CPU instructions. QEMU + KVM together are a full machine.

**Without KVM**, QEMU falls back to **TCG** (Tiny Code Generator), which JIT-translates guest
instructions into host instructions in software. It is correct and it works — but expect roughly
**10-20x slower**. For our purposes: a kernel boot that takes 2 seconds with KVM takes 30+ without.
Survivable, but it will erode your willingness to iterate.

**Why "nested".** WSL2 is *itself* a virtual machine running under Hyper-V. Running QEMU/KVM inside it
means running a hypervisor inside a hypervisor, which requires the outer hypervisor to expose VT-x to
its guest. That is **nested virtualization**, and Windows 11 enables it by default on x86.

Two things can still go wrong, and neither is a crisis:

1. **The module is not loaded.** WSL's kernel has KVM built as a module, and it is not always loaded at
   boot. `sudo modprobe kvm_intel` (or `kvm_amd`) fixes it, and a `wsl.conf` boot command makes it stick.
2. **Permissions.** `/dev/kvm` may exist but not be readable by you. Fix the group and mode.

If `/dev/kvm` genuinely will not appear — some managed or locked-down Windows configurations restrict
nested virtualization — **do not let it block you today.** Note it in your journal, use TCG, and revisit
it later. Nothing in the first two weeks depends on KVM speed.

> **Note for ARM64 Windows machines:** this cannot be made to work. WSL boots its VM at exception level
> EL1, and KVM on ARM requires EL2. There is no configuration that fixes it. On x86, you are fine.

### 7. ccache: how it works and why kernel builds love it

A kernel build compiles on the order of **30,000 C files**. `ccache` sits in front of the compiler and,
for each file, hashes:

- the **preprocessed** source (so all `#include` content is baked in)
- the compiler flags
- the compiler version

If it has seen that exact hash before, it returns the cached `.o` file instead of compiling. A cache hit
costs milliseconds instead of hundreds of them.

The reason this is so effective for kernel work specifically: your daily loop involves switching
configs, switching branches, and rebuilding after `make clean` — all operations where the *vast
majority* of translation units produce byte-identical preprocessed output. Change one driver, and
ccache serves the other 29,999 files from cache.

**How it hooks in:** installing `ccache` creates symlinks in `/usr/lib/ccache/` named `gcc`, `cc`,
`clang`, and so on. Putting that directory *first* on your `PATH` means every compiler invocation goes
through ccache transparently — Kbuild does not need to know.

**One honest limitation:** ccache caches **C**, not Rust. `rustc` has its own incremental compilation
machinery, and the kernel's Rust build is a small fraction of total build time anyway. So ccache helps
enormously with the 30,000 C files and does nothing for the Rust ones. That is fine.

### 8. Why `git config user.name` is more serious than it looks

In most projects your git identity is cosmetic. In kernel development it is a legal artifact.

Every patch you send upstream must carry:

```text
Signed-off-by: Your Real Name <your@email>
```

That line is the **Developer's Certificate of Origin** (DCO). By adding it you are formally certifying
that you have the right to submit the code under the kernel's license. It is generated from your
`user.name` and `user.email` by `git commit -s`.

Consequences:

- **Use your real name**, spelled as you would sign a document. Pseudonyms and handles are not accepted.
- **Use an email you can receive mail at**, because the entire review process happens by email and
  people will reply to that address.
- Be deliberate about *which* email — personal versus work — because it signals who is contributing.
  If your employer has an open-source policy, this is one of the things it will have an opinion about.

You are not sending patches today. Set it correctly today anyway, so that a stray `git commit` months
from now does not produce a commit you have to redo.

---

## Step-by-Step

> **Two ways to do today, and you should pick the first one.**
>
> Everything in Phases 3, 6, and 7 is automated by
> [`codes/Month_1/Week_1/Day_1/install_deps.sh`](../../../codes/Month_1/Week_1/Day_1/install_deps.sh):
>
> ```bash
> bash "$LKDRUST_REPO/codes/Month_1/Week_1/Day_1/install_deps.sh"
> # or, the very first time, before $LKDRUST_REPO exists:
> bash "/mnt/c/Users/<you>/.../SKILL/LKD_RUST/codes/Month_1/Week_1/Day_1/install_deps.sh"
> ```
>
> It is idempotent, so re-running it is safe. It also derives `$LKDRUST_REPO` from its own location, so
> you do not have to paste a path.
>
> **Read the phases anyway.** The script is the *what*; the phases below are the *why*, and the why is
> the point of today. A package list you pasted teaches you nothing when a build fails in Month 3. So:
> run the script, then read Phases 3-7 and check each claim against your machine.
>
> Phases 0, 1, 2, 4, 5, and 8 still need you — they involve Windows-side edits, a restart, your real
> name, and judgment.

### Phase 0 — Confirm where you are

```bash
# Confirm WSL2, not WSL1
uname -r                    # a WSL2 kernel version, e.g. 6.x.y-microsoft-standard-WSL2
cat /etc/os-release         # confirm Ubuntu and its version

# Confirm you are on the Linux filesystem, not /mnt/c
pwd
df -h .                     # the filesystem should NOT be drvfs / 9p
```

From PowerShell on the Windows side, confirm the version is 2:

```powershell
wsl -l -v
```

If it says `VERSION 1`, convert it — WSL1 has no real kernel and cannot do any of this:

```powershell
wsl --set-version Ubuntu 2
```

### Phase 1 — Give WSL enough resources

Create or edit `%USERPROFILE%\.wslconfig` on **Windows** (not inside WSL). There is a fuller annotated
copy at [`codes/Month_1/Week_1/Day_1/wslconfig.example`](../../../codes/Month_1/Week_1/Day_1/wslconfig.example):

```ini
[wsl2]
memory=20GB
processors=18
swap=8GB
nestedVirtualization=true
```

**Sizing rule:** give WSL roughly two thirds of your RAM and cores and leave the rest to Windows. The
numbers above suit a 22-core / 31 GB host, which leaves Windows 4 cores and ~11 GB — enough for a
browser, Teams, Outlook, and the corporate security agents that you do not get to turn off. Starving
Windows makes the whole machine feel broken, and you will blame the kernel work.

Check your own host first, from PowerShell:

```powershell
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB
(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
```

**If this file does not exist, WSL uses defaults** — about half your RAM and all your cores. That is
survivable, which is exactly why it goes unnoticed; the reason to write the file is `nestedVirtualization`
and a swap size you chose deliberately.

Apply it:

```powershell
wsl --shutdown
```

Then reopen your terminal and verify inside WSL:

```bash
nproc                       # should match `processors`
free -h                     # should match `memory`
```

### Phase 2 — Check disk space

```bash
df -h "$HOME"
```

You want **40 GB free minimum**, 60+ to be comfortable. If you are short, the fix is on the Windows
side: free space on the drive holding your WSL VHDX, since the VHDX expands into it.

### Phase 3 — Update, then install build dependencies

```bash
sudo apt update && sudo apt upgrade -y
```

```bash
# Core kernel build dependencies
sudo apt install -y \
  build-essential \
  flex bison bc \
  libssl-dev libelf-dev libncurses-dev \
  dwarves \
  cpio rsync zstd kmod \
  git ccache pkg-config \
  python3 python3-pip
```

```bash
# LLVM / Clang toolchain — required for kernel Rust (LLVM=1) and for bindgen (libclang)
sudo apt install -y clang lld llvm libclang-dev
```

```bash
# QEMU — this is what actually RUNS the kernels you build. Day 3 depends on it,
# so install it now rather than discovering it missing when you need it.
#   qemu-system-x86  the x86_64 system emulator
#   qemu-utils       qemu-img, for building guest disk images
#   cpu-checker      kvm-ok, which explains WHY kvm is unavailable when it is
#   ovmf             UEFI firmware, for booting guests the way real machines boot
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker ovmf
```

```bash
# Debugging and upstream plumbing
#   gdb        decode an oops, and attach to a running QEMU guest via -s -S
#   trace-cmd  the ftrace frontend
#   git-email  git send-email — every upstream contribution goes through it, and
#              it is far easier to install now than to debug on the day you need it
sudo apt install -y gdb trace-cmd git-email
```

```bash
# Small quality-of-life additions used later in the week
sudo apt install -y file wget curl unzip tree
```

Verify the important ones report a version:

```bash
gcc --version | head -1
clang --version | head -1
ld.lld --version
make --version | head -1
flex --version
bison --version | head -1
bc --version | head -1
pahole --version
ccache --version | head -1
git --version
qemu-system-x86_64 --version | head -1
```

`pahole` is the one people forget to check — it comes from `dwarves`, not from a package called
`pahole`.

### Phase 4 — Verify KVM

```bash
# Does the device exist?
ls -l /dev/kvm
```

If it is missing, load the module for your CPU vendor:

```bash
# Intel (including Core Ultra)
sudo modprobe kvm_intel

# AMD
# sudo modprobe kvm_amd

lsmod | grep kvm
ls -l /dev/kvm
```

Check that it is usable, and confirm the CPU exposes the extensions:

```bash
kvm-ok                                  # from cpu-checker
grep -o -m1 -E 'vmx|svm' /proc/cpuinfo  # vmx = Intel VT-x, svm = AMD-V
```

**First, find out whether you need the boot command at all.** Many current WSL kernels load
`kvm_intel` automatically and create `/dev/kvm` with the right owner and mode without any help:

```bash
lsmod | grep kvm            # is the module already loaded?
stat -c '%A %U:%G' /dev/kvm  # want: crw-rw---- root:kvm
```

If the module is loaded and the mode is already `root:kvm` / `660`, **skip the boot command** — it
would be doing work that already happens. Go straight to the group step below, which is the part you
almost certainly do need.

Only if `/dev/kvm` is missing or wrongly owned after a restart, add the boot command to
`/etc/wsl.conf`:

```bash
sudo nano /etc/wsl.conf
```

> **Merge, do not paste.** `/etc/wsl.conf` very likely already has a `[boot]` section — this repo's
> setup puts `systemd=true` there. INI files must not contain the same section header twice; a second
> `[boot]` makes the parser drop one of the two settings, and you get either no systemd or no KVM fix,
> with no error message. Add the `command` line **inside the existing** `[boot]` section:

```ini
[boot]
systemd=true
command = "modprobe kvm_intel && while [ ! -e /dev/kvm ]; do sleep 0.1; done && chown root:kvm /dev/kvm && chmod 660 /dev/kvm"
```

> The `while` loop matters: `modprobe` returns before the device node necessarily appears, so chowning
> immediately can race and fail silently. Use `kvm_amd` instead if you are on AMD.

**This next step is the one that actually bites people.** `/dev/kvm` is owned by `root:kvm` with mode
`660`, so the file existing tells you nothing about whether *you* can open it. Every "is KVM working?"
check passes, and then QEMU fails with `Could not access KVM kernel module: Permission denied`. Add
yourself to the `kvm` group so you do not need `sudo` to run QEMU:

```bash
sudo usermod -aG kvm "$USER"
```

Then restart WSL from PowerShell and verify:

```powershell
wsl --shutdown
```

```bash
ls -l /dev/kvm      # expect: crw-rw---- root kvm
groups              # expect 'kvm' in the list
```

**If `/dev/kvm` still does not appear:** note it in your journal and move on. QEMU will use software
emulation. Nothing this week is blocked.

### Phase 5 — Configure git identity

```bash
git config --global user.name  "Your Real Name"
git config --global user.email "your@email"

# Sensible defaults for kernel work
git config --global init.defaultBranch main
git config --global core.editor nano          # or vim
git config --global pull.rebase true          # linear history; the kernel does not use merge commits
git config --global log.date iso

# Verify
git config --global --list | grep -E 'user\.|init\.|pull\.'
```

### Phase 6 — Configure ccache

```bash
# Give it a real cache size — the default (a few GB) is too small for kernel builds
ccache --max-size=20G

# Put ccache's compiler symlinks first on PATH
echo 'export PATH="/usr/lib/ccache:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify it is intercepting
which gcc                # expect /usr/lib/ccache/gcc
which clang              # expect /usr/lib/ccache/clang
ls /usr/lib/ccache/      # see the symlinks it created
ccache -s                # statistics; all zeros so far, that is correct
```

If `which gcc` still shows `/usr/bin/gcc`, your `PATH` edit did not take effect — open a new shell, or
check that `~/.bashrc` is actually being sourced.

### Phase 7 — Decide where the kernel tree will live

You are not cloning today, but decide now and create the directory, so tomorrow has no decisions in it.

Recommended layout inside WSL:

```text
~/LKD_RUST/                  # your WSL working area
├── Month_1/Week_1/          # scratch space for today's experiments
├── kernel/                  # kernel trees live here — NEVER committed to git
│   └── linux/               # cloned tomorrow (M1W1D2)
└── codes/                   # scripts synced from the Windows git repo
```

```bash
mkdir -p ~/LKD_RUST/kernel
mkdir -p ~/LKD_RUST/codes

# Record the location as an environment variable so every later script can find it
echo 'export LINUX_TREE="$HOME/LKD_RUST/kernel/linux"' >> ~/.bashrc
source ~/.bashrc
echo "$LINUX_TREE"
```

While you are editing `~/.bashrc`, add the path to the Windows-side git repo too. Keeping it in
`.bashrc` rather than in a committed file means no personal paths ever end up in the repository:

```bash
# Adjust to your actual repo path. Note the double quotes — Windows paths under
# Documents or a synced cloud folder often contain spaces, and unquoted the path
# would be split on them, silently setting LKDRUST_REPO to just the first word.
echo 'export LKDRUST_REPO="/mnt/c/Users/<you>/path/to/SKILL/LKD_RUST"' >> ~/.bashrc
source ~/.bashrc
ls "$LKDRUST_REPO"
```

> **`install_deps.sh` already does all of Phase 7** — it creates the three directories, exports
> `LINUX_TREE`, adds `~/.local/bin` and `~/.cargo/env` to your shell, and derives `LKDRUST_REPO` from
> its own location so you never paste that path. If you ran the script, just verify the result:
> `echo "$LINUX_TREE"` and `ls "$LKDRUST_REPO"`.

> **Why the kernel tree is not in the repo:** it is upstream Linux — 5 GB of someone else's history.
> It gets cloned fresh, not committed. `.gitignore` already blocks `linux/` and every build artifact
> for exactly this reason.

**`$LINUX_TREE` must never point under `/mnt/`.** This is the decision Phase 7 exists to get right, and
it is not just about speed. On the Windows filesystem you also lose the executable bit and symlinks
that the kernel tree depends on — and if the path sits inside a synced cloud folder, the sync client
will try to upload roughly 100,000 files and may swap them for cloud placeholders in the middle of a
build. `check_day1.sh` **fails** rather than warns if `$LINUX_TREE` is under `/mnt/`, so this cannot
drift without you noticing.

### Phase 8 — Record the machine

```bash
{
  echo "# Environment as of $(date -Iseconds)"
  echo
  echo "## Host"
  uname -a
  echo
  echo "## OS"
  cat /etc/os-release | head -3
  echo
  echo "## CPU"
  lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core|Socket|Virtualization'
  echo
  echo "## Memory"
  free -h
  echo
  echo "## Disk"
  df -h "$HOME"
  echo
  echo "## Toolchain"
  gcc --version | head -1
  clang --version | head -1
  ld.lld --version | head -1
  make --version | head -1
  pahole --version
  ccache --version | head -1
  git --version
  echo
  echo "## KVM"
  ls -l /dev/kvm 2>&1
  lsmod | grep kvm || echo "no kvm modules loaded"
  echo
  echo "## Paths"
  echo "LINUX_TREE=$LINUX_TREE"
} | tee ~/LKD_RUST/Month_1/Week_1/env_day1.txt
```

> **There is a script for this**, and it captures more than the block above — header packages,
> `libclang`, ccache interception, and your `PATH`:
> [`codes/Month_1/Week_1/Day_1/record_env.sh`](../../../codes/Month_1/Week_1/Day_1/record_env.sh).
> Run `bash "$LKDRUST_REPO/codes/Month_1/Week_1/Day_1/record_env.sh"` and use the inline block above
> only if you want to see what it is doing.

Copy the interesting numbers into the journal section below, and into **`_internal/SETUP_LOG.md`**,
which is the long-lived record referenced by `SETUP.md`. That file lives in `_internal/` because it
contains your hostname and local paths, so it is git-ignored by design — see
[`_internal/README.md`](../../../_internal/README.md).

The full dump stays in `env_day1.txt`. When something mysteriously stops working in Month 4, diffing
two of these files is the fastest way to find out what changed underneath you.

---

## Verification

Run the Day 1 check script:

```bash
bash "$LKDRUST_REPO/codes/Month_1/Week_1/Day_1/check_day1.sh"
```

Or verify by hand — every one of these should succeed:

```bash
uname -r | grep -q WSL2 && echo "WSL2 ok"
[ "$(df -Pk "$HOME" | awk 'NR==2{print int($4/1048576)}')" -ge 40 ] && echo "disk ok"
for c in gcc clang ld.lld make flex bison bc pahole ccache git qemu-system-x86_64 gdb; do
  command -v "$c" >/dev/null && echo "$c ok" || echo "$c MISSING"
done
[ -e /dev/kvm ] && echo "kvm ok" || echo "kvm absent (not blocking)"
id -nG | tr ' ' '\n' | grep -qx kvm && echo "kvm group ok" || echo "NOT in kvm group — QEMU will be denied"
[ -n "$(git config --global user.name)" ] && echo "git identity ok"
case ":$PATH:" in *:/usr/lib/ccache:*) echo "ccache on PATH ok";; *) echo "ccache NOT on PATH";; esac
[ -d "$HOME/LKD_RUST/kernel" ] && echo "kernel dir ok"
```

---

## Gotchas

- **`dwarves` provides `pahole`.** Searching for a package called `pahole` finds nothing, and the build
  failure it causes (missing BTF) appears very late and looks unrelated.
- **`libclang-dev`, not `clang` alone.** `clang` gives you the compiler binary; `bindgen` needs the
  *library*. You can have a perfectly working Clang and still be unable to build kernel Rust.
- **`/dev/kvm` can exist but be unusable.** Check the mode and group, not just existence. "Permission
  denied" from QEMU is a permissions problem, not a missing-KVM problem.
- **`modprobe` returns before the device node appears.** Chowning `/dev/kvm` immediately after
  `modprobe` in a boot script can race. Hence the `while [ ! -e /dev/kvm ]` loop.
- **`wsl.conf` is inside WSL; `.wslconfig` is on Windows.** Two different files, similar names, very
  different scopes. `/etc/wsl.conf` configures one distro; `%USERPROFILE%\.wslconfig` configures the
  WSL2 VM globally. Putting a setting in the wrong one silently does nothing.
- **Never write a second `[boot]` section in `/etc/wsl.conf`.** If the file already has one (this setup
  puts `systemd=true` there), add your `command` line *inside* it. A duplicate section header makes the
  parser drop one of the two settings, with no error — you lose either systemd or the KVM fix, and it
  looks like the setting simply had no effect.
- **`groups` does not update until the VM restarts.** `usermod -aG kvm` edits `/etc/group`, but your
  running shell keeps the group list it was started with. `wsl --shutdown` is what applies it — a new
  terminal window is not enough.
- **`wsl --shutdown` is required** for `.wslconfig` and `wsl.conf` changes. Closing the terminal is not
  enough; the VM keeps running in the background.
- **ccache's `PATH` order is the whole trick.** If `/usr/lib/ccache` is not *before* `/usr/bin`, ccache
  is installed and doing nothing.
- **Do not put the kernel tree on `/mnt/c/`.** It will work, and it will be slow enough to make you
  quit. This is the single most common self-inflicted wound in WSL kernel development.
- **The WSL VHDX grows but does not shrink.** Deleting build output frees space for Linux but not for
  Windows. Watch `df -h` over the coming weeks.
- **`sudo apt upgrade` can pull a new kernel package** for the Ubuntu userland that WSL ignores (WSL
  supplies its own kernel). Harmless, occasionally confusing.

---

## My Notes

*(Fill this in as you work. This is the part that is worth something in six months.)*

### Machine

| Property | Value |
|----------|-------|
| CPU model | |
| CPU count (`nproc`) | |
| RAM (`free -h`) | |
| Disk free in `$HOME` | |
| WSL kernel (`uname -r`) | |
| Ubuntu version | |
| `/dev/kvm` present? | |

### Toolchain versions

| Tool | Version |
|------|---------|
| gcc | |
| clang | |
| ld.lld | |
| pahole | |
| ccache | |
| git | |

### Paths

| What | Where |
|------|-------|
| Kernel tree (`$LINUX_TREE`) | |
| WSL working area | |
| Windows git repo (`$LKDRUST_REPO`) | |

### What went wrong, and how I fixed it

### What I did not understand yet

### One thing I can now explain that I could not this morning

---

## Done When

- [ ] `uname -r` confirms WSL2 with a real Linux kernel version
- [ ] 40+ GB free in `$HOME`, on the Linux filesystem
- [ ] Every tool in the verification block reports a version
- [ ] `pahole --version` works (proving `dwarves` is installed, not just assumed)
- [ ] `libclang-dev` installed — you can explain why `bindgen` needs it
- [ ] `qemu-system-x86_64 --version` works
- [ ] `/dev/kvm` exists with sane permissions, **or** you have written down why it does not and moved on
- [ ] `groups` lists `kvm` — and you can explain why the device existing was not sufficient
- [ ] `git config user.name` is your real name, and you can explain what the DCO is
- [ ] `which gcc` returns `/usr/lib/ccache/gcc`
- [ ] `$LINUX_TREE` and `$LKDRUST_REPO` are set in `~/.bashrc` and the directories exist
- [ ] `env_day1.txt` written, and the numbers copied into the journal table above and `_internal/SETUP_LOG.md`
- [ ] You can explain, without notes, why the kernel tree must not live on `/mnt/c/`
- [ ] **`check_day1.sh` exits 0** — no failures. Warnings are acceptable if you wrote down why

---

## Reading

- `Documentation/process/changes.rst` — the kernel's own list of minimum tool versions. You have no
  tree yet; read it at [docs.kernel.org/process/changes.html](https://docs.kernel.org/process/changes.html)
  and notice how many of today's packages appear there
- [Microsoft's WSL2 kernel repo](https://github.com/microsoft/WSL2-Linux-Kernel) — skim the README, so
  the WSL kernel stops being magic
- Optional, five minutes: `man ccache`, the "How it works" section

---

**Next:** M1W1D2 — Clone and Build Mainline. Tomorrow you compile 30,000 C files for the first time,
and find out what your build time actually is.

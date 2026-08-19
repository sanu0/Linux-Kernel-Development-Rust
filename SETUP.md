# SETUP — Build Your Kernel Development Lab

> **This is Week 0.** Do it before anything else. Every later week assumes this works.
> **Success criteria:** you can edit a kernel source file, build, and be at a shell inside your own
> Rust-enabled kernel **in under 60 seconds**, and `git send-email` can actually send mail.
>
> Budget: 3-5 evenings. It will take longer than you expect. That is normal and it is worth it.

---

## Contents

- [The Three Environments You Need](#the-three-environments-you-need)
- [Step 1 — WSL2 Ubuntu](#step-1--wsl2-ubuntu)
- [Step 2 — Enable KVM](#step-2--enable-kvm)
- [Step 3 — Build Dependencies](#step-3--build-dependencies)
- [Step 4 — Clone the Kernel](#step-4--clone-the-kernel)
- [Step 5 — First Build and Boot (C only)](#step-5--first-build-and-boot-c-only)
- [Step 6 — The Fast Boot Loop with virtme-ng](#step-6--the-fast-boot-loop-with-virtme-ng)
- [Step 7 — The Rust Toolchain](#step-7--the-rust-toolchain)
- [Step 8 — Enable CONFIG_RUST and Boot It](#step-8--enable-config_rust-and-boot-it)
- [Step 9 — Load a Rust Sample Module](#step-9--load-a-rust-sample-module)
- [Step 10 — Editor and Docs](#step-10--editor-and-docs)
- [Step 11 — git send-email and b4](#step-11--git-send-email-and-b4)
- [Step 12 — Subscribe and Lurk](#step-12--subscribe-and-lurk)
- [Step 13 — Order Your Hardware](#step-13--order-your-hardware)
- [Verify Everything](#verify-everything)
- [Cross-Compilation (do this in Month 12, not now)](#cross-compilation-do-this-in-month-12-not-now)
- [Common Problems](#common-problems)

---

## The Three Environments You Need

| Environment | Role | Why |
|-------------|------|-----|
| **Windows host** | Git, editor, this repo | Where the notes live and where you commit from |
| **WSL2 Ubuntu** | Kernel builds, toolchains, QEMU | The kernel build system is Linux-only in practice |
| **QEMU guest** | Running your kernel | Because you will crash it, repeatedly, and rebooting your laptop each time is not a workflow |

Code lives in **two places on purpose**: the git-tracked copy under `LKD_RUST/codes/` on Windows, and the
working copy inside WSL where you actually build and run. The `sync_from_repo.sh` / `sync_to_repo.sh`
scripts in `codes/` bridge them. See [`codes/README.md`](codes/README.md).

**Where the kernel tree itself lives:** inside WSL's own filesystem, at
`~/LKD_RUST/kernel/linux`, **not** on `/mnt/c/`. That path is exported as **`$LINUX_TREE`** by
`install_deps.sh`, and every command in this document uses the variable rather than a literal path —
so there is exactly one place to change if you ever move it.

Building on the Windows filesystem through the 9p bridge is several times slower, and NTFS does not
preserve the executable bit or the symlinks the kernel tree relies on. If the path is also inside a
synced cloud folder, the sync client will additionally try to upload roughly 100,000 files and may swap
them for cloud placeholders in the middle of a build. `check_day1.sh` fails hard if `$LINUX_TREE`
points anywhere under `/mnt/`.

The kernel tree is not in git here anyway — it is upstream Linux, cloned fresh.

### If this repo lives in a synced cloud folder

OneDrive, Dropbox, Google Drive — the same three concerns apply to any of them, and they are worth
keeping apart. A synced folder is fine for the repo and specifically **not** fine for the kernel tree.

**1. The kernel tree — must never be in a synced folder.** ~100,000 files the sync client would try to
upload, churning constantly as you build. It lives on WSL's ext4 at `$LINUX_TREE`, which the Windows
sync client cannot see. `check_day1.sh` fails hard if `$LINUX_TREE` is under `/mnt/`, so this cannot
drift by accident.

**2. The repo itself — fine to sync, but pin it.** A few megabytes of text; free offsite backup.
The hazard is **on-demand hydration**: the sync client can replace any file with a cloud placeholder to
reclaim space. A dehydrated file breaks `git`, and breaks WSL reading these scripts over `/mnt/c`. Pin
the whole tree so content is always local:

```powershell
# From the SKILL folder, in PowerShell. +P = "Always keep on this device".
attrib +P /s /d ".\LKD_RUST\*"
attrib +P /s /d ".\LKD_RUST\.git\*"     # hidden, so it needs its own pass

# Verify: this should print 0
(Get-ChildItem .\LKD_RUST -Force -Recurse -File |
  Where-Object { -not ($_.Attributes.value__ -band 0x80000) }).Count
```

Re-run this after adding large new subtrees. Right-clicking the folder and choosing
*Always keep on this device* does the same thing.

**3. `.git` and file sync are an imperfect pair.** A sync client copying `.git/` while git is mid-write
can corrupt the index or an object. Pinning removes the dehydration half of the problem but not this
half. The real mitigation is a **git remote**: once you have pushed, the remote is your backup and the
synced copy of `.git` is redundant. Push early, push often, and do not treat file sync as the safety net
for your history.

> **Do not "fix" this by moving the repo into WSL.** Git on Windows plus builds in WSL is the design
> the sync scripts implement, and it is deliberate. The split is the point.

---

## Step 1 — WSL2 Ubuntu

```powershell
# In PowerShell, as your normal user
wsl --install -d Ubuntu
wsl --set-default-version 2
wsl --update
wsl -l -v          # confirm VERSION is 2
```

Give WSL enough resources. Create `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=20GB
processors=12
swap=8GB
nestedVirtualization=true
```

Adjust to your machine — leave the host at least 8 GB of RAM and a couple of cores. Then:

```powershell
wsl --shutdown
```

**Disk space:** a kernel tree with full history is ~5 GB, and a build tree with debug info can be
20+ GB. Plan on **60 GB free** inside WSL. Check with `df -h ~` after you start.

---

## Step 2 — Enable KVM

Nested virtualization is on by default on Windows 11 x86, but the module is not always loaded.

```bash
# Inside WSL
ls -l /dev/kvm || sudo modprobe kvm_intel   # use kvm_amd on AMD
lsmod | grep kvm
```

To make it persistent and give your user access, add to `/etc/wsl.conf` inside WSL:

```ini
[boot]
command = "modprobe kvm_intel && while [ ! -e /dev/kvm ]; do sleep 0.1; done && chown root:kvm /dev/kvm && chmod 660 /dev/kvm"
```

Then add yourself to the group and restart WSL from PowerShell:

```bash
sudo usermod -aG kvm "$USER"
```

```powershell
wsl --shutdown
```

Verify:

```bash
ls -l /dev/kvm       # should exist, group kvm, mode 660
kvm-ok               # from cpu-checker, if installed
```

> **Note:** nested virtualization is x86-only. On an ARM64 Windows machine, WSL boots at EL1 and KVM
> needs EL2, so there is no workaround. Use QEMU's TCG (software) emulation, which works but is slow.

**Without KVM, QEMU still works** — just slower. Do not let this block you; fix it later if you must.

---

## Step 3 — Build Dependencies

```bash
sudo apt update && sudo apt upgrade -y

# Kernel build essentials
sudo apt install -y build-essential flex bison bc bison libssl-dev libelf-dev \
  libncurses-dev dwarves cpio rsync zstd kmod pahole \
  git ccache pkg-config python3 python3-pip

# LLVM/Clang — the kernel's Rust support wants LLVM=1
sudo apt install -y clang lld llvm libclang-dev

# QEMU and virtualization tooling
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker

# Debugging and tracing
sudo apt install -y gdb trace-cmd linux-tools-common fio

# Device tree tooling (for Month 14 onward)
sudo apt install -y device-tree-compiler yamllint

# dtschema is not packaged, so it needs pipx. Modern Ubuntu marks its Python
# installation "externally managed" (PEP 668) and refuses `pip3 install --user`
# outright; pipx sidesteps that by giving each tool its own venv.
sudo apt install -y pipx && pipx ensurepath
pipx install dtschema
```

Turn on `ccache` — it will cut your rebuild times substantially:

```bash
ccache --max-size=20G
echo 'export PATH="/usr/lib/ccache:$PATH"' >> ~/.bashrc
source ~/.bashrc
ccache -s
```

Verify your LLVM version — the kernel documents a minimum:

```bash
clang --version
ld.lld --version
```

---

## Step 4 — Clone the Kernel

```bash
# $LINUX_TREE is ~/LKD_RUST/kernel/linux — clone into its parent so the tree lands
# exactly where every later script expects to find it.
mkdir -p "$(dirname "$LINUX_TREE")" && cd "$(dirname "$LINUX_TREE")"

# Mainline. This is a big clone; be patient.
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd "$LINUX_TREE"

# Remotes you will need later
git remote add next  https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git remote add rfl   https://github.com/Rust-for-Linux/linux.git
git remote add stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

# Fetch tags only for now; full remote fetches are large
git fetch --tags origin
```

> **Bandwidth tip:** if a full clone is painful, use `git clone --depth=1` to start, then
> `git fetch --unshallow` later. You **will** need full history eventually — `git blame`,
> `git bisect`, and `Fixes:` tags all depend on it.

Check what release you are on:

```bash
make kernelversion
git log --oneline -1
```

---

## Step 5 — First Build and Boot (C only)

Get a plain C kernel building and booting before you add Rust to the equation. One variable at a time.

```bash
cd "$LINUX_TREE"
make defconfig
time make -j"$(nproc)"
```

Write down the build time. Then boot it manually so you understand what the tooling will hide:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 2G -smp 4 \
  -kernel arch/x86/boot/bzImage \
  -append "console=ttyS0 panic=1" \
  -nographic \
  -no-reboot
```

It will boot and then panic with "No working init found" — **that is success.** You booted your own
kernel; it just has no root filesystem. Exit QEMU with `Ctrl-A` then `X`.

---

## Step 6 — The Fast Boot Loop with virtme-ng

`virtme-ng` boots your compiled kernel using **your existing WSL filesystem** as the root, so you get
a real shell with your tools, with no disk image to build. This is the single most important
productivity tool in this roadmap.

```bash
# Ubuntu packages virtme-ng, which is the least fragile way to install it.
# Do NOT use `pip3 install --user virtme-ng` — modern Ubuntu marks its Python
# installation "externally managed" (PEP 668) and that command fails outright.
sudo apt install -y virtme-ng

# If your distro does not package it, use pipx rather than fighting pip:
#   sudo apt install -y pipx && pipx ensurepath && pipx install virtme-ng

vng --version

cd "$LINUX_TREE"
vng --build          # builds a config tuned for virtme
vng                  # boots it and drops you at a shell
```

Inside the guest:

```bash
uname -a             # confirm it is YOUR kernel
exit                 # back to the host
```

Run a single command in the guest and come straight back — this is the loop you will live in:

```bash
vng --exec 'uname -r'
vng --exec 'dmesg | tail -30'
```

**Save your commands as scripts** in `codes/Month_1/Week_1/Day_1/`. You will run them thousands of times.

### Timing your loop

```bash
time (touch kernel/sched/core.c && make -j"$(nproc)" && vng --exec 'uname -r')
```

Target: under 60 seconds for an incremental build plus boot. If it is much slower:
- Confirm `ccache` is active (`ccache -s` should show hits)
- Confirm the tree is on WSL's filesystem, not `/mnt/c/`
- Give WSL more cores in `.wslconfig`
- Build only the module you changed (`make M=drivers/foo` or `make drivers/foo/bar.ko`) when possible

---

## Step 7 — The Rust Toolchain

**Read this first:** `Documentation/rust/quick-start.rst` in your tree is the authoritative document,
and it is kept current. Everything below is a summary of it.

The critical rule: **`make LLVM=1 rustavailable` is the only source of truth for which versions you
need.** Never hardcode a version from a tutorial, including this one.

```bash
# Install rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

cd "$LINUX_TREE"

# Ask the tree what it wants
scripts/min-tool-version.sh rustc
scripts/min-tool-version.sh bindgen

# Install exactly that rustc, plus the standard library source and tools
RUSTC_VER="$(scripts/min-tool-version.sh rustc)"
rustup toolchain install "$RUSTC_VER"
rustup component add rust-src clippy rustfmt --toolchain "$RUSTC_VER"

# Pin this tree to that toolchain so you do not have to remember
rustup override set "$RUSTC_VER"

# bindgen at the version the tree wants
BINDGEN_VER="$(scripts/min-tool-version.sh bindgen)"
cargo install --locked --version "$BINDGEN_VER" bindgen-cli
```

Now the moment of truth:

```bash
make LLVM=1 rustavailable
```

You want: **`Rust is available!`**

If it complains, read the message literally — it tells you exactly which tool and which version is
wrong. Iterate until it passes. Do not proceed until it does.

> **Why `LLVM=1`?** Kernel Rust needs `rustc`'s LLVM and the C compiler's LLVM to agree on code
> generation and target features. Building the C side with Clang/LLD avoids a class of mismatch
> problems. GCC-built Rust kernels are possible in some configurations but `LLVM=1` is the well-trodden
> path — use it.

**Record your working versions** in `SETUP_LOG.md`. When something breaks in three months, this file
will save you an evening.

---

## Step 8 — Enable CONFIG_RUST and Boot It

```bash
cd "$LINUX_TREE"
make LLVM=1 defconfig

# Enable Rust and the samples
scripts/config --enable RUST
scripts/config --enable SAMPLES
scripts/config --enable SAMPLES_RUST
scripts/config --module SAMPLE_RUST_MINIMAL
scripts/config --module SAMPLE_RUST_PRINT
scripts/config --module SAMPLE_RUST_MISC_DEVICE

# Debug options you will want from day one
scripts/config --enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --enable DEBUG_KERNEL
scripts/config --enable DEBUG_FS
scripts/config --enable PROVE_LOCKING
scripts/config --enable DEBUG_ATOMIC_SLEEP
scripts/config --enable DEBUG_OBJECTS
scripts/config --enable RUST_DEBUG_ASSERTIONS
scripts/config --enable RUST_OVERFLOW_CHECKS
scripts/config --enable RUST_KERNEL_DOCTESTS

make LLVM=1 olddefconfig
grep -E 'CONFIG_RUST=|CONFIG_SAMPLES_RUST=|CONFIG_PROVE_LOCKING=' .config
```

If `CONFIG_RUST` refuses to stay set, `rustavailable` is not actually passing — go back to Step 7.

Build and boot:

```bash
time make LLVM=1 -j"$(nproc)"
vng --build --config .config    # or: vng (no --build) with your existing build
vng --exec 'uname -a; ls /sys/kernel/debug | head'
```

> **Note:** `PROVE_LOCKING` and the `DEBUG_*` options slow the kernel down significantly. That is
> exactly what you want during development — they catch bugs you would otherwise ship. Keep a
> separate "fast" config profile for benchmarking (this is what KernelForge's config profiles are for).

---

## Step 9 — Load a Rust Sample Module

```bash
# Build the sample modules
make LLVM=1 -j"$(nproc)" samples/rust/

# Boot and load one
vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -20; rmmod rust_minimal; dmesg | tail -5'
```

You should see the module's init and exit messages in `dmesg`.

**This is the milestone.** You now have a Rust-enabled kernel that you built, booted, and loaded Rust
code into. Everything in the roadmap builds on this.

Write it down in `SETUP_LOG.md`: the date, the kernel version, the toolchain versions, and the `dmesg`
output. This is the first entry in an 18-month record.

---

## Step 10 — Editor and Docs

### rust-analyzer for kernel Rust

```bash
cd "$LINUX_TREE"
make LLVM=1 rust-analyzer
ls rust-project.json     # generated
```

Then open the tree in your editor. For VS Code / Cursor connected to WSL, install the
**rust-analyzer** extension; it will pick up `rust-project.json` automatically. Add to your workspace
settings if it does not:

```json
{
  "rust-analyzer.linkedProjects": ["./rust-project.json"],
  "rust-analyzer.cargo.buildScripts.enable": false,
  "rust-analyzer.check.overrideCommand": null,
  "rust-analyzer.checkOnSave": false
}
```

Regenerate `rust-project.json` whenever you change your config or pull new commits.

### The kernel Rust API docs

```bash
make LLVM=1 rustdoc
# open Documentation/output/rust/rustdoc/kernel/index.html
```

These are the docs you will live in. The same content is online at
[rust.docs.kernel.org/kernel/](https://rust.docs.kernel.org/kernel/) — bookmark it.

### C navigation

Rust-analyzer handles the Rust half. For the C half, either:

```bash
make LLVM=1 compile_commands.json    # for clangd
# or
make cscope tags                     # for classic navigation
```

You will read a great deal of C. Make it fast.

---

## Step 11 — git send-email and b4

**This blocks every contribution you will ever make. Do it now, while nothing depends on it.**

```bash
sudo apt install -y git-email
```

Configure. For Gmail you must use an **App Password**, not your account password:

```bash
git config --global user.name  "Your Real Name"
git config --global user.email "you@example.com"

git config --global sendemail.smtpServer     smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser       you@example.com
# Leave the password out of config; git will prompt, or use a credential helper
```

Test it by sending yourself a real patch:

```bash
cd "$LINUX_TREE"
# Make a trivial local change to something harmless
git commit -s -am "docs: test patch, do not submit"
git format-patch -1 -o /tmp/testpatch
git send-email --to=you@example.com --dry-run /tmp/testpatch/*.patch   # inspect first
git send-email --to=you@example.com /tmp/testpatch/*.patch             # actually send
```

Check the received mail: it must be **plain text**, with the diff intact and no line-wrapping damage.
If the patch does not apply cleanly from the received mail, your setup is broken — fix it now.

Then undo your test commit:

```bash
git reset --hard HEAD~1
```

### b4 — the modern workflow tool

```bash
# Packaged by Ubuntu. As with virtme-ng, `pip3 install --user b4` fails on any
# distro that enforces PEP 668, which includes current Ubuntu.
sudo apt install -y b4
b4 --version
```

Try it on a real series to confirm it works:

```bash
# Find any series on lore.kernel.org, copy its message-id, then:
b4 mbox <message-id>
b4 shazam <message-id>    # applies the series to your tree
```

### Kernel scripts

```bash
cd "$LINUX_TREE"
scripts/checkpatch.pl --strict -f drivers/block/rnull.rs   # see what it flags
scripts/get_maintainer.pl -f rust/kernel/pci.rs            # see who to mail
```

---

## Step 12 — Subscribe and Lurk

You learn the culture months before you post.

- **Rust-for-Linux Zulip** — [rust-for-linux.zulipchat.com](https://rust-for-linux.zulipchat.com/).
  Join. Read daily. Do not post for a few weeks.
- **`rust-for-linux@vger.kernel.org`** — subscribe, or follow via
  [lore.kernel.org/rust-for-linux/](https://lore.kernel.org/rust-for-linux/)
- **`linux-kernel@vger.kernel.org`** — do **not** subscribe (it is thousands of mails a day). Use
  `lore` search instead.
- **`kernelnewbies@kernelnewbies.org`** — subscribe. This is where beginner questions are welcome.
- **`dri-devel@lists.freedesktop.org`** and **`nouveau@lists.freedesktop.org`** — subscribe before
  Month 8.
- **IRC (OFTC):** `#kernelnewbies`, `#dri-devel`, `#nouveau`
- **LWN.net** — read the Kernel page weekly. A subscription is the best value in kernel development;
  consider paying for it.

Set up a `lore` feed or a mail filter so list traffic is separate from your inbox. You want to read it
in a batch, not have it interrupt you.

---

## Step 13 — Order Your Hardware

Do this in Week 0 so it arrives before you need it.

| Item | When needed | Notes |
|------|-------------|-------|
| **ARM SBC** (Raspberry Pi 4/5, or similar with exposed I2C/SPI/GPIO) | Month 5 | Needed for real platform/bus drivers. ~$50-80 with power supply and SD card |
| **I2C or SPI sensor breakout** with a **public datasheet** | Month 5 | Temperature, pressure, IMU, or ADC. Pick one with no existing Rust driver. ~$5-15 |
| **Jumper wires + breadboard** | Month 5 | Trivial cost, saves frustration |
| **USB logic analyzer** | Month 5, optional | ~$15 for a basic 8-channel clone. Makes I2C/SPI debugging dramatically easier |
| **USB-TTL serial adapter** | Month 5 | For the board's serial console. Non-negotiable for kernel work on a board |
| **Sacrificial x86 machine or dual-boot partition** | Month 9-13 | For bare-metal boots and real PCI hardware |
| **GA102 GPU (RTX 3090 / 3090 Ti)** | Month 9 | Required for Nova hardware work — QEMU cannot emulate the GPU. Used market, a borrowed card, or a rented bare-metal host all work. Start looking early; this is the longest lead time on the list |

**Choosing the sensor is a real decision, not a detail.** Criteria: public datasheet, simple register
interface, no existing in-tree Rust driver, and a subsystem (hwmon or IIO) you can integrate with.
Spend an hour on this in Week 18 — a good choice makes SensorRS upstreamable.

---

## Verify Everything

Run the check script:

```bash
bash codes/Month_1/Week_1/Day_5/check_setup.sh
```

Or verify by hand:

```bash
# Environment
uname -a
nproc; free -h; df -h ~
ls -l /dev/kvm

# Toolchains
clang --version | head -1
rustc --version
bindgen --version
cd "$LINUX_TREE" && make LLVM=1 rustavailable

# Kernel
make kernelversion
grep -c CONFIG_RUST=y .config

# Boot loop
vng --exec 'uname -r'

# Rust module loads
vng --exec 'insmod samples/rust/rust_minimal.ko && dmesg | tail -5'

# Upstream tooling
git send-email --version
b4 --version
scripts/checkpatch.pl --version 2>/dev/null || echo "checkpatch present"
```

### Week 0 done when

- [ ] `make LLVM=1 rustavailable` prints "Rust is available!"
- [ ] You booted a Rust-enabled kernel you compiled
- [ ] You loaded and unloaded a `samples/rust` module and saw it in `dmesg`
- [ ] Your edit-build-boot loop is under 60 seconds
- [ ] `rust-analyzer` gives you completion on `rust/kernel/` code
- [ ] You built and browsed the local `rustdoc` output
- [ ] `git send-email` delivered a patch to yourself that applies cleanly
- [ ] `b4` fetched a real series from `lore.kernel.org`
- [ ] You are on the Rust-for-Linux Zulip and reading the list
- [ ] `SETUP_LOG.md` records your toolchain versions, build times, and every error you hit
- [ ] Your Month 5 hardware is ordered

---

## Cross-Compilation (do this in Month 12, not now)

Recorded here so you have it when you get to BootMatrix. **Do not do this in Week 0** — it is a
distraction from getting one architecture working well.

```bash
sudo apt install -y \
  gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu gcc-s390x-linux-gnu \
  qemu-system-arm qemu-system-misc qemu-system-s390x

# Rust targets
rustup target add aarch64-unknown-none riscv64gc-unknown-none-elf s390x-unknown-linux-gnu

# Example: arm64
make LLVM=1 ARCH=arm64 defconfig
make LLVM=1 ARCH=arm64 rustavailable
make LLVM=1 ARCH=arm64 -j"$(nproc)"

qemu-system-aarch64 -M virt -cpu cortex-a72 -m 2G -smp 4 \
  -kernel arch/arm64/boot/Image -append "console=ttyAMA0" -nographic
```

Check `Documentation/rust/arch-support.rst` for which architectures currently support Rust — the list
grows.

---

## Common Problems

| Problem | Cause | Fix |
|---------|-------|-----|
| `rustavailable` says the `rustc` version is unsupported | Wrong toolchain active | `rustup override set <version>` inside the kernel tree; verify with `rustc --version` |
| `rustavailable` says `bindgen` is missing or wrong | `bindgen-cli` not installed or wrong version | `cargo install --locked --version "$(scripts/min-tool-version.sh bindgen)" bindgen-cli` |
| `rustavailable` complains about `libclang` | `libclang-dev` missing, or bindgen cannot find it | `sudo apt install libclang-dev`; if still failing, set `LIBCLANG_PATH=/usr/lib/llvm-<N>/lib` |
| `rust-src` not found | Component missing for the pinned toolchain | `rustup component add rust-src --toolchain <version>` |
| `CONFIG_RUST` disappears after `olddefconfig` | `rustavailable` is not actually passing | Fix Step 7 first; `CONFIG_RUST` depends on `RUST_IS_AVAILABLE` |
| Build fails with LTO or `MODVERSIONS` errors | Config conflict with Rust | Disable LTO and `CONFIG_MODVERSIONS`; check the Kconfig dependencies of `RUST` |
| `pip3 install --user ...` fails with "externally-managed-environment" | PEP 668 — the distro owns its Python and will not let pip write into it | Prefer the distro package (`sudo apt install -y virtme-ng b4`); otherwise `pipx install <tool>`. Do not reach for `--break-system-packages` |
| `/dev/kvm` missing | Module not loaded, or nested virt off | `sudo modprobe kvm_intel`; add the `/etc/wsl.conf` boot command; `wsl --shutdown` |
| `/dev/kvm` exists but QEMU says "Permission denied" | You are not in the `kvm` group — existence is not access | `sudo usermod -aG kvm "$USER"`, then `wsl --shutdown` from PowerShell. `groups` must list `kvm` |
| QEMU: "Could not access KVM kernel module: Permission denied" | Group/permissions on `/dev/kvm` | `sudo chown root:kvm /dev/kvm && sudo chmod 660 /dev/kvm`; `sudo usermod -aG kvm $USER`; restart WSL |
| Build is glacially slow | Tree on `/mnt/c/`, or no ccache | Move the tree to `$LINUX_TREE` (`~/LKD_RUST/kernel/linux`); enable `ccache`; raise `processors` in `.wslconfig` |
| `vng` boots but has no modules | Modules not built or not installed | `make modules` and let `vng` mount your build tree; check `vng --help` for the module options |
| Module loads but `dmesg` shows nothing | Log level filtering | `dmesg -n 8`, or check `/proc/sys/kernel/printk` |
| `insmod: invalid module format` | Built against a different kernel | Rebuild in the same tree you booted; check `modinfo <mod>` `vermagic` against `uname -r` |
| Rust panic on module load | `unwrap()`/`expect()` in your code | Kernel Rust must never panic. Replace with `?` and proper error returns |
| `git send-email` authentication fails | Gmail needs an App Password | Enable 2FA, create an App Password, use that. Test by mailing yourself |
| Received patch has broken whitespace | Mail client mangling | Use `git send-email` directly, never copy-paste. See `Documentation/process/email-clients.rst` |
| rust-analyzer shows errors everywhere | Stale `rust-project.json` | `make LLVM=1 rust-analyzer` again after any config change or pull |
| WSL runs out of disk | Kernel builds are large | `make clean` between config changes; `ccache -C` to clear the cache; expand the WSL VHD if needed |

---

## What Next

Go to [`Readme.md`](Readme.md) → **Week 0** and check off the items you just completed, then start
**Week 1**. Record everything you learn in `journal/` and everything you build in `codes/`.

Welcome to kernel development. It is the most rewarding kind of programming there is, and the feedback
loop is a reboot. You have made the reboot fast, which means you are ready.

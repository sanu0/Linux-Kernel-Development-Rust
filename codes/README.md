# Code — Linux Kernel Development in Rust

All code that accompanies the daily theory in `../theory/` and the weekly plans in `../Readme.md`.
The layout **mirrors the theory folder**: the code for `theory/Month_1/Week_1/Day_1.md` lives in
`codes/Month_1/Week_1/Day_1/`, so the code for any lesson sits next to where that lesson is described.

```text
theory/Month_1/Week_1/Day_1.md   <->   codes/Month_1/Week_1/Day_1/
```

## Structure

```
codes/
├── sync_from_repo.sh              # repo -> WSL (pull code to build and run it)
├── sync_to_repo.sh                # WSL -> repo (push changes back to commit)
└── Month_1/
    └── Week_1/
        ├── Day_1/                 # environment setup
        │   ├── install_deps.sh    # install every build dependency + LLVM + ccache
        │   ├── check_day1.sh      # verify Day 1 is complete (exit code = failure count)
        │   ├── record_env.sh      # dump machine + toolchain state to a file
        │   ├── wsl.conf.example   # /etc/wsl.conf — inside WSL, persists KVM
        │   └── wslconfig.example  # %USERPROFILE%\.wslconfig — on Windows, VM resources
        └── Day_5/
            └── check_setup.sh     # verify the WHOLE lab, including the Rust toolchain
```

As you progress, this grows into the shape below. Kernel modules live in `kmod/` subdirectories with
their own out-of-tree `Makefile`; userspace tools are Cargo projects.

```
codes/
├── Month_1/Week_1/Day_1/          # lab setup and verification
├── Month_1/Week_2/                # KernelForge (Rust CLI)
├── Month_2/Week_5/                # SafetyLint (Rust CLI)
├── Month_2/Week_7/                # PinDojo (Rust crate + trybuild tests)
├── Month_3/Week_9/kmod/           # KModKit modules (Rust kernel modules)
├── Month_3/Week_12/               # OopsLens (Rust CLI/TUI)
├── Month_4/Week_15/qemu/          # VirtToy QEMU device model (C)
├── Month_4/Week_15/kmod/          # VirtToy Rust driver
├── Month_4/Week_16/kmod/          # PCIScope Rust driver
├── Month_5/Week_17/               # DMAForge
├── Month_5/Week_18/kmod/          # SensorRS (the upstream candidate)
├── Month_6/Week_21/kmod/          # LockProof bug museum
├── Month_6/Week_22/kmod/          # BlockForge
└── ...
```

## Three locations, deliberately

| Location | Role |
|---|---|
| `LKD_RUST/` (Windows, in git) | the version-controlled copy — theory, code, and notes. What gets pushed to GitHub |
| `~/LKD_RUST/codes/` (inside WSL) | where you actually BUILD and RUN |
| `~/LKD_RUST/kernel/linux/` (inside WSL) | the upstream kernel tree — **never committed**, cloned fresh |

Git runs on Windows; the kernel build system, Rust toolchain, and QEMU run in WSL. WSL reaches Windows
files via `/mnt/c/...`, but building there is several times slower — so the working copy lives on
WSL's own filesystem and two scripts bridge them.

- **`sync_from_repo.sh`** — repo → WSL. Pull the latest code down to build and run it. Also strips
  Windows CRLF line endings and restores the `+x` bit, because NTFS does not preserve Unix permissions.
- **`sync_to_repo.sh`** — WSL → repo. Push what you wrote in WSL back so you can commit it.

### One-time setup (in WSL)

The repo path lives in `~/.bashrc`, which is never committed, so no personal paths end up in the
public repo:

```bash
echo 'export LKDRUST_REPO="/mnt/c/Users/<you>/path/to/SKILL/LKD_RUST"' >> ~/.bashrc
echo 'export LINUX_TREE="$HOME/LKD_RUST/kernel/linux"' >> ~/.bashrc
source ~/.bashrc
```

### Bootstrap (first time, before the sync scripts exist in WSL)

```bash
mkdir -p ~/LKD_RUST/codes ~/LKD_RUST/kernel
cp -r "$LKDRUST_REPO/codes"/. ~/LKD_RUST/codes/
find ~/LKD_RUST/codes -type f \( -name '*.sh' -o -name '*.rs' -o -name '*.c' -o -name '*.py' \) -exec sed -i 's/\r$//' {} +
find ~/LKD_RUST/codes -type f -name '*.sh' -exec chmod +x {} +

# Day 1: install everything, then verify
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_1/install_deps.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_1/check_day1.sh
```

### Daily use

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh    # get the latest code into WSL to build
# ... work, build, boot, break things, fix things ...
bash ~/LKD_RUST/codes/sync_to_repo.sh      # send WSL changes back to the repo
```

Then commit from the repo:

```bash
git add codes theory && git commit -m "..." && git push origin main
```

**Prefer the GUI?** WSL's filesystem is browsable from Windows Explorer:
- From WSL: `cd ~/LKD_RUST && explorer.exe .`
- Or paste `\\wsl.localhost\Ubuntu\home\<you>\LKD_RUST` into the Explorer address bar

After a GUI copy, restore the executable bit — Windows does not carry it:
`chmod +x ~/LKD_RUST/codes/**/*.sh`, or just run scripts as `bash script.sh`.

## Building kernel modules

Out-of-tree modules build against your kernel tree:

```bash
cd ~/LKD_RUST/codes/Month_3/Week_9/kmod
make -C "$LINUX_TREE" M="$PWD" LLVM=1 modules
```

Then load them in a QEMU guest, never on your host:

```bash
cd "$LINUX_TREE"
vng -- "insmod ~/LKD_RUST/codes/Month_3/Week_9/kmod/hello.ko; dmesg | tail; rmmod hello"
```

> **Rust out-of-tree modules:** kernel Rust support for out-of-tree modules is thinner than for C.
> Where it fights you, develop **in-tree** instead: put your module under `samples/rust/` or
> `drivers/misc/` in your kernel tree, add a Kconfig and Makefile entry, and use `sync_to_repo.sh`
> to copy the source files back here for version control. Several of the roadmap's projects assume
> this in-tree workflow.

## What is not committed

Build artifacts, kernel trees, `.ko` files, firmware blobs, crash dumps, fuzzing corpora, and books.
See `../.gitignore`. Only source code, `Makefile`s, `Kconfig` fragments, and documentation live here.

## Hardware context

Developed on Windows 11 + WSL2 Ubuntu, with QEMU/virtme-ng for guests, an ARM SBC for real bus drivers
from Month 5, and a GA102 GPU for Nova work from Month 9.

See `../SETUP.md` for the full lab build, `../theory/` for the daily notes, and `../Readme.md` for the
18-month roadmap.

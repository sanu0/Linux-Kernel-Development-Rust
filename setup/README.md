# setup/ — bring any machine up to a working kernel-Rust lab

Four scripts that take a bare Linux install to a booted, Rust-enabled kernel you compiled, with your
own module loadable in a QEMU guest, and the ability to send patches upstream.

Everything is **idempotent** — re-running is always safe.

```
setup/
├── lib-common.sh          shared logic (sourced, not run directly)
├── setup-wsl.sh           WSL2 on Windows
├── setup-baremetal.sh     native Linux
├── setup-upstream.sh      git identity + SMTP + b4      (run after either)
└── verify.sh              check that it all works
```

## Quick start

```bash
git clone https://github.com/sanu0/Linux-Kernel-Development-Rust.git
cd Linux-Kernel-Development-Rust/setup

bash setup-wsl.sh          # or: bash setup-baremetal.sh
bash setup-upstream.sh     # identity, SMTP, b4
bash verify.sh             # confirm
```

Expect **40-90 minutes** end to end. Most of it is the ~6 GB kernel clone and one full build.

## The environment file

Setup writes `~/.lkdrust_env` and hooks it into `~/.bashrc` and `~/.profile`:

```bash
export LKD_ROOT=...        # where everything lives
export LINUX_TREE=...      # the kernel tree; scripts and your muscle memory both use it
export LIBCLANG_PATH=...   # detected, so bindgen can find libclang
export PATH=...            # ccache dir first, then ~/.local/bin
```

It exists as a **separate file** on purpose. Distro `~/.bashrc` files open with

```bash
case $- in
    *i*) ;;
      *) return;;   # not interactive -> stop reading here
esac
```

so anything appended below that line is invisible to every non-interactive shell — which means every
script, cron job, and CI run. `~/.lkdrust_env` has no such guard, so anything can source it:

```bash
. ~/.lkdrust_env
```

`verify.sh` does this itself, which is why it works whether or not you opened a fresh shell.

## Which script

| | Use |
|---|---|
| `setup-wsl.sh` | Ubuntu (or similar) under WSL2 on Windows |
| `setup-baremetal.sh` | a real Linux machine, VM, or cloud instance |

Both install the same toolchain. They differ only in the platform-specific parts:

**WSL** additionally handles KVM via nested virtualization, persists the `modprobe` in `/etc/wsl.conf`,
writes a sized `.wslconfig` to your Windows profile, and **refuses to run** if you point it at `/mnt/c`.

**Bare metal** additionally sets up native KVM and the `kvm` group, inventories your PCI devices and
IOMMU groups, and can optionally install the kernel to `/boot` so you can boot it for real.

## Options

Set as environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `LKD_ROOT` | `$HOME/LKD_RUST` | where everything lives |
| `KERNEL_SRC` | `upstream` | `upstream` (clean Linux) or `fork` (your copy, with your branches) |
| `FORK_URL` | `https://github.com/sanu0/linux.git` | your kernel fork |
| `FORK_BRANCH` | *(none)* | branch to check out from your fork after cloning |
| `JOBS` | `nproc` | build parallelism |
| `INSTALL_KERNEL` | `0` | bare metal only: also install to `/boot` (prompts for confirmation) |

```bash
# clean upstream Linux
bash setup-wsl.sh

# your fork, with your work already on it
KERNEL_SRC=fork FORK_BRANCH=sanu0 bash setup-wsl.sh

# somewhere else, fewer jobs
LKD_ROOT=~/kdev JOBS=8 bash setup-baremetal.sh
```

### upstream vs fork

Only the `git clone` URL differs. Both end with the **same remotes**, because the script adds the other
one either way:

```
origin  → git.kernel.org/.../torvalds/linux.git    fetch from here (real Linux)
github  → your fork                                push to here (your backup)
next    → linux-next                               integration testing
stable  → stable trees                             backports
rfl     → Rust-for-Linux                           Rust work lands here first
```

`origin` is deliberately **always** kernel.org. A GitHub fork never auto-updates, so pointing `origin`
at it would silently freeze you at whenever you forked.

Pick `fork` on a new machine to get your existing branches back in one clone. Pick `upstream` when you
want a clean tree — useful for `git bisect`, where your own experiments would only confuse things.

## What gets installed

**Build toolchain** — `build-essential`, `flex`, `bison`, `bc`, `libssl-dev`, `libelf-dev`,
`libncurses-dev`, `dwarves` (for `pahole`), `cpio`, `rsync`, `zstd`, `kmod`, `ccache`.

**LLVM** — `clang`, `lld`, `llvm`, `libclang-dev`. Required because kernel Rust wants `LLVM=1` and
because `bindgen` links against libclang to read C headers. `LIBCLANG_PATH` is detected and persisted.

**Boot loop** — `qemu-system-x86`, `virtme-ng`, plus `gdb`, `trace-cmd`, `fio`. Installed from the
distro, never pip: modern distros mark their Python externally managed (PEP 668) and refuse it.

**Rust** — `rustup`, then `rust-src`, `rustfmt`, `clippy`, and `bindgen-cli` at the version the tree
names. If your installed stable already meets the minimum, **no toolchain is downloaded** — the script
compares versions numerically first, which matters on slow or corporate networks.

**Kernel** — cloned, remotes added, configured (`defconfig` + virtme options + `CONFIG_RUST` + sample
modules + debug options), and built.

## Notes on a few decisions

**`rust-src` is mandatory.** The kernel compiles Rust's `core` and `alloc` *from source* for its own
custom target, because no prebuilt `core` exists for "x86_64 kernel with these flags." `rustup` does not
install it by default.

**Samples are built as `=m`, not `=y`.** A built-in module cannot be `insmod`'d or `rmmod`'d, which is
the entire point of having them.

**`scripts/config` + `olddefconfig`, never `make defconfig`.** `defconfig` is a factory reset: running it
after `vng --kconfig` would silently delete the virtio options and break the boot loop. The script edits
the existing config in place and verifies the virtio options survived.

**No SMTP password is ever stored.** `setup-upstream.sh` deliberately leaves `sendemail.smtpPass` unset,
so git prompts you per send. A plaintext secret in `~/.gitconfig` is a file people routinely paste into
bug reports. `verify.sh` warns if it finds one set.

## After setup

```bash
cd "$LINUX_TREE"
vng --exec 'uname -r'                                             # boot your kernel
vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail'    # load Rust in ring 0
```

Keeping up with upstream:

```bash
git fetch origin
git checkout master && git merge --ff-only origin/master
git checkout <your-branch> && git rebase master
make LLVM=1 -j$(nproc)
```

Backing your work up:

```bash
git push github <your-branch>
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rustavailable` says no | read its message — it names the tool | usually `rust-src` or `bindgen` |
| `CONFIG_RUST` won't stay set | `rustavailable` isn't passing | fix that first; `CONFIG_RUST` depends on it |
| `error: externally-managed-environment` | PEP 668 blocking pip | use the distro package, or `pipx` |
| `vng`: *not a valid pts* | no terminal | run from a real terminal, not a pipe; don't wrap in bare `timeout` |
| Build killed, no error | OOM | lower `JOBS` |
| Builds glacially slow | tree on `/mnt/c`, or ccache not on PATH | check `which gcc` shows a ccache path |
| `insmod: invalid module format` | stale build | rebuild in the tree you booted |
| Guest boots an old kernel | stale `bzImage` | `verify.sh` catches this by comparing versions |

## Requirements

- x86-64 Linux (or WSL2 on x86-64 Windows — nested virtualization is x86-only)
- **40 GB** free disk minimum, 60+ comfortable
- 8 GB RAM minimum, 16+ comfortable
- `sudo`, and an internet connection
- Debian/Ubuntu is best supported; Fedora and Arch are handled best-effort

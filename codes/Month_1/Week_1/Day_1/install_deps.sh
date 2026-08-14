#!/bin/bash
# M1W1D1 — install everything needed to build the Linux kernel with Rust support.
#
# Safe to re-run: apt install is idempotent, and the ccache/PATH steps check before appending.
#
# Usage:  bash install_deps.sh
#
# See ../../../../theory/Month_1/Week_1/Day_1.md for what each package is actually for.

set -euo pipefail

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

say "Updating package lists"
sudo apt update

say "Core kernel build dependencies"
# build-essential  gcc/g++/make/libc-dev
# flex bison       build the Kconfig parser (scripts/kconfig/)
# bc               Kbuild computes timer constants with a bc script
# libssl-dev       module signing, certificates
# libelf-dev       objtool, BTF generation
# libncurses-dev   make menuconfig
# dwarves          provides pahole -> DWARF to BTF conversion
# cpio             initramfs images
# rsync            headers_install and other install targets
# zstd             compressed kernel images and modules
# kmod             insmod / rmmod / modprobe / depmod
sudo apt install -y \
  build-essential \
  flex bison bc \
  libssl-dev libelf-dev libncurses-dev \
  dwarves \
  cpio rsync zstd kmod \
  git ccache pkg-config \
  python3 python3-pip

say "LLVM / Clang toolchain"
# clang         the C compiler used with LLVM=1
# lld           the LLVM linker
# llvm          llvm-ar, llvm-nm, llvm-objcopy, llvm-objdump, llvm-strip
# libclang-dev  the libclang SHARED LIBRARY that bindgen links against.
#               Without this, kernel Rust cannot parse a single C header.
sudo apt install -y clang lld llvm libclang-dev

say "QEMU and virtualization tooling"
# qemu-system-x86  the x86_64 system emulator that runs your kernels
# qemu-utils       qemu-img, for building guest disk images
# cpu-checker      kvm-ok, which explains WHY kvm is unavailable when it is
# ovmf             UEFI firmware, for booting guests the way real machines boot
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker ovmf

say "Debugging and tracing"
# gdb        decode an oops, and attach to a QEMU guest via -s -S
# trace-cmd  ftrace frontend
# git-email  git send-email; every upstream contribution goes through it
sudo apt install -y gdb trace-cmd git-email

say "Quality-of-life tools"
sudo apt install -y file wget curl unzip tree

# Append a line to ~/.bashrc only if a matching key is not already there.
# Keeps this script safe to re-run without growing .bashrc every time.
add_to_bashrc() {
  local key="$1" line="$2" label="$3"
  if grep -q "$key" "$HOME/.bashrc" 2>/dev/null; then
    echo "  $label already in ~/.bashrc"
  else
    printf '%s\n' "$line" >> "$HOME/.bashrc"
    echo "  added $label to ~/.bashrc"
  fi
}

say "Configuring ccache"
ccache --max-size=20G
add_to_bashrc '/usr/lib/ccache' \
  'export PATH="/usr/lib/ccache:$PATH"' \
  '/usr/lib/ccache on PATH'

say "Creating the working directories"
mkdir -p "$HOME/LKD_RUST/kernel"
mkdir -p "$HOME/LKD_RUST/codes"
mkdir -p "$HOME/LKD_RUST/Month_1/Week_1"
echo "  $HOME/LKD_RUST/kernel          <- kernel trees (never committed to git)"
echo "  $HOME/LKD_RUST/codes           <- scripts synced from the Windows repo"
echo "  $HOME/LKD_RUST/Month_1/Week_1  <- scratch space for this week's experiments"

say "Recording paths in ~/.bashrc"

add_to_bashrc 'LINUX_TREE=' \
  'export LINUX_TREE="$HOME/LKD_RUST/kernel/linux"' \
  'LINUX_TREE'

# pip3 --user and cargo install put binaries in these two directories. virtme-ng (vng)
# and b4 both land in ~/.local/bin, and nothing works if it is not on PATH.
add_to_bashrc '.local/bin' \
  'export PATH="$HOME/.local/bin:$PATH"' \
  '~/.local/bin on PATH'

add_to_bashrc 'cargo/env' \
  '[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"' \
  '~/.cargo/env sourcing'

# Derive the Windows repo path from where this script actually lives, rather than making
# the reader paste a path by hand. Only trust the guess when the script is running from
# the Windows side (/mnt/...) — when run from the synced WSL copy, four levels up is
# ~/LKD_RUST, which is the working area, not the repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_GUESS="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

REPO_OK=no
case "$REPO_GUESS" in
  /mnt/*) [ -f "$REPO_GUESS/Readme.md" ] && REPO_OK=yes ;;
esac

if grep -q 'LKDRUST_REPO=' "$HOME/.bashrc" 2>/dev/null; then
  echo "  LKDRUST_REPO already in ~/.bashrc"
elif [ "$REPO_OK" = yes ]; then
  # Double-quote the value: Windows paths under Documents or a synced cloud folder
  # commonly contain spaces, and without quoting, sourcing .bashrc would split the
  # path on those spaces and silently set LKDRUST_REPO to just the first word.
  printf 'export LKDRUST_REPO="%s"\n' "$REPO_GUESS" >> "$HOME/.bashrc"
  echo "  added LKDRUST_REPO=$REPO_GUESS to ~/.bashrc (detected from this script's location)"
else
  echo "  LKDRUST_REPO not set and could not be detected from $SCRIPT_DIR"
  echo "  set it by hand — see step 2 at the end of this script"
fi

say "Loading the KVM module"
# WSL's kernel has KVM as a module and does not always load it at boot.
VENDOR=$(grep -o -m1 -E 'vmx|svm' /proc/cpuinfo || true)
case "$VENDOR" in
  vmx) KVM_MOD=kvm_intel ;;
  svm) KVM_MOD=kvm_amd ;;
  *)   KVM_MOD="" ;;
esac

if [ -z "$KVM_MOD" ]; then
  echo "  CPU reports no vmx/svm flag — nested virtualization is not exposed."
  echo "  QEMU will fall back to software emulation (TCG). Not a blocker; note it and move on."
elif [ -e /dev/kvm ]; then
  echo "  /dev/kvm already present"
else
  echo "  loading $KVM_MOD"
  sudo modprobe "$KVM_MOD" || echo "  modprobe failed — see the KVM section of Day_1.md"
fi

if [ -e /dev/kvm ]; then
  sudo chown root:kvm /dev/kvm 2>/dev/null || true
  sudo chmod 660 /dev/kvm 2>/dev/null || true
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
    sudo usermod -aG kvm "$USER"
    echo "  added $USER to the kvm group (takes effect after 'wsl --shutdown')"
  fi
fi

say "Done"
cat <<EOF

Remaining manual steps (they need a Windows-side edit or a restart):

  1. Set your git identity — use your REAL name, it becomes a legal signature:
       git config --global user.name  "Your Real Name"
       git config --global user.email "your@email"

  2. Only if the LKDRUST_REPO line above said it could not be detected:
       echo 'export LKDRUST_REPO="/mnt/c/Users/<you>/path/to/SKILL/LKD_RUST"' >> ~/.bashrc

  3. Persist KVM across restarts — add to /etc/wsl.conf (see wsl.conf.example here):
       sudo nano /etc/wsl.conf

  4. Give WSL more resources — edit %USERPROFILE%\\.wslconfig on Windows
     (see wslconfig.example here), then from PowerShell:
       wsl --shutdown

  5. Open a NEW shell (so PATH and the kvm group apply), then verify:
       bash check_day1.sh

Note: step 4 is what makes step 5 report the right numbers, and 'wsl --shutdown' is
also what makes your new kvm group membership take effect. Do not skip the restart.

EOF

#!/bin/bash
# M1W1D1 — dump the machine and toolchain state to a file.
#
# Run this today, and again any time something mysteriously stops working. Diffing two of these
# files is often the fastest way to find out what changed underneath you.
#
# Usage:  bash record_env.sh [output-file]
# Default output: ~/LKD_RUST/Month_1/Week_1/env_day1.txt

OUT="${1:-$HOME/LKD_RUST/Month_1/Week_1/env_day1.txt}"
mkdir -p "$(dirname "$OUT")"

ver() { command -v "$1" > /dev/null 2>&1 && "$1" --version 2>&1 | head -1 || echo "$1: NOT INSTALLED"; }

{
  echo "# Environment — $(date -Iseconds)"
  echo

  echo "## Host"
  uname -a
  echo

  echo "## OS"
  [ -r /etc/os-release ] && grep -E '^(NAME|VERSION)=' /etc/os-release
  echo

  echo "## CPU"
  lscpu | grep -E 'Model name|^CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|Socket|Virtualization|Flags' \
    | cut -c1-200
  echo

  echo "## Memory"
  free -h
  echo

  echo "## Disk (\$HOME)"
  df -hT "$HOME"
  echo

  echo "## Toolchain"
  for t in gcc g++ make clang ld.lld llvm-objcopy flex bison bc pahole ccache git python3 rsync zstd cpio \
           qemu-system-x86_64 gdb; do
    ver "$t"
  done
  echo

  echo "## Header packages"
  for h in openssl/ssl.h libelf.h ncurses.h; do
    if find /usr/include -name "$(basename "$h")" -print -quit 2>/dev/null | grep -q .; then
      echo "$h: present"
    else
      echo "$h: MISSING"
    fi
  done
  if find /usr/lib /usr/lib64 -name 'libclang.so*' -print -quit 2>/dev/null | grep -q .; then
    echo "libclang: present"
  else
    echo "libclang: MISSING"
  fi
  echo

  echo "## Virtualization"
  echo "cpu flag: $(grep -o -m1 -E 'vmx|svm' /proc/cpuinfo || echo none)"
  if [ -e /dev/kvm ]; then
    echo "/dev/kvm: $(stat -c '%A %U:%G' /dev/kvm)"
  else
    echo "/dev/kvm: absent"
  fi
  echo "kvm modules: $(lsmod | awk '/^kvm/{printf "%s ", $1}' || true)"
  echo

  echo "## git identity"
  echo "user.name:  $(git config --global user.name  || echo UNSET)"
  echo "user.email: $(git config --global user.email || echo UNSET)"
  echo

  echo "## ccache"
  echo "gcc resolves to: $(command -v gcc)"
  ccache -s 2>/dev/null | head -20
  echo

  echo "## Paths"
  echo "LINUX_TREE=${LINUX_TREE:-UNSET}"
  echo "LKDRUST_REPO=${LKDRUST_REPO:-UNSET}"
  echo "PATH=$PATH"
} | tee "$OUT"

echo
echo "Written to: $OUT"
echo "Copy the interesting numbers into the 'My Notes' table in theory/Month_1/Week_1/Day_1.md"

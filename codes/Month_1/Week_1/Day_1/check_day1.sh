#!/bin/bash
# M1W1D1 — verify the development environment is ready.
#
# Checks only what Day 1 covers: userland, build dependencies, LLVM, KVM, git identity,
# ccache, and the working directories. There is no kernel tree or Rust toolchain yet —
# those are Day 2 and Day 4, and check_setup.sh (Day 5) covers the full lab.
#
# Usage:  bash check_day1.sh
# Exit code is the number of failures, so it works as a CI predicate.

FAILURES=0
WARNINGS=0

if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; N=''
fi

section() { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s[ ok ]%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s[warn]%s %s\n' "$Y" "$N" "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '  %s[FAIL]%s %s\n' "$R" "$N" "$1"; FAILURES=$((FAILURES + 1)); }
info() { printf '         %s\n' "$1"; }

# Check a command exists and report its first version line.
check_cmd() {
  local cmd="$1" label="${2:-$1}"
  if command -v "$cmd" > /dev/null 2>&1; then
    ok "$label — $("$cmd" --version 2>&1 | head -1)"
  else
    fail "$label not found ($cmd)"
  fi
}

printf '%sM1W1D1 — environment check%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "WSL and userland"

KREL="$(uname -r)"
printf '  kernel: %s\n' "$KREL"
case "$KREL" in
  *WSL2*|*microsoft*) ok "running under WSL2 (a real Linux kernel)" ;;
  *)                  warn "does not look like WSL2 — fine if this is a native Linux box" ;;
esac

if [ -r /etc/os-release ]; then
  ok "userland: $(. /etc/os-release && echo "$PRETTY_NAME")"
fi

# ─────────────────────────────────────────────────────────────────
section "Resources"

printf '  cpus: %s\n' "$(nproc)"
printf '  ram:  %s\n' "$(free -h | awk '/^Mem:/{print $2}')"

AVAIL_GB=$(( $(df -Pk "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
if   [ "$AVAIL_GB" -ge 60 ]; then ok   "disk: ${AVAIL_GB} GB free in \$HOME"
elif [ "$AVAIL_GB" -ge 40 ]; then ok   "disk: ${AVAIL_GB} GB free in \$HOME (tight but workable)"
elif [ "$AVAIL_GB" -ge 20 ]; then warn "disk: only ${AVAIL_GB} GB free — a debug build will struggle"
else                              fail "disk: only ${AVAIL_GB} GB free — not enough for a kernel tree plus builds"
fi

# Building on the 9p bridge to Windows is legal and slow enough to derail the roadmap.
FSTYPE="$(df -PT "$HOME" 2>/dev/null | awk 'NR==2{print $2}')"
case "$FSTYPE" in
  9p|drvfs) fail "\$HOME is on the Windows filesystem ($FSTYPE) — builds will be several times slower" ;;
  ext4|btrfs|xfs|overlay) ok "\$HOME is on a native Linux filesystem ($FSTYPE)" ;;
  *) warn "\$HOME filesystem type is '$FSTYPE' — verify it is not a Windows bridge" ;;
esac

# ─────────────────────────────────────────────────────────────────
section "Build dependencies"

check_cmd gcc
check_cmd make
check_cmd flex
check_cmd bison
check_cmd bc
check_cmd cpio
check_cmd rsync
check_cmd zstd
check_cmd git

# pahole comes from the 'dwarves' package, which is the one people miss.
if command -v pahole > /dev/null 2>&1; then
  ok "pahole — $(pahole --version 2>&1 | head -1)   (from the 'dwarves' package)"
else
  fail "pahole not found — install 'dwarves'. Needed for CONFIG_DEBUG_INFO_BTF"
fi

# Header/library packages have no binary to query, so check for the headers directly.
for spec in \
  "openssl/ssl.h:libssl-dev:module signing" \
  "libelf.h:libelf-dev:objtool and BTF" \
  "ncurses.h:libncurses-dev:make menuconfig"
do
  hdr="${spec%%:*}"; rest="${spec#*:}"; pkg="${rest%%:*}"; why="${rest#*:}"
  if find /usr/include -name "$(basename "$hdr")" -print -quit 2>/dev/null | grep -q .; then
    ok "$pkg present ($why)"
  else
    fail "$pkg missing — needed for $why"
  fi
done

# ─────────────────────────────────────────────────────────────────
section "LLVM toolchain (required for kernel Rust)"

check_cmd clang
check_cmd ld.lld
check_cmd llvm-objcopy

# libclang is what bindgen links against to parse C headers. Without it there is no Rust build.
if find /usr/lib /usr/lib64 -name 'libclang.so*' -print -quit 2>/dev/null | grep -q .; then
  ok "libclang present — bindgen can parse kernel headers"
else
  fail "libclang not found — install 'libclang-dev'. Kernel Rust cannot build without it"
fi

# ─────────────────────────────────────────────────────────────────
section "Hardware virtualization"

VENDOR="$(grep -o -m1 -E 'vmx|svm' /proc/cpuinfo || true)"
case "$VENDOR" in
  vmx) ok "CPU exposes Intel VT-x (vmx)" ;;
  svm) ok "CPU exposes AMD-V (svm)" ;;
  *)   warn "CPU exposes no vmx/svm flag — nested virtualization not available to this VM" ;;
esac

if [ -e /dev/kvm ]; then
  ok "/dev/kvm exists — $(stat -c '%A %U:%G' /dev/kvm)"
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ok "/dev/kvm is readable and writable by you"
  else
    warn "/dev/kvm exists but you cannot use it — 'sudo usermod -aG kvm \$USER' then 'wsl --shutdown'"
  fi
  lsmod | grep -q kvm && ok "kvm modules loaded: $(lsmod | awk '/^kvm/{printf "%s ", $1}')"

  # /dev/kvm is root:kvm mode 660, so existence is not access. This is the failure that
  # looks like "KVM is broken" but is really "you are not in the group", and it only
  # shows up much later as a QEMU permission error.
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
    fail "you are NOT in the 'kvm' group — QEMU will fail with 'Permission denied'"
    info "fix: sudo usermod -aG kvm \"\$USER\"   then, from PowerShell: wsl --shutdown"
  else
    ok "you are in the 'kvm' group"
  fi
else
  warn "/dev/kvm missing — QEMU will use software emulation (TCG), roughly 10-20x slower"
  info "try: sudo modprobe kvm_intel   (or kvm_amd)"
  info "this does NOT block Week 1 — note it in the journal and continue"
fi

# QEMU is what actually runs your kernels. Day 3 depends on it, so catch its absence now
# rather than three days from now.
if command -v qemu-system-x86_64 > /dev/null 2>&1; then
  ok "qemu-system-x86_64 — $(qemu-system-x86_64 --version 2>&1 | head -1)"
else
  fail "qemu-system-x86_64 not found — install 'qemu-system-x86'. Day 3 needs it"
fi

# ─────────────────────────────────────────────────────────────────
section "git identity"

GNAME="$(git config --global user.name  || true)"
GMAIL="$(git config --global user.email || true)"

if [ -n "$GNAME" ]; then
  ok "user.name: $GNAME"
  # A DCO Signed-off-by must be a real name, which in practice means at least two words.
  case "$GNAME" in
    *[!\ ]\ *[!\ ]*) : ;;
    *) warn "user.name looks like a single word — Signed-off-by requires your real full name" ;;
  esac
else
  fail "git user.name unset — Signed-off-by (the DCO) needs your real name"
fi

[ -n "$GMAIL" ] && ok "user.email: $GMAIL" \
                || fail "git user.email unset — kernel review happens by email"

# ─────────────────────────────────────────────────────────────────
section "ccache"

if command -v ccache > /dev/null 2>&1; then
  ok "ccache — $(ccache --version | head -1)"
  MAXSIZE="$(ccache -k max_size 2>/dev/null || ccache -s 2>/dev/null | awk -F': *' '/[Mm]ax(imum)? cache size/{print $2}')"
  [ -n "$MAXSIZE" ] && info "max cache size: $MAXSIZE"

  # The whole trick is PATH order: /usr/lib/ccache must come before /usr/bin.
  case "$(command -v gcc)" in
    */ccache/*) ok "ccache is intercepting the compiler ($(command -v gcc))" ;;
    *)          fail "ccache installed but NOT intercepting — /usr/lib/ccache must come first on PATH" ;;
  esac
else
  fail "ccache not found — rebuilds will be far slower than necessary"
fi

# ─────────────────────────────────────────────────────────────────
section "Working directories"

[ -d "$HOME/LKD_RUST/kernel" ] \
  && ok "$HOME/LKD_RUST/kernel exists (kernel trees go here)" \
  || fail "$HOME/LKD_RUST/kernel missing — mkdir -p it"

if [ -n "${LINUX_TREE:-}" ]; then
  ok "\$LINUX_TREE set to $LINUX_TREE"

  # The single most consequential misconfiguration in WSL kernel development. A tree under
  # /mnt/ is reached over the 9p bridge: builds run several times slower, and NTFS does not
  # preserve the executable bit or symlinks that the kernel tree relies on. If the path is
  # also inside a synced cloud folder, the sync client will try to upload a ~100k-file tree
  # and may replace files with cloud placeholders mid-build. Fail hard rather than warn.
  case "$LINUX_TREE" in
    /mnt/*)
      fail "\$LINUX_TREE is under /mnt/ — the Windows filesystem. Move it to \$HOME"
      info "the kernel tree must live on ext4: export LINUX_TREE=\"\$HOME/LKD_RUST/kernel/linux\""
      info "if that path is inside a synced cloud folder, it will also try to sync ~100,000 files"
      ;;
    *)
      TREE_PARENT="$(dirname "$LINUX_TREE")"
      [ -d "$TREE_PARENT" ] || TREE_PARENT="$HOME"
      TREE_FS="$(df -PT "$TREE_PARENT" 2>/dev/null | awk 'NR==2{print $2}')"
      case "$TREE_FS" in
        9p|drvfs) fail "\$LINUX_TREE is on a Windows bridge filesystem ($TREE_FS) — move it to \$HOME" ;;
        *)        ok "\$LINUX_TREE is on a native Linux filesystem ($TREE_FS)" ;;
      esac
      ;;
  esac

  [ -d "$LINUX_TREE" ] \
    && ok "kernel tree already cloned" \
    || info "not cloned yet — that is M1W1D2"
else
  fail "\$LINUX_TREE unset — add it to ~/.bashrc so later scripts can find the tree"
fi

if [ -n "${LKDRUST_REPO:-}" ]; then
  [ -d "$LKDRUST_REPO" ] \
    && ok "\$LKDRUST_REPO points at an existing directory" \
    || warn "\$LKDRUST_REPO is set but the path does not exist: $LKDRUST_REPO"
else
  warn "\$LKDRUST_REPO unset — needed by the sync scripts. Add it to ~/.bashrc"
fi

# ─────────────────────────────────────────────────────────────────
section "Summary"

if   [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDay 1 complete. Record your numbers in the journal, then go to M1W1D2.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Day 1 is done — note the warnings in the journal.\n\n' \
    "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s). Fix the failures before M1W1D2 —\n' \
    "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  see theory/Month_1/Week_1/Day_1.md\n\n'
fi

exit "$FAILURES"

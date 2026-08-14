#!/bin/bash
# check_setup.sh — verify the kernel Rust development lab in one command.
#
# Run this at the end of Week 0, and again any time something mysteriously stops working.
# It checks, in order: the environment, the toolchains, the kernel tree, the Rust toolchain
# against what the tree demands, the boot loop, and the upstream tooling.
#
# Usage:
#   bash check_setup.sh                 # uses $LINUX_TREE, or ~/LKD_RUST/kernel/linux
#   LINUX_TREE=~/other/linux bash check_setup.sh
#
# Exit code is the number of failures, so it works as a CI predicate.

TREE="${LINUX_TREE:-$HOME/LKD_RUST/kernel/linux}"
FAILURES=0
WARNINGS=0

# Colours, but only when attached to a terminal.
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

have() { command -v "$1" > /dev/null 2>&1; }

# Check a command exists; report its version line. $2 = "required" or "optional".
check_cmd() {
  local cmd="$1" need="${2:-required}" ver
  if have "$cmd"; then
    ver="$("$cmd" --version 2>&1 | head -1)"
    ok "$cmd — $ver"
  elif [ "$need" = optional ]; then
    warn "$cmd not found (optional)"
  else
    fail "$cmd not found"
  fi
}

printf '%sKernel Rust lab check%s\n' "$B" "$N"
printf 'kernel tree: %s\n' "$TREE"

# ─────────────────────────────────────────────────────────────────
section "Environment"

printf '  host: %s\n' "$(uname -srm)"
printf '  cpus: %s   ram: %s\n' "$(nproc)" "$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')"

# Kernel builds are large; anything under 40 GB free will bite you mid-build.
avail_kb="$(df -Pk "$HOME" | awk 'NR==2{print $4}')"
avail_gb=$((avail_kb / 1024 / 1024))
if [ "$avail_gb" -ge 40 ]; then
  ok "disk: ${avail_gb} GB free in \$HOME"
elif [ "$avail_gb" -ge 20 ]; then
  warn "disk: only ${avail_gb} GB free in \$HOME (40+ recommended)"
else
  fail "disk: only ${avail_gb} GB free in \$HOME — a debug build will not fit"
fi

# Building on /mnt/c is legal and slow enough to derail the whole roadmap.
case "$TREE" in
  /mnt/*) fail "kernel tree is on the Windows filesystem ($TREE) — move it to WSL's own disk, builds are several times slower here" ;;
  *)      ok  "kernel tree is on a native Linux filesystem" ;;
esac

if [ -e /dev/kvm ]; then
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ok "/dev/kvm present and accessible"
  else
    warn "/dev/kvm exists but is not accessible to you — 'sudo usermod -aG kvm \$USER' then restart WSL"
  fi
else
  warn "/dev/kvm missing — QEMU will fall back to software emulation (slow but usable). Try: sudo modprobe kvm_intel"
fi

# ─────────────────────────────────────────────────────────────────
section "Build toolchain"

for c in gcc make flex bison bc; do check_cmd "$c"; done
check_cmd clang
check_cmd ld.lld
check_cmd pahole optional

if have ccache; then
  ok "ccache — $(ccache --version | head -1)"
  info "$(ccache -s 2>/dev/null | grep -iE 'cache size|hit rate' | tr '\n' ' ')"
  case ":$PATH:" in
    *:/usr/lib/ccache:*) ok "ccache is on PATH ahead of the real compilers" ;;
    *) warn "ccache installed but /usr/lib/ccache is not on PATH — rebuilds will be slow" ;;
  esac
else
  warn "ccache not found — rebuilds will be much slower than they need to be"
fi

# ─────────────────────────────────────────────────────────────────
section "Emulation and boot loop"

check_cmd qemu-system-x86_64
check_cmd vng optional
have vng || info "install with: sudo apt install -y virtme-ng   (this is your 60-second boot loop)"
have vng || info "not 'pip3 install --user' — Ubuntu enforces PEP 668 and rejects it"

# ─────────────────────────────────────────────────────────────────
section "Rust toolchain"

check_cmd rustc
check_cmd cargo
check_cmd bindgen
check_cmd rustfmt optional

if have rustc && [ -d "$TREE" ]; then
  # The tree is the authority on versions, not any tutorial.
  for tool in rustc bindgen; do
    if [ -x "$TREE/scripts/min-tool-version.sh" ]; then
      want="$("$TREE/scripts/min-tool-version.sh" "$tool" 2>/dev/null)"
      case "$tool" in
        rustc)   got="$(rustc --version 2>/dev/null | awk '{print $2}')" ;;
        bindgen) got="$(bindgen --version 2>/dev/null | awk '{print $2}')" ;;
      esac
      if [ -n "$want" ]; then
        if [ "$want" = "$got" ]; then
          ok "$tool $got matches what the tree wants"
        else
          warn "$tool: tree wants $want, you have ${got:-none} (newer may be fine; rustavailable decides)"
        fi
      fi
    fi
  done
fi

if have rustup; then
  ok "rustup — $(rustup --version 2>/dev/null | head -1)"
  if rustup component list --installed 2>/dev/null | grep -q '^rust-src'; then
    ok "rust-src component installed"
  else
    fail "rust-src not installed — 'rustup component add rust-src' (kernel Rust cannot build without it)"
  fi
else
  fail "rustup not found"
fi

# ─────────────────────────────────────────────────────────────────
section "Kernel tree"

if [ -d "$TREE" ]; then
  ok "tree found at $TREE"
  ( cd "$TREE" || exit 0
    printf '         version: %s\n' "$(make -s kernelversion 2>/dev/null)"
    printf '         HEAD:    %s\n' "$(git log --oneline -1 2>/dev/null)"
  )

  [ -d "$TREE/rust/kernel" ] \
    && ok "rust/kernel/ present ($(find "$TREE/rust/kernel" -name '*.rs' | wc -l) .rs files)" \
    || fail "rust/kernel/ missing — is this really a recent kernel tree?"

  [ -d "$TREE/samples/rust" ] \
    && ok "samples/rust/ present" \
    || warn "samples/rust/ missing"

  # THE check. Everything about kernel Rust depends on this passing.
  printf '  running: make LLVM=1 rustavailable (this takes a moment)\n'
  if out="$(cd "$TREE" && make LLVM=1 rustavailable 2>&1)"; then
    ok "rustavailable: Rust is available"
  else
    fail "rustavailable FAILED — nothing else about kernel Rust will work until this passes"
    printf '%s\n' "$out" | sed 's/^/         | /'
  fi

  if [ -f "$TREE/.config" ]; then
    if grep -q '^CONFIG_RUST=y' "$TREE/.config"; then
      ok "CONFIG_RUST=y in .config"
    else
      warn "CONFIG_RUST is not enabled in .config"
    fi
    for opt in PROVE_LOCKING DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT DEBUG_FS RUST_DEBUG_ASSERTIONS; do
      grep -q "^CONFIG_${opt}=y" "$TREE/.config" \
        && ok "CONFIG_${opt}=y" \
        || warn "CONFIG_${opt} not enabled — recommended during development"
    done
  else
    warn "no .config yet — run 'make LLVM=1 defconfig' in the tree"
  fi

  [ -f "$TREE/rust-project.json" ] \
    && ok "rust-project.json present (rust-analyzer will work)" \
    || warn "rust-project.json missing — run 'make LLVM=1 rust-analyzer' for editor support"
else
  fail "kernel tree not found at $TREE — set \$LINUX_TREE or clone it (see ../../../SETUP.md)"
fi

# ─────────────────────────────────────────────────────────────────
section "Upstream tooling"

if have git; then
  ok "git — $(git --version)"
  name="$(git config --global user.name)"
  mail="$(git config --global user.email)"
  [ -n "$name" ] && ok "git user.name: $name"   || fail "git user.name unset — Signed-off-by needs your real name"
  [ -n "$mail" ] && ok "git user.email: $mail"  || fail "git user.email unset"
  [ -n "$(git config --global sendemail.smtpServer)" ] \
    && ok "git send-email configured ($(git config --global sendemail.smtpServer))" \
    || fail "git send-email not configured — this blocks every contribution you will ever make"
else
  fail "git not found"
fi

check_cmd b4 optional
have b4 || info "install with: sudo apt install -y b4   (the modern patch workflow tool)"

check_cmd trace-cmd optional
check_cmd fio optional
check_cmd drgn optional

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sLab is ready. Start Week 1.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s You can start Week 1; fix the warnings as you go.\n\n' \
    "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s). Fix the failures before starting Week 1 — see ../../../SETUP.md\n\n' \
    "$R" "$FAILURES" "$N" "$WARNINGS"
fi

exit "$FAILURES"

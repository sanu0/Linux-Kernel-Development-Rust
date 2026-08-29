#!/bin/bash
# verify.sh — check that a machine set up by these scripts is actually working.
#
# Run this after setup, or any time something mysteriously stops working. It
# checks the toolchain, the kernel tree, the Rust gate, the build outputs, the
# boot loop, and upstream readiness.
#
# Usage:  bash verify.sh
# Exit code is the number of failures, so it works as a CI predicate.

set -uo pipefail

# Source the generated env directly rather than relying on ~/.bashrc, which
# distros guard with an early `return` for non-interactive shells.
# shellcheck disable=SC1090
[ -f "$HOME/.lkdrust_env" ] && . "$HOME/.lkdrust_env"

FAILURES=0
WARNINGS=0
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; N=''
fi
section() { printf '\n%s══ %s ══%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$1"; WARNINGS=$((WARNINGS+1)); }
fail() { printf '  %s✗%s %s\n' "$R" "$N" "$1"; FAILURES=$((FAILURES+1)); }
info() { printf '      %s\n' "$1"; }
have() { command -v "$1" > /dev/null 2>&1; }
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

printf '%sLKD_RUST setup verification%s\n' "$B" "$N"
[ -f "$HOME/.lkdrust_env" ] && ok "loaded ~/.lkdrust_env" \
                           || warn "no ~/.lkdrust_env — run a setup script first"

# ─────────────────────────────────────────────────────────────────
section "Host"
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  ok "WSL2 — $(uname -r)"
  PLATFORM=wsl
else
  ok "native Linux — $(uname -r)"
  PLATFORM=metal
fi
[ -r /etc/os-release ] && info "$(. /etc/os-release && echo "$PRETTY_NAME")"
info "$(nproc) CPUs, $(free -h | awk '/^Mem:/{print $2}') RAM"

# ─────────────────────────────────────────────────────────────────
section "Toolchain"
for c in gcc make flex bison bc cpio rsync zstd git; do
  have "$c" && ok "$c" || fail "$c missing"
done
have pahole && ok "pahole (from dwarves)" || fail "pahole missing — install dwarves"
for c in clang ld.lld llvm-objcopy; do
  have "$c" && ok "$c" || fail "$c missing — needed for LLVM=1"
done
if find /usr/lib /usr/lib64 -name 'libclang.so*' -print -quit 2>/dev/null | grep -q .; then
  ok "libclang present"
else
  fail "libclang missing — bindgen cannot parse C headers"
fi
[ -n "${LIBCLANG_PATH:-}" ] && ok "LIBCLANG_PATH=$LIBCLANG_PATH" \
                           || warn "LIBCLANG_PATH unset — bindgen may not find libclang"

# The whole ccache mechanism is PATH order.
case "$(command -v gcc)" in
  */ccache/*) ok "ccache is intercepting the compiler" ;;
  *)          fail "ccache NOT intercepting ($(command -v gcc)) — its dir must precede /usr/bin on PATH" ;;
esac

# ─────────────────────────────────────────────────────────────────
section "Boot loop"
have qemu-system-x86_64 && ok "qemu $(qemu-system-x86_64 --version | head -1 | awk '{print $4}')" \
                        || fail "qemu-system-x86_64 missing"
have vng && ok "vng $(vng --version 2>&1 | head -1)" || fail "vng missing"
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ok "/dev/kvm usable — near-native boot speed"
elif [ -e /dev/kvm ]; then
  warn "/dev/kvm exists but not usable by you — add yourself to the kvm group"
else
  warn "no /dev/kvm — QEMU will use software emulation (works, 10-20x slower)"
fi

# ─────────────────────────────────────────────────────────────────
section "Kernel tree"
if [ -z "${LINUX_TREE:-}" ]; then
  fail "\$LINUX_TREE unset — open a new shell, or re-check ~/.bashrc"
  printf '\n  %s%d failure(s)%s — cannot continue without a tree\n\n' "$R" "$FAILURES" "$N"
  exit "$FAILURES"
fi
ok "\$LINUX_TREE=$LINUX_TREE"
case "$LINUX_TREE" in
  /mnt/*) fail "tree is on the Windows filesystem — builds several times slower, symlinks lost" ;;
  *)      ok  "tree on a native Linux filesystem" ;;
esac
[ -d "$LINUX_TREE/.git" ] || { fail "no git repo at \$LINUX_TREE"; exit "$FAILURES"; }
cd "$LINUX_TREE" || exit 1
ok "version $(make -s kernelversion 2>/dev/null)"
info "branch $(git rev-parse --abbrev-ref HEAD), HEAD $(git log --oneline -1 | cut -c1-52)"

if [ -f .git/shallow ]; then
  fail "SHALLOW clone — blame, bisect and Fixes: tags will not work. Run: git fetch --unshallow"
else
  ok "full history ($(git rev-list --count HEAD 2>/dev/null) commits)"
fi
for r in origin next stable rfl; do
  git remote get-url "$r" > /dev/null 2>&1 && ok "remote $r" || warn "remote $r not configured"
done
git remote get-url github > /dev/null 2>&1 && ok "remote github (your fork)" \
                                           || warn "no fork remote — you have nowhere to back work up to"
case "$(git remote get-url origin 2>/dev/null)" in
  *git.kernel.org*) ok "origin points at kernel.org (correct)" ;;
  *) warn "origin is not kernel.org — a fork never auto-updates, so fetches would go stale" ;;
esac

# ─────────────────────────────────────────────────────────────────
section "Rust"
if have rustc && have bindgen; then
  wr=$(scripts/min-tool-version.sh rustc 2>/dev/null)
  wb=$(scripts/min-tool-version.sh bindgen 2>/dev/null)
  hr=$(rustc --version | awk '{print $2}')
  hb=$(bindgen --version 2>/dev/null | awk '{print $2}')
  ver_ge "$hr" "$wr" && ok "rustc $hr (needs >= $wr)" || fail "rustc $hr older than required $wr"
  ver_ge "$hb" "$wb" && ok "bindgen $hb (needs >= $wb)" || fail "bindgen $hb older than required $wb"
else
  have rustc   || fail "rustc missing"
  have bindgen || fail "bindgen missing"
fi
if have rustup; then
  rustup component list --installed 2>/dev/null | grep -q '^rust-src' \
    && ok "rust-src (lets the kernel compile core for its own target)" \
    || fail "rust-src missing — kernel Rust cannot build"
fi
if make LLVM=1 rustavailable > /tmp/ra.$$ 2>&1; then
  ok "make LLVM=1 rustavailable — Rust is available"
else
  fail "rustavailable says no:"
  sed 's/^/      | /' /tmp/ra.$$ | tail -8
fi
rm -f /tmp/ra.$$

# ─────────────────────────────────────────────────────────────────
section "Config and build"
if [ -f .config ]; then
  grep -q '^CONFIG_RUST=y' .config && ok "CONFIG_RUST=y" || fail "CONFIG_RUST not enabled"
  v=$(grep -cE '^CONFIG_(VIRTIO|NET_9P|9P_FS)' .config || true)
  [ "${v:-0}" -ge 3 ] && ok "virtio/9p options present ($v) — vng can share your filesystem" \
                      || fail "virtio/9p thin ($v) — run 'vng --kconfig' and rebuild"
  n=$(grep -cE '^CONFIG_SAMPLE_RUST.*=m' .config || true)
  [ "${n:-0}" -gt 0 ] && ok "$n Rust sample(s) as modules" \
                      || warn "no Rust samples as =m — built-in samples cannot be insmod'd"
else
  fail "no .config"
fi
[ -f vmlinux ] && ok "vmlinux $(du -h vmlinux | cut -f1) (for debugging)" || fail "vmlinux missing"
BZ=$(ls arch/*/boot/bzImage 2>/dev/null | head -1)
[ -n "$BZ" ] && ok "$BZ $(du -h "$BZ" | cut -f1) (bootable)" || fail "bzImage missing"
K=$(ls samples/rust/*.ko 2>/dev/null | wc -l)
[ "$K" -gt 0 ] && ok "$K Rust module(s) built" || warn "no Rust .ko files"

# ─────────────────────────────────────────────────────────────────
section "Does it boot?"
# vng needs a real pseudo-terminal, and `timeout` without --foreground would put
# QEMU in a background process group where terminal access stops it (state T).
if ! [ -t 0 ]; then
  warn "no TTY — skipping boot test (vng needs a pseudo-terminal)"
elif have vng && [ -n "$BZ" ]; then
  printf '  booting the guest...\n'
  OUT=$(mktemp); ERR=$(mktemp)
  timeout --foreground 180 vng --quiet --exec 'uname -r' > "$OUT" 2>"$ERR"
  RC=$?
  G=$(tr -d '\r' < "$OUT" | grep -vE '^\s*$' | tail -1)
  H=$(make -s kernelversion 2>/dev/null)
  if [ -n "$G" ]; then
    ok "guest booted and reported: $G"
    case "$G" in "$H"*) ok "guest is running YOUR kernel" ;;
                 *) warn "guest says '$G' but tree is '$H' — stale build?" ;; esac
  elif [ "$RC" -eq 124 ]; then fail "boot timed out"
  else
    fail "guest produced no output"
    [ -s "$ERR" ] && sed 's/^/      | /' "$ERR" | tail -6
  fi
  rm -f "$OUT" "$ERR"
else
  warn "skipping boot test"
fi

# ─────────────────────────────────────────────────────────────────
section "Upstream readiness"
GN=$(git config --global user.name  || true)
GM=$(git config --global user.email || true)
[ -n "$GN" ] && ok "user.name: $GN"  || fail "git user.name unset — Signed-off-by needs it"
[ -n "$GM" ] && ok "user.email: $GM" || fail "git user.email unset"
case "$GN" in *[!\ ]\ *[!\ ]*) : ;; *) [ -n "$GN" ] && warn "user.name is one word — DCO wants a real full name" ;; esac
SM=$(git config --global sendemail.smtpServer || true)
[ -n "$SM" ] && ok "send-email via $SM" || fail "SMTP unset — run setup-upstream.sh"
if git config --global sendemail.smtpPass > /dev/null 2>&1; then
  warn "sendemail.smtpPass is SET — a plaintext password in ~/.gitconfig. Consider unsetting it."
else
  ok "no plaintext SMTP password stored"
fi
git send-email --help > /dev/null 2>&1 && ok "git send-email available" || fail "git-email not installed"
have b4 && ok "b4 $(b4 --version 2>&1 | head -1)" || warn "b4 not installed (optional)"
[ -x scripts/checkpatch.pl ] && ok "checkpatch.pl" || warn "checkpatch.pl missing"

# ─────────────────────────────────────────────────────────────────
section "Summary"
if   [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sEverything checks out. This machine is ready.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Usable — review the warnings above.\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  Re-run the relevant setup script, or see setup/README.md\n\n'
fi
exit "$FAILURES"

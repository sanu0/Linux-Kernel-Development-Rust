#!/bin/bash
# M1W1D3 - verify the boot loop works and is fast enough.
#
# Checks QEMU, virtme-ng, the virtio config options vng needs, an actual guest boot,
# and the loop time. No Rust yet - that is Day 4.
#
# Usage:  bash check_day3.sh
# Exit code is the number of failures.

FAILURES=0
WARNINGS=0

if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; N=''
fi
section() { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }
ok()   { printf '  %s[ ok ]%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s[warn]%s %s\n' "$Y" "$N" "$1"; WARNINGS=$((WARNINGS+1)); }
fail() { printf '  %s[FAIL]%s %s\n' "$R" "$N" "$1"; FAILURES=$((FAILURES+1)); }
info() { printf '         %s\n' "$1"; }

printf '%sM1W1D3 - boot loop check%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Tools"

if command -v qemu-system-x86_64 > /dev/null 2>&1; then
  ok "qemu-system-x86_64 - $(qemu-system-x86_64 --version | head -1)"
else
  fail "qemu-system-x86_64 not found - sudo apt install qemu-system-x86"
fi

if command -v vng > /dev/null 2>&1; then
  ok "vng - $(vng --version 2>&1 | head -1)"
else
  fail "vng not found - pipx install virtme-ng, and put ~/.local/bin on PATH"
fi

# KVM is not required, but its absence makes every boot 10-20x slower.
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ok "/dev/kvm usable - boots run at near-native speed"
else
  warn "/dev/kvm not usable - QEMU will fall back to software emulation (TCG)"
fi

# ─────────────────────────────────────────────────────────────────
section "Kernel image"

: "${LINUX_TREE:?}" 2>/dev/null
if [ -z "${LINUX_TREE:-}" ]; then
  fail "\$LINUX_TREE unset"
  exit 1
fi
cd "$LINUX_TREE" 2>/dev/null || { fail "cannot enter $LINUX_TREE"; exit 1; }

BZ=$(ls arch/*/boot/bzImage 2>/dev/null | head -1)
if [ -n "$BZ" ]; then
  ok "$BZ ($(du -h "$BZ" | cut -f1)) - built $(date -r "$BZ" '+%Y-%m-%d %H:%M')"
else
  fail "no bzImage - run make first"
fi
[ -f vmlinux ] && ok "vmlinux present (needed for debugging from Day 12)" \
               || warn "vmlinux missing - you will want it for oops decoding"

# ─────────────────────────────────────────────────────────────────
section "Config options virtme-ng needs"

# defconfig does not enable these. Without them vng boots but cannot share your
# filesystem into the guest, so you get a kernel with no userspace.
if [ -f .config ]; then
  MISSING=0
  for opt in CONFIG_VIRTIO CONFIG_VIRTIO_PCI CONFIG_NET_9P CONFIG_9P_FS; do
    if grep -qE "^${opt}=(y|m)" .config; then
      ok "$opt"
    else
      warn "$opt not enabled"
      MISSING=$((MISSING+1))
    fi
  done
  if [ "$MISSING" -gt 0 ]; then
    info "run 'vng --kconfig' then rebuild - defconfig does not include these"
  fi
else
  fail "no .config"
fi

# ─────────────────────────────────────────────────────────────────
section "Does it actually boot?"

# virtme-ng needs a real pseudo-terminal: it fails with "not a valid pts" when stdin is
# not a tty (cron, CI, or a shell invoked non-interactively). Detect that and say so,
# rather than reporting it as a broken kernel.
if ! [ -t 0 ]; then
  warn "no TTY on stdin - skipping the boot test"
  info "vng requires a pseudo-terminal; run this script from a normal terminal (or inside tmux)"
elif command -v vng > /dev/null 2>&1 && [ -n "$BZ" ]; then
  printf '  booting the guest (a few seconds)...\n'
  ERRLOG=$(mktemp); OUTLOG=$(mktemp)
  S=$(date +%s)
  # Two subtleties, both of which caused a hang the first time round:
  #
  #  1. `timeout` WITHOUT --foreground runs its child in a NEW PROCESS GROUP so it can
  #     signal the whole group. That makes QEMU a background job as far as the terminal is
  #     concerned, so the moment it touches the tty it gets SIGTTOU/SIGTTIN - whose default
  #     action is to STOP the process. The result is a whole tree in state T, frozen, with
  #     timeout itself stopped too so it never fires. --foreground keeps it in our group.
  #
  #  2. Write stdout to a FILE, not a pipe. virtme-ng wants a real terminal, so keep the
  #     tty attached rather than capturing through $( ).
  timeout --foreground 120 vng --quiet --exec 'uname -r' > "$OUTLOG" 2>"$ERRLOG"
  RC=$?
  E=$(date +%s)
  BOOT_T=$(( E - S ))
  GUEST=$(tr -d '\r' < "$OUTLOG" | grep -vE '^\s*$' | tail -1)

  HOST_VER=$(make -s kernelversion 2>/dev/null)
  if [ "$RC" -eq 124 ]; then
    fail "boot timed out after 120s"
    [ -s "$ERRLOG" ] && sed 's/^/         | /' "$ERRLOG" | tail -10
  elif [ -z "$GUEST" ]; then
    fail "guest produced no output"
    if [ -s "$ERRLOG" ]; then
      info "vng said:"
      sed 's/^/         | /' "$ERRLOG" | tail -10
    fi
    info "try by hand: vng --exec 'uname -r'"
  else
    ok "guest booted in ${BOOT_T}s and reported: $GUEST"
    # The guest must be running the kernel you just built, not some other one.
    case "$GUEST" in
      "$HOST_VER"*) ok "guest is running YOUR kernel ($HOST_VER)" ;;
      *)            warn "guest reports '$GUEST' but the tree is '$HOST_VER' - stale build?" ;;
    esac
  fi
  rm -f "$ERRLOG" "$OUTLOG"

  if   [ "$BOOT_T" -le 15 ]; then ok   "boot time ${BOOT_T}s - good"
  elif [ "$BOOT_T" -le 40 ]; then warn "boot time ${BOOT_T}s - slower than ideal; is KVM active?"
  else                            warn "boot time ${BOOT_T}s - check KVM and CPU allocation"
  fi
else
  warn "skipping boot test - vng or bzImage missing"
fi

# ─────────────────────────────────────────────────────────────────
section "Loop hygiene"

case "$(command -v gcc)" in
  */ccache/*) ok "ccache intercepting - incremental rebuilds stay fast" ;;
  *)          fail "ccache NOT intercepting ($(command -v gcc))" ;;
esac
case "$LINUX_TREE" in
  /mnt/*) fail "tree on the Windows filesystem - builds several times slower" ;;
  *)      ok  "tree on native Linux filesystem" ;;
esac
if command -v ccache > /dev/null 2>&1; then
  HR=$(ccache -s 2>/dev/null | grep -iE '^\s*Hits:' | head -1 | sed 's/^ *//')
  [ -n "$HR" ] && info "ccache $HR"
fi

LOG="$HOME/LKD_RUST/Month_1/Week_1/boot_manual.log"
[ -f "$LOG" ] && ok "boot log captured ($(wc -l < "$LOG") lines)" \
              || warn "no boot log yet - run boot_manual.sh, and get in the habit of capturing"

# ─────────────────────────────────────────────────────────────────
section "Summary"

if   [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDay 3 complete. Measure the full loop with time_loop.sh, then go to M1W1D4.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Day 3 is workable - note the warnings.\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s). See theory/Month_1/Week_1/Day_3.md\n\n' "$R" "$FAILURES" "$N" "$WARNINGS"
fi

exit "$FAILURES"

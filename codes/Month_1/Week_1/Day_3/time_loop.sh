#!/bin/bash
# M1W1D3 - measure the edit -> build -> boot -> output loop.
#
# This is the number that quietly decides how much you learn over the next 18 months.
# Target: under 60 seconds. See theory/Month_1/Week_1/Day_3.md concept 8.
#
# Usage:  bash time_loop.sh [-jN]

set -uo pipefail

JOBS="$(nproc)"
for a in "$@"; do
  case "$a" in
    -j*) JOBS="${a#-j}" ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

: "${LINUX_TREE:?LINUX_TREE not set - open a new shell or re-check ~/.bashrc}"
cd "$LINUX_TREE" || exit 1
command -v vng > /dev/null 2>&1 || { echo "vng not found - install virtme-ng (Day 3 Phase 1)."; exit 1; }

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
secs() { printf '%dm %02ds' $(( $1 / 60 )) $(( $1 % 60 )); }

say "Setup"
echo "  tree : $LINUX_TREE ($(make -s kernelversion))"
echo "  jobs : -j$JOBS"
echo "  gcc  : $(command -v gcc)"
case "$(command -v gcc)" in
  */ccache/*) : ;;
  *) echo "         WARNING: ccache is not intercepting - the loop will be much slower" ;;
esac

# ── 1. Pure boot cost ────────────────────────────────────────────
# Nothing to rebuild: this is the floor, the irreducible cost of starting the VM.
say "1. Boot only (nothing rebuilt)"
S=$(date +%s); vng -- true > /dev/null 2>&1; RC=$?; E=$(date +%s)
T_BOOT=$(( E - S ))
if [ "$RC" -ne 0 ]; then
  echo "  vng failed (exit $RC). Try 'vng -- uname -r' by hand to see the error."
  echo "  Most common cause: virtio/9p options missing - run 'vng --kconfig' and rebuild."
  exit 1
fi
echo "  $(secs $T_BOOT)"

# ── 2. No-op build ───────────────────────────────────────────────
# Nothing changed, so make only stats files and decides there is no work.
say "2. No-op build (make with nothing changed)"
S=$(date +%s); make -j"$JOBS" > /dev/null 2>&1; E=$(date +%s)
T_NOOP=$(( E - S ))
echo "  $(secs $T_NOOP)"

# ── 3. The real loop ─────────────────────────────────────────────
# Touching a .c file forces exactly one recompile plus the relink, which is what a
# real one-line edit costs.
say "3. Full loop: touch a file -> build -> boot -> output"
touch kernel/sched/core.c
S=$(date +%s)
make -j"$JOBS" > /dev/null 2>&1 && OUT=$(vng -- uname -r 2>/dev/null | tr -d '\r')
E=$(date +%s)
T_LOOP=$(( E - S ))
echo "  guest reported: ${OUT:-<no output>}"
echo "  $(secs $T_LOOP)"

# ── Verdict ──────────────────────────────────────────────────────
say "Results"
printf '  boot only        : %s\n' "$(secs $T_BOOT)"
printf '  no-op build      : %s\n' "$(secs $T_NOOP)"
printf '  FULL LOOP        : %s\n' "$(secs $T_LOOP)"
echo
if   [ "$T_LOOP" -le 60 ];  then
  echo "  Under 60s. This is the loop you want - test every single change."
elif [ "$T_LOOP" -le 120 ]; then
  echo "  1-2 minutes. Usable, but worth tightening. Check ccache hit rate and -j."
else
  echo "  Over 2 minutes. Fix this today - it will cost you far more than the time it"
  echo "  takes to fix. Check, in order:"
  echo "    - which gcc          -> must be /usr/lib/ccache/gcc"
  echo "    - echo \$LINUX_TREE   -> must NOT be under /mnt/"
  echo "    - ccache -s          -> should show a high hit rate"
  echo "    - .wslconfig         -> raise 'processors'"
fi
echo
echo "Record these in the timings table in theory/Month_1/Week_1/Day_3.md"

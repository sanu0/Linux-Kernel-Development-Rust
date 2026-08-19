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
command -v vng > /dev/null 2>&1 || { echo "vng not found - install with: sudo apt install -y virtme-ng"; exit 1; }

# virtme-ng requires a real pseudo-terminal and fails with "not a valid pts" without one.
if ! [ -t 0 ]; then
  echo "No TTY on stdin. vng needs a pseudo-terminal - run this from a normal terminal"
  echo "(or inside tmux/screen), not from a pipe, cron, or a non-interactive shell."
  exit 1
fi

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
# NOTE: do not wrap vng in bare `timeout`, and do not capture its output with $( ).
# `timeout` without --foreground puts the child in its own process group, which makes QEMU
# a background job; touching the terminal then raises SIGTTOU/SIGTTIN and STOPS the whole
# tree (state T) rather than running it. Keep vng in our process group, and redirect to
# files rather than pipes so it keeps the tty it needs.
ERRLOG=$(mktemp)
S=$(date +%s); vng --quiet --exec true > /dev/null 2>"$ERRLOG"; RC=$?; E=$(date +%s)
T_BOOT=$(( E - S ))
if [ "$RC" -ne 0 ]; then
  echo "  vng failed (exit $RC):"
  [ -s "$ERRLOG" ] && sed 's/^/    | /' "$ERRLOG" | tail -10
  echo
  echo "  Check, in order:"
  echo "    - by hand:  vng --exec 'uname -r'"
  echo "    - virtio/9p options missing? run 'vng --kconfig' then rebuild"
  echo "    - not a valid pts? run from a normal terminal, or inside tmux"
  rm -f "$ERRLOG"
  exit 1
fi
rm -f "$ERRLOG"
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
GUESTLOG=$(mktemp)
make -j"$JOBS" > /dev/null 2>&1 \
  && vng --quiet --exec 'uname -r' > "$GUESTLOG" 2>/dev/null
OUT=$(tr -d '\r' < "$GUESTLOG" | grep -vE '^\s*$' | tail -1)
rm -f "$GUESTLOG"
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

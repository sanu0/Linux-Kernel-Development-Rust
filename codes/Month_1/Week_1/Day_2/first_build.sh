#!/bin/bash
# M1W1D2 - build the kernel and report the numbers you need for the journal.
#
# Runs a timed build, then optionally a second build with a warm ccache to demonstrate
# what the Day 1 PATH change actually bought you.
#
# Usage:
#   bash first_build.sh              # configure (if needed) + one timed build
#   bash first_build.sh --demo-cache # also: make clean + rebuild, to show the ccache effect
#   bash first_build.sh -j12         # override parallelism (default: nproc)

set -uo pipefail

JOBS="$(nproc)"
DEMO=0
for a in "$@"; do
  case "$a" in
    --demo-cache) DEMO=1 ;;
    -j*)          JOBS="${a#-j}" ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

: "${LINUX_TREE:?LINUX_TREE is not set. Open a new shell, or re-check ~/.bashrc from Day 1.}"
[ -d "$LINUX_TREE/.git" ] || { echo "No kernel tree at $LINUX_TREE - run clone_kernel.sh first."; exit 1; }

LOGDIR="$HOME/LKD_RUST/Month_1/Week_1"
mkdir -p "$LOGDIR"
cd "$LINUX_TREE"

say "Pre-flight"
echo "  tree    : $LINUX_TREE  ($(make -s kernelversion))"
echo "  jobs    : -j$JOBS"
echo "  gcc     : $(command -v gcc)"
case "$(command -v gcc)" in
  */ccache/*) echo "            ccache IS intercepting" ;;
  *)          echo "            WARNING: ccache is NOT intercepting - /usr/lib/ccache must come first on PATH" ;;
esac
echo "  free    : $(df -h "$HOME" | awk 'NR==2{print $4}')"

# Each compile job wants roughly 0.2-1 GB. Warn before the OOM reaper does.
MEM_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
if [ "$JOBS" -gt $(( MEM_GB * 2 )) ]; then
  echo "  WARNING: -j$JOBS with only ${MEM_GB} GB RAM may trigger the OOM killer."
  echo "           If the build dies with no error message, retry with -j$(( JOBS / 2 ))."
fi

if [ ! -f .config ]; then
  say "No .config - running make defconfig"
  make defconfig
else
  echo "  .config : present ($(grep -c '=y' .config) built-in, $(grep -c '=m' .config) modules)"
fi

say "Build 1 (cold cache)"
ccache -z > /dev/null 2>&1 || true
LOG1="$LOGDIR/build1.log"
START=$(date +%s)
make -j"$JOBS" 2>&1 | tee "$LOG1"
RC=${PIPESTATUS[0]}
END=$(date +%s)
T1=$(( END - START ))

if [ "$RC" -ne 0 ]; then
  echo
  echo "BUILD FAILED (exit $RC). Last errors:"
  grep -iE 'error:|Error [0-9]' "$LOG1" | tail -20
  exit "$RC"
fi

printf '\n  build 1: %dm %ds\n' $(( T1 / 60 )) $(( T1 % 60 ))

report() {
  echo "  vmlinux  : $(du -h vmlinux 2>/dev/null | cut -f1)"
  echo "  bzImage  : $(du -h arch/*/boot/bzImage 2>/dev/null | head -1 | cut -f1)"
  echo "  modules  : $(find . -name '*.ko' | wc -l)"
  echo "  warnings : $(grep -ciE 'warning:' "$LOG1")"
  echo "  tree size: $(du -sh --exclude=.git . | cut -f1)"
  echo "  disk free: $(df -h "$HOME" | awk 'NR==2{print $4}')"
}

say "Artifacts"
report
echo
echo "  vmlinux is the uncompressed ELF - keep it, it is what makes an oops readable."
echo "  bzImage is the bootable compressed image - that is what QEMU takes tomorrow."

say "ccache after a cold build (expect near-zero hits: the cache was empty)"
ccache -s 2>/dev/null | head -12

T2=""
if [ "$DEMO" = 1 ]; then
  say "Build 2 (warm cache) - make clean discards every .o, ccache hands them back"
  make clean > /dev/null 2>&1
  START=$(date +%s)
  make -j"$JOBS" > "$LOGDIR/build2.log" 2>&1
  RC2=$?
  END=$(date +%s)
  T2=$(( END - START ))
  if [ "$RC2" -ne 0 ]; then
    echo "  second build FAILED (exit $RC2) - see $LOGDIR/build2.log"
  else
    printf '  build 2: %dm %ds\n' $(( T2 / 60 )) $(( T2 % 60 ))
    echo
    ccache -s 2>/dev/null | head -12
  fi
fi

say "For the journal"
printf '  first build      : %dm %ds\n' $(( T1 / 60 )) $(( T1 % 60 ))
if [ -n "$T2" ]; then
  printf '  second build     : %dm %ds\n' $(( T2 / 60 )) $(( T2 % 60 ))
  if [ "$T2" -gt 0 ]; then
    printf '  speedup          : %sx\n' "$(awk -v a="$T1" -v b="$T2" 'BEGIN{printf "%.1f", a/b}')"
  fi
else
  echo "  second build     : not run (re-run with --demo-cache to see the ccache effect)"
fi
echo "  logs             : $LOGDIR/build1.log"
echo
echo "Copy these into the tables in theory/Month_1/Week_1/Day_2.md"

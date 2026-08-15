#!/bin/bash
# M1W1D3 - boot the kernel with a raw QEMU command line, no virtme-ng.
#
# The point is to see what a kernel boot looks like with nothing helping it: no root
# filesystem, no init, no filesystem sharing. It will panic with "No working init found",
# and that panic IS the success condition - see theory/Month_1/Week_1/Day_3.md concept 3.
#
# Usage:
#   bash boot_manual.sh              # boot, capture the log, exit on panic
#   bash boot_manual.sh --interactive # stay in QEMU (exit with Ctrl-A then X)
#   bash boot_manual.sh --debug       # add nokaslr + earlyprintk, for gdb work later

set -uo pipefail

: "${LINUX_TREE:?LINUX_TREE not set - open a new shell or re-check ~/.bashrc}"
cd "$LINUX_TREE" || exit 1

BZ="arch/x86/boot/bzImage"
[ -f "$BZ" ] || { echo "No $BZ - run 'make -j\$(nproc)' first."; exit 1; }

LOGDIR="$HOME/LKD_RUST/Month_1/Week_1"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/boot_manual.log"

INTERACTIVE=0
CMDLINE="console=ttyS0 panic=-1"
for a in "$@"; do
  case "$a" in
    --interactive) INTERACTIVE=1 ;;
    # nokaslr keeps addresses stable so gdb symbols match; earlyprintk prints before
    # the console is fully up, which is the only way to debug very early boot failures.
    --debug) CMDLINE="console=ttyS0 panic=-1 nokaslr earlyprintk=serial loglevel=7" ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

# KVM runs guest instructions on the real CPU. Without it QEMU falls back to software
# translation (TCG), which is 10-20x slower but still correct.
ACCEL=()
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL=(-enable-kvm)
  echo "acceleration : KVM"
else
  echo "acceleration : TCG (software) - /dev/kvm not usable, this will be slow"
fi

echo "kernel       : $BZ"
echo "command line : $CMDLINE"
echo "log          : $LOG"
echo
echo "Expect: a full boot, then 'Kernel panic - not syncing: No working init found.'"
echo "That is CORRECT - there is no root filesystem for the kernel to hand over to."
echo "Exit QEMU with: Ctrl-A then X"
echo

QEMU=(
  qemu-system-x86_64
  "${ACCEL[@]}"
  -m 2G -smp 4
  -kernel "$BZ"
  -append "$CMDLINE"
  -nographic
  -no-reboot
)

if [ "$INTERACTIVE" = 1 ]; then
  "${QEMU[@]}"
else
  "${QEMU[@]}" 2>&1 | tee "$LOG"
  echo
  echo "=== what the log says ==="
  grep -iE 'Linux version|Command line:|Memory:|Freeing unused|panic' "$LOG" | head -12
  echo
  echo "Full log: $LOG"
fi

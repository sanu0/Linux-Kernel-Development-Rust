#!/bin/bash
# check_day3.sh — verify M1W1D3: the kernel source tree.
#
# Today is about finding your way around, so this checks that the places the
# notes send you to really exist in YOUR tree, that the tools work, and that you
# saved your census. The understanding is checked by the questions at the end.
#
# Usage:  bash check_day3.sh
# Exit code is the number of failures.

DAY_DIR="$(cd "$(dirname "$0")" && pwd)"
TREE="${LINUX_TREE:-$HOME/LKD_RUST/kernel/linux}"
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

printf '%sM1W1D3 — the kernel source tree%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Kernel tree"

if [ ! -d "$TREE/.git" ]; then
  fail "no kernel tree at $TREE — set LINUX_TREE"
  exit 1
fi
cd "$TREE" || exit 1
ok "tree at $TREE — version $(make -s kernelversion), branch $(git rev-parse --abbrev-ref HEAD)"

# ─────────────────────────────────────────────────────────────────
section "The places the notes send you exist in this tree"

for p in drivers/net/hyperv/Makefile drivers/scsi/storvsc_drv.c drivers/hv/vmbus_drv.c \
         rust/kernel rust/bindings rust/helpers rust/macros rust/pin-init samples/rust \
         drivers/net/phy/ax88796b_rust.rs drivers/block/rnull drivers/android/binder \
         drivers/gpu/nova-core drivers/gpu/drm/nova; do
  if [ -e "$p" ]; then ok "$p"; else fail "$p is missing — has the tree changed version?"; fi
done

# ─────────────────────────────────────────────────────────────────
section "MAINTAINERS and get_maintainer.pl"

if awk '/^RUST$/{p=1} p&&/^$/{exit} p' MAINTAINERS | grep -q '^T:.*rust-next'; then
  ok "the RUST entry names the rust-next tree"
else
  fail "could not find the RUST entry's T: line in MAINTAINERS"
fi

if scripts/get_maintainer.pl --no-rolestats -f rust/kernel/print.rs 2>/dev/null | grep -q 'rust-for-linux@vger.kernel.org'; then
  ok "get_maintainer.pl sends rust/ patches to rust-for-linux@vger.kernel.org"
else
  fail "get_maintainer.pl did not name the rust-for-linux list"
fi

# ─────────────────────────────────────────────────────────────────
section "This machine's drivers"

if [ -e /sys/class/net/eth0/device/driver ]; then
  NETDRV=$(basename "$(readlink -f /sys/class/net/eth0/device/driver)")
  ok "your network card (eth0) is driven by: $NETDRV"
  if git grep -q -E "(^|[^a-z_])${NETDRV}\.o" -- '*Makefile'; then
    ok "found $NETDRV in a Makefile: $(git grep -l -E "(^|[^a-z_])${NETDRV}\.o" -- '*Makefile' | head -1)"
  else
    warn "$NETDRV is not built by any Makefile in this tree — it may live outside upstream"
  fi
else
  warn "no /sys/class/net/eth0 driver link — skipping (not WSL, or a different network name)"
fi

# ─────────────────────────────────────────────────────────────────
section "Search tools"

if git grep -q 'macro_rules! pr_info' -- rust/kernel/print.rs; then
  ok "git grep finds where pr_info! is defined (rust/kernel/print.rs)"
else
  fail "git grep could not find pr_info! in rust/kernel/print.rs"
fi
command -v rg > /dev/null && ok "ripgrep (rg) installed" || warn "ripgrep (rg) not installed — optional: sudo apt install ripgrep"

# ─────────────────────────────────────────────────────────────────
section "Your census"

if [ -x "$DAY_DIR/rust_census.sh" ] || [ -f "$DAY_DIR/rust_census.sh" ]; then
  RSF=$(bash "$DAY_DIR/rust_census.sh" 2>/dev/null | awk '/^  Rust +[0-9]/ { print $2; exit }')
  if [ -n "$RSF" ] && [ "$RSF" -gt 0 ]; then
    ok "rust_census.sh runs — $RSF Rust files in this tree"
  else
    fail "rust_census.sh ran but reported no Rust files"
  fi
else
  fail "rust_census.sh not found next to this script"
fi

SAVED=$(ls "$DAY_DIR"/census_*.txt 2>/dev/null | head -1)
[ -n "$SAVED" ] && ok "census saved: $(basename "$SAVED")" \
                || warn "no saved census yet — run: bash rust_census.sh --save"

# ─────────────────────────────────────────────────────────────────
section "What no script can check"

cat <<'EOF'
  Answer these out loud. If any is shaky, re-read that part before Day 4.

    1. Roughly what share of the kernel's code lives in drivers/, and why?
    2. Starting from a driver NAME (like hv_netvsc), how do you find its source?
    3. Why is the driver for your WSL GPU (dxgkrnl) not in your tree?
    4. In a MAINTAINERS entry, what do M:, R:, L:, S:, T: and F: mean?
    5. Which tree do Rust patches go to, and how did you find out?
    6. What lives in rust/bindings, rust/helpers, rust/kernel and rust/macros?
    7. Name three Rust drivers that are in the tree today.
    8. Why is `git grep` faster than plain grep for a kernel tree?
EOF

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sAll checks pass.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  See theory/Month_1/Week_1/Day_3.md\n\n'
fi

exit "$FAILURES"

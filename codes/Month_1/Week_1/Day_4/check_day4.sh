#!/bin/bash
# M1W1D4 - verify the Rust toolchain, the Rust-enabled kernel, and that a Rust module loads.
#
# Usage:  bash check_day4.sh
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

printf '%sM1W1D4 - Rust toolchain check%s\n' "$B" "$N"

: "${LINUX_TREE:?}" 2>/dev/null
[ -n "${LINUX_TREE:-}" ] || { fail "\$LINUX_TREE unset"; exit 1; }
cd "$LINUX_TREE" 2>/dev/null || { fail "cannot enter $LINUX_TREE"; exit 1; }

# ─────────────────────────────────────────────────────────────────
section "Versions: what the tree wants vs what you have"

want_rustc=$(scripts/min-tool-version.sh rustc 2>/dev/null)
want_bindgen=$(scripts/min-tool-version.sh bindgen 2>/dev/null)

# Compare dotted versions numerically: 1.10.0 must count as newer than 1.9.0.
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

if command -v rustc > /dev/null 2>&1; then
  have=$(rustc --version | awk '{print $2}')
  if ver_ge "$have" "$want_rustc"; then ok "rustc $have (wants >= $want_rustc)"
  else fail "rustc $have is older than the required $want_rustc"; fi
else
  fail "rustc not found - run install_rust_toolchain.sh"
fi

if command -v bindgen > /dev/null 2>&1; then
  have=$(bindgen --version 2>/dev/null | awk '{print $2}')
  if ver_ge "$have" "$want_bindgen"; then ok "bindgen $have (wants >= $want_bindgen)"
  else fail "bindgen $have is older than the required $want_bindgen"; fi
else
  fail "bindgen not found"
fi

# rust-src is what lets the kernel compile core/alloc for its own custom target.
if command -v rustup > /dev/null 2>&1; then
  if rustup component list --installed 2>/dev/null | grep -q '^rust-src'; then
    ok "rust-src installed (needed to compile core for the kernel's target)"
  else
    fail "rust-src missing - rustup component add rust-src"
  fi
  OV=$(rustup show 2>/dev/null | grep -iA1 'active toolchain' | tail -1)
  [ -n "$OV" ] && info "active toolchain here: $OV"
else
  warn "rustup not found - version pinning per-tree is unavailable"
fi

if [ -n "${LIBCLANG_PATH:-}" ] && [ -d "$LIBCLANG_PATH" ]; then
  ok "LIBCLANG_PATH=$LIBCLANG_PATH"
elif find /usr/lib -name 'libclang.so*' -print -quit 2>/dev/null | grep -q .; then
  warn "LIBCLANG_PATH unset (libclang exists, but bindgen may not find it)"
else
  fail "libclang not found - install libclang-dev"
fi

# ─────────────────────────────────────────────────────────────────
section "The gate"

if make LLVM=1 rustavailable > /tmp/ra.$$ 2>&1; then
  ok "make LLVM=1 rustavailable - Rust is available"
else
  fail "rustavailable says NO:"
  sed 's/^/         | /' /tmp/ra.$$ | tail -12
fi
rm -f /tmp/ra.$$

# ─────────────────────────────────────────────────────────────────
section "Config"

if [ -f .config ]; then
  grep -q '^CONFIG_RUST=y' .config && ok "CONFIG_RUST=y" \
                                   || fail "CONFIG_RUST not enabled - run enable_rust_config.sh"

  n=$(grep -cE '^CONFIG_SAMPLE_RUST.*=m' .config || true)
  if [ "${n:-0}" -gt 0 ]; then ok "$n Rust sample(s) configured as modules"
  else warn "no Rust samples set to =m - you cannot insmod/rmmod built-in samples"; fi

  # Day 3's boot loop depends on these. `make defconfig` would have silently removed them.
  v=$(grep -cE '^CONFIG_(VIRTIO|NET_9P|9P_FS)' .config || true)
  if [ "${v:-0}" -ge 3 ]; then ok "virtio/9p options intact ($v) - vng still works"
  else fail "virtio/9p options missing ($v) - did you run 'make defconfig'? restore a .config backup"; fi

  grep -q '^CONFIG_RUST_DEBUG_ASSERTIONS=y' .config && ok "RUST_DEBUG_ASSERTIONS=y" \
    || warn "RUST_DEBUG_ASSERTIONS off - worth having during development"
else
  fail "no .config"
fi

# ─────────────────────────────────────────────────────────────────
section "Build artifacts"

if [ -f rust/bindings/bindings_generated.rs ]; then
  ok "bindings_generated.rs ($(wc -l < rust/bindings/bindings_generated.rs) lines) - bindgen ran"
else
  fail "bindings_generated.rs missing - the Rust build has not run yet"
fi

for f in rust/core.o rust/kernel.o; do
  [ -f "$f" ] && ok "$f built" || warn "$f missing"
done

KO=$(ls samples/rust/*.ko 2>/dev/null | wc -l)
if [ "$KO" -gt 0 ]; then
  ok "$KO Rust sample module(s) built"
  ls samples/rust/*.ko 2>/dev/null | sed 's|.*/|         |'
else
  fail "no Rust .ko files - build with: make LLVM=1 -j\$(nproc)"
fi

# ─────────────────────────────────────────────────────────────────
section "Does a Rust module actually load?"

if ! [ -t 0 ]; then
  warn "no TTY on stdin - skipping the load test (vng needs a pseudo-terminal)"
elif [ "$KO" -gt 0 ] && command -v vng > /dev/null 2>&1; then
  printf '  booting and loading rust_minimal...\n'
  OUT=$(mktemp); ERR=$(mktemp)
  # timeout needs --foreground, or QEMU lands in a background process group, takes
  # SIGTTOU on its first terminal access, and the whole tree stops in state T.
  timeout --foreground 180 vng --quiet \
    --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -12; rmmod rust_minimal' \
    > "$OUT" 2>"$ERR"
  RC=$?
  if grep -qi 'rust_minimal' "$OUT"; then
    ok "rust_minimal loaded and printed to dmesg"
    grep -i 'rust_minimal' "$OUT" | head -8 | sed 's/^/         | /'
    printf '\n  %sThat is Rust executing in kernel space.%s\n' "$G" "$N"
  elif [ "$RC" -eq 124 ]; then
    fail "timed out after 180s"
  else
    fail "no rust_minimal output in dmesg"
    [ -s "$ERR" ] && sed 's/^/         | /' "$ERR" | tail -8
    info "try by hand: vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail'"
  fi
  rm -f "$OUT" "$ERR"
else
  warn "skipping load test - no .ko files or vng missing"
fi

# ─────────────────────────────────────────────────────────────────
section "Developer ergonomics"

[ -f rust-project.json ] && ok "rust-project.json present (rust-analyzer works)" \
                         || warn "run: make LLVM=1 rust-analyzer"
[ -d Documentation/output/rust/rustdoc ] && ok "local rustdoc built" \
                                        || warn "run: make LLVM=1 rustdoc"

# ─────────────────────────────────────────────────────────────────
section "Summary"

if   [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDay 4 complete. You have run Rust in ring 0. On to M1W1D5.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Day 4 is done.\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s). See theory/Month_1/Week_1/Day_4.md\n\n' "$R" "$FAILURES" "$N" "$WARNINGS"
fi

exit "$FAILURES"

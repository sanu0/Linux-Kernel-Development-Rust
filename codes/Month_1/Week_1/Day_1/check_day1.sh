#!/bin/bash
# check_day1.sh — verify M1W1D1: ownership, moves, and Drop.
#
# Today is a concepts day, so most of it cannot be checked by a script. What this
# DOES check is that your userspace Rust loop works and the demo behaves as the
# notes claim. The understanding is on you — see the questions at the end.
#
# Usage:  bash check_day1.sh
# Exit code is the number of failures.

DAY_DIR="$(cd "$(dirname "$0")" && pwd)"
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
have() { command -v "$1" > /dev/null 2>&1; }

printf '%sM1W1D1 — ownership, moves, Drop%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Rust toolchain (userspace loop)"

# rustc lives in ~/.cargo/bin, which a distro .bashrc only adds for INTERACTIVE
# shells — so a script like this one may not see it without help.
have rustc || export PATH="$HOME/.cargo/bin:$PATH"

if have rustc; then
  ok "rustc — $(rustc --version)"
else
  fail "rustc not found, even after adding ~/.cargo/bin to PATH"
  info "install with: curl --proto '=https' -sSf https://sh.rustup.rs | sh -s -- -y"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────
section "The demo compiles and runs"

SRC="$DAY_DIR/ownership_demo.rs"
if [ ! -f "$SRC" ]; then
  fail "ownership_demo.rs not found next to this script"
  exit 1
fi
ok "found ownership_demo.rs"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if rustc "$SRC" -o "$TMP/demo" 2> "$TMP/warn"; then
  ok "compiles"
  if [ -s "$TMP/warn" ]; then
    warn "compiled with warnings:"
    sed 's/^/         | /' "$TMP/warn" | head -10
  else
    ok "no warnings"
  fi
else
  fail "COMPILE FAILED:"
  sed 's/^/         | /' "$TMP/warn" | head -20
  exit 1
fi

"$TMP/demo" > "$TMP/out" 2>&1 || { fail "demo exited non-zero"; }
ok "runs ($(wc -l < "$TMP/out") lines of output)"

# ─────────────────────────────────────────────────────────────────
section "Drop behaves the way the notes claim"

# Each check pins one rule from the notes, so if a future Rust release changed
# any of them this script would catch it rather than the notes quietly lying.

# Reverse declaration order at end of scope.
if grep -A3 -- '-- end of function --' "$TMP/out" \
   | tr -d ' ' | tr '\n' ' ' | grep -q 'drop:third.*drop:second.*drop:first'; then
  ok "scope end drops in REVERSE declaration order"
else
  fail "unexpected drop order at end of scope"
fi

# Inner scope drops at its own brace, before the outer value.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' | grep -q 'drop:inner.*drop:outer'; then
  ok "nested scope drops inner before outer"
else
  fail "nested scope order wrong"
fi

# A move produces ONE make and ONE drop - the core anti-double-free property.
MAKES=$(grep -c 'make: a$' "$TMP/out")
DROPS=$(grep -c 'drop: a$' "$TMP/out")
if [ "$MAKES" -eq 1 ] && [ "$DROPS" -eq 1 ]; then
  ok "move: exactly one make and one drop (no double free, no early drop)"
else
  fail "move produced $MAKES make(s) and $DROPS drop(s), expected 1 and 1"
fi

# Early return drops only what was live, in reverse order. This is the whole
# goto-ladder replacement, so assert it precisely.
FLAT=$(tr -d ' ' < "$TMP/out" | tr '\n' ' ')
if printf '%s' "$FLAT" | grep -q 'bailingoutafterstep2--.*drop:step2.*drop:step1'; then
  ok "early return: step2 then step1, reverse order, nothing else"
else
  fail "early-return cleanup order wrong (section 5, fail_after=2)"
fi
# Bailing after step1 must NOT drop a step2 that was never constructed.
EARLY1=$(sed -n '/fail_after=1/,/fail_after=2/p' "$TMP/out")
if printf '%s' "$EARLY1" | grep -q 'drop: step1' && ! printf '%s' "$EARLY1" | grep -q 'step2'; then
  ok "early return: step2 never built, so never dropped"
else
  fail "fail_after=1 path touched step2, which should not exist yet"
fi

# Clone makes a second value, so a second drop.
if [ "$(grep -c 'drop: Tag(original)' "$TMP/out")" -eq 2 ]; then
  ok "clone: two values, two drops"
else
  fail "clone did not produce two drops"
fi

# Shadowing does NOT drop early.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' | grep -q 'drop:shadowing.*drop:shadowed'; then
  ok "shadowing: both values live to end of scope"
else
  fail "shadowing behaved unexpectedly"
fi

# mem::forget suppresses Drop.
if grep -q 'drop: kept' "$TMP/out" && ! grep -q 'drop: leaked' "$TMP/out"; then
  ok "mem::forget suppressed Drop (leaking is safe, just wrong)"
else
  fail "mem::forget did not suppress Drop"
fi

# Vec drops front to back, NOT reversed.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' | grep -q 'drop:elem0.*drop:elem1.*drop:elem2'; then
  ok "Vec drops front to back (reverse order is a SCOPE rule, not a collection rule)"
else
  fail "Vec drop order unexpected"
fi

# `./demo 3` must run section 3 alone, so predictions are not spoiled.
if "$TMP/demo" 3 > "$TMP/one" 2>&1 && grep -q '^3\. Move' "$TMP/one" \
   && ! grep -q '^1\. End of scope' "$TMP/one"; then
  ok "./demo 3 runs only section 3 (no spoilers)"
else
  fail "./demo 3 did not run section 3 on its own"
fi

# ─────────────────────────────────────────────────────────────────
section "raii_probe.rs — the goto ladder, deleted"

PSRC="$DAY_DIR/raii_probe.rs"
if [ ! -f "$PSRC" ]; then
  fail "raii_probe.rs not found next to this script"
elif rustc "$PSRC" -o "$TMP/probe" 2> "$TMP/pw"; then
  if [ -s "$TMP/pw" ]; then warn "raii_probe.rs compiled with warnings"; else ok "raii_probe.rs compiles cleanly"; fi
  "$TMP/probe" > "$TMP/pout" 2>&1
  PFLAT=$(tr -d ' ' < "$TMP/pout" | tr '\n' ' ')
  # Failing at the lock must release exactly what existed, newest first.
  if printf '%s' "$PFLAT" | grep -q 'FAILEDtoacquirelock releasedirq releasedmemory probereturnederror'; then
    ok "failure at step 3 releases irq, then memory — with no cleanup code in probe()"
  else
    fail "unexpected cleanup when step 3 fails"
  fi
  # Success tears down in reverse only because Device lists its fields in reverse.
  if printf '%s' "$PFLAT" | grep -q 'probesucceeded;deviceinuse... releasedlock releasedirq releasedmemory'; then
    ok "success tears down lock, irq, memory (struct fields drop top to bottom)"
  else
    fail "unexpected teardown order on success"
  fi
else
  fail "raii_probe.rs COMPILE FAILED:"
  sed 's/^/         | /' "$TMP/pw" | head -20
fi

# ─────────────────────────────────────────────────────────────────
section "Your own work"

MINE=$(ls "$DAY_DIR"/my_*.rs 2>/dev/null | head -1)
if [ -n "$MINE" ]; then
  ok "found $(basename "$MINE")"
  if rustc "$MINE" -o "$TMP/mine" 2>/dev/null; then
    ok "$(basename "$MINE") compiles"
  else
    warn "$(basename "$MINE") does not compile yet"
  fi
else
  warn "no my_drop_order.rs yet — the 'Your Turn' part asks you to write and save one"
fi

# ─────────────────────────────────────────────────────────────────
section "What no script can check"

cat <<'EOF'
  Answer these out loud. If any is shaky, re-read that concept before Day 2.

    1. Name the three ways giving memory back can go wrong.
    2. Why can the kernel not use a garbage collector?
    3. Draw the stack-and-heap picture of a String. Why does `let b = a;`
       move it instead of copying it, and what bug does that prevent?
    4. Why can a type never be both Copy and Drop?
    5. What prints, and in what order?

         let a = Noisy::new("a");
         { let b = Noisy::new("b"); let c = b; }
         let d = Noisy::new("d");

    6. When raii_probe fails at step 3, what is released, in what order,
       and where in probe() is the cleanup code?
    7. Why is unwrap() a bug in kernel code, not just poor style?
    8. Name four situations where Drop does not run.
       (One of them explains why you built the Week 0 samples as =m, not =y.)
EOF

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDemo verified. The understanding is the real deliverable.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  See theory/Month_1/Week_1/Day_1.md\n\n'
fi

exit "$FAILURES"

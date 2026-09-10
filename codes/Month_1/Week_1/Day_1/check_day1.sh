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

# ─────────────────────────────────────────────────────────────────
section "Your own work"

[ -f "$DAY_DIR/my_ownership_demo.rs" ] \
  && ok "my_ownership_demo.rs saved (your edited copy)" \
  || warn "no my_ownership_demo.rs yet — Phase 6 asks you to save your edited version"

# ─────────────────────────────────────────────────────────────────
section "What no script can check"

cat <<'EOF'
  Answer these out loud. If any is shaky, re-read that concept before Day 2.

    1. Why ownership instead of a garbage collector, in KERNEL terms?
    2. Why does `let b = a;` make `a` unusable? What bug does that prevent?
    3. Why can a type never be both Copy and Drop?
    4. What prints, and in what order?

         let a = Noisy::new("a");
         { let b = Noisy::new("b"); let c = b; }
         let d = Noisy::new("d");

    5. Describe how RAII removes the `goto err_unlock` ladder.
       Did you read a real one in drivers/ ?
    6. Name the three things kernel Rust does NOT have.
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

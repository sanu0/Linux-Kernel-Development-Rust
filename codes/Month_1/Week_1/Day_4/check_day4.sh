#!/bin/bash
# check_day4.sh — verify M1W1D4: structs, enums, pattern matching, derive.
#
# Checks that the demo compiles cleanly and behaves as the notes describe, that
# enum_errors.rs compiles as-is, and that uncommenting each block in it really
# produces the error code the notes claim on YOUR rustc.
#
# Usage:  bash check_day4.sh
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
have() { command -v "$1" > /dev/null 2>&1; }

printf '%sM1W1D4 — structs, enums, pattern matching%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Toolchain"

have rustc || export PATH="$HOME/.cargo/bin:$PATH"
if have rustc; then ok "rustc — $(rustc --version)"; else fail "rustc not found"; exit 1; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ─────────────────────────────────────────────────────────────────
section "enums_demo.rs"

SRC="$DAY_DIR/enums_demo.rs"
[ -f "$SRC" ] || { fail "enums_demo.rs not found next to this script"; exit 1; }

if rustc "$SRC" -o "$TMP/enums" 2> "$TMP/w"; then
  ok "compiles"
  if [ -s "$TMP/w" ]; then warn "compiled with warnings:"; sed 's/^/         | /' "$TMP/w" | head -8; else ok "no warnings"; fi
else
  fail "COMPILE FAILED:"; sed 's/^/         | /' "$TMP/w" | head -20; exit 1
fi
"$TMP/enums" > "$TMP/out" 2>&1 || fail "demo exited non-zero"

expect() {  # expect "<exact text>" "<what it proves>"
  if grep -qF -- "$1" "$TMP/out"; then ok "$2"; else fail "missing: $1"; fi
}

expect "CTRL at offset 0x10 holds 0xbeef"          "a method with &mut self changed the struct"
expect "number 42      -> ??? not a real state"     "a plain number accepts a state that does not exist"
expect "probe failed with error -19"               "an enum variant carried data and match pulled it out"
expect "-5 -> some other error"                    "a match guard (c if c < 0) caught the unlisted error"
expect "let else:  eth0 -> 42, gpu9 -> 0"          "let else returned early when there was no irq"
expect "PartialEq:      v == w is true, v == d is false" "derive(PartialEq) compares field by field"
expect "hand-written ==: true"                     "a hand-written PartialEq does the same thing"
expect "finished in state Removed"                 "the enum state machine completed a legal life cycle"
expect "cannot suspend while Uninitialized"        "an illegal move returned an error"
expect "Suspended -> Removed"                      "typestate: removed straight from Suspended"

# while let pops from the END of the list.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' \
   | grep -q 'whilelet:runningstart whilelet:runninginit whilelet:runningprobe'; then
  ok "while let ran the jobs last-in first-out (pop takes from the end)"
else
  fail "while let order unexpected"
fi

if "$TMP/enums" 3 > "$TMP/one" 2>&1 && grep -q '3\. Enum variants' "$TMP/one" \
   && ! grep -q '1\. Struct shapes' "$TMP/one"; then
  ok "running one section (./enums 3) shows only that section"
else
  fail "running ./enums 3 did not show section 3 on its own"
fi

# ─────────────────────────────────────────────────────────────────
section "enum_errors.rs — each block gives the error the notes claim"

ESRC="$DAY_DIR/enum_errors.rs"
if [ ! -f "$ESRC" ]; then
  fail "enum_errors.rs not found"
else
  if rustc "$ESRC" -o "$TMP/ee" 2>/dev/null; then
    ok "compiles as-is (every error still inside /* */)"
  else
    fail "does not compile as-is — is a block left uncommented?"
  fi
  want=("" E0004 E0599 E0382 E0277 E0369)
  what=("" "a match that forgets a variant" "an illegal typestate move" \
        "using an old state after a move" "{:?} without derive(Debug)" "== without derive(PartialEq)")
  for n in 1 2 3 4 5; do
    mkdir -p "$TMP/u$n"
    awk -v N="$n" '$0=="/*"{c++; if(c==N){skip=1; next}} skip&&$0=="*/"{skip=0; next} {print}' \
      "$ESRC" > "$TMP/u$n/enum_errors.rs"
    got=$(cd "$TMP/u$n" && rustc enum_errors.rs -o /dev/null 2>&1 | grep -o 'error\[E[0-9]*\]' | head -1)
    if [ "$got" = "error[${want[$n]}]" ]; then
      ok "block $n: ${want[$n]} — ${what[$n]}"
    else
      fail "block $n gave '${got:-no error}', notes claim ${want[$n]}"
    fi
  done
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
  warn "no my_link_state.rs yet — the 'Your Turn' part asks you to write and save one"
fi

# ─────────────────────────────────────────────────────────────────
section "What no script can check"

cat <<'EOF'
  Answer these out loud. If any is shaky, re-read that part before Day 5.

    1. What is the difference between an associated function and a method?
    2. Why is a state stored as a plain number (u8, or a C enum) risky?
    3. What does it mean that an enum variant can carry data? Give an example.
    4. Why must a match cover every variant, and why is `_ =>` risky in a
       state machine?
    5. When would you use if let, let else, and while let?
    6. Name three derives and what each one gives you.
    7. In the enum state machine, when is an illegal move caught? And in the
       typestate version?
    8. Why can't you use the old state after a typestate transition?
EOF

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sAll verified. The understanding is the real deliverable.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  See theory/Month_1/Week_1/Day_4.md\n\n'
fi

exit "$FAILURES"

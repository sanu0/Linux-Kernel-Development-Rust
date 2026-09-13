#!/bin/bash
# check_day2.sh — verify M1W1D2: borrowing and the borrow checker.
#
# Checks that the demo compiles and behaves as the notes describe, that the
# errors file still compiles with everything commented out, and that each of the
# five errors really does produce the error code the notes claim on YOUR rustc.
#
# That last part matters: error codes are stable but messages get reworded, and
# a check that pins them stops the notes quietly drifting from reality.
#
# Usage:  bash check_day2.sh
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

printf '%sM1W1D2 — borrowing and the borrow checker%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Toolchain"

have rustc || export PATH="$HOME/.cargo/bin:$PATH"
if have rustc; then
  ok "rustc — $(rustc --version)"
else
  fail "rustc not found even after adding ~/.cargo/bin to PATH"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ─────────────────────────────────────────────────────────────────
section "borrow_demo.rs — the legal shapes"

SRC="$DAY_DIR/borrow_demo.rs"
if [ ! -f "$SRC" ]; then
  fail "borrow_demo.rs not found next to this script"
  exit 1
fi

if rustc "$SRC" -o "$TMP/demo" 2> "$TMP/w"; then
  ok "compiles"
  [ -s "$TMP/w" ] && { warn "with warnings:"; sed 's/^/         | /' "$TMP/w" | head -8; } \
                  || ok "no warnings"
else
  fail "COMPILE FAILED:"
  sed 's/^/         | /' "$TMP/w" | head -20
  exit 1
fi

"$TMP/demo" > "$TMP/out" 2>&1 || fail "demo exited non-zero"
ok "runs ($(wc -l < "$TMP/out") lines)"

# Borrowing must not move: the owner is still usable afterwards.
grep -q "and b is still 'still mine'" "$TMP/out" \
  && ok "borrowing does not move — owner still usable" \
  || fail "section 1 output unexpected"

# Many shared borrows at once, all pointing at the same bytes.
grep -q 'three readers agree: hello / hello / hello' "$TMP/out" \
  && ok "many shared borrows coexist" \
  || fail "section 2 output unexpected"

# The addresses printed must be identical - no copy happened.
A1=$(grep 'same address?' "$TMP/out" | awk '{print $3}')
A2=$(grep 'same address?' "$TMP/out" | awk '{print $4}')
if [ -n "$A1" ] && [ "$A1" = "$A2" ]; then
  ok "shared borrows point at the same address ($A1) — nothing was copied"
else
  fail "expected identical addresses, got '$A1' and '$A2'"
fi

grep -q 'after:  original-modified' "$TMP/out" \
  && ok "exclusive borrow can write through" \
  || fail "section 3 output unexpected"

# NLL: the push after the borrow's last use must have succeeded.
grep -q 'after push: \[1, 2, 3, 4\]' "$TMP/out" \
  && ok "non-lexical lifetimes: borrow ended at last use, push allowed" \
  || fail "section 4 output unexpected"

# A slice reports its own length - pointer and length cannot disagree.
grep -q 'the slice itself reports len 3' "$TMP/out" \
  && ok "slices carry their own length" \
  || fail "section 5 output unexpected"

grep -q 'v.get(10) = None' "$TMP/out" \
  && ok "get() returns None instead of panicking" \
  || fail "section 6 output unexpected"

grep -q 'after split_at_mut: \[100, 4, 200, 8\]' "$TMP/out" \
  && ok "split_at_mut: two &mut into non-overlapping halves" \
  || fail "section 7 output unexpected"

# A borrow ending must NOT drop. The drop belongs to the owner's scope.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' \
   | grep -q 'expectNOdrop--.*stillalive.*NOWexpectthedrop--.*drop:thevalue'; then
  ok "references do not own — no drop when a borrow ends"
else
  fail "section 8: a borrow ending appears to have dropped something"
fi

# Guard drop releases the lock.
if tr -d ' ' < "$TMP/out" | tr '\n' ' ' \
   | grep -q '\[lockacquired\].*guardgoingoutofscope--.*\[lockreleased\]'; then
  ok "lock guard: Drop releases the lock automatically"
else
  fail "section 9 output unexpected"
fi

# ─────────────────────────────────────────────────────────────────
section "borrow_errors.rs — must compile with everything commented"

ESRC="$DAY_DIR/borrow_errors.rs"
if [ ! -f "$ESRC" ]; then
  fail "borrow_errors.rs not found"
else
  if rustc "$ESRC" -o "$TMP/be" 2> "$TMP/we"; then
    ok "compiles as-is (all five errors still commented out)"
  else
    fail "does not compile as-is — did you leave a block uncommented?"
    sed 's/^/         | /' "$TMP/we" | head -12
  fi
fi

# ─────────────────────────────────────────────────────────────────
section "The five errors really do produce those codes"

# Rebuilt as minimal standalone programs, so this verifies the codes the notes
# claim against the rustc you actually have.
mk() { printf '%s\n' "$2" > "$TMP/$1.rs"; }

mk e1 'fn main() {
    let mut v = vec![1, 2, 3];
    let first = &v[0];
    v.push(4);
    println!("{}", first);
}'
mk e2 'fn main() {
    let mut s = String::from("hi");
    let a = &mut s;
    let b = &mut s;
    a.push('"'"'!'"'"');
    b.push('"'"'?'"'"');
}'
mk e3 'fn dangle() -> &String {
    let s = String::from("local");
    &s
}
fn main() { let _ = dangle(); }'
mk e4 'fn main() {
    let s = String::from("not mut");
    let r = &mut s;
    r.push('"'"'!'"'"');
}'
mk e5 'fn consume(v: Vec<i32>) -> usize { v.len() }
fn main() {
    let v = vec![1, 2, 3];
    let first = &v[0];
    let n = consume(v);
    println!("{} {}", first, n);
}'

check_err() {
  local name="$1" want="$2" desc="$3" got
  got=$(rustc "$TMP/$name.rs" -o /dev/null 2>&1 | grep -o 'error\[E[0-9]*\]' | head -1)
  if [ "$got" = "error[$want]" ]; then
    ok "$want — $desc"
  elif [ -z "$got" ]; then
    fail "$name COMPILED — it was supposed to fail with $want"
  else
    fail "$name gave $got, notes claim $want ($desc)"
  fi
}

check_err e1 E0502 "mutable and immutable borrow overlap"
check_err e2 E0499 "two mutable borrows at once"
check_err e3 E0106 "returning a reference to a local (signature rejected)"
check_err e4 E0596 "mutable borrow of a non-mut binding"
check_err e5 E0505 "moving a value that is still borrowed"

# ─────────────────────────────────────────────────────────────────
section "Your own work"

[ -f "$DAY_DIR/my_borrow_errors.rs" ] \
  && ok "my_borrow_errors.rs saved" \
  || warn "no my_borrow_errors.rs yet — save your annotated copy"

# ─────────────────────────────────────────────────────────────────
section "What no script can check"

cat <<'EOF'
  Answer these out loud. If any is shaky, re-read that section before Day 3.

    1. State the aliasing rule. Why is each of its three cases safe or unsafe?
    2. In the Vec push example, what happens to the heap buffer, and why does
       that make the reference dangle?
    3. Why is that code rejected even when the Vec HAS spare capacity?
    4. What are non-lexical lifetimes? Which two lines can you swap to make the
       same code compile?
    5. Why can a pointer and a length never disagree in a slice?
    6. Why does kernel code prefer v.get(i) over v[i]?
    7. Why is `fn dangle() -> &String` rejected at the SIGNATURE, not the body?
    8. How do Drop (Day 1) and exclusive borrowing (Day 2) combine to make a
       lock guard safe? Name both guarantees separately.
EOF

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sAll verified. The understanding is the real deliverable.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  See theory/Month_1/Week_1/Day_2.md\n\n'
fi

exit "$FAILURES"

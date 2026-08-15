#!/bin/bash
# M1W1D2 - verify the clone and the first build.
#
# Checks only what Day 2 covers: the tree, its history, the remotes, the config, the build
# artifacts, and ccache. There is no Rust toolchain yet (Day 4) and nothing has been booted
# (Day 3), so neither is checked here.
#
# Usage:  bash check_day2.sh
# Exit code is the number of failures, so it works as a CI predicate.

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

printf '%sM1W1D2 - clone and build check%s\n' "$B" "$N"

# ─────────────────────────────────────────────────────────────────
section "Environment carried over from Day 1"

if [ -n "${LINUX_TREE:-}" ]; then
  ok "\$LINUX_TREE = $LINUX_TREE"
else
  fail "\$LINUX_TREE unset - re-check ~/.bashrc from Day 1 Phase 7, then open a new shell"
  exit 1
fi

case "$LINUX_TREE" in
  /mnt/*) fail "tree is under /mnt/ - the Windows filesystem. Builds will be several times slower" ;;
  *)      ok  "tree is on a native Linux filesystem" ;;
esac

case "$(command -v gcc)" in
  */ccache/*) ok "ccache is intercepting the compiler" ;;
  *)          fail "ccache NOT intercepting ($(command -v gcc)) - /usr/lib/ccache must be first on PATH" ;;
esac

# ─────────────────────────────────────────────────────────────────
section "The clone"

if [ ! -d "$LINUX_TREE/.git" ]; then
  fail "no git repository at $LINUX_TREE - run clone_kernel.sh"
  exit 1
fi
cd "$LINUX_TREE" || exit 1
ok "repository present"
info "version : $(make -s kernelversion 2>/dev/null)"
info "HEAD    : $(git log --oneline -1 2>/dev/null)"

# History is a kernel development tool: blame, bisect, and Fixes: tags all need it.
if [ -f .git/shallow ]; then
  fail "SHALLOW clone - git blame, bisect and Fixes: tags will not work"
  info "fix: git fetch --unshallow   (this will take a while, and is worth it)"
else
  COMMITS=$(git rev-list --count HEAD 2>/dev/null)
  if [ "${COMMITS:-0}" -gt 1000000 ]; then
    ok "full history ($COMMITS commits)"
  else
    warn "only $COMMITS commits reachable - expected >1,000,000. Truncated history?"
  fi
fi

if git config --get remote.origin.promisor > /dev/null 2>&1; then
  warn "blobless partial clone - fine, but blame on old revisions will pause to fetch"
fi

# Prove the history is actually usable rather than just present.
if git log -1 --format=%H -- rust/kernel/lib.rs > /dev/null 2>&1; then
  ok "git log works on a real path"
else
  warn "could not query history for rust/kernel/lib.rs"
fi

info ".git size  : $(du -sh .git 2>/dev/null | cut -f1)"
info "tree size  : $(du -sh --exclude=.git . 2>/dev/null | cut -f1)"

# ─────────────────────────────────────────────────────────────────
section "Remotes"

for r in origin next stable rfl; do
  if u=$(git remote get-url "$r" 2>/dev/null); then
    ok "$r -> $u"
  else
    warn "remote '$r' not configured (add it with clone_kernel.sh)"
  fi
done

case "$(git remote get-url origin 2>/dev/null)" in
  *git.kernel.org*) ok "origin tracks the canonical kernel.org tree" ;;
  *github.com/torvalds*) warn "origin points at the GitHub mirror - fine, but kernel.org is canonical" ;;
esac

# ─────────────────────────────────────────────────────────────────
section "Tree layout"

for d in arch drivers kernel mm fs net block include rust samples scripts tools Documentation; do
  [ -d "$d" ] && ok "$d/" || fail "$d/ missing - is this really a kernel tree?"
done
[ -f MAINTAINERS ] && ok "MAINTAINERS present" || fail "MAINTAINERS missing"
[ -d include/uapi ] && ok "include/uapi/ (the permanent userspace contract)" || warn "include/uapi/ missing"
[ -d rust/kernel ] && ok "rust/kernel/ ($(find rust/kernel -name '*.rs' | wc -l) .rs files)" \
                   || fail "rust/kernel/ missing - tree too old for this roadmap"
[ -d samples/rust ] && ok "samples/rust/" || warn "samples/rust/ missing"

# ─────────────────────────────────────────────────────────────────
section "Configuration"

if [ -f .config ]; then
  ok ".config present ($(wc -l < .config) lines)"
  info "built-in (=y) : $(grep -c '=y' .config)"
  info "modules  (=m) : $(grep -c '=m' .config)"
  if grep -q '^CONFIG_RUST=y' .config; then
    ok "CONFIG_RUST=y (ahead of schedule - that is Day 4)"
  else
    ok "CONFIG_RUST not enabled (expected today)"
  fi
else
  fail "no .config - run: make defconfig"
fi

# ─────────────────────────────────────────────────────────────────
section "Build artifacts"

if [ -f vmlinux ]; then
  ok "vmlinux ($(du -h vmlinux | cut -f1)) - the uncompressed ELF, used for debugging"
else
  fail "vmlinux missing - the build did not complete"
fi

BZ=$(ls arch/*/boot/bzImage 2>/dev/null | head -1)
if [ -n "$BZ" ]; then
  ok "$BZ ($(du -h "$BZ" | cut -f1)) - the bootable image for tomorrow"
else
  fail "bzImage missing - the build did not complete"
fi

KO=$(find . -name '*.ko' 2>/dev/null | wc -l)
if [ "$KO" -gt 0 ]; then ok "$KO kernel modules built"; else warn "no .ko files - did you run plain 'make'?"; fi

if [ -f vmlinux ] && command -v nm > /dev/null 2>&1; then
  if nm vmlinux 2>/dev/null | grep -q ' T start_kernel'; then
    ok "vmlinux has symbols (start_kernel found)"
  else
    warn "could not find start_kernel in vmlinux symbols"
  fi
fi

# ─────────────────────────────────────────────────────────────────
section "ccache"

if command -v ccache > /dev/null 2>&1; then
  HITS=$(ccache -s 2>/dev/null | grep -iE 'cacheable calls|hits' | head -3)
  [ -n "$HITS" ] && printf '%s\n' "$HITS" | sed 's/^/         /'
  SIZE=$(ccache -s 2>/dev/null | grep -iE '^(cache size|Cache size)' | head -1)
  if [ -n "$SIZE" ]; then
    ok "cache populated - $SIZE"
  else
    warn "could not read ccache size"
  fi
  info "a cold first build has ~0% hit rate by definition; judge ccache on build two"
else
  fail "ccache not installed"
fi

# ─────────────────────────────────────────────────────────────────
section "Summary"

if   [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDay 2 complete. Fill in the tables in Day_2.md, then go to M1W1D3.%s\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Day 2 is done - note the warnings in the journal.\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s). See theory/Month_1/Week_1/Day_2.md\n\n' "$R" "$FAILURES" "$N" "$WARNINGS"
fi

exit "$FAILURES"

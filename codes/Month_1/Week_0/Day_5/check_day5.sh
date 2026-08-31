#!/bin/bash
# check_day5.sh — verify M1W0D5: developer ergonomics and upstream plumbing.
#
# Day 5 is about being able to CONTRIBUTE, not build. So this checks git
# discipline, the send-email path, the review scripts, and the reading tools.
#
# The one thing a script cannot check is the thing that matters most: that a
# patch you mailed yourself came back intact and `git am` applied it. That
# requires your eyes on the received mail. This script reminds you at the end.
#
# Usage:  bash check_day5.sh
# Exit code is the number of failures, so it works as a CI predicate.

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
info() { printf '         %s\n' "$1"; }
have() { command -v "$1" > /dev/null 2>&1; }

printf '%sM1W0D5 — upstream plumbing check%s\n' "$B" "$N"
printf 'kernel tree: %s\n' "$TREE"

# ─────────────────────────────────────────────────────────────────
section "Identity (this goes into public kernel history forever)"

NAME="$(git config --global user.name)"
MAIL="$(git config --global user.email)"

if [ -n "$NAME" ]; then
  ok "user.name: $NAME"
  # A DCO sign-off requires a real name, which in practice means 2+ words.
  case "$NAME" in
    *[!\ ]\ *[!\ ]*) ok "looks like a full name" ;;
    *) warn "'$NAME' is a single word — Signed-off-by wants your real full name" ;;
  esac
else
  fail "user.name unset — Signed-off-by is impossible without it"
fi

if [ -n "$MAIL" ]; then
  ok "user.email: $MAIL"
  case "$MAIL" in
    *@users.noreply.github.com)
      fail "a GitHub noreply address cannot RECEIVE review replies — use a real inbox" ;;
    *) ok "address can receive mail" ;;
  esac
else
  fail "user.email unset"
fi

# ─────────────────────────────────────────────────────────────────
section "Git discipline"

if [ -d "$TREE/.git" ]; then
  cd "$TREE" || exit 1

  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  case "$BRANCH" in
    master|main) warn "you are on '$BRANCH' — work belongs on a topic branch" ;;
    HEAD)        warn "detached HEAD (fine if you are mid-bisect)" ;;
    *)           ok "on topic branch '$BRANCH'" ;;
  esac

  # The one hard rule: master must be exactly upstream, so --ff-only always works
  # and 'git log master..HEAD' means "my work".
  if git rev-parse --verify -q master > /dev/null 2>&1; then
    AHEAD="$(git rev-list --count origin/master..master 2>/dev/null)"
    if [ "${AHEAD:-0}" -eq 0 ]; then
      ok "master is clean (no commits of yours on it)"
    else
      fail "master has $AHEAD commit(s) of yours — 'git merge --ff-only' will now fail"
      info "move them: git branch topic master && git reset --hard origin/master"
    fi
  fi

  # At least one signed-off commit somewhere in your own work.
  if git log --format='%b' origin/master..HEAD 2>/dev/null | grep -q 'Signed-off-by:'; then
    ok "found a Signed-off-by in your commits"
  else
    warn "no Signed-off-by in commits ahead of origin/master — use 'git commit -s'"
  fi

  git remote get-url github > /dev/null 2>&1 \
    && ok "fork remote 'github' present (off-machine backup)" \
    || warn "no 'github' remote — your work exists on exactly one disk"

  [ -f rust-project.json ] \
    && ok "rust-project.json present (rust-analyzer)" \
    || warn "rust-project.json missing — run 'make LLVM=1 rust-analyzer'"
else
  fail "no kernel tree at $TREE"
fi

RERERE="$(git config --global rerere.enabled)"
[ "$RERERE" = true ] \
  && ok "rerere enabled — conflict resolutions get replayed" \
  || warn "rerere not enabled — 'git config --global rerere.enabled true'"

# ─────────────────────────────────────────────────────────────────
section "Send-email path"

if git send-email --help > /dev/null 2>&1; then
  ok "git send-email available"
else
  fail "git send-email missing — 'sudo apt install -y git-email'"
fi

SMTP="$(git config --global sendemail.smtpServer)"
if [ -n "$SMTP" ]; then
  ok "smtpServer: $SMTP"
  info "port $(git config --global sendemail.smtpServerPort), \
encryption $(git config --global sendemail.smtpEncryption), \
user $(git config --global sendemail.smtpUser)"
else
  fail "SMTP not configured — this blocks every contribution you will ever make"
  info "run: bash ~/LKD_RUST/setup/setup-upstream.sh"
fi

# Storing the password is the one thing we actively do NOT want.
if git config --global sendemail.smtpPass > /dev/null 2>&1; then
  fail "sendemail.smtpPass is SET — a plaintext password in ~/.gitconfig"
  info "remove it: git config --global --unset sendemail.smtpPass"
else
  ok "no plaintext SMTP password stored (git will prompt)"
fi

# ─────────────────────────────────────────────────────────────────
section "Review tooling"

if [ -d "$TREE" ]; then
  [ -x "$TREE/scripts/checkpatch.pl" ] \
    && ok "checkpatch.pl" || fail "checkpatch.pl missing or not executable"
  [ -x "$TREE/scripts/get_maintainer.pl" ] \
    && ok "get_maintainer.pl" || fail "get_maintainer.pl missing or not executable"

  # Smoke test: prove get_maintainer actually resolves a real path.
  if [ -x "$TREE/scripts/get_maintainer.pl" ] && [ -f "$TREE/rust/kernel/lib.rs" ]; then
    M_COUNT="$(cd "$TREE" && ./scripts/get_maintainer.pl --no-rolestats -f rust/kernel/lib.rs 2>/dev/null | wc -l)"
    if [ "${M_COUNT:-0}" -gt 0 ]; then
      ok "get_maintainer.pl resolves rust/kernel/lib.rs to $M_COUNT recipient(s)"
    else
      warn "get_maintainer.pl returned nothing — check your perl install"
    fi
  fi
fi

if have b4; then
  ok "b4 — $(b4 --version 2>&1 | head -1)"
else
  warn "b4 not installed — 'sudo apt install -y b4' or 'pipx install b4'"
  info "b4 shazam '<msgid>' applies a whole series from lore in one command"
fi

# ─────────────────────────────────────────────────────────────────
section "The check no script can do"

cat <<'EOF'
  A green run here does NOT mean your patches will arrive intact. Mail servers
  convert to HTML, append footers, and wrap long lines — silently, and a
  maintainer who receives a mangled patch usually says nothing at all.

  Confirm by hand, once:

    cd "$LINUX_TREE"
    git format-patch -1 -o /tmp/selftest
    git send-email --to="$(git config --global user.email)" /tmp/selftest/*.patch

    # then download the RAW message from your mail client and:
    git checkout -b selftest-apply master
    git am /tmp/received.eml        # <- this applying is the real pass
    git checkout - && git branch -D selftest-apply

  Arrival proves nothing. `git am` applying it proves the whole path is clean.
EOF

# ─────────────────────────────────────────────────────────────────
section "Summary"

if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  printf '  %sDay 5 plumbing is in place.%s Do the mail self-test if you have not.\n\n' "$G" "$N"
elif [ "$FAILURES" -eq 0 ]; then
  printf '  %s%d warning(s), no failures.%s Usable — review the warnings above.\n\n' "$Y" "$WARNINGS" "$N"
else
  printf '  %s%d failure(s)%s and %d warning(s).\n' "$R" "$FAILURES" "$N" "$WARNINGS"
  printf '  See theory/Month_1/Week_0/Day_5.md, or run setup/setup-upstream.sh\n\n'
fi

exit "$FAILURES"

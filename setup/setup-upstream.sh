#!/bin/bash
# setup-upstream.sh — make this machine able to send kernel patches.
#
# Configures git identity, git send-email (SMTP), b4, and verifies the kernel's
# own review scripts work. Run after setup-wsl.sh or setup-baremetal.sh.
#
# ─── SECURITY ────────────────────────────────────────────────────────────────
# This script NEVER writes a password anywhere. `sendemail.smtpPass` is left
# deliberately unset, so git prompts you per send (or uses your credential
# helper). Storing an SMTP password in ~/.gitconfig means a plaintext secret in
# a file people routinely paste into bug reports.
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage:
#   bash setup-upstream.sh                       # interactive
#   GIT_NAME="Your Name" GIT_EMAIL=you@x.com bash setup-upstream.sh
#   SMTP_PRESET=gmail bash setup-upstream.sh     # gmail | outlook | custom | skip

set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=lib-common.sh
. ./lib-common.sh

printf '%s\n' "════════════════════════════════════════════════════════"
printf '%s\n' "  Upstream contribution setup — identity, SMTP, b4"
printf '%s\n' "════════════════════════════════════════════════════════"

# ─── 1. git identity ─────────────────────────────────────────────
say "git identity"
cat <<'EOF'
    This becomes your Signed-off-by line — the Developer's Certificate of
    Origin, a legal assertion that you have the right to submit the code.

      * Use your REAL full name. Pseudonyms are not accepted upstream.
      * Use an email you can RECEIVE mail at; review happens by email.
      * It is permanent and public: it will sit in lore.kernel.org forever.
EOF
printf '\n'

CUR_NAME="$(git config --global user.name  || true)"
CUR_MAIL="$(git config --global user.email || true)"
[ -n "$CUR_NAME" ] && info "current name : $CUR_NAME"
[ -n "$CUR_MAIL" ] && info "current email: $CUR_MAIL"

GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
if [ -z "$GIT_NAME" ]; then
  read -r -p "  Full name [${CUR_NAME}]: " GIT_NAME
  GIT_NAME="${GIT_NAME:-$CUR_NAME}"
fi
if [ -z "$GIT_EMAIL" ]; then
  read -r -p "  Email [${CUR_MAIL}]: " GIT_EMAIL
  GIT_EMAIL="${GIT_EMAIL:-$CUR_MAIL}"
fi

[ -n "$GIT_NAME" ]  || die "a name is required"
[ -n "$GIT_EMAIL" ] || die "an email is required"
# A DCO sign-off needs a real name, which in practice means at least two words.
case "$GIT_NAME" in
  *[!\ ]\ *[!\ ]*) : ;;
  *) warn "'$GIT_NAME' is a single word — Signed-off-by wants your real full name" ;;
esac
case "$GIT_EMAIL" in
  *@users.noreply.github.com) warn "a GitHub noreply address cannot receive review replies — use a real inbox" ;;
esac

git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
ok "identity set: $GIT_NAME <$GIT_EMAIL>"

say "git defaults that suit kernel work"
git config --global init.defaultBranch main
git config --global core.editor "${EDITOR:-nano}"
# Contributors' branches must stay linear: a series containing a merge commit is
# unusable to a maintainer.
git config --global pull.rebase true
git config --global log.date iso
git config --global format.signOff false   # use `git commit -s` explicitly instead
ok "init.defaultBranch, core.editor, pull.rebase, log.date"

# ─── 2. git send-email ───────────────────────────────────────────
say "git send-email"
detect_pkg_mgr
if ! git send-email --help > /dev/null 2>&1; then
  info "installing the git-email package"
  case "$PKG" in
    apt)    pkg_install git-email ;;
    dnf)    pkg_install git-email ;;
    pacman) pkg_install perl-authen-sasl perl-net-smtp-ssl perl-mime-tools ;;
  esac
fi
git send-email --help > /dev/null 2>&1 && ok "git send-email available" \
  || warn "git send-email still unavailable — install the git-email package"

SMTP_PRESET="${SMTP_PRESET:-}"
if [ -z "$SMTP_PRESET" ]; then
  cat <<'EOF'

    Which mail provider will you send patches through?
      1) gmail    smtp.gmail.com:587       (needs an App Password)
      2) outlook  smtp.office365.com:587
      3) custom   enter server and port yourself
      4) skip     configure later
EOF
  read -r -p "  Choice [1-4]: " c
  case "$c" in
    1) SMTP_PRESET=gmail ;; 2) SMTP_PRESET=outlook ;;
    3) SMTP_PRESET=custom ;; *) SMTP_PRESET=skip ;;
  esac
fi

case "$SMTP_PRESET" in
  gmail)   SMTP_HOST=smtp.gmail.com;      SMTP_PORT=587; SMTP_ENC=tls ;;
  outlook) SMTP_HOST=smtp.office365.com;  SMTP_PORT=587; SMTP_ENC=tls ;;
  custom)
    read -r -p "  SMTP server: " SMTP_HOST
    read -r -p "  Port [587]: " SMTP_PORT; SMTP_PORT="${SMTP_PORT:-587}"
    read -r -p "  Encryption (tls/ssl) [tls]: " SMTP_ENC; SMTP_ENC="${SMTP_ENC:-tls}"
    ;;
  skip) SMTP_HOST="" ;;
esac

if [ -n "${SMTP_HOST:-}" ]; then
  git config --global sendemail.smtpServer     "$SMTP_HOST"
  git config --global sendemail.smtpServerPort "$SMTP_PORT"
  git config --global sendemail.smtpEncryption "$SMTP_ENC"
  git config --global sendemail.smtpUser       "$GIT_EMAIL"
  # Sensible defaults for kernel lists.
  git config --global sendemail.confirm        always
  git config --global sendemail.suppressCC     self
  git config --global sendemail.thread         true
  git config --global sendemail.chainReplyTo   false
  ok "SMTP: $SMTP_HOST:$SMTP_PORT ($SMTP_ENC) as $GIT_EMAIL"

  # Deliberately NOT set: sendemail.smtpPass. See the header.
  git config --global --unset sendemail.smtpPass 2>/dev/null || true
  warn "no password stored — git will prompt you on each send. That is intentional."

  if [ "$SMTP_PRESET" = gmail ]; then
    printf '\n  %sGmail requires an App Password%s — your normal password is rejected.\n' "$C_B" "$C_N"
    cat <<'EOF'
      1. Enable 2-Step Verification on the Google account
      2. Create an App Password at https://myaccount.google.com/apppasswords
      3. Use that 16-character string when git prompts you
EOF
  fi
else
  warn "SMTP skipped — you cannot send patches until this is configured"
fi

# ─── 3. b4 ───────────────────────────────────────────────────────
say "b4 (the modern patch workflow tool)"
if have b4; then
  ok "b4 $(b4 --version 2>&1 | head -1)"
else
  case "$PKG" in
    apt|dnf) pkg_install b4 2>/dev/null || true ;;
  esac
  have b4 || {
    info "not packaged here; trying pipx"
    have pipx || pkg_install pipx 2>/dev/null || true
    have pipx && pipx install b4 > /dev/null 2>&1 || true
  }
  have b4 && ok "b4 $(b4 --version 2>&1 | head -1)" \
          || warn "b4 not installed — optional, but it automates most of the send workflow"
fi

# ─── 4. Kernel review scripts ────────────────────────────────────
say "Kernel review tooling"
if [ -n "${LINUX_TREE:-}" ] && [ -d "$LINUX_TREE" ]; then
  cd "$LINUX_TREE" || die "cannot enter $LINUX_TREE"
  [ -x scripts/checkpatch.pl ]     && ok "scripts/checkpatch.pl"     || warn "checkpatch.pl missing"
  [ -x scripts/get_maintainer.pl ] && ok "scripts/get_maintainer.pl" || warn "get_maintainer.pl missing"
  if [ -f rust/kernel/pci.rs ]; then
    info "smoke test — who maintains rust/kernel/pci.rs:"
    scripts/get_maintainer.pl --no-rolestats -f rust/kernel/pci.rs 2>/dev/null | head -5 | sed 's/^/      /'
  fi
else
  warn "\$LINUX_TREE not set or missing — run setup-wsl.sh / setup-baremetal.sh first"
fi

# ─── 5. Self-test ────────────────────────────────────────────────
say "Self-test: mail yourself a patch"
cat <<EOF
    Never mail a list before proving your setup works. Send yourself a real
    patch and confirm the received mail is plain text with an intact diff that
    'git am' can apply. If it cannot, a maintainer would have seen garbage.

      cd "\$LINUX_TREE"
      git checkout -b selftest origin/master
      printf '\\n' >> Documentation/rust/index.rst   # a trivial change
      git commit -s -am "docs: rust: send-email self test, do not submit"
      git format-patch -1 -o /tmp/selftest
      git send-email --to=$GIT_EMAIL /tmp/selftest/*.patch

    Then clean up:
      git checkout - && git branch -D selftest && rm -rf /tmp/selftest
EOF

say "Done"
cat <<EOF
  identity : $(git config --global user.name) <$(git config --global user.email)>
  smtp     : $(git config --global sendemail.smtpServer 2>/dev/null || echo 'NOT CONFIGURED')
  b4       : $(have b4 && echo yes || echo no)

  Read UPSTREAM.md next — commit message conventions, series structure, cover
  letters, the trailer reference, review etiquette, and a pre-submission checklist.
EOF

# Send Path — Upstream Setup Runbook

> Copy-paste runbook. No theory — the reasoning is in [`Day_5.md`](Day_5.md).
> Takes a fresh Linux machine to "can send kernel patches", in about 15 minutes.
>
> Legend: **⚠ MANUAL** = browser/human step, cannot be scripted.
> **✓ PASS →** / **✗ FAIL →** = what to do next depending on the result.

---

## Step 0 — Before you start

**⚠ MANUAL — Gmail users, do this first or Step 7 will fail.**

Your normal Google password **will not work**. Google disabled plain-password SMTP entirely.
You need a 16-character App Password:

1. Enable 2-Step Verification → https://myaccount.google.com/signinoptions/two-step-verification
2. Generate an App Password → https://myaccount.google.com/apppasswords
   - Name it `git send-email`
   - Copy the 16 characters, e.g. `abcd efgh ijkl mnop`

> If the App Passwords page is missing, 2-Step Verification is not fully enabled. It stays hidden
> until it is.

Outlook / corporate mail: get your SMTP host, port and whether it wants TLS or SSL.

---

## Step 1 — Packages

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y git git-email b4

# Fedora / RHEL
sudo dnf install -y git git-email b4

# Arch
sudo pacman -S --needed git perl-authen-sasl perl-net-smtp-ssl perl-mime-tools
```

Verify:

```bash
git send-email --help > /dev/null 2>&1 && echo "OK: send-email present" || echo "MISSING"
```

**✗ FAIL →** the `git-email` package did not install. On Arch, `git send-email` ships with git but
needs the three perl modules above.

`b4` not packaged on your distro:

```bash
sudo apt install -y pipx && pipx install b4
```

---

## Step 2 — Identity

**⚠ Substitute your own values.** This goes into public kernel history permanently.

```bash
git config --global user.name  "Your Full Name"
git config --global user.email "you@example.com"
```

Rules, all enforced by maintainers:

- Real **full name**, two words minimum. Pseudonyms are rejected.
- An inbox you can **receive** at — review arrives as a reply.
- **Never** a `@users.noreply.github.com` address. It cannot receive mail.

---

## Step 3 — Git defaults for kernel work

```bash
git config --global init.defaultBranch main
git config --global core.editor       "${EDITOR:-vim}"
git config --global pull.rebase       true
git config --global log.date          iso
git config --global rerere.enabled    true
git config --global rerere.autoUpdate true
```

---

## Step 4 — SMTP

**Gmail:**

```bash
git config --global sendemail.smtpServer     smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser       "$(git config --global user.email)"
```

**Outlook / Office 365:**

```bash
git config --global sendemail.smtpServer     smtp.office365.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser       "$(git config --global user.email)"
```

Kernel-list defaults, same for every provider:

```bash
git config --global sendemail.confirm      always
git config --global sendemail.suppressCC   self
git config --global sendemail.thread       true
git config --global sendemail.chainReplyTo false
```

**Never store the password.** Git will prompt instead:

```bash
git config --global --unset sendemail.smtpPass 2>/dev/null || true
```

Cache it in memory for an hour so you are not retyping it all day:

```bash
git config --global credential.helper 'cache --timeout=3600'
```

> Do **not** use `credential.helper store` — it writes the password in plaintext to
> `~/.git-credentials`.

Verify:

```bash
git config --global --get-regexp '^sendemail\.'
```

---

## Step 5 — Point at a kernel tree

```bash
export LINUX_TREE="$HOME/LKD_RUST/kernel/linux"     # adjust to your path
cd "$LINUX_TREE"

[ -x scripts/checkpatch.pl ]     && echo "OK: checkpatch"     || echo "MISSING: not a kernel tree?"
[ -x scripts/get_maintainer.pl ] && echo "OK: get_maintainer" || echo "MISSING"
```

Persist it:

```bash
grep -q 'export LINUX_TREE=' ~/.bashrc || echo "export LINUX_TREE=\"$LINUX_TREE\"" >> ~/.bashrc
```

---

## Step 6 — Make a throwaway test patch

Do **not** use real work for this.

```bash
cd "$LINUX_TREE"
git checkout -b smtp-test master

printf '\n' >> Documentation/rust/index.rst
git commit -s -am "docs: rust: smtp self test, do not submit"

git format-patch -1 -o /tmp/selftest
cat /tmp/selftest/*.patch
```

`-s` is mandatory — it adds `Signed-off-by:`. Check it:

```bash
scripts/checkpatch.pl /tmp/selftest/*.patch
```

**✗ FAIL → `ERROR: Missing Signed-off-by`:** you committed without `-s`.

```bash
git commit --amend -s --no-edit
rm -rf /tmp/selftest && git format-patch -1 -o /tmp/selftest
```

---

## Step 7 — Send it to yourself

```bash
git send-email --to="$(git config --global user.email)" /tmp/selftest/*.patch
```

Answer `y` at the confirm prompt, then paste the **App Password** from Step 0.

| Result | Meaning | Fix |
|---|---|---|
| `Result: 250` | sent | continue to Step 8 |
| `5.7.8 Username and Password not accepted` | you used your account password | use the App Password from Step 0 |
| `Unable to initialize SMTP ... server=localhost port=25` | Step 4 not applied | redo Step 4 |
| `STARTTLS failed` | wrong port/encryption | port 587 + `tls`, or port 465 + `ssl` |
| `Net::SMTP::SSL not found` | missing perl module | `sudo apt install -y libnet-smtp-ssl-perl libauthen-sasl-perl` |
| hangs, then times out | corporate firewall blocking 587 | try port 465 with `ssl`, or a different network |

---

## Step 8 — Prove it survived (the real test)

**⚠ MANUAL.** Open the mail, then:

1. Confirm it is **plain text**, monospaced, no HTML, no appended footer.
2. Download the **raw** message:
   - Gmail: `⋮` → **Show original** → **Download Original**
   - Thunderbird: right-click → **Save As**
3. Save it as `/tmp/received.eml`.

```bash
cd "$LINUX_TREE"
git checkout -b selftest-apply master
git am /tmp/received.eml
```

**✓ PASS — `Applying: docs: rust: smtp self test`:** your send path is clean. Done.

```bash
git log --oneline -1
git show --stat HEAD
```

**✗ FAIL — `Patch does not apply` / `corrupt patch`:** the mail was mangled in transit.

| Cause | Fix |
|---|---|
| Lines wrapped at 78 chars | use `b4 send`, which is more robust about encoding |
| Corporate gateway added a footer | use a personal address, not a work one |
| Converted to HTML | check your provider's plain-text setting |

---

## Step 9 — Clean up

```bash
cd "$LINUX_TREE"
git checkout master
git branch -D smtp-test selftest-apply 2>/dev/null
git checkout -- Documentation/rust/index.rst 2>/dev/null
rm -rf /tmp/selftest /tmp/received.eml
```

Confirm nothing of the test survived:

```bash
git log --oneline origin/master..master      # must be EMPTY
git status -sb                               # must be clean
```

---

## Step 10 — Verify the whole thing

```bash
bash ~/LKD_RUST/codes/Month_1/Week_0/Day_5/check_day5.sh
```

Exit code is the failure count. Zero means ready.

---

## Sending a real patch (the shape of it)

```bash
cd "$LINUX_TREE"

# 1. Base on the RIGHT tree - Rust work goes via rust-next, not mainline
grep -A 20 '^RUST$' MAINTAINERS                       # read the T: line
git fetch rfl && git checkout -b my-fix rfl/rust-next

# 2. One logical change, then commit with -s and a kernel-style subject
git commit -s                                          # "subsystem: area: do the thing"

# 3. Build and BOOT it, not just compile
make LLVM=1 -j"$(nproc)"
vng --exec 'dmesg | tail'

# 4. Robot review
git format-patch -1 -o /tmp/out                        # add -v2 for a second revision
scripts/checkpatch.pl --strict /tmp/out/*.patch

# 5. Who to send to - maintainers To:, lists and reviewers Cc:
scripts/get_maintainer.pl /tmp/out/*.patch

# 6. ALWAYS yourself first
git send-email --to="$(git config --global user.email)" /tmp/out/*.patch

# 7. Only then the real recipients
git send-email --to=<maintainer> --cc=<list> /tmp/out/*.patch
```

Reading other people's series:

```bash
b4 mbox   '<message-id>'      # download the thread
b4 shazam '<message-id>'      # fetch AND apply to the current branch
b4 diff   '<message-id>'      # what changed between v1 and v2
```

---

## Everything at once

For a machine where you have already done Step 0. **Edit the two identity lines first.**

```bash
set -e

# --- EDIT THESE TWO ---
GIT_NAME="Your Full Name"
GIT_MAIL="you@example.com"
# ----------------------

sudo apt update && sudo apt install -y git git-email b4

git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_MAIL"

git config --global init.defaultBranch main
git config --global core.editor       "${EDITOR:-vim}"
git config --global pull.rebase       true
git config --global log.date          iso
git config --global rerere.enabled    true
git config --global rerere.autoUpdate true

git config --global sendemail.smtpServer     smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser       "$GIT_MAIL"
git config --global sendemail.confirm        always
git config --global sendemail.suppressCC     self
git config --global sendemail.thread         true
git config --global sendemail.chainReplyTo   false
git config --global --unset sendemail.smtpPass 2>/dev/null || true
git config --global credential.helper 'cache --timeout=3600'

git config --global --get-regexp '^sendemail\.'
echo
echo "Config done. Now run the self-test (Steps 6-8) — it is not optional."
```

Then Steps 6, 7, 8 by hand, because Step 8 needs you to download the mail.

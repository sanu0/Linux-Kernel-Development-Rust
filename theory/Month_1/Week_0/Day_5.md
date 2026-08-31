# M1W0D5 — Developer Ergonomics & Upstream Plumbing

> **Goal:** make your machine able to *contribute*, not just build. By the end of today a patch
> written by you will have travelled out through a real mail server and arrived back in your own
> inbox, intact and applicable.
>
> **Time:** 2-3 hours. No long builds today — the waiting is on mail delivery, not the compiler.
>
> **Why this matters:** Days 1-4 built a lab. A lab that cannot send patches is a very elaborate
> way of reading someone else's code. Every contribution for the next two years goes through the
> pipe you build today, and the failure modes are silent — a mail server that quietly reformats
> your patch produces a submission that gets ignored with no explanation. So we test it against
> the only reviewer who will tell you the truth: yourself.

---

## Today's Checklist

- [ ] Understand why the kernel uses email and not pull requests
- [ ] Make a topic branch, commit on it, and read the commit back three ways
- [ ] Learn the branch conventions — especially that `master` is never yours
- [ ] Enable `rerere` so you solve each rebase conflict once
- [ ] Run the **reflog recovery drill** deliberately, while it is not an emergency
- [ ] Push a topic branch to your fork as off-machine backup
- [ ] Confirm `rust-analyzer` and local `rustdoc` from Day 4 actually work
- [ ] Run `checkpatch.pl` and `get_maintainer.pl` on real files
- [ ] Configure `git send-email`
- [ ] **Mail yourself a patch and prove `git am` can apply it**
- [ ] Install `b4`; fetch a real series from `lore.kernel.org`
- [ ] Set up list reading (lore feeds, not a firehose subscription)
- [ ] Join the Rust-for-Linux Zulip — read only
- [ ] Journal: your working SMTP settings and the self-test result

---

## Concepts

### 1. Why email, and why that is not nostalgia

You know GitHub's model: push a branch, open a pull request, discuss in a web UI. The kernel does
none of that. Patches are **plain-text email** sent to mailing lists.

The reflex is to assume this is greybeards refusing to move on. It isn't. Look at the scale:

| | |
|---|---|
| Lines of code | ~40 million |
| Contributors per release | ~2,000, from ~200 companies |
| Commits per release | ~14,000 over ~9 weeks |
| LKML traffic | tens of thousands of mails a month |

Now consider what email gives you that a web UI does not:

**It is offline and scriptable.** A maintainer on a plane can read 300 patches, reply to 40, and
sync when they land. Every step is a program you can pipe into another program.

**Review happens in the patch.** A reply quotes the exact diff line and answers underneath it. The
comment and the code are in one document, forever, in the archive — not attached to a line number
that moves when you force-push.

**No company owns it.** The kernel outlived SourceForge and will outlive GitHub. `lore.kernel.org`
holds the whole archive, and anyone can mirror it.

**One patch, many lists.** A change touching DRM and Rust goes to both, plus the individual
maintainers, in one send. There is no equivalent gesture on GitHub.

**It scales down.** A one-line typo fix is one email. Opening a PR for that is heavier.

> **The thing to internalise:** you are not sending a *link* to your work. You are sending the work
> itself, as text, and it must survive the journey byte for byte.

### 2. A patch is a text file — look at one

This demystifies everything. `git format-patch` turns a commit into a file:

```text
From 4a1b2c3d... Mon Sep 17 00:00:00 2001
From: Your Name <you@example.com>
Date: Mon, 31 Aug 2026 09:14:22 +0530
Subject: [PATCH] rust: kernel: fix typo in KVec documentation

The comment says "lenght" where it should say "length".

Signed-off-by: Your Name <you@example.com>
---
 rust/kernel/alloc/kvec.rs | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/rust/kernel/alloc/kvec.rs b/rust/kernel/alloc/kvec.rs
index abc1234..def5678 100644
--- a/rust/kernel/alloc/kvec.rs
+++ b/rust/kernel/alloc/kvec.rs
@@ -142,7 +142,7 @@ impl<T, A: Allocator> Vec<T, A> {
-    /// Returns the lenght of the vector.
+    /// Returns the length of the vector.
```

That is the entire mechanism. Mail headers at the top, commit message, then a `diff`. `git am`
("apply mailbox") reads that back and reconstructs your commit — author, date, message and all.

Two consequences worth sitting with:

- **The `---` line is a boundary.** Anything you write between it and the `diff` is not part of the
  commit message. That is where you put "changes since v1" notes, which belong in the mail but not
  in kernel history forever.
- **Whitespace is data.** A diff is positional. If something in the path adds a footer, converts to
  HTML, or wraps a long line at 78 characters, the patch stops applying. This is why concept 5 exists.

### 3. Your name and email are permanent and public

`Signed-off-by:` is not a formality. It is the **Developer's Certificate of Origin** — a legal
assertion that you wrote this, or have the right to submit it, and that it may ship under the
kernel's licence. `Documentation/process/submitting-patches.rst` has the full text.

Practical consequences:

- **Real full name.** Pseudonyms and single words are not accepted.
- **An inbox you actually read.** Review arrives by reply. An address that cannot receive mail —
  a GitHub `noreply`, for instance — makes you unreachable.
- **It is forever.** Your patch lands in `lore.kernel.org`, which is public, mirrored, and indexed
  by search engines. There is no delete.

Think for a second about which address you want attached to your kernel work for the rest of your
career — and whether a work address is the right choice given that leaving that job does not
detach your name from the commits. `UPSTREAM.md` has a section on the employer dimension; read it
before your first real submission, not after.

### 4. Why Gmail demands an "App Password"

You will hit this immediately, and the error message is not helpful.

Your Google password is protected by two-factor authentication. SMTP — the protocol `git send-email`
speaks — was designed in 1982 and has no way to prompt you for a code from your phone. So Google
refuses the normal password outright.

An **App Password** is a separate 16-character credential, generated once, that skips 2FA for one
specific program. It can be revoked on its own without changing your real password.

```text
Google Account -> Security -> 2-Step Verification (must be ON)
              -> App passwords -> generate -> "git send-email"
```

**Do not put that string in a config file.** Our setup deliberately leaves `sendemail.smtpPass`
unset so git prompts you per send. A plaintext password in `~/.gitconfig` is a secret sitting in a
file people routinely paste into bug reports — and if you ever push your dotfiles, into a public
repository.

### 5. Why you mail *yourself* first

This is the step people skip, and it is the entire point of today.

Between `git send-email` and a maintainer's inbox sits your mail provider, possibly a corporate
gateway, and their provider. Any of them can quietly damage a patch:

| What can happen | Result |
|---|---|
| Converted to HTML | patch is unusable, and you get told off for HTML mail |
| A signature or legal footer appended | trailing junk in the diff |
| Long lines wrapped at 78 chars | **`git am` fails** — the classic corporate-mail failure |
| Tabs converted to spaces | every changed line fails to match |
| Base64 or quoted-printable encoding | reviewers cannot quote your diff inline |
| Reply-To rewritten | replies go somewhere you never see |

None of these announce themselves. A maintainer receiving a mangled patch will usually say nothing
at all — they have hundreds more in the queue.

So: send a patch to yourself, save the raw message, and prove `git am` applies it. That is a real
end-to-end test of the whole path, and it takes five minutes.

### 6. `checkpatch.pl` — the robot reviewer

`scripts/checkpatch.pl` is in the tree. It checks style mechanically: line length, indentation,
spacing, commit-message shape, missing `Signed-off-by`.

Run it on every patch before sending. Maintainers do, and arriving with checkpatch errors signals
that you did not read the process documentation.

But it is a script, not an oracle. It produces false positives, especially on Rust, which it
understands only partially. The rule is not "checkpatch must be silent" — it is **you must know why
you are ignoring each thing it says.** "checkpatch complained and I didn't understand it" is not a
position you can defend in review.

### 7. `get_maintainer.pl` — who to send to

The kernel has no single inbox. Sending to the wrong people means silence.

`MAINTAINERS` is a machine-readable file at the tree root mapping paths to people:

```text
M:  Maintainer          — has the final say; goes in To:
R:  Reviewer            — wants to see it; goes in Cc:
L:  Mailing list        — goes in Cc: (or To:)
S:  Status              — Maintained / Odd Fixes / Orphan
F:  Files               — the path patterns this entry covers
T:  Tree                — the git tree to base your work on
```

`scripts/get_maintainer.pl` reads it *and* the recent git history of the files you touched, and
tells you who to address. That `T:` line matters more than people expect — it is how you learn
which tree to base a patch on, which is the difference between "applies cleanly" and "please rebase".

### 8. `b4` — the tool that removes the busywork

`b4` is a Python tool by a kernel.org sysadmin that automates the fiddly parts.

Reading other people's work:

| Command | Does |
|---|---|
| `b4 mbox <msgid>` | download a whole thread as an mbox |
| `b4 am <msgid>` | produce a `.mbx` of the latest version of a series, ready for `git am` |
| `b4 shazam <msgid>` | fetch **and apply** a series straight to your tree |
| `b4 diff <msgid>` | show what changed between v1 and v2 of someone's series |

`b4 shazam` is the one that changes your life. Reviewing a series used to mean saving mails by hand
and hoping you got the order right. Now it is one command from a message ID.

There is also a newer `b4 prep` / `b4 send` flow for *sending* series, which tracks versions and
generates changelogs for you. Note it exists; you will adopt it around Month 2 when you send a real
series. Today, learn the reading side.

### 9. `lore.kernel.org` is your research tool

Every mail to every kernel list, publicly archived and searchable. You will use it constantly for
three things:

**Checking prior art.** Before proposing anything, search for it. Chances are good someone tried in
2019 and there is a thread explaining exactly why it was rejected. Finding that thread saves you a
month and makes your own proposal far stronger.

**Reading how review actually goes.** Pick a merged Rust series and read the whole thread — v1
through v4, every objection, every revision. This teaches tone and expectations faster than any
guide, including this one.

**Following without drowning.** Every list has an Atom feed. You do not have to subscribe.

Which brings us to:

### 10. Do not subscribe to LKML

`linux-kernel@vger.kernel.org` receives tens of thousands of messages a month. Subscribing will
bury your inbox within a day, you will set up a filter, and then you will never read it. Everyone
learns this once.

A workable arrangement:

| List | How |
|---|---|
| `rust-for-linux@vger.kernel.org` | **Subscribe properly.** Manageable volume, and it is your field |
| `linux-kernel@vger.kernel.org` | lore only, searched when you need it. Never subscribed |
| Subsystem lists (`dri-devel`, `linux-i2c`) | subscribe when you start working in that area |
| `kernelnewbies@kernelnewbies.org` | optional; gentler, good for process questions |

And when you do reply on a list: **plain text, no HTML, reply inline underneath the quoted text you
are answering.** Top-posting is the one piece of etiquette that will get you corrected fastest.

### 11. Branch conventions, since you are about to make your first one

> The full reasoning lives in
> [**Owning Your Work: Git Discipline For A Two-Year Project**](../../../Readme.md#owning-your-work-git-discipline-for-a-two-year-project)
> in the roadmap — read it today. What follows is the operative summary.

One hard rule and a few soft ones.

**Never commit to `master`.** It should point at exactly what `origin/master` points at, always.
That is what keeps updating trivial:

```bash
git fetch origin
git checkout master
git merge --ff-only origin/master     # refuses loudly if you polluted it
```

`--ff-only` is the safety net. Commit to `master` and that command starts failing, and
`git log master..HEAD` — "what is mine" — stops being meaningful.

Beyond that:

| Work | Branch? |
|---|---|
| A patch series for upstream | Yes — fresh, off the correct base |
| Learning, experiments, throwaway hacks | One long-lived branch is fine |
| `git bisect` | No — it uses detached HEAD, let it |
| Testing someone else's series | Throwaway branch, delete after |
| Two approaches to one problem | One each, so you can diff them |

The unit is **one branch per patch series**, not per commit. Eight patches fixing one thing is one
branch, and v2 is a rebase of that same branch — not a new `my-fix-v2`.

**The surprise: nobody upstream sees your branch name.** Patches travel as email; a branch name
appears nowhere in a patch file. Branch names are for you alone, so don't agonise over them.

What matters instead is your **base commit**, because that is what gets patches rejected. Check the
`T:` line from `get_maintainer.pl` and branch from that tree.

### 12. `rerere` and worktrees — two settings you will thank yourself for

**`rerere`** is "reuse recorded resolution". Enable it and git remembers how you resolved a
conflict, then replays that resolution automatically next time the same conflict appears.

Over two years you will rebase the same out-of-tree patches onto new upstream dozens of times, and
hit the same conflict in the same file repeatedly. Solve it once.

**`git worktree`** gives you a second checked-out tree sharing one `.git`. This matters more in
kernel work than elsewhere: switching branches touches headers, touching a header invalidates
thousands of objects, and you get a 15-minute rebuild for unrelated work. Two directories, two
build outputs, no thrash:

```bash
git worktree add ../linux-next next/master
```

No second 5 GB clone — both trees share the one object store.

**The case you will actually hit is Month 8**, when you want mainline and `drm-rust-next` checked
out simultaneously: reading DRM's Rust work in one tree while your own series stays built in the
other. Adding the DRM tree as a remote and giving it its own worktree costs you a fetch, where a
second clone would cost 5 GB and a fresh full build. Note it now; you do not need it today.

### 13. `reflog` is the undo button — and it needs a drill

Your kernel tree is **not backed up by anything.** It lives outside this repo, no sync script
covers it, and 5 GB of Torvalds history has no business in OneDrive.

So the only thing between you and redoing a week is git's own safety net:

```bash
git reflog                       # every position HEAD has held, ~90 days
git checkout -b rescue <hash>    # your "deleted" work, back on a branch
```

**Deleting a branch does not delete its commits.** It removes the *name*. The commits survive about
90 days and `git show <hash>` keeps working the whole time.

Reading that is not the same as having done it. So today you will delete a branch on purpose and
get it back, while your pulse is normal.

---

## Step-by-Step

### Phase 0 — Sync and confirm where you are

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

cd "$LINUX_TREE"
git status -sb
git branch -vv
make -s kernelversion
```

Confirm your identity is what you want attached to public kernel history forever:

```bash
git config --global user.name
git config --global user.email
```

If either is wrong, fix it **now**, before you make commits you would have to rewrite:

```bash
git config --global user.name  "Your Full Name"
git config --global user.email "you@example.com"
```

### Phase 1 — A topic branch, and reading a commit three ways

```bash
cd "$LINUX_TREE"
git checkout -b hello-rust
```

Make a small, real change — a genuine typo fix if you can find one, otherwise a comment:

```bash
# find something harmless to touch
git grep -n "lenght\|recieve\|seperate\|occured" -- '*.rs' | head

# or just add a comment in a sample
$EDITOR samples/rust/rust_minimal.rs
```

Commit it with a sign-off:

```bash
git add -A
git commit -s
```

`-s` appends your `Signed-off-by:`. Write a real message while you are here — subject under 60
characters, imperative mood ("fix", not "fixed"), then a blank line, then why:

```text
rust: samples: note the KVec allocation is fallible

The minimal sample allocates a KVec without commenting on why the
push is fallible, which reads as noise to someone new to kernel Rust.

Signed-off-by: Your Name <you@example.com>
```

Now read it back three ways, because each answers a different question:

```bash
git log --oneline -3          # where am I in history?
git show HEAD                 # what exactly changed, line by line?
git show --stat HEAD          # which files, how much?
```

Save that hash. It is a permanent, offline reference to this exact state:

```bash
git rev-parse --short HEAD
```

### Phase 2 — `rerere`, and reading up on worktrees

```bash
git config --global rerere.enabled true
git config --global rerere.autoUpdate true
```

Then skim the worktree docs and note them for Month 8:

```bash
git worktree --help    # q to quit
```

### Phase 3 — The recovery drill (do this deliberately)

You are about to destroy a branch and get it back. **This is safe** — that is the point of running
it now rather than at 1am in Month 7.

```bash
cd "$LINUX_TREE"

# 1. Note the hash of the work you are about to "lose"
DOOMED=$(git rev-parse --short HEAD)
echo "remember this: $DOOMED"

# 2. Leave the branch and delete it, forcefully
git checkout master
git branch -D hello-rust        # "Deleted branch hello-rust (was abc1234)"
```

Your work now has **no branch pointing at it**. `git branch` does not list it. In most tools that
would be the end of the story.

```bash
# 3. It is still there. Find it.
git reflog | head -20

# 4. Bring it back under a new name
git checkout -b rescue "$DOOMED"
git log --oneline -2            # your commit, intact
git show HEAD                   # message, author, diff - all of it
```

Now put it back where it belongs and clean up:

```bash
git branch -m rescue hello-rust
```

> **What just happened:** a branch is only a *name* pointing at a commit. Deleting the name does not
> touch the commit. The reflog records every position `HEAD` has held for about 90 days, so the hash
> stays reachable. Commits become genuinely unrecoverable only after they expire from the reflog and
> garbage collection runs — which is why "I deleted my branch" is almost never fatal, and why
> `git reflog` is the first command to reach for when something looks lost.

### Phase 4 — Off-machine backup to your fork

Your fork is a **backup and a browsable diff view**, never a route for contribution.

```bash
cd "$LINUX_TREE"
git remote -v | grep github          # should exist from Day 2
git push github hello-rust
```

> ⚠ **A fork of a public repo is permanently public on GitHub**, with no option to make it private.
> Your branch names, commit messages, and the name and email in `git log` are all visible and
> indexed. Never open a pull request against `torvalds/linux` — it will be closed by a bot, and it
> is the most recognisable newcomer mistake there is.

### Phase 5 — Confirm Day 4's editor and docs work

You ran these yesterday; today confirm they actually function.

```bash
cd "$LINUX_TREE"
ls -la rust-project.json          # rust-analyzer's map of the tree
```

Open `rust/kernel/sync/lock/spinlock.rs` in your editor. You should get completion and
go-to-definition. If not, point your editor's rust-analyzer at `rust-project.json` and disable any
Cargo-based detection — there is no `Cargo.toml`, so Cargo-mode finds nothing.

```bash
make LLVM=1 rustdoc
```

Output lands at `Documentation/output/rust/rustdoc/kernel/index.html`, browsable from Windows at
`\\wsl.localhost\Ubuntu\...`. Same content online at
[rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/).

Spend ten minutes looking up `KVec`, `KBox`, `Error`, `Result`, `SpinLock`, `Mutex`. You are
learning **where things live**, not what they do.

### Phase 6 — `checkpatch.pl` and `get_maintainer.pl`

On your own commit first:

```bash
cd "$LINUX_TREE"
git format-patch -1 -o /tmp/p
scripts/checkpatch.pl /tmp/p/*.patch
```

Then on a real file, to see the scale of what it reports:

```bash
scripts/checkpatch.pl -f rust/kernel/lib.rs | tail -20
```

Note how it handles Rust imperfectly. That is expected — remember concept 6.

Now who you would send to:

```bash
scripts/get_maintainer.pl /tmp/p/*.patch

# and by file
scripts/get_maintainer.pl --no-rolestats -f rust/kernel/pci.rs
scripts/get_maintainer.pl --no-rolestats -f drivers/gpu/nova-core/
```

Read the raw `MAINTAINERS` entry for Rust, and find the `T:` line — the tree to base work on:

```bash
grep -A 20 '^RUST$' MAINTAINERS
```

### Phase 7 — Configure `git send-email`

The fast path, which also handles `b4` and prints the Gmail instructions:

```bash
bash ~/LKD_RUST/setup/setup-upstream.sh
```

<details>
<summary><b>Or configure it by hand</b> — worth reading once so you know what the script did</summary>

```bash
sudo apt install -y git-email

git config --global sendemail.smtpServer     smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser       "$(git config --global user.email)"

# Sensible defaults for kernel lists
git config --global sendemail.confirm      always
git config --global sendemail.suppressCC   self
git config --global sendemail.thread       true
git config --global sendemail.chainReplyTo false
```

**Deliberately not set:** `sendemail.smtpPass`. Git will prompt you. See concept 4.

</details>

Check what you ended up with:

```bash
git config --global --get-regexp '^sendemail\.'
```

### Phase 8 — The self-test: mail yourself a patch

**The most important step today.**

```bash
cd "$LINUX_TREE"
git checkout hello-rust
git format-patch -1 -o /tmp/selftest
cat /tmp/selftest/*.patch          # read it. this is what a maintainer sees
```

Send it to yourself:

```bash
git send-email --to="$(git config --global user.email)" /tmp/selftest/*.patch
```

Gmail will prompt for the App Password from concept 4. Then verify — and **verify properly**, which
means checking the patch still applies, not just that mail arrived:

1. Open the mail. It must be **plain text**, monospaced, with no footer and no HTML.
2. Save the **raw** message (Gmail: ⋮ → *Show original* → *Download Original*) as `/tmp/received.eml`.
3. Prove it applies:

```bash
cd "$LINUX_TREE"
git checkout -b selftest-apply master
git am /tmp/received.eml
git log --oneline -1        # your commit, reconstructed from an email
git show HEAD
```

If `git am` succeeds, **your entire submission path works.** If it fails, read concept 5 — the
common culprit is line wrapping, and the fix is either a different provider or `b4 send`, which is
more robust about encoding.

Clean up:

```bash
git checkout hello-rust
git branch -D selftest-apply
rm -rf /tmp/selftest /tmp/p
```

### Phase 9 — `b4`

```bash
sudo apt install -y b4 || pipx install b4
b4 --version
```

Now fetch something real. Go to [lore.kernel.org/rust-for-linux](https://lore.kernel.org/rust-for-linux/),
pick any patch series, and copy its message ID from the URL:

```bash
cd "$LINUX_TREE"
b4 mbox '<message-id>'                # download the thread
b4 am '<message-id>'                  # .mbx ready for git am

# fetch AND apply, on a throwaway branch
git checkout -b review-test master
b4 shazam '<message-id>'
git log --oneline -5

git checkout hello-rust
git branch -D review-test
```

You just pulled a stranger's patch series out of a mailing list archive and applied it to your tree
with one command. That is how you will review other people's work from Month 3 on.

### Phase 10 — Lists and Zulip

Subscribe to the one list that is actually your field:

```bash
# Rust-for-Linux: subscribe via the web UI at
#   https://subspace.kernel.org/vger.kernel.org.html
# or send a mail to majordomo@vger.kernel.org with body:
#   subscribe rust-for-linux
```

For everything else, use lore Atom feeds in your RSS reader instead of a subscription:

```text
https://lore.kernel.org/rust-for-linux/new.atom
https://lore.kernel.org/linux-kernel/new.atom      (firehose - sample, don't follow)
```

Then join the **Rust-for-Linux Zulip** at [rust-for-linux.zulipchat.com](https://rust-for-linux.zulipchat.com/).

**Read, do not post yet.** Spend twenty minutes reading recent threads. You are calibrating on how
these people talk to each other before you say anything.

Finally, pick one merged Rust series on lore and read the entire thread, v1 to final. This is the
single best use of thirty minutes in Week 0.

### Phase 11 — Record it

```bash
bash ~/LKD_RUST/codes/Month_1/Week_0/Day_5/check_day5.sh
bash ~/LKD_RUST/codes/Month_1/Week_0/Day_1/record_env.sh
```

---

## Verification

```bash
cd "$LINUX_TREE"

git config --global user.name && git config --global user.email
git config --global --get-regexp '^sendemail\.'
git config --global rerere.enabled                 # true
git rev-parse --abbrev-ref HEAD                    # hello-rust, not master
git log --oneline origin/master..master            # EMPTY - master must be clean
scripts/checkpatch.pl --version > /dev/null && echo checkpatch ok
b4 --version
ls rust-project.json
```

And the one that actually counts: **a patch you mailed yourself applied cleanly with `git am`.**

---

## Gotchas

- **Using your Google password instead of an App Password.** Rejected with an unhelpful error. 2FA
  and SMTP are incompatible by design.
- **Storing the SMTP password in `~/.gitconfig`.** A plaintext secret in a file you may one day
  paste into a bug report or push with your dotfiles. Let git prompt.
- **Declaring victory when the mail arrives.** Arrival proves nothing. `git am` applying it proves
  the path is clean.
- **Sending HTML mail.** Instantly rejected by every list. Check your provider's default.
- **A corporate mail gateway appending a footer or wrapping lines.** Silently breaks patches. This
  is exactly what the self-test catches — and a strong argument for a personal address.
- **Subscribing to LKML.** Tens of thousands of messages a month. Use lore.
- **Top-posting on a list.** Reply inline, underneath what you are answering.
- **Opening a pull request against `torvalds/linux`.** Closed by a bot. The most recognisable
  newcomer mistake.
- **Committing on `master`.** Breaks `git merge --ff-only` and makes "what is mine" unanswerable.
- **Treating `checkpatch.pl` as infallible.** It is a script with false positives, especially on
  Rust. Know why you are overriding it.
- **`get_maintainer.pl` output pasted blindly.** It over-suggests. Maintainers and lists in `To:`,
  everyone else `Cc:`, and drop people with no connection to your change.
- **Forgetting `-s` on `git commit`.** No `Signed-off-by` means the patch cannot be applied, full
  stop. Consider `git config --global format.signOff true` once you are sure you want it always.
- **Assuming a deleted branch is gone.** It is in the reflog for ~90 days. Do the drill.

---

## My Notes

### SMTP settings that worked

| Setting | Value |
|---|---|
| `sendemail.smtpServer` | |
| `sendemail.smtpServerPort` | |
| `sendemail.smtpEncryption` | |
| `sendemail.smtpUser` | |
| App Password needed? | |
| Password stored anywhere? | should be **no** |

### The self-test

| Check | Result |
|---|---|
| Mail arrived | |
| Plain text, no HTML | |
| No footer appended | |
| No lines wrapped | |
| `git am` applied it cleanly | |

### Tooling

| Tool | Version |
|---|---|
| `b4` | |
| `git send-email` available | |
| `checkpatch.pl` on my patch | (clean / N warnings) |

### Who maintains `rust/`

```text
(paste the get_maintainer.pl output, and the T: tree from MAINTAINERS)
```

### The recovery drill

| | |
|---|---|
| Hash I deleted | |
| Did `git reflog` find it | |
| Command that brought it back | |

### The series I read on lore, and what I noticed about the review

### What went wrong, and how I fixed it

### What I do not understand yet

---

## Done When

- [ ] You can explain why the kernel uses email rather than pull requests, without calling it nostalgia
- [ ] You can describe what a patch file physically contains, and what the `---` line separates
- [ ] `user.name` and `user.email` are set to what you want public forever
- [ ] A topic branch exists with a signed-off commit on it, and `master` is still clean
- [ ] You can explain why `master` must stay pristine, and what `--ff-only` protects
- [ ] `rerere.enabled` is true, and you can say what it does for you
- [ ] **You have deleted a branch and recovered it from the reflog, on purpose**
- [ ] Topic branch pushed to your fork; you know why a PR to `torvalds/linux` is wrong
- [ ] `rust-analyzer` gives completion in `rust/kernel/`; local rustdoc browsed
- [ ] `checkpatch.pl` run on your own patch, and you can explain a false positive
- [ ] `get_maintainer.pl` run, and you can read an `M:`/`R:`/`L:`/`T:` entry
- [ ] `git send-email` configured, with **no password stored**
- [ ] **You mailed yourself a patch and `git am` applied it cleanly**
- [ ] `b4` installed, and you have applied a real series from lore with `b4 shazam`
- [ ] Subscribed to `rust-for-linux`; lore feeds set up for the rest
- [ ] Rust-for-Linux Zulip joined, and you have read one full review thread
- [ ] Journal tables filled in

---

## Reading

- **`Documentation/process/submitting-patches.rst`** — the authoritative document. Read it properly
  today; you will re-read it before your first real submission
- **`Documentation/process/email-clients.rst`** — how to stop your mail client destroying patches.
  Boring until it saves you
- **`Documentation/process/5.Posting.rst`** — the posting chapter of the development process guide
- **[Owning Your Work](../../../Readme.md#owning-your-work-git-discipline-for-a-two-year-project)**
  in the roadmap — why the git discipline above matters over a two-year project, the command
  reference table, and carrying your own patches across a moving upstream
- **`UPSTREAM.md`** in this repo — commit messages, series structure, cover letters, the trailer
  reference, review etiquette, and the pre-submission checklist
- `Documentation/process/submit-checklist.rst` — the mechanical list
- [lore.kernel.org/rust-for-linux](https://lore.kernel.org/rust-for-linux/) — read one full thread
- `b4 --help`, and [b4.docs.kernel.org](https://b4.docs.kernel.org/) for the `prep`/`send` flow

---

## 📖 The Whole Day As A Story (read this first on revision)

*Plain words, no jargon. If you only re-read one section months from now, make it this one.*

### What today is for

Days 1-4 built a lab that can compile and boot a Rust-enabled kernel. Today we made it able to
**send work out**, and — the part that matters — proved the pipe doesn't leak.

### 1. The kernel uses email, and there are real reasons

Not nostalgia. Email is offline, scriptable, vendor-neutral, and lets a reply quote the exact diff
line it is answering. One send can reach three lists and five people. It scales from a one-line
typo fix to a 40-patch series.

The mental shift: **you are not sending a link to your work. You are sending the work itself, as
text.** It has to survive the journey unchanged.

### 2. A patch is just a text file

Mail headers, then the commit message, then a `diff`. `git am` reads it back and rebuilds the
commit — author, date, message, everything.

Which means **whitespace is data**. If anything in the path wraps a long line or converts tabs, the
patch stops applying.

### 3. Your name and email are permanent

`Signed-off-by` is a legal statement — the Developer's Certificate of Origin. Real full name, an
inbox you read, and it goes into a public archive that search engines index. Forever. Choose
deliberately.

### 4. Gmail needs a special password

SMTP is from 1982 and cannot prompt you for a 2FA code, so Google rejects your real password. An
App Password is a separate 16-character credential for one program, revocable on its own.

We **don't store it**. Git prompts instead, because a plaintext password in `~/.gitconfig` is a
secret in a file that gets pasted into bug reports.

### 5. The step everyone skips, and the reason today exists

Between you and a maintainer sit two or three mail servers. Any of them can convert your mail to
HTML, append a footer, or wrap lines at 78 characters — and **none of them tell you.** A maintainer
who receives a mangled patch usually just says nothing.

So we mailed a patch to ourselves, downloaded the raw message, and ran `git am` on it. Arrival
proves nothing; applying proves everything.

### 6. Two scripts already in the tree

`checkpatch.pl` is a robot reviewer for style. Run it every time — but it has false positives on
Rust, so the rule is *know why you're ignoring it*, not *make it silent*.

`get_maintainer.pl` reads `MAINTAINERS` and tells you who to send to. Its `T:` line names the git
tree to base your work on, which is the difference between "applies cleanly" and "please rebase".

### 7. `b4` removes the busywork

```bash
b4 shazam '<message-id>'
```

One command pulls a stranger's whole patch series out of the mailing list archive and applies it to
your tree. That is how you'll review other people's work from Month 3.

### 8. Don't subscribe to LKML

Tens of thousands of messages a month. Subscribe to `rust-for-linux` only; read the rest through
lore Atom feeds. And when you reply: plain text, inline, never top-posted.

### 9. Branch conventions

**Never commit to `master`** — it tracks upstream, and keeping it pristine is what makes
`git merge --ff-only origin/master` work and `git log master..HEAD` meaningful.

One branch per *series*, not per commit. And the surprise: **nobody upstream ever sees your branch
name**, because patches travel as email. Names are for you. Your **base commit** is what actually
matters.

### 10. The drill

We deleted a branch on purpose and got it back:

```bash
git reflog                       # find the hash
git checkout -b rescue <hash>    # work restored
```

A branch is only a *name* pointing at a commit. Deleting the name leaves the commit alone, and the
reflog remembers every position for ~90 days.

Your kernel tree is backed up by nothing. This is the safety net — practised once while calm, so it
is muscle memory when it isn't.

### If you remember only four things

1. **A patch is text, and whitespace is data.** Anything that reformats mail breaks it.
2. **Mail yourself first, and check `git am` applies it.** Arrival is not success.
3. **Never commit to `master`,** and `--ff-only` is what enforces it.
4. **A deleted branch is not gone** — `git reflog`, then `git checkout -b rescue <hash>`.

### The commands, in order

```bash
cd "$LINUX_TREE"
git checkout -b hello-rust
git commit -s                                  # -s adds Signed-off-by
git log --oneline; git show HEAD

git config --global rerere.enabled true

# the drill: destroy and recover
DOOMED=$(git rev-parse --short HEAD)
git checkout master && git branch -D hello-rust
git reflog | head
git checkout -b hello-rust "$DOOMED"

git push github hello-rust                     # backup, never a PR

scripts/checkpatch.pl /tmp/p/*.patch
scripts/get_maintainer.pl --no-rolestats -f rust/kernel/pci.rs

bash ~/LKD_RUST/setup/setup-upstream.sh        # SMTP + b4

git format-patch -1 -o /tmp/selftest
git send-email --to="$(git config --global user.email)" /tmp/selftest/*.patch
# download the raw mail, then:
git am /tmp/received.eml                       # THE test

b4 shazam '<message-id>'                       # apply a series from lore
```

---

**Week 0 is complete.** You have a machine that builds a Rust-enabled kernel, boots it in seconds,
loads your modules, and can send a patch that survives the journey. That is the whole point of the
week, and everything from here is content rather than plumbing.

**Next:** the Saturday project — the **Lab Bring-Up Report** in `_internal/SETUP_LOG.md`, the
`check_setup.sh` one-command verifier, and the **`hello_rust` Kernel Lab**: your own Rust module
typed by hand in four stages, in vim, building and booting after each one. Runbook in
[`activity.md`](activity.md). Then Sunday's reading, and Week 1 begins Rust ownership properly.

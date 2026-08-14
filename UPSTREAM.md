# UPSTREAM — The Contribution Playbook

> How to get code into `git.kernel.org/torvalds/linux`. This is a reference you will return to
> before every submission, not a document you read once.
>
> **The kernel does not use GitHub pull requests.** Patches go to mailing lists as plain-text email.
> This feels archaic for about two weeks, then it starts to feel like a rather good code review system.

---

## Contents

- [The Mental Model](#the-mental-model)
- [Your First Patch: Choosing a Target](#your-first-patch-choosing-a-target)
- [The Full Workflow](#the-full-workflow)
- [Writing a Commit Message](#writing-a-commit-message)
- [Structuring a Patch Series](#structuring-a-patch-series)
- [Writing a Cover Letter](#writing-a-cover-letter)
- [Trailers Reference](#trailers-reference)
- [Rust-Specific Pre-Flight Checks](#rust-specific-pre-flight-checks)
- [Sending With b4](#sending-with-b4)
- [Surviving Review](#surviving-review)
- [Sending v2 and Beyond](#sending-v2-and-beyond)
- [Bug Fixes, Fixes Tags, and Stable](#bug-fixes-fixes-tags-and-stable)
- [Reviewing Other People's Patches](#reviewing-other-peoples-patches)
- [Where To Contribute as a Rust Newcomer](#where-to-contribute-as-a-rust-newcomer)
- [Etiquette: The Unwritten Rules](#etiquette-the-unwritten-rules)
- [Employer Considerations](#employer-considerations)
- [Why Patches Get Ignored](#why-patches-get-ignored)
- [The Pre-Submission Checklist](#the-pre-submission-checklist)

---

## The Mental Model

```text
your branch
    |
    |  git format-patch / b4 send
    v
mailing list (archived forever at lore.kernel.org)
    |
    |  review: maintainers, reviewers, robots (kernel test robot, syzbot)
    v
maintainer's tree (e.g. drm-misc-next, rust-next, char-misc-next)
    |
    |  soaks in linux-next; conflicts and build failures surface here
    v
Linus's tree, during the next merge window
    |
    v
release, then distributions, then a billion devices
```

Key consequences of this shape:

- **The list is the record.** Everything is public and permanent. Write as though your future employer
  will read it, because they will.
- **Timing matters.** During the merge window (the two weeks after a release), maintainers are busy
  merging, not reviewing. `-rc1` through `-rc4` is the sweet spot for new features. Late `-rc` is for
  fixes only.
- **The base matters.** Base your work on the right tree. For `rust/kernel` changes that is usually
  `rust-next` or mainline; for DRM it is `drm-misc-next` or `drm-next`; for Nova it is `drm-rust-next`.
  State your base in the cover letter.
- **Robots review before humans.** The kernel test robot will build your patch on many
  configurations and architectures and mail you the failures. Treat its mail as a free code review.

---

## Your First Patch: Choosing a Target

Do this in **Week 41-42**, not before — but choose well, because a smooth first submission builds
confidence and a botched one wastes a maintainer's goodwill.

**Good first patches:**
- A typo or grammatical fix in `Documentation/`
- A real `checkpatch --strict` violation in a file you have actually read
- A missing `// SAFETY:` comment you can genuinely justify (found by your own SafetyLint)
- A `rustdoc` improvement in `rust/kernel/`
- A KUnit test for an untested function
- A `Fixes:` tag that was omitted on an existing bug fix

**Bad first patches:**
- Bulk whitespace or style cleanups across many files (maintainers hate churn)
- "Fixing" code you have not read and do not understand
- Anything found by a tool you ran without verifying the finding
- Renaming things because you prefer a different name
- Anything in a subsystem you have never built

**The rule:** your patch must make something genuinely better, and you must be able to explain why.
A trivially small patch that is *correct and well-explained* is a great start. A large patch that is
*mechanically generated* is a bad start.

---

## The Full Workflow

```bash
cd "$LINUX_TREE"

# 1. Base on the right tree, up to date
git fetch origin
git checkout -b my-change origin/master      # or the right subsystem tree

# 2. Make the change. Build it. BOOT IT.
make LLVM=1 -j"$(nproc)"
vng -- 'insmod ...; dmesg | tail'

# 3. Commit with sign-off
git commit -s

# 4. Pre-flight checks
scripts/checkpatch.pl --strict --git HEAD~1..HEAD
make LLVM=1 rustfmtcheck
make LLVM=1 CLIPPY=1 -j"$(nproc)"
make LLVM=1 rustdoc
make LLVM=1 W=1 -j"$(nproc)"          # extra warnings

# 5. Who should receive it?
scripts/get_maintainer.pl --git-blame HEAD~1..HEAD
# or for a file:
scripts/get_maintainer.pl -f rust/kernel/pci.rs

# 6. Generate the patches
git format-patch -o /tmp/series --cover-letter origin/master..HEAD   # drop --cover-letter for a single patch

# 7. Read every patch as if you were the maintainer
less /tmp/series/*.patch

# 8. Dry run, then send
git send-email --dry-run --to=... --cc=... /tmp/series/*.patch
git send-email --to=... --cc=... /tmp/series/*.patch
```

Or use `b4`, which handles most of this for you — see [Sending With b4](#sending-with-b4).

---

## Writing a Commit Message

```text
rust: pci: add MSI-X vector allocation

The PCI abstraction currently exposes only legacy interrupt handling,
which forces drivers that need multiple interrupt vectors to fall back
to the raw bindings. That defeats the purpose of the abstraction layer
and means every such driver reimplements the same unsafe code.

Add MsiXVectors, which allocates a range of MSI-X vectors on probe and
releases them on drop. The vector count is validated against what the
device reports, so a driver cannot request more than the hardware has.

Tested on x86_64 and arm64 under QEMU with a pci-testdev device, and on
real hardware with an Intel NIC.

Signed-off-by: Your Name <you@example.com>
```

### Subject line

- **Prefix with the subsystem**, matching what `git log --oneline <path>` shows for that area.
  `rust:`, `rust: pci:`, `drm/nova:`, `docs: rust:`, `block: rnull:` — copy the local convention.
- **Imperative mood:** "add", "fix", "remove", "convert" — not "added", "adding", "this adds"
- **No trailing period.** Under ~72 characters
- **Say what changes, not how you feel about it**

### Body

- **Explain the *why*.** The diff already shows the *what*. What problem existed? Why is this the
  right fix? What did you consider and reject?
- **Wrap at ~72 columns.** Plain text, no markdown
- **Imperative mood throughout:** "Add X" not "This patch adds X"
- **Describe your testing.** Which architectures, which configs, which hardware, which test suites
- **Link to context** where relevant: `Link: https://lore.kernel.org/r/<message-id>`
- If the change is subtle, **explain the subtlety**. Reviewers will find it anyway; better that you
  raise it first

### Common mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| "This patch adds support for..." | Redundant; use the imperative: "Add support for..." |
| No body at all | Even a one-line change usually needs a sentence of justification |
| Describing the diff line by line | The reviewer can read the diff; they cannot read your mind |
| No testing information | This is the first thing a maintainer looks for |
| Markdown formatting | Commit messages are plain text |

---

## Structuring a Patch Series

The rule: **each patch does one logical thing, and the tree builds and boots after every patch.**

A reviewer should be able to review patch 3 without holding patches 4 through 9 in their head. A
bisect should never land on a broken commit.

### Good structure

```text
[PATCH 0/4] rust: pci: MSI-X support
[PATCH 1/4] rust: pci: add irq vector count accessor
[PATCH 2/4] rust: pci: add MsiXVectors allocation type
[PATCH 3/4] rust: pci: wire MsiXVectors into the Driver trait
[PATCH 4/4] samples: rust: demonstrate MSI-X in the PCI sample
```

Each is independently reviewable, each builds, and the dependency order is obvious.

### Bad structure

```text
[PATCH 1/2] rust: pci: MSI-X support        <- 900 lines, six unrelated concerns
[PATCH 2/2] fix build                       <- never do this; squash it
```

### Rules

- **Refactors first, features second.** A pure-refactor patch with no behavior change is easy to
  review; mixing it with a feature makes both hard
- **Never a "fix the previous patch" patch.** Squash it. The series is a story you are telling, not a
  history of your afternoon
- **Keep it under ~10 patches** where you can. Longer series get reviewed more slowly
- **Add tests and documentation in the same series**, either alongside each patch or at the end
- **Say what tree you based on** in the cover letter

---

## Writing a Cover Letter

Only needed for multi-patch series. Its job is to earn the maintainer's next 60 seconds.

```text
Subject: [PATCH 0/4] rust: pci: MSI-X support

Drivers that need multiple interrupt vectors currently have to reach
into rust/bindings/ directly, which is exactly what the abstraction
layer exists to prevent. This series adds a safe MSI-X allocation type
to the PCI abstraction.

The design ties vector lifetime to the device via Devres, so vectors
cannot outlive the device they belong to. Vector counts are validated
against what the device reports, so an over-request fails at allocation
rather than producing a partially-configured device.

I considered exposing raw vector indices instead, but that would let a
driver hold an index past teardown. The current shape trades a little
ergonomics for that guarantee; feedback welcome if the tradeoff is
wrong.

Based on: rust-next, commit abc1234 ("rust: ...")

Testing:
  - x86_64, arm64, riscv64: KUnit suite passes, QEMU boot clean
  - KASAN + KCSAN + PROVE_LOCKING: clean over 1000 bind/unbind cycles
  - Real hardware: Intel I210 NIC, 8 vectors allocated and used
  - checkpatch --strict, rustfmt, clippy, rustdoc: clean

Open questions:
  - Should the vector count be a const generic instead of runtime?
  - Naming: MsiXVectors vs IrqVectors vs MsiVectors?

Your Name (4):
  rust: pci: add irq vector count accessor
  rust: pci: add MsiXVectors allocation type
  rust: pci: wire MsiXVectors into the Driver trait
  samples: rust: demonstrate MSI-X in the PCI sample

 rust/kernel/pci.rs      | 142 +++++++++++++++++++
 samples/rust/rust_pci.rs |  38 +++++
 2 files changed, 180 insertions(+)
```

**Include:** the problem, the approach, the tree you based on, your testing, and any open questions.
**Asking a specific question dramatically increases your chance of a reply** — it gives the reviewer
something concrete to respond to.

---

## Trailers Reference

| Trailer | Meaning | Who adds it |
|---------|---------|-------------|
| `Signed-off-by:` | The Developer's Certificate of Origin — you have the right to submit this. **Mandatory** | You (`git commit -s`) |
| `Reviewed-by:` | "I have reviewed this and believe it is correct" | A reviewer; you carry it into v2 |
| `Tested-by:` | "I have actually run this" | A tester; you carry it into v2 |
| `Acked-by:` | "I am fine with this going in" — usually from a maintainer of an adjacent area | Them |
| `Reported-by:` | Credit for whoever found the bug | You |
| `Suggested-by:` | Credit for whoever suggested the approach | You |
| `Co-developed-by:` | Someone else wrote a substantial part (must be paired with their `Signed-off-by:`) | You |
| `Fixes: <12-char-sha> ("subject")` | Identifies the commit that introduced the bug | You |
| `Closes: <URL>` | Links to the bug report this closes | You |
| `Link: <URL>` | Links to relevant discussion, usually a `lore` message | You |
| `Cc: stable@vger.kernel.org # 6.6+` | Requests a stable backport | You |

**Carry forward tags you were given.** If someone gave you a `Reviewed-by:` on v1 and v2 changes that
patch substantially, drop the tag and say so in the changelog — do not silently keep it.

---

## Rust-Specific Pre-Flight Checks

Run all of these. Every time. Automate them (this is what PatchPilot is for).

```bash
# Formatting — non-negotiable
make LLVM=1 rustfmtcheck

# Lints
make LLVM=1 CLIPPY=1 -j"$(nproc)"

# Documentation builds and doctests pass
make LLVM=1 rustdoc
# with CONFIG_RUST_KERNEL_DOCTESTS=y, doctests run at boot

# Extra compiler warnings
make LLVM=1 W=1 -j"$(nproc)"

# Style
scripts/checkpatch.pl --strict --git <base>..HEAD

# Tests
tools/testing/kunit/kunit.py run --arch=x86_64 --make_options LLVM=1

# Sanitizers
# build with KASAN, KCSAN, UBSAN configs and boot each

# Multi-arch (BootMatrix does this for you)
for a in x86_64 arm64 riscv64 s390x; do ...; done
```

### The Rust review checklist maintainers apply

- [ ] Is every `unsafe` block **necessary**? Could a safe abstraction be used instead?
- [ ] Does every `unsafe` block have a `// SAFETY:` comment that actually justifies it?
- [ ] Does every `unsafe fn` have a `# Safety` doc section stating the caller's obligations?
- [ ] Is there any `unwrap()`, `expect()`, or arithmetic that can panic? **Kernel Rust must not panic**
- [ ] Is every allocation fallible and handled? (`KBox::new(x, GFP_KERNEL)?`)
- [ ] Are the GFP flags right for the context? (`GFP_ATOMIC` where sleeping is forbidden)
- [ ] Does a leaf driver use only `rust/kernel` abstractions, never `rust/bindings` directly?
- [ ] Is `unsafe impl Send`/`Sync` justified in writing?
- [ ] Are objects that the C side holds pointers to properly pinned?
- [ ] Is the abstraction **sound** — can any safe usage cause UB?
- [ ] Are error paths complete, with correct teardown ordering?
- [ ] Is there documentation with examples, and do the examples compile?
- [ ] Are there tests, including error and allocation-failure paths?
- [ ] Does the code follow `Documentation/rust/coding-guidelines.rst` exactly?

---

## Sending With b4

`b4` is the modern tool and it removes most of the ways to get this wrong.

```bash
# Start tracking a series on your branch
b4 prep -n my-msix-series -f origin/master

# Edit the cover letter (b4 keeps it as a tracked commit)
b4 prep --edit-cover

# Auto-populate the Cc list from get_maintainer.pl
b4 prep --auto-to-cc

# Run the pre-flight checks b4 knows about
b4 send --dry-run          # shows exactly what will be sent, to whom

# Actually send
b4 send
```

For v2 onward, `b4` tracks the changelog and version numbering:

```bash
# after making changes
b4 prep --edit-cover       # add the "Changes in v2:" section
b4 send
```

Other useful `b4` commands:

```bash
b4 mbox <msgid>            # download a series as mbox
b4 shazam <msgid>          # download AND apply a series to your tree
b4 am <msgid>              # download as a patch series to apply manually
b4 diff <msgid>            # diff v1 against v2 of someone's series
b4 trailers -u             # collect Reviewed-by/Tested-by from the list into your commits
```

`b4 trailers -u` is worth knowing: after review, it pulls the tags people gave you off the list and
adds them to your local commits automatically.

---

## Surviving Review

This is the part nobody prepares you for.

### What to expect

- **Silence for a week is normal.** Maintainers are volunteers or have day jobs full of other patches.
  Do not ping before 7-10 days
- **Blunt feedback is normal and is not personal.** "This is wrong because X" is a technical statement,
  not an insult. Kernel review culture is direct because it is efficient
- **The kernel test robot will find something.** It builds on configurations you have never heard of.
  Fix what it finds
- **Multiple versions are the norm, not a failure.** v3 or v4 is completely ordinary for a real change
- **Some patches die.** Sometimes the answer is no, or the maintainer does not want the feature. This
  is information, not a verdict on you

### How to respond

1. **Reply to every comment.** Either "fixed in v2" or a technical explanation of why you disagree.
   Never silently ignore a comment — that is the fastest way to lose a reviewer
2. **Reply inline, below the quoted text.** No top-posting
3. **Trim the quote** to the part you are responding to
4. **Plain text only.** HTML mail gets bounced by the lists
5. **If you disagree, make the technical case** with evidence. Reviewers change their minds when shown
   data. If the maintainer still says no after that, the answer is no
6. **If you do not understand a comment, say so and ask.** "Could you clarify what you mean by X?" is
   entirely acceptable and much better than guessing
7. **Thank people for review.** It costs you nothing and reviewers are scarce
8. **Do not go quiet.** Series die from author silence far more often than from technical objections.
   If you need three weeks, say "I need a few weeks for this, will send v2 by <date>"

### Reply format

```text
On Tue, Aug 18, 2026 at 10:23:45AM +0200, Reviewer Name wrote:
> > +    let vectors = unsafe { bindings::pci_alloc_irq_vectors(...) };
>
> Leaf code should not call bindings directly. Can this go through
> an abstraction?

You are right, and that was the point of the series in the first place.
Moved into rust/kernel/pci.rs in v2 so drivers never see this.

> > +        // SAFETY: the device is valid
> 
> This does not say why it is valid or who guarantees it.

Rewritten in v2 to state that `self.dev` is a `Device<Bound>`, which
by its type invariant is bound for the lifetime of the borrow, so the
underlying `struct pci_dev` cannot be freed while we hold it.

Thanks for the review.
```

---

## Sending v2 and Beyond

```text
Subject: [PATCH v2 0/4] rust: pci: MSI-X support

Changes in v2:
- Moved the raw pci_alloc_irq_vectors call into rust/kernel/pci.rs so
  leaf drivers never touch bindings (Reviewer Name)
- Rewrote the SAFETY comment on MsiXVectors::new to state the type
  invariant that guarantees device validity (Reviewer Name)
- Added a KUnit test for the over-request failure path
- Fixed a build failure on 32-bit x86 reported by the kernel test robot
- Picked up Reviewed-by from Reviewer Name on patches 1 and 4

v1: https://lore.kernel.org/r/20260818...@example.com

[... rest of cover letter, updated ...]
```

Rules:

- **A per-version changelog in the cover letter**, crediting whoever prompted each change
- **Per-patch changelogs below the `---`** for patches that changed substantially (that text is not
  committed)
- **Link to the previous version** on `lore`
- **Carry forward `Reviewed-by:`/`Tested-by:`** only for patches that did not change materially
- **Same thread or new thread?** Send v2 as a **new thread** (not `In-Reply-To` v1), with the `v1:`
  link in the cover letter. Some subsystems differ — follow the local convention
- **Wait for review to settle** before sending v2. Do not send v2 four hours after v1; let other
  reviewers finish

---

## Bug Fixes, Fixes Tags, and Stable

### Finding the introducing commit

```bash
# Blame the line, then walk back
git log -S'the_broken_expression' --oneline -- path/to/file.rs
git blame -L 100,120 path/to/file.rs

# Format the tag exactly: 12-char SHA, then the subject in quotes
git log -1 --format='Fixes: %h ("%s")' --abbrev=12 <sha>
```

```text
Fixes: a1b2c3d4e5f6 ("rust: pci: add MsiXVectors allocation type")
```

The format is checked by scripts. Get it exactly right.

### Requesting a stable backport

Add to the commit message, **above** your `Signed-off-by:`:

```text
Cc: stable@vger.kernel.org # 6.6+
```

A fix qualifies for stable if it:
- Fixes a real bug users hit (crash, hang, data corruption, security issue)
- Is obviously correct and small
- Is already in Linus's tree (stable takes upstream commits, not new code)

It does **not** qualify if it is a new feature, a cleanup, a performance improvement, or a theoretical
fix for something nobody hits. Read `Documentation/process/stable-kernel-rules.rst`.

### Regressions

If your patch breaks something, the expectation is that you fix it or it gets reverted, quickly. Read
`Documentation/process/handling-regressions.rst` before you need it. The kernel takes regressions very
seriously; handling one gracefully earns more respect than never causing one.

---

## Reviewing Other People's Patches

Reviewing is how you become known, and it makes you a better author. Start in Week 43.

### How to review

```bash
b4 shazam <msgid>          # apply the series locally
make LLVM=1 -j"$(nproc)"   # does it build?
vng -- ...                 # does it boot? does it work?
```

Then read it critically:
- Does the commit message explain why?
- Does each patch do one thing? Does the tree build after each?
- Are the error paths complete? What happens on allocation failure?
- Is the locking right? What context is each function called in?
- Is every `unsafe` block justified? Is the safety comment real?
- Does it break uAPI?
- Are there tests? Is there documentation?

### How to write a review

```text
On Tue, Aug 18, 2026 at 10:23:45AM +0200, Author wrote:
> +    let buf = KVec::with_capacity(len, GFP_KERNEL)?;

This is called from the interrupt handler path (see foo_irq() below),
so GFP_KERNEL may sleep here. GFP_ATOMIC, or move the allocation to
probe time?

> +        // SAFETY: ptr is valid

Could you state why? I think it holds because the caller guarantees it
comes from probe(), but that should be written down.

Otherwise this looks good to me, and it builds and boots clean on
x86_64 and arm64 here.

Reviewed-by: Your Name <you@example.com>
```

- **Be specific.** Point at the line, say what is wrong, say why
- **Suggest the fix** where you can
- **Say what you tested**, if you tested
- **Be kind and direct at the same time.** These are not in tension
- **Give the tag** if you genuinely reviewed it. `Reviewed-by:` means "I believe this is correct" —
  do not give it casually, and do not withhold it out of perfectionism

---

## Where To Contribute as a Rust Newcomer

Ordered from lowest to highest friction. Work down the list over Months 5-16.

| Target | Difficulty | Why it works |
|--------|-----------|--------------|
| **Documentation** (`Documentation/rust/`, `rustdoc` comments, `Documentation/gpu/nova/`) | Easy | Always wanted, rarely done, high acceptance rate |
| **KUnit tests** for `rust/kernel/` modules | Easy-Medium | Tests are the most welcome contribution in any subsystem |
| **Nova register definitions** (`regs.rs`) and HAL bits | Easy-Medium | Explicitly listed as newcomer-friendly on Nova's TODO |
| **`// SAFETY:` comment improvements** | Easy-Medium | Real value, but you must genuinely understand the invariant |
| **Small refactors** flagged by in-tree TODO comments | Medium | Look for `// TODO` in `rust/` and ask before doing it |
| **A new I2C/SPI/hwmon/IIO driver in Rust** | Medium | Small, self-contained, and there are very few of these yet |
| **A new safe abstraction** for a C subsystem with none | Hard | The highest-leverage contribution type in Rust-for-Linux |
| **Porting a C driver to Rust** | Hard | Technically and politically demanding; requires parity proof |
| **Nova features** (engines, memory management) | Very Hard | Rated Expert on the TODO for good reason; needs hardware and maintainer coordination |

**Always check first:**
1. `lore.kernel.org` — is someone already doing this?
2. The Rust-for-Linux Zulip — ask, and claim it publicly
3. The subsystem's TODO list or wishlist
4. `MAINTAINERS` — who cares about this file?

Duplicating in-flight work wastes your month and irritates the person you duplicated.

---

## Etiquette: The Unwritten Rules

- **Plain text email. Always.** HTML mail is silently dropped by the lists
- **Reply inline, below the quote. Never top-post**
- **Do not send attachments.** Patches go inline in the mail body (`git send-email` does this)
- **Do not resend a patch because nobody replied in two days.** Wait 7-10 days, then reply to your own
  mail with a polite ping and the `lore` link
- **Do not Cc `linux-kernel@` and nothing else.** Get the actual maintainers and the subsystem list
- **Do not Cc twenty people.** `get_maintainer.pl` sometimes over-collects; use judgment
- **Do not argue about tone.** Respond to the technical content and move on
- **Do not claim work you have not started.** And do not sit on claimed work silently for a month
- **Do not use AI-generated code you do not understand.** You will be asked to explain your patch, in
  detail, by someone who knows the subsystem far better than you. Use AI to learn and to review; never
  to substitute for understanding. Check the current state of `Documentation/process/` regarding tool
  disclosure expectations
- **Credit people.** `Suggested-by:`, `Reported-by:`, and a "thanks" in the reply cost nothing
- **Read the subsystem's own handbook** if it has one (`Documentation/process/maintainer-*.rst`)

---

## Employer Considerations

You work at a hardware company. Take this seriously **before** your first patch, not after.

- [ ] Read your employer's open-source contribution policy, in full
- [ ] Find out whether you need approval to contribute, and get it in writing
- [ ] Understand whose copyright your contributions carry, and use the right email address
- [ ] `Signed-off-by:` is a legal certification (the DCO) that you have the right to submit the code —
  make sure that is actually true
- [ ] **Never** let internal documentation, internal source, or unreleased hardware details appear in a
  commit message, a code comment, or a mailing-list post. Internal docs can help you *understand* a
  device; the patch must be derivable from public information or from work you are cleared to publish
- [ ] If you are contributing to a driver for your employer's hardware, the boundary between "my
  learning project" and "company work product" needs to be explicit and agreed
- [ ] When in doubt, ask your manager and your open-source program office. Asking is cheap; a leak is
  not

Being inside a hardware company is a genuine advantage — you can ask the people who designed the
silicon. Use it for understanding, and keep the artifacts clean.

---

## Why Patches Get Ignored

| Reason | Fix |
|--------|-----|
| Sent to the wrong list or missing the maintainer | `scripts/get_maintainer.pl`; add the subsystem list |
| HTML email | Use `git send-email`; check `Documentation/process/email-clients.rst` |
| Whitespace mangled by the mail client | Never copy-paste a patch; always `git send-email` |
| Based on the wrong tree, does not apply | State your base; use the subsystem's tree |
| Sent during the merge window | Wait for `-rc1`; resend then |
| No commit message body | Explain the why |
| No testing information | Say what you tested, where |
| Series does not build patch-by-patch | Restructure; test each patch independently |
| `checkpatch` violations everywhere | Run it before sending, with `--strict` |
| Obvious `unwrap()` or panic path in Rust code | Fix it; this is an instant reject |
| Too large, too many concerns at once | Split into a logical series |
| Author went quiet on v1 review | Do not go quiet |
| Nobody understands why you want this | Lead with the problem, not the solution |

---

## The Pre-Submission Checklist

Copy this into every submission's journal entry and tick it honestly.

### Correctness
- [ ] Builds clean with `LLVM=1` and `W=1`
- [ ] **Boots.** In QEMU at minimum; on hardware if the change touches hardware
- [ ] The feature actually works — demonstrated, not assumed
- [ ] Error paths tested with fault injection where possible
- [ ] Teardown tested: load/unload or bind/unbind in a loop
- [ ] No leaks (`kmemleak`), no UAF (KASAN), no races (KCSAN), no lock issues (`PROVE_LOCKING`)

### Rust hygiene
- [ ] `make LLVM=1 rustfmtcheck` clean
- [ ] `make LLVM=1 CLIPPY=1` clean
- [ ] `make LLVM=1 rustdoc` clean, doctests pass
- [ ] Zero `unwrap()`/`expect()`/panic paths
- [ ] Every allocation fallible and handled
- [ ] Every `unsafe` block has a real `// SAFETY:` comment
- [ ] Every `unsafe fn` has a `# Safety` doc section
- [ ] Leaf code uses no `rust/bindings` directly

### Process
- [ ] `scripts/checkpatch.pl --strict` clean (or every warning justified)
- [ ] `scripts/get_maintainer.pl` run; recipient list reviewed by a human
- [ ] Based on the correct tree, and the base is stated in the cover letter
- [ ] Commit messages: subsystem prefix, imperative mood, why-not-what body, testing described
- [ ] Series structure: one logical change per patch, builds after each
- [ ] `Signed-off-by:` present on every patch
- [ ] `Fixes:` tag if this fixes a specific commit; `Cc: stable@` if it qualifies
- [ ] Cover letter with problem, approach, testing, and open questions
- [ ] Multi-arch results included (x86_64 plus at least one other)
- [ ] Tests and documentation included in the series
- [ ] Sent with `git send-email` or `b4 send`, verified with `--dry-run` first
- [ ] You have read every patch as if you were the maintainer

### After sending
- [ ] Series archived in your journal with the `lore` link
- [ ] Calendar reminder to check for replies in 3 days and again in 10
- [ ] Prepared to reply to every comment and send v2

---

## Reference Documents (read these, in this order)

1. `Documentation/process/howto.rst` — how kernel development works
2. `Documentation/process/submitting-patches.rst` — **the** document
3. `Documentation/process/submit-checklist.rst` — the checklist above, official version
4. `Documentation/process/email-clients.rst` — do not skip this
5. `Documentation/rust/coding-guidelines.rst` — governs every Rust patch
6. `Documentation/process/development-process.rst` — the whole cycle explained
7. `Documentation/process/stable-kernel-rules.rst` — backports
8. `Documentation/process/handling-regressions.rst` — when you break something
9. `Documentation/process/maintainer-handbooks.rst` — subsystem-specific rules
10. `Documentation/maintainer/` — the other side of the table; makes you a better contributor
11. The [`b4` documentation](https://b4.docs.kernel.org/) — the tool that does most of this for you

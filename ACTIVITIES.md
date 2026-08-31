# ACTIVITIES — The Kernel Lab Track

> Every Saturday Project in `Readme.md` says *what* to build. An **activity** says *how to run it*,
> and ends with your own code executing inside a kernel you compiled.
>
> This document is the standard they are all written to, plus the index of which ones exist.

---

## Contents

- [Why This Exists](#why-this-exists)
- [The Three Rules](#the-three-rules)
- [The Kernel Lab Track (Weeks 0-8)](#the-kernel-lab-track-weeks-0-8)
- [Where Activities Live](#where-activities-live)
- [The Template](#the-template)
- [Index](#index)
- [Writing A New Activity](#writing-a-new-activity)

---

## Why This Exists

Two problems, found by auditing all 44 Saturday Projects across Weeks 0-64.

**Problem 1: the projects are specifications, not runbooks.** A Saturday Project is three or four
bullets describing a deliverable. That is the right level for a roadmap — but on Saturday morning
you do not need a deliverable description, you need to know which file to create, which directory it
goes in, which command builds it, what correct output looks like, and what to do when it does not
work. The gap between "build SafetyLint v0.1" and a running program is where weekends die.

**Problem 2: Weeks 1-8 contain no kernel code at all.** The Saturday Projects for those eight weeks
are, in order: a register-map parser, KernelForge `doctor`/`config`, RustScope, KernelForge
`build`/`boot`, SafetyLint, a *userspace* concurrency bug museum, PinDojo, and polish on the last
two. Every one is a userspace Rust CLI. The first Saturday Project that builds a kernel module is
Week 9's KModKit.

Those tools are genuinely worth building and the chain they form is good. But eight weeks is a long
time to learn kernel development without writing kernel code, and the Week 0 activity proved the
alternative is more motivating: you get `dmesg` output from code you wrote, in a kernel you
compiled, on day one.

So each of Weeks 1-8 now carries a small additional **Kernel Lab** — one module, one concept, thirty
to sixty minutes. The userspace project is unchanged. The lab is the part that keeps your hands in
the kernel while the Rust concepts land.

---

## The Three Rules

Every activity in this repo obeys these. If a proposed activity breaks one, it is not ready.

### 1. It ends with something running

Not compiling. Not passing a lint. **Running**, in a `vng` guest, producing output you can paste
into your journal. An activity whose success criterion is "the code builds" teaches you that the
code builds.

### 2. It is cumulative — week N uses weeks 0 through N

The Kernel Lab for week N must reuse a skill from an earlier week, not just the current one. This is
what makes the track feel like construction rather than a series of tutorials, and it is how you
find out what you have actually retained. Week 6's lab uses Week 4's fallible allocation; Week 8's
lab uses the module scaffolding from Week 0 and the `unsafe` discipline from Week 5.

If week N's lab could have been done in week 1, it is a bad lab.

### 3. It has a failure mode you deliberately trigger

Every lab includes a step where you break it on purpose and read the error: pass a bad module
parameter, force an allocation failure, violate a lock ordering, load a module built against the
wrong tree. Kernel development is mostly reading failures, and a lab that only shows the success
path trains the wrong skill.

---

## The Kernel Lab Track (Weeks 0-8)

Each lab is one module. Each builds on the last. All of them live in
`codes/Month_N/Week_M/` and get wired into the tree with the same `install_hello.sh` pattern
established in Week 0.

| Week | Lab | Rust concept, in the kernel | Reuses from |
|---|---|---|---|
| 0 | `hello_rust` | `module!`, `Drop`, fallible `KVec::push` | — |
| 1 | `drop_order` | `Drop` order across nested owned values, and on the early-return path | W0 module scaffolding |
| 2 | `trait_regs` | a `Register` trait with two in-kernel backends; static vs dynamic dispatch | W1 register parser, W0 scaffolding |
| 3 | `raii_probe` | acquire three resources, fail at the second, prove teardown order in `dmesg` | W1 `Drop`, W2 traits |
| 4 | `alloc_fail` | `KBox`/`KVec`/`Arc` under `CONFIG_FAILSLAB` fault injection | W3 error paths |
| 5 | `unsafe_contract` | one `unsafe fn` with a real `# Safety` section, called correctly and incorrectly | W4 allocation, W0 params |
| 6 | `spin_atomic` | `SpinLock<T>`, kernel atomics, lockdep turned on via module param | W5 `unsafe`, W4 `Arc` |
| 7 | `pinned_list` | `#[pin_data]` + `pin_init!`, then an intrusive `List` | W6 locking, W5 `unsafe` |
| 8 | `bindgen_peek` | call a C helper through `rust/bindings/`, and read a C struct field safely | W5 `unsafe`, W7 pinning |

**The through-line:** by Week 8 you have written, in the kernel, every Rust mechanism that Week 9's
KModKit assumes you already understand — so KModKit becomes assembly of familiar parts rather than
eight new ideas at once.

After Week 8 the Saturday Projects are already kernel-resident (KModKit, VirtToy, BlockForge,
TinyDRM, Nova), so the separate lab track stops. From Week 9 on, the activity document *is* the
Saturday Project's runbook.

---

## Where Activities Live

```text
theory/Month_1/Week_0/activity.md      <- the runbook you follow
codes/Month_1/Week_0/Day_4/*.rs        <- the source, version controlled
codes/Month_1/Week_0/Day_4/install_*.sh <- wires it into $LINUX_TREE
```

The pattern from Week 0, unchanged:

- **The repo is the source of record.** Your `.rs` lives in `codes/`, under git.
- **The kernel tree is disposable.** `install_*.sh` copies the source into `samples/rust/` and adds
  a Kconfig plus a Makefile line. `git checkout` in the tree undoes all of it.
- **Line endings are handled by `.gitattributes`,** which declares `*.sh` and `*.rs` as `eol=lf`.
  Committed scripts are LF on disk and run fine from `/mnt/c/`. Only a freshly created,
  not-yet-committed file can carry CRLF — commit it, or run `sync_from_repo.sh`, to fix that.

---

## The Template

Every `activity.md` has these sections, in this order. Deviating makes them harder to follow when
you are tired, which is when you will be reading them.

```markdown
# Activity — <name>

> Goal:    one sentence, phrased as an observable outcome
> When:    which week/day, and what must already work
> Time:    honest estimate, split between typing and building

## The N Things We Are Doing        <- the concepts, before any commands
## Files This Activity Uses         <- table: path -> role
## Gotchas, Verified                <- only things actually confirmed on this machine
## Part 0 — Prerequisites           <- exact commands, with the reason for each
## Part 1..N — <the work>           <- commands + expected output, verbatim
## Side By Side                     <- comparison table, when there are two variants
## Experiments Worth Running        <- includes the deliberate failure (Rule 3)
## Putting The Tree Back            <- how to undo it
## Journal                          <- what to record, plus questions to answer unaided
## Troubleshooting                  <- symptom / cause / fix table
```

Two sections carry most of the value and are the ones most often skipped:

**Expected output, pasted verbatim.** Not "you should see the module load". The actual `dmesg` lines.
This is how you tell a subtle failure from success.

**Journal questions you answer without notes.** Three to five, aimed at the concept rather than the
commands. "Why does `Drop` never run in the built-in build?" is a good question. "What command loads
a module?" is not.

---

## Index

| Week | Activity | Status |
|---|---|---|
| 0 | [Hello World From Inside Your Own Rust Kernel](theory/Month_1/Week_0/activity.md) | **written** |
| 1 | `drop_order` — Drop order where it matters | pending |
| 2 | `trait_regs` — traits as kernel vtables | pending |
| 3 | `raii_probe` — the teardown ladder, deleted | pending |
| 4 | `alloc_fail` — make the allocator fail on purpose | pending |
| 5 | `unsafe_contract` — write a contract, then break it | pending |
| 6 | `spin_atomic` — lockdep as a teaching tool | pending |
| 7 | `pinned_list` — pin_init and intrusive lists | pending |
| 8 | `bindgen_peek` — across the FFI boundary | pending |

Written **just in time**, one or two weeks ahead of where you are — not all upfront. Two reasons,
both practical: the `kernel` crate API moves fast enough that a lab written for Week 55 today would
be wrong by the time you reach it, and a lab is only well-pitched if it is written knowing what you
actually struggled with in the preceding weeks.

For Weeks 9 and later, the Saturday Project in `Readme.md` is already the right shape; it gains an
activity document when you reach it.

---

## Writing A New Activity

When you get to a week with no activity yet, write it yourself — this is a genuinely useful exercise
and it is how the roadmap becomes yours.

1. Read the week's Saturday Project in `Readme.md`, and its Daily Breakdown.
2. Pick the **one** concept that is best learned by watching it happen in `dmesg` rather than by
   reading. That is your lab.
3. Find the reuse. What from an earlier week does this need? If nothing, pick a different concept
   (Rule 2).
4. Decide the deliberate failure before you write the success path (Rule 3). It is usually the more
   instructive half, and designing for it shapes the module.
5. Write the expected output *before* you run it. Then run it and correct your guess — the delta is
   the most valuable thing you will learn that day.
6. Keep it to one module and under an hour. A lab that eats the whole Saturday has displaced the
   Saturday Project it was supposed to support.

> **On the deliberate failure:** the point is not to memorise error messages. It is that after a
> year of this, an unfamiliar kernel failure will feel like a category you recognise instead of a
> wall of hex. That is most of what separates someone who can debug a kernel from someone who
> cannot, and it is not taught by success paths.

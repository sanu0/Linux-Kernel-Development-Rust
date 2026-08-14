# Journal

The engineering journal. In kernel work this is worth more than in any other discipline, because
the bug you hit at 1 a.m. in Month 3 will reappear in Month 11 wearing a different hat.

## Why bother

- Kernel debugging is **archaeology**. Six weeks from now you will hit the same KASAN report and have
  no memory of what caused it. The journal is the memory.
- **Measurements decay.** "It was about 40 microseconds" is useless. The number you wrote down is not.
- **Review feedback is a curriculum.** Every comment a maintainer leaves is a lesson someone paid
  attention to give you. Losing it in a mail archive wastes it.
- **Your monthly project write-ups come from here.** So do your blog posts and your conference talk.
- **Your six-month and twelve-month retrospectives are only possible if you wrote things down.**

## Layout

```
journal/
├── README.md                 # this file
├── 2026-08-week00.md         # one file per week
├── 2026-08-week01.md
├── measurements/             # benchmark results, with the command that produced them
├── crashes/                  # oops/KASAN/lockdep reports, with what caused each
└── submissions/              # one file per patch series: what, where, review, outcome
```

## Weekly template

```markdown
# Week NN — <topic>  (YYYY-MM-DD to YYYY-MM-DD)

## What I set out to learn
<the week's goal from Readme.md>

## What I actually built
<code, with paths into codes/>

## What broke, and why
<the failures — this is the most valuable section, do not skip it>

## Numbers
<build times, boot times, throughput, latency, LOC, unsafe count — with the exact command>

## What I did not understand
<be honest. This list becomes next week's reading and next month's buffer week>

## Something I can now explain that I could not last week
<one paragraph, in your own words, no notes>

## Open questions for the list / Zulip
<things worth actually asking>
```

## Crash template (`crashes/`)

```markdown
# YYYY-MM-DD — <one-line summary>

**Kernel:** <version + your branch + config profile>
**Trigger:** <exact steps to reproduce>
**Tooling:** <KASAN / KCSAN / lockdep / plain>

## Report
<paste the full report, unabridged>

## Root cause
<what was actually wrong>

## Fix
<the change, and why it is correct rather than just quieting the tool>

## Lesson
<the general principle, so you recognise this class of bug next time>
```

## Submission template (`submissions/`)

```markdown
# <series subject>

**Sent:** YYYY-MM-DD
**To:** <lists and maintainers>
**Base:** <tree + commit>
**Lore:** <link>

## What it does
## Testing claimed
## Review received
<every comment, and what you did about it>
## Versions
- v1: <link> — <outcome>
- v2: <link> — <outcome>
## Outcome
<merged / dropped / still in review>
## What I learned about this subsystem's culture
```

## The rules

1. **Write it the same day.** A journal entry written a week later is fiction.
2. **Paste the whole error.** Not a summary. The exact text is what you will search for later.
3. **Record the command, not just the number.** A benchmark you cannot reproduce is not a measurement.
4. **Write the failures more carefully than the successes.** The successes are in the code; the
   failures are only here.
5. **Never put internal or confidential material in here if this repo is public.** Keep a separate
   private note for anything that comes from work.

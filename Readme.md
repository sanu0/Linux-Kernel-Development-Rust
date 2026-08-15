<a id="toc"></a>

# Linux Kernel Development in Rust — Mastery Roadmap

> **Daily: 2-3 hours** | **Saturday: 3-4 hrs project** | **Sunday: 1-2 hrs reading (papers, LWN, talks)**
> **Duration:** ~18 months | **6-month milestone:** real Rust drivers that boot, plus patches on the mailing list
> **After each month:** 1 week revision buffer to revisit weak areas + complete monthly projects
> **Projects:** 1 weekly project + **2 monthly projects** (novel, cumulative, useful to other kernel developers)
> **End goal:** merged contributions in **mainline Linux** (`git.kernel.org/torvalds/linux`), and the judgment of an engineer who can be trusted with `unsafe` at the C boundary.

---

## 📑 Table of Contents

### 🎯 Getting Started
- [North Star](#north-star)
- [Why Rust in the Kernel (and Where It Does Not Belong Yet)](#why-rust-in-the-kernel-and-where-it-does-not-belong-yet)
- [State of Rust-for-Linux (Read This Before Planning)](#state-of-rust-for-linux-read-this-before-planning)
- [Your Lab (Hardware & Environment Reality)](#your-lab-hardware--environment-reality)
- [How To Use This File](#how-to-use-this-file)
- [Project Philosophy: Novel + Useful + Cumulative](#project-philosophy-novel--useful--cumulative)
- [Expertise Gates](#expertise-gates)
- [How This Folder Relates To Your Other Tracks](#how-this-folder-relates-to-your-other-tracks)
- [Repo Layout & GitHub Setup](#repo-layout--github-setup)
- [Progress Overview](#progress-overview)

### 🏆 Monthly Capstone Project Catalog
- [Month 1 — KernelForge + RustScope](#month-1-project-a-kernelforge--one-command-rust-kernel-lab)
- [Month 2 — SafetyLint + PinDojo](#month-2-project-a-safetylint--the-unsafe-and-safety-comment-auditor)
- [Month 3 — KModKit + OopsLens](#month-3-project-a-kmodkit--the-rust-kernel-module-starter-suite)
- [Month 4 — VirtToy + PCIScope](#month-4-project-a-virttoy--the-hardware-free-pci-driver-lab)
- [Month 5 — DMAForge + SensorRS](#month-5-project-a-dmaforge--dma-scatter-gather-and-iommu-lab)
- [Month 6 — BlockForge ⭐ + LockProof](#month-6-project-a-blockforge--rust-block-driver-with-fault-injection--milestone-project)
- [Month 7 — TarFS-RS + TraceRust](#month-7-project-a-tarfs-rs--a-fuzz-hardened-read-only-rust-filesystem)
- [Month 8 — TinyDRM + FenceScope](#month-8-project-a-tinydrm--a-real-rust-drmkms-driver-you-can-boot)
- [Month 9 — NovaScope ⭐ + GSPAtlas](#month-9-project-a-novascope--nova-register-and-gsp-rpc-toolkit)
- [Month 10 — SafeAbstract + KFuzzRS](#month-10-project-a-safeabstract--ship-a-new-kernel-rust-abstraction-upstream)
- [Month 11 — PortToRust + PatchPilot](#month-11-project-a-porttorust--port-a-real-c-driver-to-rust-upstream-quality)
- [Month 12 — KUnitRS + BootMatrix](#month-12-project-a-kunitrs--test-coverage-for-the-kernel-crate)
- [Month 13 — ProdDriver + AbiGuard](#month-13-project-a-proddriver--take-one-driver-to-production-and-merge-it)
- [Month 14 — VirtioRS + MemLab](#month-14-project-a-virtiors--a-rust-virtio-driver-end-to-end)
- [Month 15 — NovaFeature ⭐ + KernelRustBook](#month-15-project-a-novafeature--a-substantial-nova-contribution)
- [Month 16 — UpstreamRun + EcosystemContrib](#month-16-project-a-upstreamrun--10-merged-patches-across-3-subsystems)
- [Month 17-18 — Magnum Opus ⭐⭐](#month-17-18-project-magnum-opus--your-signature-kernel-contribution)
- [Monthly Project Tracker (overview table)](#monthly-project-tracker-2-projects-per-month)

### 📅 Month-by-Month Focus & Capabilities
- [Month 1 — Rust Core + Kernel Build, Boot, Source Map](#month-1--rust-core--kernel-build-boot-source-map)
- [Month 2 — Unsafe Rust, Pin, FFI, Concurrency Theory](#month-2--unsafe-rust-pin-ffi-concurrency-theory)
- [Month 3 — The kernel Crate + Your First Rust Modules](#month-3--the-kernel-crate--your-first-rust-modules--debugging)
- [Month 4 — Char/Misc, Platform, PCI, Interrupts](#month-4--charmisc-devices-platform-drivers-pci-interrupts)
- [Month 5 — DMA, Buses, sysfs/debugfs, Power Management](#month-5--dma-buses-sysfsdebugfs-power-management)
- [Month 6 — Real Kernel Concurrency + Block + Net ⭐](#month-6--real-kernel-concurrency--data-structures--block--net--6-month-milestone)
- [Month 7 — Filesystems, Binder, Tracing](#month-7--filesystems-binder-as-a-case-study-tracing--observability)
- [Month 8 — DRM/GPU Subsystem](#month-8--drmgpu-subsystem-kms-gem-fences-scheduling)
- [Month 9 — Nova Internals ⭐](#month-9--nova-internals-pci-vbios-falcon-gsp-rpc-drm-uapi)
- [Month 10 — Performance, Security, Fuzzing, Abstraction Design](#month-10--performance-security-fuzzing--abstraction-design)
- [Month 11 — The Upstream Machine](#month-11--the-upstream-machine-trees-review-porting)
- [Month 12 — Testing Infrastructure & Multi-Arch CI](#month-12--testing-infrastructure--multi-arch-ci)
- [Month 13 — Production Driver Quality, ABI, Stable/LTS](#month-13--production-driver-quality-abi-stability-stablelts)
- [Month 14 — Virtualization + Advanced Memory Management](#month-14--virtualization-virtio-vfio-kvm--advanced-memory-management)
- [Month 15 — Major Contribution + Teaching ⭐](#month-15--major-contribution--teaching-and-authoring)
- [Month 16 — Sustained Open Source & Ecosystem](#month-16--sustained-open-source--ecosystem-contributions)
- [Months 17-18 — Magnum Opus](#months-17-18--magnum-opus--maintainership-path)

### 🛠 Phase 1: Foundations (Weeks 0-12, Months 1-3)
- [Week 0 — Lab Setup: Build & Boot a Rust-Enabled Kernel](#week-0--lab-setup-build--boot-a-rust-enabled-kernel-do-this-immediately)
- [Week 1 — Rust Ownership + The Kernel Source Tree](#week-1--rust-ownership--the-kernel-source-tree)
- [Week 2 — Rust Types & Traits + Kconfig/Kbuild](#week-2--rust-types--traits--kconfigkbuild)
- [Week 3 — Lifetimes, Errors, Iterators + Device/Driver Model](#week-3--lifetimes-errors-iterators--the-devicedriver-model)
- [Week 4 — Smart Pointers + A C Kernel Module (Know Your Enemy)](#week-4--smart-pointers--a-c-kernel-module-know-your-enemy)
- [🔄 Buffer Week (Month 1 Revision)](#-buffer-week-month-1-revision)
- [Week 5 — Unsafe Rust, Raw Pointers, Undefined Behavior](#week-5--unsafe-rust-raw-pointers-undefined-behavior)
- [Week 6 — Concurrency: Send/Sync, Atomics, Memory Ordering](#week-6--concurrency-sendsync-atomics-memory-ordering)
- [Week 7 — Pin, Self-Reference, and pin-init](#week-7--pin-self-reference-and-pin-init)
- [Week 8 — no_std, FFI, bindgen, and the Kernel Rust Build](#week-8--no_std-ffi-bindgen-and-the-kernel-rust-build)
- [🔄 Buffer Week (Month 2 Revision)](#-buffer-week-month-2-revision)
- [Week 9 — The kernel Crate Tour](#week-9--the-kernel-crate-tour)
- [Week 10 — Your First Real Rust Module: Misc Device + ioctl](#week-10--your-first-real-rust-module-misc-device--ioctl)
- [Week 11 — Kernel Sync Primitives in Rust](#week-11--kernel-sync-primitives-in-rust)
- [Week 12 — Debugging & Testing Kernel Rust](#week-12--debugging--testing-kernel-rust)
- [✅ Phase 1 Completion Checklist](#-phase-1-completion-checklist)

### 🚀 Phase 2: Driver Engineering (Weeks 13-24, Months 4-6)
- [🔄 Buffer Week (Month 3 Revision)](#-buffer-week-month-3-revision)
- [Week 13 — Character Devices & User Memory](#week-13--character-devices--user-memory)
- [Week 14 — Platform Drivers & Device Tree](#week-14--platform-drivers--device-tree)
- [Week 15 — PCI Drivers in Rust](#week-15--pci-drivers-in-rust)
- [Week 16 — Interrupts, Workqueues, Timers](#week-16--interrupts-workqueues-timers)
- [🔄 Buffer Week (Month 4 Revision)](#-buffer-week-month-4-revision)
- [Week 17 — Memory & DMA](#week-17--memory--dma)
- [Week 18 — I2C, SPI, GPIO, clk, regulator, PWM](#week-18--i2c-spi-gpio-clk-regulator-pwm)
- [Week 19 — sysfs, debugfs, configfs, Module Params](#week-19--sysfs-debugfs-configfs-module-params)
- [Week 20 — Power Management](#week-20--power-management)
- [🔄 Buffer Week (Month 5 Revision)](#-buffer-week-month-5-revision)
- [Week 21 — RCU, LKMM, lockdep: Concurrency For Real](#week-21--rcu-lkmm-lockdep-concurrency-for-real)
- [Week 22 — Kernel Data Structures in Rust](#week-22--kernel-data-structures-in-rust)
- [Week 23 — The Block Layer in Rust](#week-23--the-block-layer-in-rust)
- [Week 24 — Networking in Rust](#week-24--networking-in-rust)
- [✅ Phase 2 Completion Checklist (6-MONTH MILESTONE)](#-phase-2-completion-checklist-6-month-milestone)
- [🔄 Buffer Week (Month 6 Revision) ⭐](#-buffer-week-month-6-revision--6-month-milestone)

### ⚙ Phase 3: Subsystem Depth (Weeks 25-36, Months 7-9)
- [Week 25-26 — Filesystems in Rust](#week-25-26--filesystems-in-rust)
- [Week 27 — Binder: The Production Rust Driver Case Study](#week-27--binder-the-production-rust-driver-case-study)
- [Week 28 — Tracing, ftrace, perf, eBPF Interaction](#week-28--tracing-ftrace-perf-ebpf-interaction)
- [🔄 Buffer Week (Month 7 Revision)](#-buffer-week-month-7-revision)
- [Week 29-30 — DRM & KMS Fundamentals](#week-29-30--drm--kms-fundamentals)
- [Week 31-32 — GEM, dma-fence, Scheduling, GPUVM/VM_BIND](#week-31-32--gem-dma-fence-scheduling-gpuvmvm_bind)
- [🔄 Buffer Week (Month 8 Revision)](#-buffer-week-month-8-revision)
- [Week 33-34 — Nova Core: PCI, VBIOS, Falcon, GSP Boot](#week-33-34--nova-core-pci-vbios-falcon-gsp-boot)
- [Week 35-36 — Nova DRM: uAPI, RPC, and Your First Nova Patch](#week-35-36--nova-drm-uapi-rpc-and-your-first-nova-patch)
- [🔄 Buffer Week (Month 9 Revision)](#-buffer-week-month-9-revision)
- [✅ Phase 3 Completion Checklist](#-phase-3-completion-checklist)

### 🎓 Phase 4: Upstream Engineer (Weeks 37-52, Months 10-13)
- [Week 37-38 — Designing Sound Abstractions](#week-37-38--designing-sound-abstractions)
- [Week 39-40 — Security, Sanitizers, Fuzzing](#week-39-40--security-sanitizers-fuzzing)
- [🔄 Buffer Week (Month 10 Revision)](#-buffer-week-month-10-revision)
- [Week 41-42 — The Upstream Machine: Trees, linux-next, Merge Windows](#week-41-42--the-upstream-machine-trees-linux-next-merge-windows)
- [Week 43-44 — Reviewing Patches & Porting C to Rust](#week-43-44--reviewing-patches--porting-c-to-rust)
- [🔄 Buffer Week (Month 11 Revision)](#-buffer-week-month-11-revision)
- [Week 45-46 — Testing Infrastructure: KUnit & kselftest](#week-45-46--testing-infrastructure-kunit--kselftest)
- [Week 47-48 — Multi-Arch, Cross-Compilation & CI](#week-47-48--multi-arch-cross-compilation--ci)
- [🔄 Buffer Week (Month 12 Revision)](#-buffer-week-month-12-revision)
- [Week 49-50 — Performance Engineering & Benchmarking](#week-49-50--performance-engineering--benchmarking)
- [Week 51-52 — Production Quality, ABI, Stable/LTS](#week-51-52--production-quality-abi-stablelts)
- [🔄 Buffer Week (Month 13 Revision)](#-buffer-week-month-13-revision)
- [✅ Phase 4 Completion Checklist](#-phase-4-completion-checklist)

### 🏅 Phase 5: Mastery (Weeks 53-64, Months 14-16)
- [Week 53-54 — Virtualization: virtio, VFIO, KVM](#week-53-54--virtualization-virtio-vfio-kvm)
- [Week 55-56 — Advanced Memory Management](#week-55-56--advanced-memory-management)
- [🔄 Buffer Week (Month 14 Revision)](#-buffer-week-month-14-revision)
- [Week 57-60 — Major Contribution + Authoring](#week-57-60--major-contribution--authoring)
- [🔄 Buffer Week (Month 15 Revision)](#-buffer-week-month-15-revision)
- [Week 61-64 — Sustained Upstream & Ecosystem](#week-61-64--sustained-upstream--ecosystem)
- [🔄 Buffer Week (Month 16 Revision)](#-buffer-week-month-16-revision)

### 🎖 Phase 6: Magnum Opus & Portfolio (Weeks 65-78, Months 17-18)
- [Week 65-72 — Magnum Opus Build](#week-65-72--magnum-opus-build)
- [Week 73-78 — Portfolio, Talk, Maintainership Path](#week-73-78--portfolio-talk-maintainership-path)

### 📦 Appendix: Essential Resources
- [📚 Books](#books)
- [🎓 Courses, Labs & Training](#courses-labs--training)
- [💻 Code To Study (In-Tree and Out)](#code-to-study-in-tree-and-out)
- [📄 Master Reading List (45 Items)](#master-reading-list-45-items)
- [🔧 Kernel Rust Abstraction Checklist](#kernel-rust-abstraction-checklist)
- [⚙ Kernel Internals Knowledge Checklist](#kernel-internals-knowledge-checklist)
- [📮 Upstream Workflow Checklist](#upstream-workflow-checklist)
- [🌐 Communities, Lists & Conferences](#communities-lists--conferences)
- [🧰 Lab & Hardware Checklist](#lab--hardware-checklist)
- [🚑 Troubleshooting Cheat Sheet](#troubleshooting-cheat-sheet)

---

## North Star

Become the kind of kernel engineer who can reason across the full stack **and** be trusted with the language boundary:

```text
hardware datasheet -> register semantics -> C subsystem API -> safe Rust abstraction
-> driver logic in safe Rust -> concurrency correctness -> uAPI contract with userspace
-> a patch series that a maintainer merges without hesitation
```

After this roadmap, you should not merely "know that Rust is in the kernel." You should be able to:

- Write a Linux device driver in Rust from a blank file: probe, resources, interrupts, DMA, sysfs, power management, teardown — with correct error paths
- Design a **safe abstraction** over a C subsystem, write the safety contract for every `unsafe` block, and defend its soundness in review
- Explain kernel concurrency with precision: what a spinlock guarantees, why RCU exists, what `Send`/`Sync` mean in a kernel context, and where the Linux Kernel Memory Model bites
- Debug a kernel you broke: oops decoding, KASAN/KCSAN reports, ftrace, kgdb, bisection
- Navigate a 40-million-line C codebase and find the ten lines that matter
- Run the upstream workflow fluently: `checkpatch` → `get_maintainer` → `git send-email` → review → v2 → merged, with `Fixes:` tags and stable backports where appropriate
- Ship tools and documentation that make other kernel Rust developers faster

The journey is deliberately hard. Kernel work has no undo button, the feedback loop is a reboot, and the reviewers are the most demanding in software. The reward is rare: very few engineers can hold both the hardware model and the type-theory model in their head at once. That intersection is exactly where Rust-for-Linux lives.

---

## Why Rust in the Kernel (and Where It Does Not Belong Yet)

### The case for it

- **Memory safety where it matters most.** A large share of kernel CVEs are memory-safety bugs — use-after-free, double-free, out-of-bounds, uninitialized reads, data races. Rust's ownership and borrow rules turn most of those into compile errors instead of `panic()` on someone's production machine.
- **Drivers are the right blast radius.** A driver is a contained unit with a defined interface to the rest of the kernel. That makes it the natural place to introduce a second language.
- **The type system encodes invariants that C can only document.** `Devres<Bar0>` cannot outlive the device. A `Guard` cannot be dropped without releasing the lock. A pinned object cannot be moved. In C these are comments; in Rust they are compile errors.
- **Error paths stop being an afterthought.** `Result` + `?` + `Drop` gives you the unwinding discipline that C drivers reimplement (badly) with `goto err_free_foo` ladders.

### Where it does not belong (yet)

- **No rewrite is happening.** The kernel remains overwhelmingly C. There is no plan to convert existing C code. Rust is *additive*.
- **Coverage is incomplete.** If an abstraction for a C API does not exist yet, you must write the abstraction first — that is real, reviewable work, not a five-minute task.
- **Some subsystems have said no, or not yet.** Maintainer buy-in is per-subsystem and political as much as technical. Check the current temperature before investing months.
- **C remains the primary skill.** You cannot write a Rust abstraction over a subsystem you do not understand in C. **Reading C fluently is non-negotiable** — this roadmap treats C kernel literacy as a requirement, not an optional extra.
- **Panic is not an option.** Kernel Rust cannot unwind. `unwrap()` in a driver is a bug. Allocation is fallible. `alloc` is not `std`.

**Honest expectation setting:** your first ten upstream contributions will most likely be register definitions, documentation, small refactors, test coverage, and abstraction plumbing — not a new GPU driver. That is the correct path and it is how everyone gets in.

---

## State of Rust-for-Linux (Read This Before Planning)

Snapshot as of **August 2026** — verify against `Documentation/rust/` and [rust-for-linux.com](https://rust-for-linux.com/) before you rely on any of it, because this moves fast.

| Fact | Detail |
|------|--------|
| First merged | Rust support landed in **Linux 6.0** (Oct 2022), marked experimental |
| Status change | **Officially supported, no longer experimental (Dec 2025)** — maintainers review and accept Rust patches as normal development |
| First useful driver | **ASIX AX88772A network PHY** driver + PHY abstraction layer, **Linux 6.8** |
| Flagship production driver | **Rust Binder** (Android IPC), merged in **6.18** |
| Flagship GPU work | **Nova** (`drivers/gpu/nova-core/` + `drivers/gpu/drm/nova/`) — Rust successor to Nouveau for GSP-based NVIDIA GPUs, heavy NVIDIA investment; **Tyr** — Arm Mali; **Asahi AGX** — Apple silicon |
| Other drivers | `rnull` (null block), several PHY drivers, LED driver, NVMe effort, misc/platform drivers |
| Current era | Mainline is in the **7.2 / 7.3** range. Recent additions: the `zerocopy` crate in-tree, higher-ranked lifetime types for driver/device lifetimes, Auto-FDO for Rust code, s390 Rust support |
| In flight | **USB** abstractions and **sysfs device attribute** abstractions are on the list as RFCs — a live example of how a new abstraction gets built |
| Toolchain truth | `make LLVM=1 rustavailable` is the **only** authority on which `rustc`/`bindgen` versions you need. Never trust a version pinned in a blog post |

### The mental model that matters

```text
   C kernel headers (include/)
            |
        [ bindgen ]                       <- rust/bindings/  : raw, unsafe, auto-generated
            |
   safe abstractions                      <- rust/kernel/    : carefully reviewed, unsafe lives HERE
            |
   leaf code: drivers, filesystems        <- drivers/, fs/   : ideally zero unsafe blocks
```

**Rule:** leaf drivers must not touch `rust/bindings/` directly. If the abstraction you need does not exist, writing it *is* the contribution.

---

## Your Lab (Hardware & Environment Reality)

Kernel development needs a machine you can crash. Your primary box is Windows 11 with an RTX 1000 Ada laptop GPU (6 GB VRAM), a Core Ultra CPU, and 31.5 GB RAM. That is plenty for building kernels and running QEMU guests — but it shapes the plan.

| Tier | What it is | What you can do with it | When you need more |
|------|-----------|------------------------|--------------------|
| **Tier 1 — WSL2 (start here)** | Ubuntu under WSL2 on your Windows box | Build kernels, run QEMU/virtme-ng guests, load your own modules inside the guest, run KUnit, use `git send-email`. Nested virtualization is on by default on Windows 11 x86, so `/dev/kvm` should exist (verify — you may need `modprobe kvm_intel`) | Anything that touches real hardware |
| **Tier 2 — QEMU virtual devices** | QEMU-emulated PCI/virtio/serial devices inside the guest | Real PCI driver development with **zero hardware**: BARs, MSI-X, DMA, interrupts. This is how Month 4-5 works | GPU work, timing-sensitive work |
| **Tier 3 — A cheap ARM board** | Raspberry Pi / BeagleBone / similar with exposed I2C+SPI+GPIO | Platform drivers, device tree, real I2C/SPI sensor drivers — the most *upstreamable* beginner target. ~$50 unlocks a whole class of contributions | x86-specific or GPU work |
| **Tier 4 — Sacrificial x86 box** | Dual-boot partition, old desktop, or a cloud VM with nested virt | Boot your own kernel on bare metal, real PCI hardware, perf work | — |
| **Tier 5 — GA102 box** | RTX 3090 / 3090 Ti (Ampere GA102) | **Required for Nova hardware work.** QEMU cannot emulate the GPU | — |

### Lab decisions to make in Week 0

- [ ] Set up WSL2 Ubuntu, confirm `/dev/kvm` exists, and get `make LLVM=1 rustavailable` to say yes
- [ ] Install QEMU + `virtme-ng` — your boot loop must be **under 60 seconds** or you will lose momentum
- [ ] Get `git send-email` actually sending (test by mailing yourself) — this blocks every contribution
- [ ] Decide your Tier 3 board and order it now, so it arrives before Month 5
- [ ] Plan for Tier 4/5 access before Month 9 — a GA102 board is required for Nova hardware work, so start sourcing one early (used market, a loan from a friend, or a rented bare-metal host)

**See `SETUP.md` for the full step-by-step lab build.**

---

## How To Use This File

- **Check off items** as you complete them: change `[ ]` to `[x]`
- Each **day = 2-3 hours** of focused work
- Days alternate between **Rust language depth** and **kernel internals** (or split 50/50) — you need both muscles growing together
- **Saturday** = weekly project: something that compiles, boots, and can be shown to another person
- **Sunday** = rest + read the listed paper / LWN article / conference talk
- If a day takes longer, split it across 2 days — **no rush**. Kernel concepts do not compress.
- **After every month:** take 1 extra week to revise everything from that month + previous months
- **Monthly projects:** complete 2 per month — each must use skills from the current AND previous months
- **Write down every failure.** A kernel journal is worth more here than in any other discipline, because the bug you hit at 1 a.m. in Month 3 will reappear in Month 11. Keep it in `./journal/`.
- **Read C every single week.** Pick one real C driver and read it end to end. Rust fluency without C kernel literacy is useless upstream.
- **Lurk on the mailing lists from Week 1.** You learn the culture by osmosis long before you post.
- **Use AI (Cursor/Codex/Claude)** as a tutor, C-to-Rust translator, and ruthless reviewer — but **never** paste AI-written code into an upstream patch without understanding every line. Maintainers will find out, and your reputation is the only currency you have.

### The one rule that beats all the others

> **Boot it.** A kernel change that has not been booted does not exist. If you cannot boot it, you cannot claim it works, and you must not send it.

---

## Project Philosophy: Novel + Useful + Cumulative

Every month has two projects because kernel expertise needs two muscles:

- **Project A:** deep implementation of the month's main technical theme — the thing that teaches you the subsystem
- **Project B:** a tool, test suite, or piece of documentation that packages the learning so other kernel developers benefit

For Month `N`, both projects must use Month `1...N` skills. The project should show visible evidence of that cumulative learning:

- **Month 1+ toolchain proof:** you can build, boot, and instrument a Rust-enabled kernel reproducibly
- **Month 2+ safety proof:** every `unsafe` block has a real safety argument, not a shrug
- **Month 3+ module proof:** a loadable Rust module with correct init/teardown and no leaks
- **Month 4+ driver proof:** a driver that binds to a device, handles interrupts, and survives unbind/rebind cycles
- **Month 5+ hardware proof:** DMA, buses, and power management done correctly, measured
- **Month 6+ concurrency proof:** clean under lockdep and KCSAN, with a written argument for the locking design
- **Month 7+ subsystem proof:** you implemented against a real subsystem's contract (fs, tracing, block)
- **Month 8+ GPU proof:** DRM/KMS/GEM understanding demonstrated in working code
- **Month 9+ Nova proof:** you can trace GSP boot in the source and explain it to someone else
- **Month 10+ soundness proof:** an abstraction with a documented safety contract and a soundness argument that survived review
- **Month 11+ upstream proof:** a patch series with review responses and a v2+
- **Month 12+ testing proof:** KUnit/kselftest coverage and multi-arch boot results
- **Month 13+ production proof:** ABI documentation, stable-worthy fixes, error-path completeness
- **Month 15+ community proof:** merged code, documentation others cite, people asking you questions

### Novelty Scorecard

Before starting any monthly project, fill this in. If the score is weak, redesign the project.

| Question | Must Be True |
|----------|--------------|
| Who is this for? | A specific person exists: a kernel newcomer, a driver author, a maintainer, a Rust-for-Linux contributor, a distro engineer |
| What pain does it remove? | It saves debug time, review time, boot cycles, reading time, or prevents a class of bug |
| What is new about it? | A missing tool, a missing abstraction, a missing test, clearer documentation, or a better measurement |
| What will I measure? | Boot time, throughput, latency, LOC, `unsafe` count, bugs found, coverage, review rounds saved |
| What previous months are visible? | The README explicitly says which Month 1...N skills appear and where |
| Can someone else run it? | It has a documented setup, a QEMU recipe, and sane defaults — no "works on my machine" |
| Would a maintainer respect it? | If the answer is no, it is a toy. Toys are fine for Week projects, not for monthly ones |

### Definition Of Done For Monthly Projects

A monthly project is not done when it "compiles." It is done when it has:

- [ ] Clear problem statement: who it helps and why it matters
- [ ] Working implementation with a **reproducible boot/run recipe** (QEMU command line included)
- [ ] Evidence: benchmark, test output, `dmesg` transcript, or bug-found list
- [ ] Architecture note or diagram: what the pieces are and how they talk
- [ ] Cumulative-learning section: "Skills from Month 1...N used here"
- [ ] Tests: KUnit, kselftest, or a userspace test script that proves the core behavior
- [ ] Failure analysis: where it breaks, what is unsound, what you would do next
- [ ] Every `unsafe` block has a `// SAFETY:` comment that would survive review
- [ ] Public-quality README with install, usage, examples, and results
- [ ] One short technical write-up explaining the hardest idea you hit

### Anti-Tutorial Rule

You may learn from tutorials, but final projects must not look like tutorials. To pass:

- Add one original capability that solves a real developer pain
- Compare against a baseline (the C equivalent, the existing tool, or "no tool at all") and publish numbers
- Explain a design decision using hardware, kernel, or type-system reasoning
- Make it reusable by someone who is not you, on a machine that is not yours

### Upstream-First Rule

From **Month 5 onward**, every monthly project must answer: *"Which part of this could go upstream?"* Even if the answer is "just the documentation" or "just the tests" — identify it, and try. Contributions that get merged are worth ten projects that live only on GitHub.

---

## Expertise Gates

Use these gates to decide whether you are truly leveling up:

| Point | You Should Be Able To Do |
|-------|---------------------------|
| End of Month 1 | Build and boot a Rust-enabled kernel from a clean tree in under 15 minutes, and navigate to any subsystem's source without searching |
| End of Month 3 | Write, load, and unload a Rust misc-device driver with an ioctl interface, correct error paths, and no leaks — and debug it when it panics |
| End of Month 6 | Write a Rust driver that binds to a real (or QEMU) PCI device, handles interrupts and DMA, is clean under lockdep/KCSAN, and explain its locking design in writing |
| End of Month 9 | Read `nova-core` and explain the GSP boot path; write a DRM driver that modesets in QEMU; have patches in review |
| End of Month 12 | Design and defend a new safe abstraction over a C subsystem, with KUnit tests and a soundness argument |
| End of Month 15 | Have multiple merged patches across multiple subsystems, review other people's Rust patches usefully, and be recognized on a list or in Zulip |
| End of Month 18 | Lead a non-trivial Rust kernel contribution from RFC to merge, and be a credible candidate for co-maintainership of something |

If a gate feels weak, pause and build one more small driver before moving on. Speed is worthless here; compounding correctly is everything.

---

## How This Folder Relates To Your Other Tracks

You already have adjacent work in this workspace. Use it — do not duplicate it.

| Folder | What it gives you | How it feeds this roadmap |
|--------|-------------------|---------------------------|
| `LINUX/` (TLPI + KVM books) | Linux **userspace** systems programming in C, and KVM/QEMU virtualization | The other side of every syscall you will implement. Ch. 4-5 (file I/O), 20-22 (signals), 29-33 (threads), 44-55 (IPC), 63 (I/O models) are direct prep for char devices, ioctls, and uAPI design. The KVM book directly supports Month 14. |
| `Rust/` | Existing Rust projects (`ai_sandbox`, etc.) | Proof you can already write Rust. Phase 1 here is about *kernel-flavored* Rust: `no_std`, fallible allocation, `Pin`, `unsafe` at the FFI boundary. |
| `AI_ML_LLM/` + `LOCAL-AI/` | GPU/CUDA/LLM systems | Shared hardware intuition: memory hierarchies, bandwidth, DMA, PCIe. Month 8-9 GPU work will feel familiar. |
| `CUDA/`, `HFT/` | Low-level performance work | Performance-engineering instincts for Weeks 49-50. |

**Study rhythm suggestion:** this roadmap is the primary track at 2-3 hrs/day. If you are also running `AI_ML_LLM`, alternate days rather than splitting each day — context switching between GPU math and kernel internals mid-session wastes both.

---

## Repo Layout & GitHub Setup

```text
LKD_RUST/
├── Readme.md                  # this file — the 18-month roadmap (the theory + daily concepts)
├── SETUP.md                   # Week 0: build the lab (WSL2, kernel, Rust toolchain, QEMU, git send-email)
├── UPSTREAM.md                # the contribution playbook: patch workflow, etiquette, first-patch targets
├── LICENSE                    # MIT for these notes (kernel patches themselves are GPL-2.0)
├── .gitignore
├── .gitattributes             # keeps .sh/.rs/.c LF so they work in Linux
├── theory/                    # the daily notes — written as you study
│   └── Month_1/Week_1/
│       ├── Day_1.md
│       ├── Day_2.md
│       └── ...
├── codes/                     # all code, mirroring theory/ exactly
│   ├── README.md
│   ├── sync_from_repo.sh      # repo -> WSL (pull code to build and run it)
│   ├── sync_to_repo.sh        # WSL -> repo (push changes back to commit)
│   └── Month_1/Week_1/
│       ├── Day_1/             # install_deps.sh, check_day1.sh, record_env.sh, config examples
│       └── Day_5/             # check_setup.sh — verify the whole lab
└── journal/                   # measurements, crashes, submissions
    └── README.md
```

### theory/ and codes/ mirror each other

```text
theory/Month_1/Week_1/Day_1.md   <->   codes/Month_1/Week_1/Day_1/
```

The theory file explains what you learned; the code folder holds what you ran. Same coordinates, so you
never have to search for the code that goes with a lesson.

### How the daily notes work

**This file is the plan.** Every week below lists the concepts for each day, the Saturday project, and
the Sunday reading. It is deliberately not a textbook.

**`theory/` is the record**, and you write it as you go — one file per study day, during or right after
the session. Do not pre-generate them; a day file written before you have done the work is just the plan
copied twice.

A day file that earns its place has the concepts in your own words, the commands you actually ran, what
broke and why, the numbers you measured, and what you still do not understand. Add a
`Day_N_REVISION.md` when a buffer week makes you revisit something.

The **kernel tree is not in this repo.** It lives in WSL at `~/LKD_RUST/kernel/linux`, cloned fresh from
upstream — 5 GB of someone else's history has no business in your git history. `.gitignore` blocks it
along with every build artifact.

### Connecting to GitHub

```bash
cd LKD_RUST
git init -b main
git add .
git commit -m "Linux kernel development in Rust: roadmap + lab setup"
gh repo create linux-kernel-rust --public --source=. --remote=origin --push
# or, without gh:
#   git remote add origin git@github.com:<you>/linux-kernel-rust.git
#   git push -u origin main
```

**Do not commit:** kernel trees, `vmlinux`, build artifacts, firmware blobs, `.config` files with machine-specific paths, or anything from an employer's internal source. The `.gitignore` covers the mechanical cases; the last one is on you.

> ⚠ **A note on working at a hardware company:** everything you upstream must be derived from public sources or from work you are cleared to contribute. Read your employer's open-source contribution policy *before* your first patch, not after. Non-public documentation may help you *understand* a device faster; it must never appear in a commit message, a code comment, a variable name, or a mailing-list post.

### Sources for this roadmap

Everything in this repository is derived from public material, and it needs to stay that way:

- Upstream kernel source (`torvalds/linux`) and in-tree `Documentation/`
- [docs.kernel.org](https://docs.kernel.org/) — including `docs.kernel.org/gpu/nova/`
- [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/) and [rust-for-linux.com](https://rust-for-linux.com/)
- Public patch archives: `lore.kernel.org`, `lore.freedesktop.org`
- Published books, papers, conference talks, LWN, and hardware datasheets that are freely available
- Nouveau's public reverse-engineering documentation

If you cannot point at a public URL or a published book for something you wrote here, take it out. This
matters most for GPU work, where the temptation to reach for a non-public reference is highest and the
consequences of doing so are worst — a patch whose provenance is questionable is worse than no patch,
because it damages trust you cannot rebuild.

---

## Progress Overview

| Phase | Weeks | Months | Focus | Status |
|-------|-------|--------|-------|--------|
| Phase 1: Foundations | 0-12 | 1-3 | Rust depth + kernel fundamentals + first modules | ⬜ Not Started |
| Phase 2: Driver Engineering | 13-24 | 4-6 | Real drivers: PCI, DMA, buses, concurrency, block, net | ⬜ Not Started |
| Phase 3: Subsystem Depth | 25-36 | 7-9 | Filesystems, tracing, DRM/GPU, Nova | ⬜ Not Started |
| Phase 4: Upstream Engineer | 37-52 | 10-13 | Abstractions, security, review, porting, CI, production | ⬜ Not Started |
| Phase 5: Mastery | 53-64 | 14-16 | Virtualization, advanced MM, major contribution, ecosystem | ⬜ Not Started |
| Phase 6: Magnum Opus | 65-78 | 17-18 | Signature contribution, portfolio, maintainership path | ⬜ Not Started |

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════════════
# MONTHLY CAPSTONE PROJECT CATALOG (Build Only When Reached)
# ═══════════════════════════════════════════════════════════

> **TWO projects per month.** Each must combine skills from the current month AND
> all previous months. Each must have a **novelty angle** — a missing tool, a missing
> abstraction, a missing test, or documentation that does not exist yet.
> This is a catalog of future project briefs. Build each project only during the
> **buffer week** after the required weeks have been completed.
> These are the projects you put on your resume, your GitHub, and — where possible — on the mailing list.
>
> **Project A** = the deep technical build. **Project B** = the tool/test/doc that helps others.
> Both must use current month + all previous month skills.

Each brief below is a starting point, not a cage. If you discover a sharper pain while studying, improve the project — but keep the cumulative rule: Month `N` must visibly use Month `1...N`.

Every monthly project README should include:

- **User:** who this helps
- **Pain:** what slow/confusing/dangerous thing it fixes
- **Novelty:** what is different from what already exists in-tree or on GitHub
- **Cumulative skills:** which months are used and where in the code
- **Evidence:** benchmark, `dmesg` transcript, test output, or bugs found
- **Reproduce:** the exact QEMU/virtme-ng command line to run it
- **Upstream angle:** which part of this could become a patch (required from Month 5 on)

---

## Month 1 Project A: "KernelForge — One-Command Rust Kernel Lab"
**When to build:** Month 1 buffer week, after Weeks 0-4.
**What:** A CLI tool (written in Rust, naturally) that takes you from a clean Linux tree to a booted, Rust-enabled kernel with one command — and tells you how long every stage took.
**Novelty:** Everyone reinvents these shell scripts badly. Yours is reproducible, cached, measured, and diagnoses toolchain problems *before* wasting a 20-minute build. It turns `make LLVM=1 rustavailable` failures into actionable instructions.
**Skills used:** Rust CLI + error handling (Month 1), Kconfig/Kbuild (Month 1), kernel build/boot (Month 1), QEMU/virtme-ng (Week 0)
**Deliverables:**
- [ ] `kforge doctor` — checks rustc/bindgen/LLVM/libclang versions against what the tree demands, and prints exact fix commands
- [ ] `kforge config` — applies a named config profile (minimal-rust, debug-everything, kasan, kcsan) as a Kconfig fragment overlay, not a hand-edited `.config`
- [ ] `kforge build` — incremental build with ccache, timing per stage, warning summary
- [ ] `kforge boot` — boots the result under QEMU/virtme-ng, captures the console, greps for oops/warnings, exits non-zero on failure
- [ ] `kforge bisect-boot` — wraps `git bisect run` with a boot test as the predicate
- [ ] A boot-time report: config → build time → boot time → module load result
- [ ] **Publish to GitHub with a demo GIF of clean-tree-to-boot in one command**

## Month 1 Project B: "RustScope — Kernel Rust Adoption Tracker"
**When to build:** Month 1 buffer week, after Weeks 0-4.
**What:** A tool + generated dashboard that answers, from any Linux git tree: how much Rust is in the kernel, where, which abstractions exist, and how it has grown release by release.
**Novelty:** People keep asking "how much Rust is in the kernel now?" and answer with vibes. Yours answers with data from the actual tree, per subsystem, over git history — and doubles as your personal map of the codebase.
**Skills used:** Rust iterators/collections/error handling (Month 1), kernel source layout (Month 1), Kconfig knowledge (Month 1), git plumbing
**Deliverables:**
- [ ] Walk any Linux tree: count Rust LOC per directory, per subsystem, per driver
- [ ] Inventory every module in `rust/kernel/` with its doc summary and the `CONFIG_*` that gates it
- [ ] List every in-tree Rust driver with its subsystem, `MAINTAINERS` entry, and first-appearing release
- [ ] Historical mode: walk tags (`v6.0`..`HEAD`) and plot Rust LOC + abstraction count over time
- [ ] `unsafe` block census per file, as a first pass at the Month 2 project
- [ ] Output as markdown + a static HTML page with charts
- [ ] **Publish to GitHub — this is genuinely useful to the community and a great first calling card**

---

## Month 2 Project A: "SafetyLint — The unsafe and SAFETY-Comment Auditor"
**What:** A static analysis tool for kernel Rust that finds every `unsafe` block, `unsafe fn`, and `unsafe impl`, checks whether it carries a `// SAFETY:` comment, and classifies the invariant being claimed.
**Novelty:** The kernel's Rust coding guidelines *require* safety comments, but nothing enforces or summarizes them. Yours produces a per-subsystem "unsafe hygiene" report, flags missing or copy-pasted justifications, and categorizes claims (pointer validity, aliasing, lifetime, initialization, locking, C API contract). This is checkpatch-adjacent and could genuinely land in `scripts/`.
**Skills used:** `unsafe` Rust and UB rules (Month 2), Rust parsing/tooling (Month 2), kernel Rust guidelines (Month 2), source-tree walking (Month 1)
**Deliverables:**
- [ ] Parse Rust source (`syn` or `proc-macro2`-based, or `rust-analyzer` IR) — find all `unsafe` constructs with file:line
- [ ] Detect missing `// SAFETY:` comments; detect `SAFETY` comments that say nothing ("this is safe")
- [ ] Classify the safety claim into categories; report the distribution per subsystem
- [ ] Flag duplicated safety comments across dissimilar call sites (a copy-paste smell)
- [ ] Compare `rust/kernel/` (where unsafe *should* live) against `drivers/` (where it should be near zero)
- [ ] Run it on the whole tree and write up what you found — an honest, data-backed blog post
- [ ] **Publish to GitHub; float the idea on the Rust-for-Linux Zulip**

## Month 2 Project B: "PinDojo — Pin, pin-init & Self-Reference Playground"
**What:** A userspace Rust crate that teaches the hardest concept in kernel Rust — pinning — by mirroring the exact patterns the kernel uses, with runnable examples and compile-fail tests.
**Novelty:** `Pin`, `#[pin_data]`, and `pin_init!` are where every kernel Rust newcomer stalls, and existing explanations are either too abstract (`std::pin` docs) or too deep (kernel source). Yours is a graded dojo: 20 exercises, each with a failing version, a fixed version, and an explanation of *why the kernel needs this at all*.
**Skills used:** `Pin`/`Unpin`, `PhantomPinned`, variance, `PhantomData` (Month 2), `unsafe` reasoning (Month 2), Rust type system (Month 1)
**Deliverables:**
- [ ] 20+ graded exercises with `trybuild` compile-fail tests proving the borrow checker catches the mistake
- [ ] Progression: why moving breaks self-reference → `Pin<&mut T>` → `Unpin` → pin projection → `#[pin_data]` → `pin_init!` → fallible pinned init
- [ ] A side-by-side "the kernel does it like this" section citing real `rust/kernel/` code for each concept
- [ ] A worked example: build a linked-list node and a mutex-guarded struct that *must* be pinned, and show what breaks if it moves
- [ ] Written explanation: "why hardware objects in the kernel are pinned" in plain language
- [ ] **Publish as a crate + mdBook; this is the resource you wished existed in Week 7**

---

## Month 3 Project A: "KModKit — The Rust Kernel Module Starter Suite"
**What:** The `samples/rust/` that should exist: six minimal, exhaustively documented Rust kernel modules, each with a KUnit test and an automated QEMU boot test.
**Novelty:** In-tree samples are minimal by design and assume you already know the kernel. Yours are *teaching* modules — every line commented with what it does and which C API it wraps — plus a generator so a newcomer can scaffold a working module in one command and actually load it.
**Skills used:** `kernel` crate (Month 3), module lifecycle (Month 3), misc device + file ops (Month 3), sync primitives (Month 3), KUnit (Month 3), build/boot harness from KernelForge (Month 1)
**Deliverables:**
- [ ] `01-hello` — module init/exit, `pr_info!`, module params, correct teardown
- [ ] `02-miscdev` — a misc device with open/read/write/release and `UserSlice` copying
- [ ] `03-ioctl` — a well-designed ioctl interface with versioning and a userspace client
- [ ] `04-sync` — `SpinLock`, `Mutex`, `CondVar`, `Arc` used correctly, with a demonstration of what lockdep catches
- [ ] `05-work` — workqueue + timer + deferred work, with a clean shutdown that cannot race
- [ ] `06-debugfs` — expose driver state through debugfs and `seq_file`
- [ ] Each module: KUnit tests + a QEMU boot test + a `dmesg` transcript in the README
- [ ] `kmodkit new <name>` scaffolding command
- [ ] **Publish to GitHub; propose the best two as additions to `samples/rust/`**

## Month 3 Project B: "OopsLens — Kernel Crash & KASAN Report Decoder"
**What:** A Rust CLI/TUI that ingests a kernel oops, panic, `WARN`, `BUG`, KASAN, KCSAN, or Rust panic report and turns it into a human explanation: what happened, where, what the call chain was, and what to look at first.
**Novelty:** `decode_stacktrace.sh` exists but is bare-bones and C-centric. Yours understands **Rust kernel panics and `Result`-less failure paths**, resolves symbols against `vmlinux` with `addr2line`, annotates KASAN reports with the allocation/free stacks side by side, and gives a plain-English diagnosis with a suggested next debug step.
**Skills used:** Rust parsing + TUI (Month 3), kernel debugging (Month 3), memory allocation model (Month 3), oops anatomy (Month 3), Month 1 tooling
**Deliverables:**
- [ ] Parse oops/panic/WARN/BUG/KASAN/KCSAN/UBSAN and Rust `panic!` output from dmesg or a serial log
- [ ] Symbolize with `vmlinux` + `addr2line`; handle module-relative addresses
- [ ] KASAN mode: show use-after-free with alloc stack, free stack, and access stack aligned in one view
- [ ] Classify the bug: UAF, OOB, double-free, null deref, deadlock, data race, `unwrap()` on `None`
- [ ] Suggest the next step: "enable KASAN + `slub_debug`", "this is a lockdep ordering issue, run with `CONFIG_PROVE_LOCKING`"
- [ ] TUI mode for browsing long logs; batch mode for CI
- [ ] Test corpus: crash your own KModKit modules deliberately, 10 different ways, and decode each
- [ ] **Publish to GitHub with the crash corpus as test fixtures**

---

## Month 4 Project A: "VirtToy — The Hardware-Free PCI Driver Lab"
**What:** A complete, self-contained PCI driver development lab: a custom QEMU virtual PCI device (C, as a QEMU device model) plus its Rust kernel driver plus a userspace test suite — so anyone can learn Rust PCI driver development with **zero hardware**.
**Novelty:** This is the single biggest barrier for kernel newcomers: "I want to write a PCI driver but I have no device to write it for." `edu` and `pci-testdev` exist in QEMU but have no Rust driver and no teaching material. Yours is a purpose-built device with escalating features and a matching driver, staged as lessons.
**Skills used:** PCI abstractions (Month 4), `Devres`/`Revocable`/BAR mapping (Month 4), MMIO (Month 4), interrupts + MSI-X (Month 4), platform/device model (Month 4), everything from Months 1-3
**Deliverables:**
- [ ] A QEMU PCI device model with: a config space identity, 2 BARs (MMIO registers + a scratch region), a mailbox register protocol, an interrupt-raising doorbell, MSI-X support
- [ ] Rust driver: `probe()`/`remove()`, BAR mapping via `Devres<Bar0>`, register accessors with typed offsets, MSI-X vector setup, interrupt handler, misc device for userspace
- [ ] Correct lifetime handling: prove the driver survives hot-unplug (`echo 1 > .../remove`) without a UAF
- [ ] Userspace test suite that exercises every register and every interrupt path
- [ ] A staged lesson sequence: BAR read → register write → interrupt → MSI-X → error injection
- [ ] `virttoy up` one-command launch: builds QEMU device, builds kernel, boots, loads driver, runs tests
- [ ] **Publish to GitHub — this is a genuinely valuable community artifact**

## Month 4 Project B: "PCIScope — Safe-Rust PCI X-Ray Driver"
**What:** A Rust kernel driver + userspace tool that binds to any PCI device you point it at and exposes a complete, human-readable x-ray: config space decoded, every capability parsed, BAR layout, MSI/MSI-X state, link speed/width, power state, and error counters — all through debugfs.
**Novelty:** `lspci -vvv` reads config space from userspace; it cannot see what the *kernel* sees, and it cannot safely poke a device under a bound driver. Yours runs in-kernel with correct locking and resource management, decodes capabilities that `lspci` renders as hex, and is written entirely against safe abstractions — a real demonstration that a useful PCI driver can have zero `unsafe` blocks in the leaf code.
**Skills used:** PCI config space + capabilities (Month 4), debugfs + `seq_file` (Month 4), safe abstraction usage (Month 4), interrupts (Month 4), Months 1-3 tooling and testing
**Deliverables:**
- [ ] Bind by explicit `pci_stub`-style override so it never fights a real driver
- [ ] Decode: vendor/device/class, all standard + extended capabilities, BAR sizes and types, ROM
- [ ] Report MSI/MSI-X vector counts and masking state, link speed/width vs capability, ASPM state, current PM state
- [ ] AER / error counters where available
- [ ] debugfs tree per device + a userspace pretty-printer with `--diff` between two devices
- [ ] **Count your `unsafe` blocks in the leaf driver and report it: the target is zero**
- [ ] **Publish to GitHub; compare its output against `lspci -vvv` and document what only the kernel can see**

---

## Month 5 Project A: "DMAForge — DMA, Scatter-Gather and IOMMU Lab"
**What:** Extend VirtToy into a full DMA lab: the virtual device gains a DMA engine, and the Rust driver implements coherent allocations, streaming mappings, scatter-gather lists, and IOMMU-aware addressing — with a benchmark harness that measures throughput and latency for each strategy.
**Novelty:** DMA is where kernel newcomers get destroyed, and where memory-safety bugs become silent data corruption instead of a clean crash. Yours is the first hands-on DMA curriculum with a Rust driver, measurable results, and a written analysis of **which classic DMA bugs Rust's type system catches and which it cannot** (spoiler: cache coherency and device-side lifetime are still on you).
**Skills used:** DMA abstractions + `CoherentAllocation` (Month 5), scatterlist (Month 5), IOMMU (Month 5), page allocation (Month 5), PCI + interrupts (Month 4), measurement harness (Month 1)
**Deliverables:**
- [ ] Virtual DMA engine in the QEMU device: descriptor ring, source/dest addresses, length, completion interrupt
- [ ] Driver: coherent allocation path, streaming map/unmap path, scatter-gather path
- [ ] DMA mask negotiation, and a deliberate demonstration of what happens when the mask is wrong
- [ ] IOMMU on/off comparison (`intel_iommu=on`) with measured overhead
- [ ] Benchmark harness: throughput and latency vs transfer size, per strategy, with plots
- [ ] Bug museum: implement 5 classic DMA bugs deliberately (use-after-unmap, missing sync, wrong direction, mask overflow, descriptor race), show which the compiler caught and which needed KASAN or produced silent corruption
- [ ] **Publish with the bug museum as the headline — that analysis is the novel contribution**

## Month 5 Project B: "SensorRS — An Upstreamable Rust I2C/SPI Sensor Driver"
**What:** A real driver for real hardware: pick an I2C or SPI sensor (temperature, pressure, IMU, ADC), write its driver in Rust against the in-tree abstractions, wire it into hwmon or IIO, add device tree bindings, and **submit it upstream**.
**Novelty:** Rust I2C/SPI sensor drivers are almost nonexistent in-tree, the abstractions exist, and the hardware costs a few dollars. This is the single highest-probability path to *your name in a real driver file*. The novelty is not the sensor — it is being early, doing it properly, and leaving behind a template that others copy.
**Skills used:** I2C/SPI abstractions (Month 5), platform + OF/device tree (Month 5), regmap-style register access (Month 5), sysfs (Month 5), runtime PM (Month 5), device model + probe (Month 4), error handling and teardown (Months 1-3)
**Deliverables:**
- [ ] Pick a sensor with a clean datasheet and no existing Rust driver; document why you chose it
- [ ] Driver: probe from device tree, read chip ID, configure, read measurements, handle errors and absent hardware
- [ ] Integrate with **hwmon** or **IIO** so standard userspace tools see it (`sensors`, `iio_info`)
- [ ] Device tree binding documentation (`Documentation/devicetree/bindings/...`) in the correct YAML schema
- [ ] Runtime PM: suspend/resume the sensor, verified by measuring current draw or at least by tracing the callbacks
- [ ] Wire it up on your Tier-3 board; capture `dmesg` + real readings as evidence
- [ ] `checkpatch.pl` clean; `get_maintainer.pl` recipient list prepared
- [ ] **Submit the series to the appropriate list. Expect v2, v3. Getting reviewed is the deliverable; getting merged is the prize.**

---

## Month 6 Project A: "BlockForge — Rust Block Driver with Fault Injection" ⭐ (MILESTONE PROJECT)
**When to build:** Month 6 buffer week, after Weeks 21-24.
**What:** A Rust block device driver in the spirit of `rnull`, but built as a **testing instrument**: configurable latency distributions, configurable I/O error injection, configurable write-ordering violations — so filesystem and storage developers can reproduce nasty bugs deterministically.
**Novelty:** `null_blk` (C) has some fault injection; `rnull` (Rust) is a minimal demonstration. Nobody has built a Rust block driver designed specifically as a *reproducible failure generator* for filesystem testing, with a scenario file format and a report of which filesystems survive which failure patterns. Run it under `fio` and `xfstests` and publish the matrix.
**Skills used:** block layer + blk-mq (Month 6), kernel data structures (Month 6), concurrency + locking discipline (Month 6), DMA/memory (Month 5), device model (Month 4), `kernel` crate mastery (Month 3), testing harness (Months 1-3)
**Deliverables:**
- [ ] Multi-queue block driver: register a gendisk, handle read/write requests, correct completion
- [ ] Backing modes: memory-backed, sparse, and discard-aware
- [ ] Latency injection: fixed, uniform, and heavy-tail distributions, per-queue and per-operation
- [ ] Error injection: `EIO` on the Nth write, on a specific LBA range, on flush, on discard
- [ ] Barrier/FUA/flush semantics honored correctly — and a mode that deliberately violates them
- [ ] Scenario files (declarative config) so a bug reproduction is one file someone can send you
- [ ] Configuration via configfs, matching how `null_blk` does it
- [ ] Clean under lockdep and KCSAN; documented locking design
- [ ] Benchmark vs `null_blk` (C): IOPS, latency percentiles, CPU per IO — with an honest analysis of any gap
- [ ] Run `xfstests` against ext4/xfs/btrfs on top of it under 5 failure scenarios; publish the matrix
- [ ] **Publish to GitHub with the failure matrix as the headline result**

## Month 6 Project B: "LockProof — What Rust Actually Buys Kernel Concurrency"
**What:** An empirical study, delivered as code: a set of Rust and C kernel modules that deliberately implement the same 15 classic kernel concurrency bugs, plus a harness that runs them under lockdep, KCSAN, and stress, and a report of which bugs the Rust compiler rejected outright, which lockdep caught, which KCSAN caught, and which shipped silently.
**Novelty:** The Rust-in-the-kernel debate is full of assertions and short on measurements. This is a real, reproducible answer to "what does Rust actually prevent?" — including the honest negatives (Rust does not prevent deadlock, does not understand RCU grace periods, does not know your interrupt context rules). This is publishable, quotable work.
**Skills used:** RCU + LKMM + memory ordering (Month 6), `SpinLock`/`Mutex`/`CondVar`/atomics (Month 6), lockdep + KCSAN (Month 6), `Send`/`Sync` reasoning (Month 2), module authoring (Month 3), C literacy (all months)
**Deliverables:**
- [ ] 15 bug pairs (C version + attempted Rust version): data race on shared counter, missing lock, wrong lock, lock ordering inversion, sleep in atomic context, use-after-free across threads, RCU read-side leak, missing memory barrier, ABBA deadlock, double-unlock, unbalanced refcount, IRQ-unsafe lock in IRQ context, torn read, publish-before-init, and one of your own choosing
- [ ] For each: does it compile in Rust? If yes, what caught it — lockdep, KCSAN, stress, or nothing?
- [ ] A harness that builds each case, boots it in QEMU under the relevant sanitizer, and produces a results table automatically
- [ ] Written analysis: the three-column truth — *prevented at compile time* / *caught by tooling* / *still your problem*
- [ ] Explicit treatment of what Rust cannot help with: deadlock, RCU semantics, atomic-context rules, cache coherency, hardware ordering
- [ ] **Publish as a repo + write-up; share on the Rust-for-Linux Zulip and consider a Kangrejos or LPC lightning talk**

---

## Month 7 Project A: "TarFS-RS — A Fuzz-Hardened Read-Only Rust Filesystem"
**What:** A read-only filesystem in Rust that mounts a container-style image (tar or a simple custom format), implementing the real VFS contract: superblock, inodes, dentries, `readdir`, `read`, mmap-able page cache.
**Novelty:** Rust filesystem work in-tree (tarfs, PuzzleFS) is early and thin on adversarial testing. Yours is built **fuzz-first**: a syzkaller/AFL harness feeds malformed images from day one, and the deliverable includes a triaged crash corpus plus a written analysis of which malformed-input bug classes Rust eliminated (integer overflow on lengths, unchecked slice indexing) and which it did not (logical corruption, infinite loops, resource exhaustion).
**Skills used:** VFS + fs abstractions (Month 7), page cache + mmap (Month 7), `unsafe` at parsing boundaries (Month 2), fuzzing (Month 7), block/storage understanding (Month 6), everything prior
**Deliverables:**
- [ ] Mount a valid image; `ls`, `cat`, `stat`, `find` all behave correctly
- [ ] Correct superblock/inode/dentry lifecycle with no leaks across mount/unmount cycles
- [ ] Page cache integration; verify `mmap` works and pages are correct
- [ ] A malformed-image fuzzer with a seed corpus; run for 24+ hours under KASAN
- [ ] Triaged crash list: every crash reduced to a minimal reproducer
- [ ] Robustness analysis: bug classes eliminated by construction vs bug classes that required testing
- [ ] Comparison against a C read-only fs (cramfs/squashfs/romfs) on LOC, error handling, and fuzz resistance
- [ ] **Publish with the fuzzing corpus; report any real bug you find in an in-tree fs the proper way**

## Month 7 Project B: "TraceRust — Tracing & Live State Inspection for Rust Drivers"
**What:** A tracing story for Rust kernel drivers: idiomatic tracepoint support, an instrumentation pattern for driver state machines, and a userspace TUI that renders a live view of driver internals from tracepoints and debugfs.
**Novelty:** C drivers have a mature tracing culture; Rust drivers currently mostly `pr_info!` and hope. Yours provides reusable instrumentation patterns and a visualizer that makes a driver's state machine, queue depths, and error paths visible while it runs. Debugging a Rust driver stops being print-archaeology.
**Skills used:** tracepoints + ftrace + perf (Month 7), debugfs + `seq_file` (Month 5), macros (Month 2), driver internals (Months 4-6), TUI tooling (Month 3)
**Deliverables:**
- [ ] Ergonomic tracepoint usage from Rust: define, emit, and verify events appear in `/sys/kernel/tracing`
- [ ] A state-machine instrumentation pattern: every transition traced with before/after state and a reason
- [ ] Latency histograms from tracepoints for driver-internal operations
- [ ] A userspace TUI: live queue depths, state, error counters, event stream, per-operation latency
- [ ] eBPF interop: show that a bpftrace one-liner can observe your Rust driver's tracepoints
- [ ] Retrofit it onto VirtToy and BlockForge; find one real bug with it and document the session
- [ ] **Publish; write up "how to make a Rust kernel driver observable" as the missing guide**

---

## Month 8 Project A: "TinyDRM — A Real Rust DRM/KMS Driver You Can Boot"
**What:** A complete-enough Rust DRM driver for a virtual display device: DRM device registration, KMS modesetting (CRTC, encoder, connector, plane), GEM buffer objects, dumb buffers, page flips — booted in QEMU and driving a real compositor.
**Novelty:** The in-tree Rust DRM drivers (Nova, Tyr) are enormously complex hardware drivers; there is no *minimal, complete, readable* Rust DRM driver to learn from. Yours is the `vkms` of the Rust world: small enough to read in an afternoon, real enough that Weston or a Wayland compositor actually runs on it, and documented as a teaching artifact.
**Skills used:** DRM/KMS + GEM (Month 8), DRM Rust abstractions (Month 8), device model + PCI/platform (Month 4), memory + DMA (Month 5), concurrency (Month 6), everything prior
**Deliverables:**
- [ ] DRM device registration with correct driver features and a versioned uAPI declaration
- [ ] Full KMS pipeline: CRTC + primary plane + encoder + connector, with mode enumeration
- [ ] Atomic modesetting: check + commit paths implemented correctly
- [ ] GEM object management with dumb buffer creation, mapping, and correct refcounting
- [ ] Page flip with vblank event delivery
- [ ] Boots in QEMU; `modetest` enumerates it; a compositor (Weston/Sway headless) runs on it; screenshots as proof
- [ ] `unsafe` block census in the driver, with every block justified
- [ ] Heavily commented source, plus an architecture write-up mapping Rust types to DRM concepts
- [ ] **Publish; this is the DRM Rust teaching driver the ecosystem is missing**

## Month 8 Project B: "FenceScope — GPU Scheduling, dma-fence & VM_BIND Visualizer"
**What:** A tool that records and renders GPU job lifecycle: submission, dependency resolution, `dma-fence` signaling, DRM scheduler decisions, and GPUVM/VM_BIND operations — as a readable timeline.
**Novelty:** GPU scheduling and fence dependency bugs are among the hardest to debug in the kernel, and the current tooling is `dmesg` plus intuition. FenceScope turns a fence deadlock into a picture. Nobody has built this for the Rust DRM stack, and Nova developers will hit exactly these problems.
**Skills used:** dma-fence + DRM scheduler + GPUVM/VM_BIND (Month 8), tracepoints (Month 7), concurrency/ordering (Month 6), TUI/visualization (Months 3, 7), all prior
**Deliverables:**
- [ ] Capture GPU scheduler and dma-fence tracepoints into a structured trace
- [ ] Render a Gantt-style timeline: job submitted → dependencies → scheduled → executing → fence signaled
- [ ] Dependency graph view: which fence is waiting on which, with cycle detection for deadlocks
- [ ] VM_BIND view: address space operations over time, showing map/unmap and their fences
- [ ] Deadlock and long-wait detection with an explanation of the blocking chain
- [ ] Validate against TinyDRM and (if you have hardware) a real driver
- [ ] **Publish; show it to `#dri-devel` — practical GPU debugging tools are always welcome**

---

## Month 9 Project A: "NovaScope — Nova Register and GSP RPC Toolkit" ⭐
**When to build:** Month 9 buffer week, after Weeks 33-36.
**What:** The tooling Nova developers actually want: a register-definition generator and validator for `regs.rs`, a GSP-RM log buffer decoder, and an RPC tracer that makes the host↔GSP conversation readable.
**Novelty:** Nova's `regs.rs` register definitions are added by hand and are one of the explicitly newcomer-friendly contribution areas; GSP RPC debugging currently means staring at ring buffers. Yours mechanizes the boring half and illuminates the opaque half. Both halves are directly upstreamable and both put you in the review loop with Nova maintainers.
**Skills used:** Nova internals: PCI/BAR, VBIOS, Falcon, GSP boot, RPC (Month 9), DRM (Month 8), tracing (Month 7), PCI + MMIO (Month 4), Rust macros and codegen (Month 2), tooling (Months 1-3)
**Deliverables:**
- [ ] Register definition validator: cross-check `regs.rs` entries for overlap, gaps, naming-convention violations, and field-width errors
- [ ] Generator: produce `regs.rs`-shaped definitions from a structured input, matching Nova's macro conventions exactly
- [ ] GSP-RM log decoder: parse `LOGINIT` / `LOGINTR` / `LOGRM` debugfs buffers into readable, timestamped, sequenced output
- [ ] RPC tracer: decode host↔GSP message types, correlate request/response pairs, flag timeouts and unhandled types
- [ ] A boot-path timeline: from `probe()` through Falcon load to GSP ready, with per-stage timing
- [ ] Test against real hardware (GA102 or newer) — capture a full boot trace as evidence
- [ ] **Coordinate on `nouveau@`/`dri-devel@`/Zulip so you do not duplicate in-flight work, then submit the pieces that fit**

## Month 9 Project B: "GSPAtlas — Generated Documentation for Nova's Boot Path"
**What:** Documentation that cannot go stale: a tool that reads the Nova source and generates an accurate, diagram-rich explanation of the GSP boot sequence, the register touchpoints, the firmware images involved, and the RPC protocol — plus the hand-written prose that makes it comprehensible.
**Novelty:** Nova's TODO list explicitly wants documentation, and documentation is the highest-acceptance-probability first contribution to any subsystem. The novelty is *generated* documentation: diagrams and sequence charts derived from the code, so they stay correct as the driver changes. This is the contribution that gets your name in `Documentation/gpu/nova/`.
**Skills used:** Nova source reading (Month 9), DRM/GPU model (Month 8), doc tooling + Sphinx/kernel-doc (Month 9), code analysis (Months 1-2), everything prior
**Deliverables:**
- [ ] Source analysis pass: extract the boot state machine, register accesses, and RPC message types from the code
- [ ] Generated sequence diagrams: PCI probe → BAR0 map → chip ID → VBIOS parse → Falcon boot → GSP handoff → RPC ready
- [ ] A register touchpoint map: which registers are read/written at which boot stage, and why
- [ ] Firmware image inventory: which blobs, which formats, which stages consume them
- [ ] Hand-written prose that explains the *why*, not just the *what* — written for someone in Week 1
- [ ] Formatted as kernel-doc/Sphinx `.rst` so it can drop straight into `Documentation/gpu/nova/`
- [ ] Verified against real hardware boot logs so no diagram lies
- [ ] **Submit as a documentation patch series. Documentation patches get merged. This is your realistic first Nova commit.**

---

## Month 10 Project A: "SafeAbstract — Ship a New Kernel Rust Abstraction Upstream"
**What:** Find a C subsystem with no Rust abstraction yet, design one, implement it, prove it with a sample driver and KUnit tests, write the soundness argument, and send the RFC series.
**Novelty:** This is not a project in the portfolio sense — it is *the* real work of Rust-for-Linux. Candidates as of now: hwmon, IIO, watchdog, LED, RTC, thermal, input, sysfs attribute groups (RFC in flight — check first), USB pieces (RFC in flight), pinctrl, mailbox, or whatever gap you found in Month 5 while writing SensorRS. The novelty is that after this month, an abstraction exists that did not exist before, and other people's drivers will use it.
**Skills used:** abstraction design + soundness reasoning (Month 10), `unsafe` contracts (Month 2), the target C subsystem read in full (Month 10), KUnit (Month 3), upstream workflow (Months 5, 11), and the driver experience of Months 4-9
**Deliverables:**
- [ ] Survey: confirm no abstraction exists and no series is in flight (search `lore.kernel.org`, ask on Zulip)
- [ ] Read the C subsystem *completely*: every function you will wrap, every lifetime rule, every locking requirement
- [ ] Design document: the Rust API, the ownership model, what invariants the types encode, what remains the caller's responsibility
- [ ] Implementation in `rust/kernel/<subsystem>.rs` following in-tree conventions exactly
- [ ] A `// SAFETY:` comment for every `unsafe` block that would survive a hostile review
- [ ] A sample driver in `samples/rust/` using only the safe API — ideally with zero `unsafe`
- [ ] KUnit tests for the abstraction
- [ ] Written soundness argument: why the API cannot be misused into UB, and what you deliberately left out
- [ ] **Send as an RFC series. Iterate through vN. Merged or not, this is the month that makes you a Rust-for-Linux contributor.**

## Month 10 Project B: "KFuzzRS — Syzkaller Harness for Rust Drivers"
**What:** A complete fuzzing playbook and harness for Rust kernel drivers: syzkaller descriptions for your drivers' ioctl and file interfaces, sanitizer-enabled build configurations, crash triage automation, and a report on the bug classes found.
**Novelty:** Syzkaller is the kernel's most productive bug finder, and there is almost no material on pointing it at Rust drivers. Yours is the missing bridge: how to write syzlang for a Rust driver's uAPI, how to build Rust kernel code under KASAN/KCSAN/UBSAN, and what the results actually look like. The report — "we fuzzed N Rust drivers for M CPU-hours and here is what we found" — is a talk waiting to happen.
**Skills used:** fuzzing + sanitizers (Month 10), syzkaller (Month 10), uAPI/ioctl design (Months 3-4), all your own drivers as targets (Months 4-8), crash decoding from OopsLens (Month 3)
**Deliverables:**
- [ ] Syzlang descriptions for VirtToy, KModKit's ioctl module, BlockForge's configfs interface, and TarFS-RS's mount path
- [ ] Reproducible sanitizer build configs (KASAN, KCSAN, UBSAN, KMSAN where supported) via KernelForge profiles
- [ ] A `syz-manager` setup that runs against your QEMU images unattended
- [ ] Automated crash triage: dedupe, minimize, and decode via OopsLens
- [ ] A results report: CPU-hours, unique crashes, bug classes, and which were Rust-logic bugs vs abstraction-soundness bugs vs C-side bugs
- [ ] Fix everything you find in your own code; report anything you find in in-tree code properly
- [ ] **Publish the playbook — "how to fuzz a Rust kernel driver" does not exist yet and should**

---

## Month 11 Project A: "PortToRust — Port a Real C Driver to Rust, Upstream-Quality"
**What:** Pick a small, real, in-tree C driver and port it to Rust with genuine feature parity — identical sysfs ABI, identical behavior, identical module parameters — then benchmark both, analyze both, and submit the series.
**Novelty:** Ports get proposed often and executed rigorously almost never. The novelty is the *rigor*: a parity test suite proving byte-identical userspace behavior, a benchmark showing no regression, an `unsafe`/LOC/error-path comparison, and an honest account of what got harder in Rust as well as what got safer.
**Skills used:** everything. C reading fluency, the target subsystem's abstractions, driver lifecycle, error paths, sysfs ABI, PM, testing, and the upstream workflow
**Deliverables:**
- [ ] Candidate selection with justification: small, self-contained, testable, non-controversial, hardware you can access (or QEMU-emulable)
- [ ] Read and annotate the entire C driver first — a written walkthrough of what every function does
- [ ] Rust port with full feature parity, including the ugly corners (quirks, workarounds, legacy module params)
- [ ] A parity test suite: same sysfs paths, same values, same error codes, same `dmesg` semantics
- [ ] Benchmark: throughput/latency/CPU where meaningful, showing no regression
- [ ] Analysis: LOC, `unsafe` count, error-path count, and the three bugs the borrow checker would have prevented (find real historical fixes in `git log` for the C driver to prove the point)
- [ ] Honest negatives: what was harder, what abstraction was missing, what you had to add
- [ ] **Submit the series. Expect strong opinions. Handle them well — that is the skill this month teaches.**

## Month 11 Project B: "PatchPilot — The Kernel Contribution Workflow, Automated"
**What:** A Rust CLI that makes the mailing-list workflow feel like a modern tool: pre-flight checks, cover-letter scaffolding, recipient resolution, series versioning, `b4` integration, lore thread tracking, and a review-response checklist.
**Novelty:** `b4` is excellent and `checkpatch` is essential, but the end-to-end path from "commits on a branch" to "well-formed vN series with the right people on Cc and no rookie mistakes" is still tribal knowledge held together by shell aliases. PatchPilot encodes that knowledge — and encodes it with Rust-specific checks nobody else runs (`rustfmt`, `clippy`, missing `SAFETY` comments via SafetyLint, `rustdoc` build, KUnit pass).
**Skills used:** upstream process mastery (Month 11), git plumbing (Month 11), Rust CLI (Month 1), SafetyLint reuse (Month 2), KernelForge reuse (Month 1)
**Deliverables:**
- [ ] `pilot check` — runs `checkpatch.pl`, `rustfmt --check`, `clippy`, `rustdoc`, SafetyLint, KUnit, and a build+boot test; refuses to proceed on failure
- [ ] `pilot recipients` — `get_maintainer.pl` plus list inference, with a warning if a required list is missing
- [ ] `pilot cover` — generates a cover letter skeleton from the branch: what/why/testing/changelog sections prefilled
- [ ] `pilot send` — wraps `b4`/`git send-email` with a dry-run diff of exactly what will go out to whom
- [ ] `pilot track` — polls `lore.kernel.org` for replies to your series and summarizes outstanding review comments
- [ ] `pilot v2` — builds the next version with an auto-generated changelog from what you actually changed
- [ ] A response checklist: every review comment must be either addressed in code or answered in prose — the tool will not let you drop one
- [ ] **Publish; use it for every subsequent submission in this roadmap**

---

## Month 12 Project A: "KUnitRS — Test Coverage for the kernel Crate"
**What:** Pick modules in `rust/kernel/` with thin test coverage, write comprehensive KUnit tests for them, and upstream the tests.
**Novelty:** Tests are the single most welcome contribution to any subsystem and the lowest-friction way to become a trusted regular. Beyond the tests themselves, the deliverable is a **coverage map of the kernel Rust abstraction layer** — which abstractions are tested, which are not, and where the risk concentrates. Nobody has published that map.
**Skills used:** KUnit in Rust (Month 12), the `kernel` crate in depth (Months 3-10), soundness reasoning (Month 10), multi-arch awareness (Month 12), upstream workflow (Month 11)
**Deliverables:**
- [ ] Coverage survey of `rust/kernel/`: modules with tests, modules without, doctests vs KUnit
- [ ] Pick 3-5 under-tested modules and write real tests: happy path, error path, edge cases, allocation failure
- [ ] Test allocation failure explicitly — fallible allocation is a kernel Rust invariant and is easy to get wrong
- [ ] Verify tests pass on multiple architectures (x86_64, arm64, riscv64 at minimum) via BootMatrix
- [ ] Publish the coverage map as a report
- [ ] **Submit the tests upstream, one module per series. Tests get merged.**

## Month 12 Project B: "BootMatrix — Multi-Arch Rust Kernel CI in QEMU"
**What:** A personal KernelCI: builds a Rust-enabled kernel for x86_64, arm64, riscv64, and s390x, boots each under QEMU, runs your KUnit tests and kselftests, and publishes a status matrix.
**Novelty:** Rust kernel code breaks on architectures you never test — different pointer widths, different alignment, different endianness on s390x, different atomics. Individual contributors almost never test beyond x86_64, which is exactly why arch-specific breakage keeps happening. BootMatrix makes multi-arch testing a single command, and its matrix output is exactly what a maintainer wants to see in a cover letter.
**Skills used:** cross-compilation + QEMU per-arch (Month 12), KUnit + kselftest (Month 12), CI design (Month 12), KernelForge foundations (Month 1), OopsLens for triage (Month 3)
**Deliverables:**
- [ ] Cross toolchains for 4+ architectures, with a `doctor` command that verifies each
- [ ] Per-arch Kconfig profiles that actually enable Rust and your test targets
- [ ] Parallel build + boot + test, with per-arch logs preserved
- [ ] Failure triage: automatically decode any oops via OopsLens and attach it to the matrix cell
- [ ] Sanitizer variants: at least one arch each with KASAN and KCSAN enabled
- [ ] GitHub Actions (or local) runner config so it runs on every push
- [ ] Markdown matrix output suitable for pasting into a patch cover letter
- [ ] **Publish; use its output as the "Testing:" section of every series you send from now on**

---

## Month 13 Project A: "ProdDriver — Take One Driver to Production and Merge It"
**What:** Choose your strongest driver from Months 4-9, and take it all the way: complete error paths, full power management, documented ABI, device tree bindings, `MAINTAINERS` entry, stable-worthy fixes, and a merged series.
**Novelty:** The gap between "works in QEMU" and "merged in mainline" is where most hobby drivers die. The novelty here is *finishing* — the unglamorous 80%: every allocation failure handled, every unbind path leak-free, every sysfs file documented in `Documentation/ABI/`, every DT property in a YAML binding, suspend/resume actually tested, and a maintainer's review satisfied.
**Skills used:** everything from Months 1-12, plus ABI stability discipline (Month 13), PM (Month 5), documentation (Month 9), review handling (Month 11)
**Deliverables:**
- [ ] Error-path audit: every `?` return leaves the device in a consistent state; verified by fault injection on every allocation
- [ ] Unbind/rebind stress: 1000 cycles with no leak (verified with `kmemleak`) and no UAF (verified with KASAN)
- [ ] Full PM: runtime PM, system suspend/resume, and a documented power state machine — tested, not assumed
- [ ] `Documentation/ABI/` entries for every sysfs file, with stability class declared
- [ ] Device tree binding YAML that passes `dt_binding_check`
- [ ] `MAINTAINERS` entry with you as the maintainer or reviewer
- [ ] Multi-arch clean via BootMatrix; sanitizer-clean; `checkpatch` clean
- [ ] **Merged. This is the month you become a driver author, not a driver hobbyist.**

## Month 13 Project B: "AbiGuard — uAPI and sysfs ABI Break Detector"
**What:** A tool that detects userspace ABI breakage: parse ioctl definitions, struct layouts, sysfs attribute sets, and debugfs interfaces from a kernel tree, snapshot them, and diff two versions to flag anything that would break existing userspace.
**Novelty:** "We do not break userspace" is the kernel's first law, and enforcement is entirely human. Tools exist for ELF library ABI; nothing does this for kernel uAPI at the driver level. AbiGuard gives a driver author a pre-submission check: *did I just break someone?* For Rust drivers specifically, it catches the classic trap of a struct layout changing because a type changed size on another architecture.
**Skills used:** uAPI/ioctl design (Months 3-4), struct layout and `repr(C)` reasoning (Month 2), multi-arch awareness (Month 12), tooling (Months 1-11)
**Deliverables:**
- [ ] Extract ioctl numbers, direction, and argument struct layouts from C headers and Rust `ioctl!` usage
- [ ] Compute struct layout (size, offsets, padding) per architecture — this is where the real bugs hide
- [ ] Snapshot sysfs/debugfs attribute trees from a booted kernel
- [ ] Diff two snapshots: classify each change as compatible, ambiguous, or breaking
- [ ] Run it across recent kernel releases and validate it finds known intentional and accidental changes
- [ ] CI mode: fail a build if the ABI changed without an explicit acknowledgment file
- [ ] **Publish; run it on your own drivers and on Nova's evolving uAPI**

---

## Month 14 Project A: "VirtioRS — A Rust virtio Driver End-to-End"
**What:** A virtio device driver written in Rust — virtqueue handling, descriptor rings, feature negotiation, notification/interrupt paths — talking to a QEMU or vhost-user backend you also control.
**Novelty:** virtio is the interface every cloud VM depends on, the specification is public and excellent, and it is a perfect Rust target because the whole driver is about *correctly interpreting shared memory written by an untrusted peer* — exactly where C drivers get exploited. Combine it with your `LINUX/kvm-virtualization` reading, and you can build both sides of the interface, which almost nobody does.
**Skills used:** virtio + virtqueues (Month 14), DMA + memory barriers (Months 5-6), shared-memory validation and `unsafe` discipline (Month 2), PCI/MMIO transport (Month 4), KVM/QEMU knowledge (Month 14 + your KVM book), all prior
**Deliverables:**
- [ ] A virtio device of your choosing (a simple custom device type, or a real one like virtio-rng/virtio-serial reimplemented)
- [ ] Feature negotiation, virtqueue setup, split-ring descriptor handling, used-ring processing
- [ ] Correct memory barriers for the guest/host shared ring — and a written explanation of each one
- [ ] Hostile-backend hardening: validate every field the host controls, and a test backend that lies deliberately
- [ ] Both sides: your driver plus a QEMU device model or a vhost-user backend
- [ ] Benchmark throughput/latency against the equivalent C driver
- [ ] **Publish with the hostile-backend test suite — that adversarial framing is the novel part**

## Month 14 Project B: "MemLab — mmap, Folios, Shrinkers and Memory Pressure in Rust"
**What:** A deep exploration of kernel memory management from a Rust driver: implement `mmap` correctly, manage pages/folios, register a shrinker that responds to memory pressure, and measure the whole thing under stress.
**Novelty:** `mmap` from a driver and shrinker registration are two of the hardest, least-documented, most footgun-laden things a driver can do, and there is essentially no Rust material on either. Getting both right — with fault handlers, correct refcounting, and correct behavior under OOM — is a genuine demonstration of advanced capability, and the write-up would be the reference for the next person.
**Skills used:** page/folio management, VMA and fault handling, shrinkers (Month 14), DMA + coherency (Month 5), lifetime and pinning (Month 2), concurrency under pressure (Month 6), all prior
**Deliverables:**
- [ ] A driver exposing a memory region via `mmap` with a correct fault handler and correct VMA lifecycle
- [ ] Page/folio refcounting done right — verified by unmapping under load without leaking or double-freeing
- [ ] Huge page support where applicable, with a measured performance difference
- [ ] A registered shrinker that frees cached objects under pressure, verified by driving the system into reclaim
- [ ] OOM behavior: prove the driver degrades gracefully instead of deadlocking, using fault injection on allocation
- [ ] Measurement: page fault cost, reclaim latency, memory returned under pressure
- [ ] Written guide: "mmap and shrinkers from a Rust kernel driver" with every gotcha you hit
- [ ] **Publish the guide — it will be the only one**

---

## Month 15 Project A: "NovaFeature — A Substantial Nova Contribution" ⭐
**What:** Move from tooling and documentation to a real Nova code contribution, coordinated with the maintainers: a HAL addition, chip enablement, a register/VBIOS subsystem piece, an engine bring-up step, or whatever the TODO list and the maintainers say is genuinely needed and unclaimed.
**Novelty:** By Month 15 you have the DRM knowledge (Month 8), the Nova knowledge (Month 9), the abstraction-design skill (Month 10), the upstream fluency (Months 11-13), and existing credibility from merged documentation and tooling. This is the month that combination cashes out into a contribution that matters to a driver NVIDIA is actively investing in.
**Skills used:** all of it — GPU/DRM, Nova internals, PCI/MMIO, firmware, concurrency, abstraction design, upstream process, testing, and hardware access
**Deliverables:**
- [ ] Coordinate before coding: read the current TODO, check the list and Zulip, and confirm with a maintainer that your target is unclaimed and wanted
- [ ] Design note posted for feedback *before* you write 2000 lines
- [ ] Implementation matching Nova's coding guidelines exactly
- [ ] Tested on real hardware across at least two GPU generations if you can get them
- [ ] Documentation and tests alongside the code, not after
- [ ] **A merged Nova contribution, or a series in serious review. Either is a career-visible result.**

## Month 15 Project B: "KernelRustBook — The Course You Wished Existed"
**What:** An open, tested, hands-on book/course: *Linux Kernel Development in Rust*, built from the code you actually wrote across 15 months, with QEMU-based labs that anyone can run without hardware.
**Novelty:** The learning path you are following does not exist as a coherent resource — it is scattered across in-tree docs, LWN, Zulip threads, and conference talks. Yours would be the first end-to-end, lab-driven, *testable* curriculum, with every example booting in CI (via BootMatrix) so it never rots. This is simultaneously the highest-leverage community contribution you can make and the strongest possible portfolio piece.
**Skills used:** everything, plus technical writing, curriculum design, and the CI infrastructure from Month 12
**Deliverables:**
- [ ] mdBook or Sphinx site with 15+ chapters mapping to this roadmap's arc
- [ ] Every chapter has a runnable lab: one command to build, boot, and verify in QEMU
- [ ] Labs derived from your real projects: KModKit, VirtToy, DMAForge, BlockForge, TinyDRM
- [ ] Every code example compiled and boot-tested in CI on every commit — no rotting examples
- [ ] Exercises with solutions, and compile-fail examples that teach the borrow checker's kernel-specific lessons
- [ ] A chapter on the upstream process that ends with the reader sending a real (trivial) patch
- [ ] Honest chapters on the limits: what Rust does not fix, where the abstractions are thin, what is still C-only
- [ ] **Publish; announce on Zulip and kernelnewbies. This becomes the thing people know you for.**

---

## Month 16 Project A: "UpstreamRun — 10+ Merged Patches Across 3+ Subsystems"
**What:** A deliberate campaign of sustained upstream contribution: ten or more merged patches, spread across at least three subsystems, including at least one bug fix with a `Fixes:` tag and at least one stable backport.
**Novelty:** Not novelty — *consistency*. One merged driver makes you an author; a sustained contribution record makes you a known quantity whose patches get reviewed quickly and whose opinions carry weight. This month is about becoming a regular.
**Skills used:** all technical skills, plus review responsiveness, patience, and taste in choosing what to work on
**Deliverables:**
- [ ] 10+ merged patches, tracked in a table with subsystem, type, and link to the commit
- [ ] At least 3 different subsystems (e.g. `rust/kernel`, a driver subsystem, DRM, docs, tests)
- [ ] At least one real bug fix with a correct `Fixes:` tag and a `Cc: stable@` where warranted
- [ ] At least one patch found by your own tooling (SafetyLint, KFuzzRS, AbiGuard, BootMatrix)
- [ ] At least 5 `Reviewed-by:` or `Tested-by:` tags **given** to other people's patches
- [ ] A retrospective: which submissions went smoothly, which did not, and what you learned about each subsystem's culture
- [ ] **Publish the contribution log; this table is your résumé now**

## Month 16 Project B: "EcosystemContrib — Contribute Beyond the Kernel Tree"
**What:** Contribute to the tools the Rust-for-Linux ecosystem runs on: `pin-init`, `bindgen`, `rustc` (kernel-relevant issues), `clippy`, QEMU, `syzkaller`, `virtme-ng`, `b4`, or Mesa/NVK on the userspace GPU side.
**Novelty:** The kernel does not exist in isolation, and the tooling gaps you hit in Months 1-15 are contributions waiting to happen. Fixing the tool that annoyed you in Week 13 helps everyone who comes after, and contributing to `bindgen` or `pin-init` gives you standing in conversations the kernel depends on.
**Skills used:** everything, plus a different set of contribution cultures (GitHub PRs instead of mailing lists — a useful contrast)
**Deliverables:**
- [ ] Pick 2 ecosystem projects and land at least one meaningful contribution in each
- [ ] Prefer things that annoyed you personally — you already have the reproduction and the motivation
- [ ] For `pin-init` or `bindgen`: a fix or feature that directly benefits kernel Rust
- [ ] For QEMU: a device model improvement that makes hardware-free driver development better (your VirtToy device, upstreamed?)
- [ ] For `virtme-ng`/`b4`: workflow improvements you already prototyped in PatchPilot
- [ ] Write up how the cultures differ: mailing list vs GitHub, and what each does better
- [ ] **Publish; you are now a contributor on both sides of the toolchain boundary**

---

## Month 17-18 Project: "Magnum Opus — Your Signature Kernel Contribution" ⭐⭐
**When to build:** Months 17-18, Weeks 65-78.
**What:** One substantial, coherent piece of kernel work that only you could have produced, built from 16 months of compounding skill. Choose ONE and go deep.

**Option A — A complete Rust driver for real hardware, merged.**
Non-trivial hardware, in a subsystem that welcomes Rust, with full PM, DMA, interrupts, sysfs ABI, DT bindings, tests, documentation, multi-arch validation, and a `MAINTAINERS` entry. You maintain it afterward.

**Option B — A new subsystem abstraction layer plus two drivers using it.**
Pick a subsystem with no Rust story, build the abstraction, and prove it with two independent drivers. This is the highest-leverage contribution type in Rust-for-Linux: every future driver in that subsystem uses your work.

**Option C — A significant Nova subsystem feature.**
Engine enablement, memory management, a scheduler piece, or chip generation support — a TODO item rated Intermediate-to-Expert, done properly, on hardware, with the maintainers.

**Option D — A Rust filesystem or storage driver, merged.**
Take TarFS-RS or BlockForge from teaching artifact to mainline-quality, fuzz-hardened, `xfstests`-passing, and upstream it.

**Option E — The definitive Rust-for-Linux learning platform.**
KernelRustBook expanded into the canonical resource: complete curriculum, CI-verified labs, hardware-free from start to finish, adopted by other newcomers, cited in the community.

**Deliverables regardless of option:**
- [ ] A 2000+ word technical deep-dive with architecture diagrams
- [ ] Complete test coverage: KUnit, kselftest, fuzzing, multi-arch boot matrix
- [ ] Every `unsafe` block justified; a written soundness argument for anything new in `rust/kernel/`
- [ ] Merged upstream, or in advanced review with maintainer engagement
- [ ] A conference talk proposal submitted (Kangrejos, Linux Plumbers Rust MC, XDC, FOSDEM)
- [ ] A portfolio page linking every project from Months 1-18 with results
- [ ] An honest retrospective: what you would do differently, and what you want to own next

---

### Monthly Project Tracker (2 projects per month)

| Month | Project A | ✓ | Project B | ✓ |
|-------|-----------|---|-----------|---|
| 1 | KernelForge — One-Command Rust Kernel Lab | ⬜ | RustScope — Kernel Rust Adoption Tracker | ⬜ |
| 2 | SafetyLint — unsafe/SAFETY Auditor | ⬜ | PinDojo — Pin & pin-init Playground | ⬜ |
| 3 | KModKit — Rust Module Starter Suite | ⬜ | OopsLens — Crash & KASAN Decoder | ⬜ |
| 4 | VirtToy — Hardware-Free PCI Driver Lab | ⬜ | PCIScope — Safe-Rust PCI X-Ray | ⬜ |
| 5 | DMAForge — DMA & IOMMU Lab | ⬜ | SensorRS — Upstreamable I2C/SPI Driver | ⬜ |
| 6 | BlockForge — Fault-Injecting Block Driver ⭐ | ⬜ | LockProof — What Rust Buys Concurrency | ⬜ |
| 7 | TarFS-RS — Fuzz-Hardened Rust Filesystem | ⬜ | TraceRust — Tracing for Rust Drivers | ⬜ |
| 8 | TinyDRM — A Real Rust DRM Driver | ⬜ | FenceScope — GPU Fence/Sched Visualizer | ⬜ |
| 9 | NovaScope — Nova Register & RPC Toolkit ⭐ | ⬜ | GSPAtlas — Generated Nova Documentation | ⬜ |
| 10 | SafeAbstract — New Abstraction Upstream | ⬜ | KFuzzRS — Syzkaller for Rust Drivers | ⬜ |
| 11 | PortToRust — C Driver Port, Upstream-Quality | ⬜ | PatchPilot — Contribution Workflow CLI | ⬜ |
| 12 | KUnitRS — Tests for the kernel Crate | ⬜ | BootMatrix — Multi-Arch Rust Kernel CI | ⬜ |
| 13 | ProdDriver — Production Quality & Merged | ⬜ | AbiGuard — uAPI/sysfs Break Detector | ⬜ |
| 14 | VirtioRS — Rust virtio Driver End-to-End | ⬜ | MemLab — mmap, Folios & Shrinkers | ⬜ |
| 15 | NovaFeature — Substantial Nova Contribution ⭐ | ⬜ | KernelRustBook — The Course & Labs | ⬜ |
| 16 | UpstreamRun — 10+ Merged Patches | ⬜ | EcosystemContrib — Beyond the Kernel Tree | ⬜ |
| 17-18 | Magnum Opus — Signature Contribution ⭐⭐ | ⬜ | *(portfolio, talk, maintainership)* | ⬜ |

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════════════
# MONTH-BY-MONTH FOCUS & CAPABILITIES
# "After this month, I can..."
# ═══════════════════════════════════════════════════════════

---

### Month 1 — Rust Core + Kernel Build, Boot, Source Map
**Focus:** Ownership, borrowing, moves; structs/enums/traits/generics; `Option`/`Result`/`?`; iterators and closures; lifetimes; smart pointers (`Box`, `Rc`, `RefCell`) and why the kernel replaces them. In parallel: kernel source tree layout, Kconfig/Kbuild, `make menuconfig`, building and booting a kernel, QEMU/virtme-ng iteration loop, the device/driver model, and a first C kernel module so you know what Rust is replacing.
**Projects:** KernelForge + RustScope

**After this month, you can:**
- [ ] Build and boot a Rust-enabled kernel from a clean tree, reproducibly, and explain every step
- [ ] Get `make LLVM=1 rustavailable` to say yes and diagnose it when it says no
- [ ] Navigate the kernel source tree from memory: where drivers, subsystems, `rust/`, `samples/`, `Documentation/`, and `MAINTAINERS` live
- [ ] Read and write Kconfig entries and Kbuild `Makefile` fragments
- [ ] Write idiomatic userspace Rust: ownership, borrowing, traits, generics, iterators, error propagation
- [ ] Explain why `Rc<RefCell<T>>` does not appear in kernel Rust and what replaces it
- [ ] Load and unload a C kernel module and read its `dmesg` output
- [ ] Explain the device/driver model: buses, `struct device`, `struct driver`, `probe()`/`remove()`
- [ ] Iterate on a kernel change in under 60 seconds using virtme-ng

---

### Month 2 — Unsafe Rust, Pin, FFI, Concurrency Theory
**Focus:** `unsafe` and what it actually permits; raw pointers, aliasing, undefined behavior; the Rustonomicon; `MaybeUninit` and initialization discipline; `Send`/`Sync` and auto-trait reasoning; atomics and memory ordering (`Relaxed` → `SeqCst`) via *Rust Atomics and Locks*; `Pin`, `Unpin`, `PhantomPinned`, variance, `PhantomData`; pin projection and `pin-init`; `no_std`; `repr(C)` and the C ABI; `extern "C"`; bindgen; how the kernel generates its bindings.
**Projects:** SafetyLint + PinDojo

**After this month, you can:**
- [ ] State precisely what `unsafe` does and does not turn off, and enumerate the forms of undefined behavior you must avoid
- [ ] Write a `// SAFETY:` comment that a hostile reviewer would accept
- [ ] Reason about aliasing rules and explain why `&mut` aliasing is UB even without a data race
- [ ] Use `MaybeUninit` correctly and explain why reading uninitialized memory is UB, not just unlucky
- [ ] Explain `Send` and `Sync` in kernel terms, and why `unsafe impl Send` requires an argument, not a hope
- [ ] Choose the right atomic ordering and explain the guarantee it gives — and why `SeqCst` everywhere is a smell
- [ ] Explain pinning from first principles: what breaks when a self-referential object moves, and how `Pin` prevents it
- [ ] Read and write `#[pin_data]` / `pin_init!` code and explain what the macro expands to
- [ ] Cross the FFI boundary safely: `repr(C)`, `extern "C"`, null and validity contracts, ownership transfer
- [ ] Explain how `rust/bindings/` is generated and why leaf drivers must not use it directly

---

### Month 3 — The kernel Crate + Your First Rust Modules + Debugging
**Focus:** The `kernel` crate: prelude, `module!` macro, `KBox`/`KVec`/`KVBox` and fallible allocation, `Error`/`Result` and kernel error codes, `pr_info!` family, `CStr`/`CString`, `Arc`/`ARef`. Misc devices and file operations; `UserSlice` and copying to/from userspace; ioctl definition and design. Kernel sync primitives in Rust: `SpinLock`, `Mutex`, `CondVar`, `Lock`/`Guard`; workqueues, timers, `Delta`/`Instant`. Debugging: `dmesg`, oops anatomy, `panic` in kernel Rust, KASAN, `kmemleak`, ftrace, kgdb, KUnit, `#[test]` vs kernel tests, virtme-ng workflows.
**Projects:** KModKit + OopsLens

**After this month, you can:**
- [ ] Write a Rust kernel module from a blank file: `module!`, init, teardown, module parameters
- [ ] Handle allocation failure correctly everywhere — no `unwrap()`, no `expect()`, no panic paths in a driver
- [ ] Map kernel error codes to Rust `Error` values and propagate them with `?` through a driver
- [ ] Implement a misc device with open/read/write/release and copy data to and from userspace safely
- [ ] Design a versioned ioctl interface and write the userspace client for it
- [ ] Use `SpinLock`, `Mutex`, `CondVar`, and `Arc` correctly, and explain when each is legal in kernel context
- [ ] Defer work with workqueues and timers, and shut them down without racing teardown
- [ ] Read an oops, decode a stack trace, and interpret a KASAN report
- [ ] Write KUnit tests for Rust kernel code and run them in QEMU
- [ ] Debug a module that panics, leaks, or hangs — and know which tool to reach for first

---

### Month 4 — Char/Misc Devices, Platform Drivers, PCI, Interrupts
**Focus:** Character device deep dive and `file_operations` semantics. Platform drivers, device tree / OF matching, `devres` and resource lifetime. PCI in Rust: config space, BARs, `Devres<Bar0>`, `Revocable`, MMIO accessors, capability parsing, MSI/MSI-X. Interrupts: registering handlers, `IrqRequest`, threaded IRQs, shared interrupts, top-half/bottom-half split, interrupt context restrictions. Workqueues, tasklets (and why not to use them), timers and hrtimers. Hotplug, unbind, and the lifetime bugs they expose.
**Projects:** VirtToy + PCIScope

**After this month, you can:**
- [ ] Write a PCI driver in Rust that probes, maps BARs, reads/writes registers, and tears down cleanly
- [ ] Explain what `Devres` and `Revocable` protect against, and why a raw BAR pointer would be unsound
- [ ] Parse PCI config space and capabilities, and set up MSI-X vectors
- [ ] Register an interrupt handler, decide what belongs in the handler vs deferred work, and justify the split
- [ ] Explain what you may not do in interrupt context and what happens if you do it anyway
- [ ] Survive hot-unplug: prove your driver has no use-after-free when the device disappears mid-operation
- [ ] Write a platform driver that binds via device tree, with correct property parsing
- [ ] Build a QEMU virtual device and drive it from your own kernel driver — no hardware required
- [ ] Write a leaf driver with **zero** `unsafe` blocks and explain why that is possible

---

### Month 5 — DMA, Buses, sysfs/debugfs, Power Management
**Focus:** Kernel memory: page allocation, GFP flags, allocation contexts, `kmalloc` vs `vmalloc` equivalents in Rust. DMA: coherent vs streaming mappings, `CoherentAllocation`, DMA masks, direction, cache coherency, scatter-gather lists, IOMMU. Buses: I2C, SPI, GPIO, `clk`, `regulator`, PWM abstractions. Userspace interfaces: sysfs attributes, debugfs, `seq_file`, configfs, module parameters, and ABI stability rules. Power management: runtime PM, system suspend/resume, OPP, cpufreq. Subsystem integration: hwmon and IIO.
**Projects:** DMAForge + SensorRS

**After this month, you can:**
- [ ] Choose the right allocation strategy and GFP flags for a given context, and explain the consequences of getting it wrong
- [ ] Set up coherent and streaming DMA correctly, including masks, direction, and synchronization
- [ ] Build and consume scatter-gather lists, and explain how the IOMMU changes the picture
- [ ] Name five classic DMA bugs and say which ones Rust's types prevent and which ones remain yours
- [ ] Write an I2C or SPI device driver in Rust that binds from device tree and reads real hardware
- [ ] Integrate a driver with hwmon or IIO so standard userspace tools work with it unmodified
- [ ] Expose driver state through sysfs and debugfs, and document the ABI properly
- [ ] Implement runtime PM and system suspend/resume, and verify they actually run
- [ ] Write a device tree binding YAML that passes `dt_binding_check`
- [ ] Prepare a real driver series for submission, `checkpatch`-clean, with the right recipients

---

### Month 6 — Real Kernel Concurrency + Data Structures + Block + Net ⭐ (6-MONTH MILESTONE)
**Focus:** Concurrency for real: RCU (read-side, grace periods, `synchronize_rcu`, when it beats locking), the Linux Kernel Memory Model and `tools/memory-model`, memory barriers, `lockdep`, KCSAN, preemption and interrupt contexts, per-CPU data, reference counting patterns. Kernel data structures in Rust: intrusive `list`, `rbtree`, `xarray`, `maple_tree`, `bitmap`, `id_pool`. Block layer: blk-mq, request queues, `gendisk`, bio/request lifecycle, flush/FUA semantics, `rnull` as reference. Networking: netdevice basics, `sk_buff`, PHY drivers (the ASIX driver as the canonical Rust example).
**Projects:** BlockForge ⭐ + LockProof

**After this month, you can:**
- [ ] Explain RCU precisely: what a read-side critical section guarantees, what a grace period is, and why it is not just a fancy rwlock
- [ ] Reason with the Linux Kernel Memory Model and explain why kernel ordering rules differ from Rust's `std` atomics model
- [ ] Design a locking scheme for a driver, write it down, and defend it
- [ ] Interpret lockdep and KCSAN reports and fix what they find
- [ ] Say honestly what Rust prevents, what tooling catches, and what is still purely your discipline
- [ ] Use intrusive kernel data structures from Rust and explain why they are intrusive
- [ ] Write a multi-queue block driver that handles requests correctly and honors flush/FUA
- [ ] Read the block layer's request lifecycle in C and map it onto the Rust abstractions
- [ ] Understand `sk_buff` lifetime and write or read a Rust network PHY driver
- [ ] **Ship a driver you would be comfortable defending in a mailing-list review**

---

### Month 7 — Filesystems, Binder as a Case Study, Tracing & Observability
**Focus:** VFS: superblocks, inodes, dentries, the dcache, `file_operations` vs `inode_operations`, mount and unmount lifecycle, page cache and `address_space_operations`, mmap of file pages, read-only filesystem design. Rust `fs` abstractions and the tarfs/PuzzleFS efforts. Binder as the production Rust driver case study: read it end to end and study its review history. Tracing and observability: tracepoints, ftrace, function graph tracing, `perf`, dynamic tracing, eBPF interaction, static keys/jump labels, `seq_file`-based state exposure.
**Projects:** TarFS-RS + TraceRust

**After this month, you can:**
- [ ] Explain the VFS object model and the lifetime rules for superblocks, inodes, and dentries
- [ ] Implement a read-only filesystem: mount, lookup, readdir, read, and page cache integration
- [ ] Explain why filesystems are a hostile-input problem and how that shapes the Rust argument
- [ ] Read the Rust Binder driver and explain its architecture, its `unsafe` usage, and its concurrency design
- [ ] Mine a driver's mailing-list review history for design lessons (Binder's review is a masterclass)
- [ ] Add tracepoints to a Rust driver and observe them with `trace-cmd`, `perf`, and `bpftrace`
- [ ] Instrument a driver so its state machine is visible while running, not reconstructed after a crash
- [ ] Use ftrace and function graph tracing to answer "what actually happened" during a failure
- [ ] Fuzz a filesystem with malformed images and triage the crashes

---

### Month 8 — DRM/GPU Subsystem: KMS, GEM, Fences, Scheduling
**Focus:** DRM framework: device registration, driver features, uAPI and the render-node vs primary-node split. KMS: CRTCs, encoders, connectors, planes, atomic modesetting (check/commit), vblank. GEM: buffer objects, handles, mmap, dumb buffers, refcounting, `drm_gem_shmem`. Command submission model. `dma-fence`: signaling, dependency chains, deadlock hazards, `dma_resv`. The DRM scheduler. GPUVM / VM_BIND / EXEC — the modern memory model Vulkan requires. The kernel↔Mesa split and where NVK/Zink live. DRM Rust abstractions as they currently stand.
**Projects:** TinyDRM + FenceScope

**After this month, you can:**
- [ ] Explain the full DRM/KMS object model and write a driver that modesets
- [ ] Implement atomic modesetting check and commit paths correctly
- [ ] Manage GEM buffer objects with correct refcounting and mmap support
- [ ] Explain `dma-fence` semantics, the signaling rules, and how fence deadlocks happen
- [ ] Explain what the DRM scheduler does and why GPU drivers need one
- [ ] Explain GPUVM / VM_BIND and why Vulkan's memory model forced it into existence
- [ ] Draw the kernel↔userspace GPU stack and say exactly where the uAPI boundary sits
- [ ] Read the DRM Rust abstractions and identify what is still missing
- [ ] Debug a GPU scheduling or fence problem with a trace rather than a guess

---

### Month 9 — Nova Internals: PCI, VBIOS, Falcon, GSP, RPC, DRM uAPI ⭐
**Focus:** `nova-core`: `probe()`, BAR0 mapping via `Devres<Bar0>`/`Revocable`, chip identification (`NV_PMC_BOOT_0`/`BOOT_42`), the register definition system in `regs.rs`, the VBIOS parser, Falcon microcontroller boot, firmware image formats, WPR2 and secure memory regions, GSP (GPU System Processor) boot sequence, GSP-RM RPC protocol, debugfs GSP log buffers (`LOGINIT`/`LOGINTR`/`LOGRM`), the HAL and chip-generation abstraction. `nova-drm`: the DRM driver skeleton, its IOCTLs, and its explicitly-unstable uAPI. The `drm-rust-next` development tree, Nova's coding guidelines, and the TODO list as your issue tracker.
**Projects:** NovaScope ⭐ + GSPAtlas

**After this month, you can:**
- [ ] Trace Nova from `probe()` to GSP-ready in the source and narrate every stage
- [ ] Explain what the GSP is, why NVIDIA's driver architecture centers on it, and what that means for an open driver
- [ ] Add and validate register definitions in Nova's conventions
- [ ] Decode GSP-RM log buffers and RPC traffic into something a human can read
- [ ] Explain Nova's HAL/chip-generation strategy and where per-chip differences live
- [ ] Build and run Nova from `drm-rust-next` on real hardware and debug a boot failure
- [ ] Read Nova's coding guidelines and match them without being told
- [ ] Pick a Beginner/Intermediate TODO item, coordinate on it publicly, and start it
- [ ] Explain honestly what Nova can and cannot do today, and what the path to rendering looks like

---

### Month 10 — Performance, Security, Fuzzing & Abstraction Design
**Focus:** Abstraction design: what makes a Rust API sound, encoding invariants in types, `PhantomData` and lifetime tricks, builder and typestate patterns, the "as-safe-as-possible" doctrine, how to write a safety contract, and how to defend soundness in review. Reading a C subsystem completely before wrapping it. Security: KASAN, KCSAN, UBSAN, KMSAN, `kmemleak`, hardening options, syzkaller/syzbot, the anatomy of real kernel CVEs, threat modeling a driver's uAPI. Fuzzing: syzlang, coverage-guided fuzzing, crash triage and minimization.
**Projects:** SafeAbstract + KFuzzRS

**After this month, you can:**
- [ ] Design a safe Rust abstraction over a C subsystem, from API sketch through soundness argument
- [ ] Encode a lifetime or state invariant in the type system so misuse fails to compile
- [ ] Write the safety contract for an `unsafe fn` such that a caller knows exactly what they must guarantee
- [ ] Explain unsoundness with an example, and recognize it in someone else's abstraction during review
- [ ] Build a kernel with each sanitizer and interpret what each one catches
- [ ] Write syzkaller descriptions for a driver's ioctl interface and run a fuzzing campaign
- [ ] Triage, minimize, and report a kernel crash properly
- [ ] Read a real kernel CVE and say whether Rust would have prevented it, honestly
- [ ] Threat-model your own driver's uAPI: what can a malicious userspace do?

---

### Month 11 — The Upstream Machine: Trees, Review, Porting
**Focus:** How Linux actually develops: maintainer trees, subsystem trees, `linux-next`, merge windows, `-rc` cycles, the `MAINTAINERS` file, `lore.kernel.org` and `b4`, patch series structure, cover letters, changelogs, `Fixes:` tags, `Reported-by:`/`Suggested-by:`/`Reviewed-by:`/`Tested-by:`, DCO and `Signed-off-by:`, stable/LTS rules and backporting, `git bisect` for regressions. Review as a skill: how to read a patch critically, how to give feedback that helps, how to receive feedback that stings. Porting C drivers to Rust with feature parity and evidence.
**Projects:** PortToRust + PatchPilot

**After this month, you can:**
- [ ] Explain the full lifecycle of a patch from your branch to Linus's tree
- [ ] Find the right tree, the right maintainer, and the right list for any change
- [ ] Structure a multi-patch series so each patch builds, boots, and reviews cleanly on its own
- [ ] Write a cover letter that a busy maintainer can act on in 60 seconds
- [ ] Use `b4` to fetch, apply, and track series — yours and other people's
- [ ] Write a correct `Fixes:` tag and decide whether a fix belongs in stable
- [ ] Bisect a regression and report it usefully
- [ ] Review someone else's Rust patch and leave a comment that improves it
- [ ] Take review criticism without ego and turn it into a better v2
- [ ] Port a C driver to Rust with proven parity and an honest performance and safety comparison

---

### Month 12 — Testing Infrastructure & Multi-Arch CI
**Focus:** KUnit in depth: test organization, assertions, fixtures, parameterized tests, testing allocation failure, testing error paths. `kselftest` for userspace-visible behavior. Doctests in kernel Rust. Cross-compilation for arm64, riscv64, s390x; per-arch QEMU recipes; endianness, alignment, and pointer-width portability traps. CI: KernelCI, LKFT, and building your own boot matrix. Coverage measurement. Fault injection frameworks. Test-driven abstraction development.
**Projects:** KUnitRS + BootMatrix

**After this month, you can:**
- [ ] Write thorough KUnit tests for kernel Rust code, including failure paths and allocation failure
- [ ] Write kselftests that validate uAPI behavior from userspace
- [ ] Cross-compile and boot a Rust-enabled kernel for at least four architectures
- [ ] Identify and fix portability bugs: alignment, pointer width, endianness, atomics availability
- [ ] Build a CI pipeline that boots and tests every commit automatically
- [ ] Measure test coverage of kernel Rust code and identify the gaps that matter
- [ ] Use fault injection to prove your error paths actually work
- [ ] Include a credible "Testing:" section in every patch series you send
- [ ] **Contribute tests upstream — the most reliably-accepted contribution there is**

---

### Month 13 — Production Driver Quality, ABI Stability, Stable/LTS
**Focus:** What separates a merged driver from a hobby driver: exhaustive error paths, allocation-failure survival, unbind/rebind correctness, `kmemleak`-clean teardown, complete power management, documented sysfs ABI (`Documentation/ABI/`), device tree binding schemas, `MAINTAINERS` ownership, deprecation and compatibility policy. The "we do not break userspace" rule in practice: uAPI design, struct layout stability across architectures, ioctl versioning, feature flags. Stable/LTS: what qualifies, how to backport, how distributions consume your work.
**Projects:** ProdDriver + AbiGuard

**After this month, you can:**
- [ ] Audit a driver's error paths exhaustively and prove them with fault injection
- [ ] Survive 1000 unbind/rebind cycles with no leaks and no use-after-free
- [ ] Implement and verify complete power management, including edge cases like suspend during I/O
- [ ] Document a sysfs ABI properly and declare its stability class
- [ ] Design a uAPI that can evolve without breaking existing userspace
- [ ] Reason about struct layout across architectures and avoid the classic padding trap
- [ ] Decide correctly whether a fix belongs in stable, and prepare the backport
- [ ] Take ownership of code in `MAINTAINERS` and act like a maintainer of it
- [ ] **Have a driver merged that other people's machines will run**

---

### Month 14 — Virtualization (virtio, VFIO, KVM) + Advanced Memory Management
**Focus:** virtio: the specification, virtqueues, split and packed rings, descriptor chains, feature negotiation, notification suppression, the memory barriers the shared ring requires, and validating everything a potentially-hostile host writes. VFIO and device passthrough; mediated devices; vDPA. KVM fundamentals from the host side (connecting to your `LINUX/kvm-virtualization` reading). Advanced memory management: pages and folios, VMAs and fault handlers, `mmap` from a driver, huge pages, shrinkers and reclaim, memory pressure and OOM behavior, `kmemleak` and allocation debugging.
**Projects:** VirtioRS + MemLab

**After this month, you can:**
- [ ] Implement a virtio driver: feature negotiation, virtqueue setup, descriptor handling, notifications
- [ ] Place and justify every memory barrier in a guest/host shared-ring protocol
- [ ] Harden a driver against a hostile device or host — validate every externally-controlled field
- [ ] Explain VFIO, device passthrough, and mediated devices, and when each is used
- [ ] Connect kernel-side KVM concepts to the QEMU/libvirt userspace you already know
- [ ] Implement `mmap` from a driver with a correct fault handler and VMA lifecycle
- [ ] Manage pages and folios with correct refcounting under concurrent unmapping
- [ ] Register a shrinker and prove it responds correctly to real memory pressure
- [ ] Make a driver degrade gracefully under OOM instead of deadlocking

---

### Month 15 — Major Contribution + Teaching and Authoring ⭐
**Focus:** Converting 14 months of skill into a contribution that matters: choosing a target with maintainer input, posting a design before writing code, executing at the quality bar of the subsystem, and shepherding it through review. In parallel: authoring — turning your own path into the resource that did not exist, with CI-verified labs so it cannot rot. Technical writing for kernel audiences: precision over enthusiasm, evidence over assertion.
**Projects:** NovaFeature ⭐ + KernelRustBook

**After this month, you can:**
- [ ] Choose a substantial contribution target with maintainer buy-in before writing code
- [ ] Post a design proposal and incorporate feedback before implementation
- [ ] Execute a multi-hundred-line contribution at a subsystem's quality bar
- [ ] Shepherd a series through multiple review rounds without losing momentum
- [ ] Write technical documentation that a newcomer can follow and an expert cannot fault
- [ ] Build a curriculum whose examples are verified by CI on every commit
- [ ] Explain kernel Rust to an audience — in writing, and out loud
- [ ] **Be someone whose name a maintainer recognizes positively**

---

### Month 16 — Sustained Open Source & Ecosystem Contributions
**Focus:** Consistency over heroics: a sustained contribution record across multiple subsystems, including bug fixes with `Fixes:` tags and stable backports. Becoming a reviewer whose `Reviewed-by:` carries weight. Contributing to the ecosystem the kernel depends on: `pin-init`, `bindgen`, `rustc`/`clippy` kernel-relevant issues, QEMU device models, syzkaller, `virtme-ng`, `b4`, and Mesa/NVK on the userspace GPU side. Understanding the cultural difference between mailing-list and GitHub contribution models.
**Projects:** UpstreamRun + EcosystemContrib

**After this month, you can:**
- [ ] Sustain a steady contribution cadence across multiple subsystems
- [ ] Find your own bugs with your own tooling and fix them upstream
- [ ] Give useful `Reviewed-by:`/`Tested-by:` tags that maintainers trust
- [ ] Contribute to the Rust toolchain and tooling that kernel Rust depends on
- [ ] Navigate both mailing-list and GitHub contribution cultures fluently
- [ ] Mentor someone else's first kernel patch
- [ ] **Be a known, trusted regular rather than a one-time contributor**

---

### Months 17-18 — Magnum Opus & Maintainership Path
**Focus:** One substantial, coherent contribution built from everything: a complete Rust driver, a new subsystem abstraction layer with drivers proving it, a major Nova feature, a merged filesystem or block driver, or the definitive Rust-for-Linux learning platform. Plus the career layer: portfolio, technical writing, a conference talk proposal, and the honest question of what you want to own long-term.
**Project:** Magnum Opus — Your Signature Kernel Contribution

**After these months, you can:**
- [ ] Take a substantial kernel contribution from idea through RFC, review, and merge
- [ ] Own code in `MAINTAINERS` and support it for other people
- [ ] Write a 2000+ word technical deep-dive with diagrams that other engineers cite
- [ ] Present kernel Rust work at a conference (Kangrejos, Linux Plumbers, XDC, FOSDEM)
- [ ] Design and defend an abstraction that future drivers will be built on
- [ ] **Point at mainline Linux and say "that part is mine"**
- [ ] **Be a credible candidate for maintainership of a Rust driver or abstraction**

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════
# PHASE 1: FOUNDATIONS (Weeks 0-12, Months 1-3)
# Rust Depth, Kernel Fundamentals, First Rust Modules
# ═══════════════════════════════════════════════

---

## Week 0 — Lab Setup: Build & Boot a Rust-Enabled Kernel (DO THIS IMMEDIATELY)

> This week has no theory. Its only purpose is to make every later week possible.
> **Do not move on until you have booted a kernel you compiled, with Rust enabled.**
> Full instructions live in `SETUP.md`; this is the checklist.

### Day 1 — Linux Development Environment ✅
- [x] Install WSL2 Ubuntu (or set up your dedicated Linux box) with plenty of disk — a kernel tree plus builds wants 40+ GB
- [x] Install build dependencies: `build-essential flex bison bc libssl-dev libelf-dev libncurses-dev dwarves cpio rsync zstd git ccache`
- [x] Install LLVM/Clang toolchain (the kernel's Rust support wants `LLVM=1`) and `libclang-dev`
- [x] Verify `/dev/kvm` exists (Windows 11 enables nested virtualization by default; you may need `sudo modprobe kvm_intel` and a `wsl.conf` boot command to persist it)
- [x] Configure `git` identity, and set up `ccache` so rebuilds are fast
- [x] **Journal:** record your CPU count, RAM, disk, and where your kernel tree lives

### Day 2 — Clone and Build Mainline ✅
- [x] `git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git` (shallow clone first if bandwidth is tight, then unshallow later — you will want full history)
- [x] Also add remotes you will need later: `linux-next`, and the Rust-for-Linux tree
- [x] `make defconfig` then `make -j$(nproc)` — time it, write the number down
- [x] Learn `make menuconfig` navigation and search (`/`)
- [x] Understand the top-level layout: `arch/`, `block/`, `drivers/`, `fs/`, `include/`, `kernel/`, `mm/`, `net/`, `rust/`, `samples/`, `scripts/`, `tools/`, `Documentation/`
- [x] **Journal:** build time, warnings encountered, disk used

### Day 3 — Fast Boot Loop (This Is The Most Important Day)
- [ ] Install QEMU (`qemu-system-x86`) and **`virtme-ng`**
- [ ] Boot your compiled kernel with `vng` and get a shell inside it
- [ ] Boot it the manual way too, with an explicit `qemu-system-x86_64 -kernel ... -append "console=ttyS0" -nographic` command, so you understand what `vng` automates
- [ ] Set up serial console capture to a file so you never lose an oops
- [ ] **Target: edit → build → boot → shell in under 60 seconds.** If it is slower, fix that now, not later
- [ ] **Journal:** your exact boot command lines, saved as scripts in `codes/Month_1/Week_1/Day_3/`

### Day 4 — Rust Toolchain for the Kernel
- [ ] Install `rustup`; then install the **exact** `rustc` version the tree wants, plus `rust-src`, `clippy`, `rustfmt`
- [ ] Install `bindgen-cli` at the version the tree wants
- [ ] `make LLVM=1 rustavailable` → **must print "Rust is available!"**. Iterate until it does
- [ ] Read `Documentation/rust/quick-start.rst` — it is the authoritative setup document
- [ ] Enable `CONFIG_RUST` in `menuconfig` (Kernel hacking → or search for `RUST`), plus `CONFIG_SAMPLES_RUST` and the sample modules
- [ ] Build a Rust-enabled kernel; boot it; load a `samples/rust` module; confirm in `dmesg`
- [ ] **Journal:** the exact toolchain versions that worked, because you will need them again

### Day 5 — Developer Ergonomics & Upstream Plumbing
- [ ] `make LLVM=1 rust-analyzer` → wire up your editor so you get completion in kernel Rust
- [ ] `make LLVM=1 rustdoc` → build and *browse* the kernel Rust API docs locally (also online at [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/))
- [ ] Configure **`git send-email`** with your SMTP and send yourself a test patch. This blocks every future contribution — do it now
- [ ] Install `b4`; learn `b4 mbox` and `b4 shazam` to fetch someone else's series from `lore.kernel.org`
- [ ] Run `scripts/checkpatch.pl` and `scripts/get_maintainer.pl` on a real file to see what they do
- [ ] Subscribe (or set up `lore` feeds) for: `rust-for-linux@vger.kernel.org`, `linux-kernel@vger.kernel.org` (digest or lore only — it is a firehose), `kernelnewbies@kernelnewbies.org`
- [ ] Join the **Rust-for-Linux Zulip**. Read, do not post yet

### 🔨 Saturday Project
- [ ] **Lab Bring-Up Report** — `_internal/SETUP_LOG.md` recording: toolchain versions, build times, your boot scripts, and every error you hit with its fix. It lives in `_internal/` because it records the hostname and local paths, so it is git-ignored by design
- [ ] Write the `codes/Month_1/Week_1/Day_5/check_setup.sh` script that verifies your whole lab in one command
- [ ] Deliberately break something (bad `.config`, wrong rustc version) and confirm your script catches it

### 📄 Sunday Reading
- [ ] `Documentation/rust/index.rst` — all of it, including `general-information.rst` and `coding-guidelines.rst`
- [ ] [rust-for-linux.com](https://rust-for-linux.com/) — the project overview and current status
- [ ] `Documentation/process/howto.rst` — how kernel development works, from the source

---

## Week 1 — Rust Ownership + The Kernel Source Tree

### Day 1 — Ownership, Moves, and Drop
- [ ] Ownership rules: one owner, moved on assignment, dropped at scope end
- [ ] Move vs copy vs clone; `Copy` types and why they exist
- [ ] `Drop`: deterministic destruction, drop order, why this matters enormously in a kernel (RAII replaces `goto err_unlock`)
- [ ] What is *not* in kernel Rust: no `std`, no unwinding, no infallible allocation
- [ ] **Code:** write a type whose `Drop` prints, and demonstrate drop order in nested scopes and on early return

### Day 2 — Borrowing, References, and the Borrow Checker
- [ ] Shared (`&T`) vs exclusive (`&mut T`) references; the aliasing rule
- [ ] Non-lexical lifetimes; why the compiler accepts things that look wrong
- [ ] Slices and how they avoid the C "pointer + length that disagree" bug class
- [ ] **Code:** deliberately write five borrow-checker errors, read each message carefully, then fix each. Save them with notes — this is how you learn to read `rustc`

### Day 3 — Kernel Source Tree Deep Tour
- [ ] Walk `drivers/` and identify what lives where; find three drivers for hardware you own
- [ ] Read `MAINTAINERS` structure: `M:`, `R:`, `L:`, `S:`, `F:`, `T:` — and look up who maintains `rust/`
- [ ] Locate the Rust code: `rust/kernel/`, `rust/bindings/`, `rust/helpers/`, `rust/macros/`, `samples/rust/`
- [ ] Locate the in-tree Rust drivers: `drivers/net/phy/` (ASIX), `drivers/block/rnull.rs`, `drivers/android/` (Binder), `drivers/gpu/nova-core/`, `drivers/gpu/drm/nova/`
- [ ] Learn to search the tree fast: `git grep -n`, `ripgrep`, `cscope`/`ctags` or `rust-analyzer` + clangd
- [ ] **Code:** run RustScope's precursor — count Rust files and lines per directory with a one-liner, and save the numbers

### Day 4 — Structs, Enums, and Pattern Matching
- [ ] `struct` forms, `impl` blocks, associated functions vs methods
- [ ] `enum` as a real sum type; `match` exhaustiveness; `if let`, `let else`, `while let`
- [ ] Modeling hardware state as an enum instead of an `int` with magic values
- [ ] `#[derive(...)]` and what each common derive actually generates
- [ ] **Code:** model a device's state machine (uninitialized → probing → ready → suspended → removed) as an enum, with transitions as methods that make illegal transitions impossible

### Day 5 — Kernel Build System Basics + Reading Real C
- [ ] `Kconfig` syntax: `config`, `bool`/`tristate`, `depends on`, `select`, `default`, `help`
- [ ] `Makefile` fragments: `obj-$(CONFIG_FOO) += foo.o`, multi-file modules, `ccflags-y`
- [ ] How a module gets built as `.ko` vs built-in, and what `tristate` really means
- [ ] **Read C:** pick the simplest real driver you can find (a misc device or a simple platform driver) and read it line by line. Write down every function you do not recognize and look it up
- [ ] **Code:** add a `CONFIG_` option and a stub file to your tree, build it as a module, and load it

### 🔨 Saturday Project
- [ ] **Register Map Parser (Rust CLI)** — parse a text file of `NAME = 0xADDR, bits [hi:lo] = FIELD` lines into typed structures, validate for overlaps and gaps, and pretty-print a register map
- [ ] Why this: it is real ownership/`Vec`/`String`/error-handling practice, **and** it is the seed of the Nova register tooling you will build in Month 9
- [ ] Handle malformed input with `Result` and clear error messages — no panics

### 📄 Sunday Reading
- [ ] The Rust Book, Ch. 4 (Ownership) — read it twice, properly
- [ ] `Documentation/process/submitting-patches.rst` — read it now even though you will not submit for weeks. It sets the standard everything else is measured against
- [ ] LWN: search the `Rust` topic index and read the two most recent Rust-in-kernel articles

---

## Week 2 — Rust Types & Traits + Kconfig/Kbuild

### Day 1 — Traits and Generics
- [ ] Traits as interfaces; default methods; trait bounds; `where` clauses
- [ ] Static dispatch (monomorphization) vs dynamic dispatch (`dyn Trait`) — and why the kernel cares about code size
- [ ] Associated types vs generic parameters; when each is right
- [ ] Blanket implementations and the orphan rule
- [ ] **Code:** define a `Register` trait with `read`/`write`, implement it for two mock backends, and write a generic function over it

### Day 2 — How the Kernel Uses Traits for vtables
- [ ] Read `rust/kernel/` for the `#[vtable]` pattern: how a Rust trait becomes a C `struct` of function pointers
- [ ] Trace one example end to end — e.g. how a driver's operations get registered with a C subsystem
- [ ] Understand why the kernel needs `#[vtable]` and cannot just use `dyn Trait`
- [ ] **Code:** write a userspace toy that mimics it — a trait, a static struct of function pointers, and a registration function

### Day 3 — Kconfig and Kbuild For Real
- [ ] Kconfig dependency semantics: `depends on` vs `select` vs `imply`, and how `select` causes pain
- [ ] Kconfig fragments and `scripts/kconfig/merge_config.sh` — the right way to manage configs
- [ ] `make localmodconfig`, `make olddefconfig`, `savedefconfig` and why you should never hand-edit `.config`
- [ ] `CONFIG_RUST` and its dependencies; which options gate which `rust/kernel` modules
- [ ] **Code:** build three named config profiles as fragments (minimal-rust, debug-everything, kasan) — this becomes KernelForge's `config` command

### Day 4 — Collections, Strings, and Error Handling
- [ ] `Vec`, `HashMap`, `BTreeMap`, `VecDeque` — and what the kernel provides instead of each
- [ ] `String` vs `&str` vs `CStr`/`CString`; UTF-8 vs kernel C strings
- [ ] `Option` and `Result` combinators; `?` and `From` conversions for errors
- [ ] Custom error types; `thiserror`-style patterns in userspace vs kernel `Error`
- [ ] **Code:** refactor the Week 1 register parser to use a custom error enum with `From` conversions, and no `unwrap()` anywhere

### Day 5 — Modules, Crates, and Reading `rust/kernel/`
- [ ] Rust module system: `mod`, `pub`, `use`, paths, visibility, re-exports
- [ ] Crates, `Cargo.toml`, features — and how the kernel deliberately does *not* use Cargo
- [ ] Read `rust/kernel/lib.rs`: the module list, the `#[cfg(CONFIG_...)]` gating, the `#![no_std]` attribute
- [ ] Read `rust/kernel/prelude.rs`: what every kernel Rust file gets for free
- [ ] **Code:** browse the local `rustdoc` output and write a one-line summary of 20 `kernel` crate modules in your journal

### 🔨 Saturday Project
- [ ] **KernelForge v0.1** — the `doctor` and `config` commands
  - [ ] `doctor`: parse what the tree demands (`rustavailable` output, `scripts/min-tool-version.sh`), compare with what is installed, print exact fix commands
  - [ ] `config`: apply a named Kconfig fragment profile to a tree via `merge_config.sh`
  - [ ] Structured errors, no panics, clear output

### 📄 Sunday Reading
- [ ] The Rust Book, Ch. 10 (Generics, Traits, Lifetimes) — traits sections
- [ ] `Documentation/kbuild/kconfig-language.rst` and `Documentation/kbuild/makefiles.rst` (skim, then reference)
- [ ] `Documentation/rust/coding-guidelines.rst` — internalize this; it governs every patch you will send

---

## Week 3 — Lifetimes, Errors, Iterators + The Device/Driver Model

### Day 1 — Lifetimes, Properly
- [ ] Lifetimes as compile-time-only annotations describing relationships, not durations
- [ ] Elision rules; when you must annotate; lifetime bounds on structs and impls
- [ ] `'static` and what it really means (and does not mean)
- [ ] Higher-ranked trait bounds (`for<'a>`) — and note that the kernel recently gained higher-ranked lifetime types to tie driver lifetimes to devices
- [ ] **Code:** write a struct holding a reference, hit the errors, annotate correctly, then explain in your journal why each annotation was needed

### Day 2 — Variance and Why Lifetimes Save Drivers
- [ ] Covariance, contravariance, invariance — at least enough to know when you are being bitten
- [ ] Why lifetimes are the kernel's killer feature: a resource that cannot outlive the device it belongs to
- [ ] Read `rust/kernel/devres.rs` and `revocable.rs` — the practical answer to "what if the device disappears?"
- [ ] **Code:** model it in userspace — a `Device` owning a `Resource`, where the compiler refuses to let the resource escape

### Day 3 — The Device/Driver Model (C side)
- [ ] `struct device`, `struct device_driver`, `struct bus_type` — the three-way relationship
- [ ] Matching and binding: how `probe()` gets called, and what `remove()` must undo
- [ ] Reference counting on devices: `get_device`/`put_device` and why lifetimes are hard in C
- [ ] `sysfs` as the visible face of the device model: walk `/sys/bus/`, `/sys/devices/`, `/sys/class/`
- [ ] **Explore:** on a running system, follow one real device from `/sys/devices/` to its driver and back
- [ ] **Read C:** a platform driver's `probe()`/`remove()` pair, tracing every resource acquired and released

### Day 4 — Iterators, Closures, and Zero-Cost Abstraction
- [ ] `Iterator` trait; adapters (`map`, `filter`, `zip`, `chain`, `take_while`); consumers (`collect`, `fold`, `sum`, `any`)
- [ ] Closures: `Fn`, `FnMut`, `FnOnce`; capture modes; `move`
- [ ] Why iterator chains compile to the same code as a hand-written loop — and how to verify with `cargo asm` or the playground's MIR/asm view
- [ ] **Code:** rewrite two loop-based functions from your register parser as iterator chains; confirm the output is identical

### Day 5 — Error Handling Discipline for Kernel Code
- [ ] Kernel error codes as negative errno; how `rust/kernel/error.rs` maps them
- [ ] `Result<T>` in kernel Rust (the `Error` type is fixed, unlike userspace)
- [ ] The teardown problem: partial initialization failure, and how `Drop` + `?` solves the `goto` ladder
- [ ] **Never panic:** why `unwrap()`, `expect()`, indexing, and integer overflow in debug builds are all hazards
- [ ] **Code:** write a function that acquires three resources in sequence and correctly releases what it got if step 2 or 3 fails — first with explicit cleanup, then with RAII, and compare

### 🔨 Saturday Project
- [ ] **RustScope v0.1** — the adoption tracker
  - [ ] Walk any Linux tree; count Rust LOC per subsystem; list `rust/kernel/` modules with their gating `CONFIG_`
  - [ ] List in-tree Rust drivers with subsystem and `MAINTAINERS` entry
  - [ ] Markdown output; iterator-heavy implementation; zero `unwrap()`

### 📄 Sunday Reading
- [ ] The Rust Book, Ch. 10 (lifetimes section) and Ch. 13 (closures, iterators)
- [ ] `Documentation/driver-api/driver-model/` — `overview`, `device`, `driver`, `binding`, `bus`
- [ ] *Linux Device Drivers, 3rd ed.* Ch. 14 (The Linux Device Model) — dated APIs, timeless model

---

## Week 4 — Smart Pointers + A C Kernel Module (Know Your Enemy)

### Day 1 — Box, Rc, RefCell, and Their Kernel Replacements
- [ ] `Box<T>`: heap allocation and ownership; why kernel Rust uses `KBox` with explicit GFP flags instead
- [ ] `Rc<T>`/`Arc<T>`: shared ownership; why the kernel has its own `Arc` (fallible allocation, no weak by default)
- [ ] `RefCell<T>`/`Cell<T>`: interior mutability with runtime checks — and why runtime panics are unacceptable in a driver
- [ ] `Cow`, `Deref`, `DerefMut`, and smart-pointer ergonomics
- [ ] **Code:** build a shared-ownership structure with `Rc<RefCell<T>>`, then rewrite it with explicit ownership and no interior mutability; note what became harder and what became clearer

### Day 2 — Fallible Allocation, the Kernel's Defining Constraint
- [ ] Why `std`'s allocation aborts on failure and why the kernel cannot
- [ ] `KBox::new(x, GFP_KERNEL)?` — allocation as a `Result`
- [ ] GFP flags preview: `GFP_KERNEL` (may sleep) vs `GFP_ATOMIC` (may not) and why the distinction is life-or-death
- [ ] `KVec` and its `push` returning `Result`
- [ ] **Code:** read `rust/kernel/alloc/` and write a summary of every allocation type and when to use it

### Day 3 — Write a C Kernel Module
- [ ] A minimal `hello.c` module: `module_init`, `module_exit`, `MODULE_LICENSE`, `printk`/`pr_info`
- [ ] Out-of-tree build with a `Makefile` against your kernel's build directory
- [ ] `insmod`, `rmmod`, `lsmod`, `modinfo`, `dmesg` — the whole loop
- [ ] Module parameters with `module_param`, visible in `/sys/module/`
- [ ] **Code:** write it, load it in your QEMU guest, break it deliberately (return an error from init) and observe what happens

### Day 4 — A C Misc Device, With All Its Sharp Edges
- [ ] `struct file_operations`; `open`, `read`, `write`, `release`, `unlocked_ioctl`
- [ ] `copy_to_user`/`copy_from_user` and why every one of them must be checked
- [ ] `misc_register`/`misc_deregister`; the device node in `/dev`
- [ ] Count the ways this C code can go wrong: unchecked copy, missing error path, race on module unload, integer overflow on a length
- [ ] **Code:** write it in C, then list every bug the compiler did *not* catch. Keep this list — it is your motivation document for the next 17 months

### Day 5 — Bringing It Together
- [ ] Compare your C misc device with `samples/rust/` equivalents: read both, line by line
- [ ] Identify each C error path and find its Rust counterpart (or its absence)
- [ ] Read `Documentation/process/coding-style.rst` (C) and `Documentation/rust/coding-guidelines.rst` (Rust) back to back
- [ ] **Code:** write a `dmesg`-parsing helper in Rust that extracts your module's messages — the seed of OopsLens

### 🔨 Saturday Project
- [ ] **KernelForge v0.2** — add `build`, `boot`, and `bisect-boot`
  - [ ] `build`: incremental build with timing per stage and a warning summary
  - [ ] `boot`: QEMU/virtme-ng boot, capture console, grep for `Oops|BUG|WARNING|call trace`, exit non-zero on failure
  - [ ] `bisect-boot`: `git bisect run` with your boot test as the predicate
  - [ ] Prove it works: introduce a deliberate boot regression, and let bisect find it

### 📄 Sunday Reading
- [ ] The Rust Book, Ch. 15 (Smart Pointers)
- [ ] *Linux Kernel Development* (Love), Ch. 17 (Devices and Modules) — or *Linux Kernel Programming* (Billimoria) Ch. 4-5 for a modern take
- [ ] `Documentation/kbuild/modules.rst` — out-of-tree module building

---

## 🔄 Buffer Week (Month 1 Revision)
- [ ] Revise Rust: ownership, borrowing, lifetimes, traits, generics, iterators, error handling, smart pointers
- [ ] Revise kernel: source layout, Kconfig/Kbuild, device/driver model, module lifecycle, build/boot loop
- [ ] Re-read your five saved borrow-checker errors and confirm you can explain each without help
- [ ] Re-read your C misc device bug list — can you now say which ones Rust prevents?
- [ ] Rebuild your kernel from clean and confirm your times and scripts still work
- [ ] **Build Monthly Project A:** KernelForge — One-Command Rust Kernel Lab
- [ ] **Build Monthly Project B:** RustScope — Kernel Rust Adoption Tracker
- [ ] Push both projects to GitHub with real READMEs
- [ ] **Gate check:** clean tree to booted Rust-enabled kernel in under 15 minutes, one command

---

## Week 5 — Unsafe Rust, Raw Pointers, Undefined Behavior

### Day 1 — What `unsafe` Actually Does
- [ ] The five superpowers: dereference raw pointers, call `unsafe fn`, access `static mut`, implement `unsafe` traits, access union fields
- [ ] What `unsafe` does **not** do: it does not disable the borrow checker, it does not make UB acceptable
- [ ] `unsafe fn` vs `unsafe {}` block vs `unsafe impl` — three different contracts
- [ ] The safety contract concept: an `unsafe fn` has preconditions the *caller* must guarantee
- [ ] **Code:** write an `unsafe fn` with a documented contract, then call it correctly and incorrectly, and observe what the compiler does and does not tell you

### Day 2 — Raw Pointers and Undefined Behavior
- [ ] `*const T`, `*mut T`; creating, casting, and dereferencing
- [ ] Pointer validity: dangling, misaligned, null, out-of-bounds, provenance
- [ ] The UB catalogue: data races, invalid values, aliasing violations, misaligned access, uninitialized reads, breaking type invariants
- [ ] Why UB is worse than a crash — the compiler is allowed to assume it never happens
- [ ] **Code:** write UB deliberately in a userspace program and run it under **Miri** (`cargo +nightly miri run`). Miri is your UB microscope; learn it now

### Day 3 — Initialization Discipline and `MaybeUninit`
- [ ] Why `mem::uninitialized()` was deprecated and why `MaybeUninit<T>` exists
- [ ] Partial initialization; `assume_init` and its contract; arrays of uninitialized values
- [ ] `ptr::read`/`write`/`copy`/`copy_nonoverlapping` and when each is required
- [ ] `transmute` and why it is almost always the wrong tool
- [ ] **Code:** correctly initialize a struct field-by-field through a `MaybeUninit`, verify under Miri

### Day 4 — Writing Safety Comments Like a Kernel Developer
- [ ] Read `Documentation/rust/coding-guidelines.rst` on `// SAFETY:` and `# Safety` doc sections
- [ ] Study 20 real `// SAFETY:` comments in `rust/kernel/` — grade them: which ones actually prove something?
- [ ] The anatomy of a good safety comment: which invariant, why it holds *here*, who guarantees it
- [ ] Common bad patterns: "this is safe", restating the code, appealing to the caller without saying what the caller must do
- [ ] **Code:** take five `unsafe` blocks you wrote this week and write real safety comments for each

### Day 5 — Unsafe at the C Boundary
- [ ] `repr(C)`, `repr(transparent)`, `repr(packed)` — layout guarantees and their costs
- [ ] The C ABI: `extern "C"`, calling conventions, `c_int`/`c_void` and the `ffi` types
- [ ] Passing ownership across FFI: who frees what, and how Rust types encode that
- [ ] Null-pointer and validity contracts on C function arguments and return values
- [ ] **Code:** write a small C library, call it from Rust with `extern "C"`, pass a struct both ways, and get it exactly right — then get it wrong and see what breaks

### 🔨 Saturday Project
- [ ] **SafetyLint v0.1** — find and audit `unsafe` in kernel Rust
  - [ ] Parse Rust source and locate every `unsafe` block, `unsafe fn`, `unsafe impl` with file:line
  - [ ] Detect missing `// SAFETY:` comments; detect content-free ones
  - [ ] Run it on the whole `rust/` tree and on `drivers/`; report the difference
  - [ ] Write up the numbers — this is a real finding

### 📄 Sunday Reading
- [ ] **The Rustonomicon** — "Meet Safe and Unsafe", "Working with Unsafe", "Data Layout" chapters
- [ ] Paper: "RustBelt: Securing the Foundations of the Rust Programming Language" (Jung et al., POPL 2018) — read the intro and the model, skip the Coq
- [ ] Paper: "Safe Systems Programming in Rust" (Jung et al., CACM 2021) — the accessible companion

---

## Week 6 — Concurrency: Send/Sync, Atomics, Memory Ordering

### Day 1 — `Send`, `Sync`, and Auto Traits
- [ ] What `Send` means (safe to move to another thread) and `Sync` means (safe to share by reference)
- [ ] Auto-derivation and negative reasoning: why `Rc` is neither, why `Arc<T>` is `Send + Sync` only if `T` is
- [ ] `unsafe impl Send`/`Sync`: what you are promising, and how to justify it
- [ ] Kernel context: threads are not the only concurrency — interrupts, softirqs, preemption, and per-CPU data all matter
- [ ] **Code:** build a type that is deliberately `!Send`, try to move it across threads, then make it `Send` with a written justification

### Day 2 — Atomics and Memory Ordering
- [ ] Atomic types and operations: load, store, swap, `compare_exchange`, fetch-and-modify
- [ ] Orderings: `Relaxed`, `Acquire`, `Release`, `AcqRel`, `SeqCst` — what each guarantees
- [ ] Happens-before, synchronizes-with, and why `Relaxed` is not "no guarantees"
- [ ] The release-acquire pattern: the workhorse of correct lock-free code
- [ ] **Code:** implement a spinlock from an `AtomicBool` with correct orderings; then deliberately weaken the orderings and reason about what breaks

### Day 3 — Building Blocks: From Atomics to Locks
- [ ] Mutex, RwLock, condition variables — how they are built and what they cost
- [ ] Lock guards and RAII; poisoning (userspace) vs no-poisoning (kernel)
- [ ] Lock-free vs wait-free vs blocking; when lock-free is actually worse
- [ ] ABA problem, memory reclamation, and why RCU exists (preview of Month 6)
- [ ] **Code:** implement a small channel or a bounded queue with atomics; test it hard under `loom` if you can

### Day 4 — Kernel Concurrency Contexts (C side)
- [ ] Process context vs interrupt context vs softirq vs NMI — and what each may do
- [ ] Preemption, `preempt_disable`, and why sleeping in atomic context is fatal
- [ ] Spinlock vs mutex in the kernel: the actual decision rule
- [ ] IRQ-safe locking: `spin_lock_irqsave` and the deadlock it prevents
- [ ] Per-CPU variables as an alternative to locking
- [ ] **Read C:** find a driver that uses `spin_lock_irqsave` and explain precisely why it needs it

### Day 5 — Mapping Rust Concurrency onto Kernel Concurrency
- [ ] Read `rust/kernel/sync/`: `Lock`, `Guard`, `SpinLock`, `Mutex`, `CondVar`, `Arc`, `LockClassKey`
- [ ] How lockdep integration works from Rust, and why lock classes exist
- [ ] Why kernel Rust does not use `std::sync` and what would go wrong if it did
- [ ] The Linux Kernel Memory Model vs the Rust/C++ model — note that they are *different*, and the kernel's rules win
- [ ] **Code:** write a summary in your journal: for each kernel context, which Rust sync primitive is legal

### 🔨 Saturday Project
- [ ] **Concurrency Bug Museum, Part 1 (userspace)** — the seed of Month 6's LockProof
  - [ ] Implement 8 classic concurrency bugs in userspace Rust: data race, ABBA deadlock, double-unlock, torn read, publish-before-init, missing barrier, use-after-free across threads, lost wakeup
  - [ ] For each: does it compile? If it compiles, does `loom`/`miri`/TSan catch it?
  - [ ] Write the three-column table: prevented at compile time / caught by tooling / silent

### 📄 Sunday Reading
- [ ] **"Rust Atomics and Locks" (Mara Bos)** — Ch. 1-3 (free online). This book is the single best investment for this month
- [ ] `Documentation/memory-barriers.txt` — start it; you will not finish it, and that is expected
- [ ] Paper: "Frightening small children and disconcerting grown-ups: Concurrency in the Linux kernel" (Alglave et al., ASPLOS 2018) — the LKMM paper

---

## Week 7 — Pin, Self-Reference, and pin-init

### Day 1 — Why Moving Breaks Things
- [ ] Rust moves are memcpy: a self-referential struct's internal pointer becomes garbage
- [ ] Where this appears in the kernel: anything the C side holds a pointer to, intrusive list nodes, locks registered with lockdep, hardware descriptor structures
- [ ] `Unpin` as the default, and `PhantomPinned` as the opt-out
- [ ] **Code:** build a self-referential struct, move it, and demonstrate the corruption under Miri

### Day 2 — `Pin` Mechanics
- [ ] `Pin<P>` as a wrapper on a pointer type, not on a value
- [ ] `Pin<&mut T>`, `Pin<Box<T>>`, `Pin::new`, `Pin::new_unchecked` and its contract
- [ ] The pinning guarantee: once pinned, never moved until dropped
- [ ] Pin projection: getting `Pin<&mut Field>` from `Pin<&mut Struct>` safely
- [ ] **Code:** implement pin projection by hand for a two-field struct; then compare with what `pin-project`/`#[pin_data]` generates

### Day 3 — `pin-init` and the Kernel's Initialization Problem
- [ ] The problem: kernel objects must be initialized *in place*, fallibly, possibly with self-references, without a temporary on the stack
- [ ] Read `rust/pin-init/` and `rust/kernel/init.rs`
- [ ] `#[pin_data]`, `pin_init!`, `try_pin_init!`, `PinInit`/`Init` traits
- [ ] How failure part-way through initialization is handled correctly
- [ ] **Code:** write a struct with a pinned `Mutex` field and initialize it with `pin_init!` in a real Rust module

### Day 4 — `PhantomData`, Variance, and Typestate
- [ ] `PhantomData<T>` for unused type parameters; `PhantomData<&'a T>` for lifetime binding; `PhantomData<*const T>` for invariance
- [ ] Variance in practice: when your struct is accidentally covariant and unsound
- [ ] Typestate pattern: encoding a state machine so illegal operations do not compile
- [ ] **Code:** build a typestate device wrapper: `Device<Uninit>` → `Device<Ready>` → `Device<Suspended>`, where calling `read()` on `Uninit` is a compile error

### Day 5 — Reading Pinning in Real Kernel Code
- [ ] Find every use of `#[pin_data]` in `rust/kernel/` and one in a real driver; explain why each object must be pinned
- [ ] Read how `rust/kernel/sync/lock.rs` uses pinning and lock classes together
- [ ] Read how intrusive lists (`rust/kernel/list/`) depend on pinning
- [ ] **Code:** write your journal entry titled "Why hardware objects in the kernel are pinned" — in plain language, for your future self

### 🔨 Saturday Project
- [ ] **PinDojo v0.1** — the pinning dojo
  - [ ] 10 graded exercises with `trybuild` compile-fail tests
  - [ ] Progression: move breaks self-reference → `Pin<&mut T>` → `Unpin` → projection → `#[pin_data]`
  - [ ] Each exercise cites the real kernel code that uses the same pattern

### 📄 Sunday Reading
- [ ] `std::pin` module documentation — all of it, slowly
- [ ] The Rustonomicon — "Subtyping and Variance", "PhantomData"
- [ ] `rust/pin-init/README.md` and the crate docs

---

## Week 8 — no_std, FFI, bindgen, and the Kernel Rust Build

### Day 1 — `no_std` and What You Lose
- [ ] `core` vs `alloc` vs `std`: what each provides
- [ ] What disappears in `no_std`: `println!`, `Vec` (unless `alloc`), threads, files, time, panics-with-unwinding
- [ ] `#![no_std]`, `#[panic_handler]`, and why kernel Rust panics are `BUG()`-like
- [ ] The kernel's custom `alloc` situation: fallible allocation with explicit flags
- [ ] **Code:** write a `no_std` userspace binary that does something real — you will feel exactly what the kernel takes away

### Day 2 — bindgen and Generated Bindings
- [ ] What bindgen does: C headers → raw Rust `extern "C"` declarations and `repr(C)` structs
- [ ] Look at generated `rust/bindings/bindings_generated.rs` in your build tree — read it and be appropriately unnerved
- [ ] `rust/helpers/` — why some C constructs (inlines, macros) need C shim functions
- [ ] Why leaf drivers must never use `bindings::` directly, and how reviewers enforce that
- [ ] **Code:** run bindgen yourself on a small C header and compare its output style with the kernel's

### Day 3 — The Kernel Rust Build Pipeline
- [ ] How `rust/Makefile` orchestrates: `core`, `alloc`, `kernel`, `macros`, `bindings`, `uapi`
- [ ] `--extern`, `--emit=metadata`, and why kernel Rust builds are not Cargo builds
- [ ] `CONFIG_RUST_*` options: debug assertions, overflow checks, build-time docs, `RUST_KERNEL_DOCTESTS`
- [ ] How `.rs` files become objects and get linked with C
- [ ] **Code:** add a new file to `rust/kernel/`, wire it into `lib.rs`, and build — then break it deliberately and read the error

### Day 4 — Kernel Rust Macros
- [ ] Read `rust/macros/`: `module!`, `#[vtable]`, `pin_data`, `#[export]`, and friends
- [ ] Procedural macros vs declarative macros; what each is used for here
- [ ] `cargo expand` equivalents: how to see what `module!` expands to
- [ ] Why the kernel writes its own macros instead of pulling crates from crates.io — the "no external dependencies" rule
- [ ] **Code:** write a small declarative macro of your own that reduces boilerplate in your register parser

### Day 5 — Build a Rust Module From Scratch, Properly
- [ ] Create a new `samples/rust`-style module in your tree: Kconfig entry, Makefile entry, `.rs` file
- [ ] `module!` with authors, description, license; module parameters
- [ ] Init returning `Result`; correct teardown in `Drop`
- [ ] Build it, load it, unload it, and verify no leaks with `kmemleak`
- [ ] **Code:** deliberately return an error from init and confirm the kernel handles it cleanly

### 🔨 Saturday Project
- [ ] **PinDojo v0.2 + SafetyLint v0.2** — polish both for the buffer week
  - [ ] PinDojo: expand to 20 exercises, add the `pin_init!` section, add prose explanations
  - [ ] SafetyLint: add safety-claim classification (pointer validity, aliasing, lifetime, initialization, locking, C contract) and per-subsystem hygiene scores

### 📄 Sunday Reading
- [ ] `Documentation/rust/general-information.rst` and `arch-support.rst`
- [ ] The `bindgen` user guide — the sections on layout and unsupported constructs
- [ ] Paper: "An Empirical Study of Rust-for-Linux: The Success, Dissatisfaction, and Compromise" (Li et al., USENIX ATC 2024) — the honest account of what is hard

---

## 🔄 Buffer Week (Month 2 Revision)
- [ ] Revise `unsafe`: the five superpowers, the UB catalogue, safety contracts, safety comments
- [ ] Revise concurrency: `Send`/`Sync`, atomics, orderings, kernel contexts, which primitive is legal where
- [ ] Revise pinning: why it exists, `Pin` mechanics, projection, `pin_init!`
- [ ] Revise FFI: `repr(C)`, `extern "C"`, bindgen, the abstraction/bindings/leaf-driver layering
- [ ] Re-run everything under Miri; re-read your safety comments and improve the weak ones
- [ ] **Build Monthly Project A:** SafetyLint — the `unsafe`/SAFETY auditor
- [ ] **Build Monthly Project B:** PinDojo — the pinning playground
- [ ] Push both to GitHub; post SafetyLint's findings somewhere (blog, Zulip) — get your first external feedback
- [ ] **Gate check:** you can explain pinning and safety contracts to another engineer without notes

---

## Week 9 — The kernel Crate Tour

### Day 1 — Prelude, Errors, and Printing
- [ ] `rust/kernel/prelude.rs`: what every module imports
- [ ] `rust/kernel/error.rs`: `Error`, `Result`, `code::*` constants, conversions from C return values
- [ ] `to_result` and the `from_err_ptr`/`from_result` helpers at the C boundary
- [ ] `pr_info!`, `pr_err!`, `pr_debug!`, `dev_info!`, `dev_err!` — and why `dev_*` is preferred in drivers
- [ ] **Code:** write a module that exercises every log level and every error path, and read the results in `dmesg`

### Day 2 — Allocation: KBox, KVec, and Friends
- [ ] `rust/kernel/alloc/`: `Kmalloc`, `Vmalloc`, `KVmalloc` allocators and when each applies
- [ ] `KBox`, `VBox`, `KVBox`; `KVec`, `VVec`, `KVVec`
- [ ] GFP flags in Rust: `GFP_KERNEL`, `GFP_ATOMIC`, `__GFP_ZERO`, `GFP_NOWAIT`
- [ ] `try_*` methods and why every allocation is a `Result`
- [ ] `ArrayLayout`, `Box::new_uninit`, in-place initialization for large objects
- [ ] **Code:** allocate in three different contexts with the correct flags; deliberately use `GFP_KERNEL` in atomic context and observe the complaint

### Day 3 — Types, Strings, and Reference Counting
- [ ] `rust/kernel/types.rs`: `Opaque`, `ARef`, `AlwaysRefCounted`, `ForeignOwnable`, `ScopeGuard`
- [ ] `ARef<T>` — the kernel's refcounted reference, and how it differs from `Arc`
- [ ] `CStr`, `CString`, `c_str!` macro, `fmt` module
- [ ] `Opaque<T>` for C types you must not construct or inspect
- [ ] **Code:** read the docs for `ARef` and `AlwaysRefCounted` and write down when you would implement each

### Day 4 — Device, Driver, and the Registration Pattern
- [ ] `rust/kernel/device.rs`: `Device`, `Device<Bound>`, `Device<Core>` — the lifetime states and why they exist
- [ ] `rust/kernel/driver.rs`: the generic registration machinery shared by PCI, platform, and other buses
- [ ] `rust/kernel/devres.rs` and `revocable.rs`: resources tied to device lifetime
- [ ] The `Registration` pattern: an object whose `Drop` unregisters
- [ ] **Code:** trace one complete registration path in `rust/kernel/` from the driver's `impl` to the C call, and write the chain in your journal

### Day 5 — Survey the Whole Crate
- [ ] Browse the full module list in your local `rustdoc` output and in [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/)
- [ ] For each module, write one line: what it wraps and whether you will need it
- [ ] Identify which C subsystems have **no** Rust abstraction yet — this list is your future contribution pipeline. Save it
- [ ] Cross-check against RustScope's output from Month 1
- [ ] **Code:** update RustScope to also flag "C subsystems with no Rust abstraction" as a gap report

### 🔨 Saturday Project
- [ ] **KModKit v0.1** — modules `01-hello` and `02-miscdev`
  - [ ] `01-hello`: init/exit, module params, correct teardown, exhaustive comments
  - [ ] `02-miscdev`: misc device with open/read/write/release using `UserSlice`
  - [ ] Both with a boot test via KernelForge and a `dmesg` transcript in the README

### 📄 Sunday Reading
- [ ] Browse `rust.docs.kernel.org/kernel/` systematically — one hour of just reading API docs
- [ ] `rust/kernel/lib.rs` and `prelude.rs` in full
- [ ] LWN: the most recent "Rust for Linux" status article you can find

---

## Week 10 — Your First Real Rust Module: Misc Device + ioctl

### Day 1 — Misc Devices in Rust
- [ ] `rust/kernel/miscdevice.rs`: `MiscDevice` trait, `MiscDeviceRegistration`, `MiscDeviceOptions`
- [ ] The file operations you can implement: `open`, `release`, `read`, `write`, `ioctl`, `compat_ioctl`, `mmap`, `poll`
- [ ] Per-open private data and its lifetime; `ForeignOwnable`
- [ ] **Code:** a misc device that maintains per-open state and proves it (each open gets its own counter)

### Day 2 — Copying To and From Userspace
- [ ] `rust/kernel/uaccess.rs`: `UserSlice`, `UserSliceReader`, `UserSliceWriter`
- [ ] Why you cannot just dereference a userspace pointer, ever
- [ ] Partial copies, `EFAULT`, and TOCTOU hazards when you read a userspace struct twice
- [ ] Bounds checking and integer overflow on lengths — the classic exploit primitive
- [ ] **Code:** implement `read`/`write` that copy a bounded buffer, then write a userspace program that tries to abuse it (huge length, bad pointer, partial buffer) and confirm it fails safely

### Day 3 — ioctl Design and Implementation
- [ ] ioctl number encoding: `_IO`, `_IOR`, `_IOW`, `_IOWR`; type, number, size, direction
- [ ] `rust/kernel/ioctl.rs` helpers
- [ ] Designing an ioctl interface that can evolve: versioning, size fields, reserved fields, flags
- [ ] Compat ioctl and 32-bit userspace on a 64-bit kernel — the struct layout trap
- [ ] **Code:** define three ioctls (get version, get info, do operation) with a shared UAPI header usable from both C and Rust

### Day 4 — uAPI Design as a Permanent Contract
- [ ] "We do not break userspace" — what that means for you personally
- [ ] Struct layout stability: padding, alignment, `__u64` vs `unsigned long`, explicit sizes always
- [ ] Extensibility patterns: size-prefixed structs, feature flags, reserved-must-be-zero fields
- [ ] Where uAPI headers live (`include/uapi/`) and why they are separate
- [ ] **Code:** write your UAPI header properly, and verify layout is identical on 32-bit and 64-bit with a static assertion

### Day 5 — The Userspace Half
- [ ] Write a real userspace client for your driver: open, ioctl, read, write, error handling
- [ ] Use your `LINUX/` TLPI knowledge — this is exactly Ch. 4-5 and Ch. 63 material from the other side
- [ ] Test error paths: driver not loaded, permission denied, bad arguments, device removed mid-operation
- [ ] **Code:** a test suite (shell or C or Rust) that exercises every ioctl and every failure mode

### 🔨 Saturday Project
- [ ] **KModKit v0.2** — module `03-ioctl`
  - [ ] Well-designed, versioned ioctl interface with a shared UAPI header
  - [ ] Userspace client + test suite covering success and every error path
  - [ ] Documented ABI (a mini `Documentation/ABI/` entry, for practice)

### 📄 Sunday Reading
- [ ] `Documentation/driver-api/ioctl.rst` and `Documentation/process/adding-syscalls.rst` (the uAPI design principles apply to ioctls too)
- [ ] `Documentation/process/stable-api-nonsense.rst` — the in-kernel API is not stable; the userspace API is forever
- [ ] TLPI Ch. 63 (Alternative I/O Models) if you have not read it — `poll`/`epoll` from the userspace side

---

## Week 11 — Kernel Sync Primitives in Rust

### Day 1 — SpinLock and Mutex in Kernel Rust
- [ ] `rust/kernel/sync/lock/spinlock.rs` and `mutex.rs`
- [ ] The `Lock<T, B>` / `Guard<T, B>` design: data-owning locks, so you cannot access data without holding the lock
- [ ] `new_spinlock!`/`new_mutex!` macros and why locks must be pinned
- [ ] Lock classes and lockdep integration
- [ ] **Code:** a module with shared state behind both a `SpinLock` and a `Mutex`; measure which contexts each can be taken in

### Day 2 — What The Type System Buys You Here
- [ ] Compare: C's `spin_lock(&lock); use(data); spin_unlock(&lock);` where nothing connects `lock` and `data`
- [ ] Rust's `let guard = lock.lock(); guard.field = x;` where the connection is the type
- [ ] What is still possible to get wrong: lock ordering, holding a lock too long, sleeping while holding a spinlock
- [ ] Enable `CONFIG_PROVE_LOCKING` and see lockdep work
- [ ] **Code:** deliberately create an ABBA deadlock with two `Mutex`es and let lockdep catch it. Read the report carefully — you will see many of these

### Day 3 — CondVar, Atomics, and Waiting
- [ ] `rust/kernel/sync/condvar.rs`: `wait`, `wait_interruptible`, `notify_one`, `notify_all`
- [ ] Why you must re-check the condition in a loop after waking
- [ ] Kernel atomics from Rust; `rust/kernel/sync/atomic/` and the ordering types
- [ ] Interruptible vs uninterruptible sleep and what userspace sees (`D` state processes)
- [ ] **Code:** a producer/consumer module using `CondVar`, with a bounded queue, that shuts down cleanly on module unload

### Day 4 — Arc, Reference Counting, and Shared Ownership
- [ ] `rust/kernel/sync/arc.rs`: `Arc`, `ArcBorrow`, `UniqueArc`
- [ ] Why the kernel's `Arc` is not `std::sync::Arc` (fallible allocation, no unwinding, `ForeignOwnable`)
- [ ] `UniqueArc` for building an object before sharing it
- [ ] Refcount cycles and why the kernel does not give you `Weak` by default
- [ ] **Code:** share state between a workqueue item and a file operation via `Arc`; prove there is no leak on unload with `kmemleak`

### Day 5 — Workqueues, Timers, and Deferred Work
- [ ] `rust/kernel/workqueue.rs`: `Work`, `WorkItem`, `impl_has_work!`, queuing onto the system workqueue
- [ ] Why work items must be pinned and embedded, not boxed independently
- [ ] Timers and `hrtimer` abstractions; `rust/kernel/time/`
- [ ] The teardown race: cancelling work and timers before freeing the data they reference
- [ ] **Code:** a module with a periodic timer that queues work; unload it under load 100 times and prove no use-after-free with KASAN

### 🔨 Saturday Project
- [ ] **KModKit v0.3** — modules `04-sync` and `05-work`
  - [ ] `04-sync`: `SpinLock`, `Mutex`, `CondVar`, `Arc` used correctly, plus a lockdep demonstration you can turn on with a module param
  - [ ] `05-work`: workqueue + timer + clean shutdown, stress-tested with repeated load/unload under KASAN
  - [ ] Document the locking design for each in the README — practice for real patches

### 📄 Sunday Reading
- [ ] "Rust Atomics and Locks" Ch. 4-6 (building locks and channels)
- [ ] `Documentation/locking/` — `locktypes.rst`, `lockdep-design.rst`, `mutex-design.rst`
- [ ] `Documentation/core-api/workqueue.rst`

---

## Week 12 — Debugging & Testing Kernel Rust

### Day 1 — Reading a Kernel Failure
- [ ] Anatomy of an oops: the RIP, the registers, the call trace, tainted flags, module list
- [ ] `WARN_ON` vs `BUG_ON` vs panic; what each does to the machine
- [ ] Rust panics in the kernel: what `panic!` compiles to, why `unwrap()` is a bug, and how a Rust panic looks in `dmesg`
- [ ] `scripts/decode_stacktrace.sh`, `addr2line`, and symbolizing module addresses
- [ ] **Code:** crash your KModKit modules five different ways deliberately, capture each report, and decode all five

### Day 2 — Sanitizers and Memory Debugging
- [ ] **KASAN**: what it catches (UAF, OOB, double-free), how to read its report's three stacks
- [ ] **KCSAN**: data race detection, and why its reports are probabilistic
- [ ] **UBSAN**: undefined behavior detection
- [ ] `kmemleak`: finding leaks, and its false positives
- [ ] `slub_debug`, `page_poison`, and `CONFIG_DEBUG_*` options worth knowing
- [ ] **Code:** add sanitizer profiles to KernelForge; write a UAF and an OOB in a Rust module (you will need `unsafe`) and confirm KASAN catches both

### Day 3 — Tracing and Live Inspection
- [ ] `ftrace` basics: function tracer, function graph tracer, event tracing via `/sys/kernel/tracing`
- [ ] `trace-cmd` and `perf` for kernel work
- [ ] `dynamic_debug` and `pr_debug` control at runtime
- [ ] `debugfs` for exposing driver state; `seq_file` for structured output
- [ ] **Code:** trace your module's functions with the function graph tracer and read the timing

### Day 4 — KUnit and Testing Kernel Rust
- [ ] `rust/kernel/kunit.rs` and the `#[test]`-style macros for kernel tests
- [ ] `kunit_tool` (`tools/testing/kunit/kunit.py`) for running tests in QEMU quickly
- [ ] Rust doctests in the kernel (`CONFIG_RUST_KERNEL_DOCTESTS`) — the docs are the tests
- [ ] What to test: error paths, allocation failure, boundary conditions, not just the happy path
- [ ] **Code:** write KUnit tests for your KModKit modules and run them with `kunit.py run`

### Day 5 — Interactive Debugging
- [ ] `kgdb` over serial and `gdb` against a QEMU guest (`-s -S`) — set a breakpoint in your Rust module
- [ ] `crash`/`drgn` for post-mortem analysis of a vmcore
- [ ] `drgn` scripting to inspect live kernel data structures — enormously useful and underused
- [ ] `printk` discipline: what belongs in a driver at each level, and why `dev_dbg` is preferred
- [ ] **Code:** break in your module with gdb, inspect a Rust struct's fields, and step through a function

### 🔨 Saturday Project
- [ ] **OopsLens v0.1** — the crash decoder
  - [ ] Parse oops/panic/WARN/BUG/KASAN/Rust-panic from a log
  - [ ] Symbolize with `vmlinux` + `addr2line`, handling module offsets
  - [ ] KASAN mode: align access/alloc/free stacks side by side
  - [ ] Test it against the crash corpus you generated on Day 1

### 📄 Sunday Reading
- [ ] `Documentation/dev-tools/` — `kasan.rst`, `kcsan.rst`, `ubsan.rst`, `kunit/`, `kgdb.rst`, `kmemleak.rst`
- [ ] `Documentation/admin-guide/bug-hunting.rst`
- [ ] The `drgn` documentation — skim it and note three things you would use it for

---

## 🔄 Buffer Week (Month 3 Revision)
- [ ] Revise the `kernel` crate: prelude, errors, allocation, types, device/driver, registration pattern
- [ ] Revise module authoring: `module!`, init/teardown, params, misc devices, ioctls, uAPI design
- [ ] Revise sync: `SpinLock`, `Mutex`, `CondVar`, `Arc`, workqueues, timers, teardown races
- [ ] Revise debugging: oops decoding, KASAN/KCSAN, ftrace, KUnit, kgdb
- [ ] Re-read every `unsafe` block you wrote this month and improve every safety comment
- [ ] Stress-test all your modules: 1000 load/unload cycles under KASAN + lockdep + `kmemleak`
- [ ] **Build Monthly Project A:** KModKit — the Rust Kernel Module Starter Suite
- [ ] **Build Monthly Project B:** OopsLens — Crash & KASAN Report Decoder
- [ ] Push both to GitHub; consider proposing your two best KModKit modules for `samples/rust/`
- [ ] **Gate check:** write a Rust misc-device driver with an ioctl interface from a blank file, with correct error paths, and debug it when it breaks

---

### ✅ Phase 1 Completion Checklist
- [ ] Can build and boot a Rust-enabled kernel from clean in under 15 minutes, reproducibly
- [ ] Can write idiomatic Rust: ownership, lifetimes, traits, generics, iterators, error handling
- [ ] Can explain `unsafe`, the UB catalogue, and write safety comments that survive review
- [ ] Can explain `Send`/`Sync`, atomics, memory ordering, and which sync primitive is legal in which kernel context
- [ ] Can explain pinning from first principles and use `#[pin_data]`/`pin_init!`
- [ ] Can explain the bindings/abstractions/leaf-driver layering and why it exists
- [ ] Can write, load, unload, and debug a Rust kernel module with misc device and ioctl interfaces
- [ ] Can handle allocation failure everywhere — no panics in any of your driver code
- [ ] Can decode an oops and a KASAN report without help
- [ ] Can write and run KUnit tests for kernel Rust
- [ ] Can read a real C driver end to end and explain what it does

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# PHASE 2: DRIVER ENGINEERING (Weeks 13-24, Months 4-6)
# PCI, DMA, Buses, Concurrency, Block, Networking
# ═══════════════════════════════════════════════════

---

## Week 13 — Character Devices & User Memory

### Day 1 — Character Devices Beyond miscdevice
- [ ] Major/minor numbers, `alloc_chrdev_region`, `cdev`, and what `miscdevice` hides from you
- [ ] Device classes, `udev`, and how a `/dev` node actually appears
- [ ] When to use misc device vs a proper char device vs a class device
- [ ] **Read C:** a real char driver that manages its own major/minor range
- [ ] **Code:** extend your KModKit misc device to expose multiple minors with independent state

### Day 2 — File Operations in Depth
- [ ] `llseek`, `poll`, `fasync`, `flush`, `fsync` — the operations people forget
- [ ] Blocking vs non-blocking I/O (`O_NONBLOCK`), and implementing `poll` correctly with wait queues
- [ ] `mmap` from a char device (preview — full treatment in Month 14)
- [ ] Concurrency: two processes with the same file open, or the same process from two threads
- [ ] **Code:** implement `poll` on your driver and write a userspace `epoll` client for it

### Day 3 — Userspace Memory Access Hazards
- [ ] TOCTOU when reading a userspace struct twice — read once, validate the copy
- [ ] Integer overflow on lengths and offsets; `checked_add`, `checked_mul` discipline
- [ ] `access_ok`, page faults during copy, and why partial copies happen
- [ ] What a malicious userspace can do to your driver: huge sizes, unaligned pointers, concurrent modification, closing fds mid-operation
- [ ] **Code:** write an adversarial test program for your driver and fix everything it breaks

### Day 4 — Reference Counting and Object Lifetime
- [ ] File lifetime vs device lifetime vs module lifetime; the three-way race
- [ ] Why a module cannot be unloaded while a file is open, and how that is enforced
- [ ] `AlwaysRefCounted` and `ARef` for wrapping C refcounted objects
- [ ] The classic bug: driver freed while a userspace operation is in flight
- [ ] **Code:** hold a file open, remove the device, and continue operating on the fd — prove your driver survives

### Day 5 — Reading Real Rust Drivers
- [ ] Read a complete in-tree Rust driver end to end (the ASIX PHY driver is a good size)
- [ ] Map every abstraction it uses back to the `kernel` crate module it comes from
- [ ] Find its `MAINTAINERS` entry and read its original submission thread on `lore.kernel.org`
- [ ] Note the review comments — this is free education in what maintainers care about
- [ ] **Journal:** write "what I learned from reading the ASIX driver's review thread"

### 🔨 Saturday Project
- [ ] **Adversarial Driver Test Harness** — a reusable test tool that attacks any char device
  - [ ] Fuzz ioctl arguments, sizes, and pointers; race concurrent operations; remove the device mid-operation
  - [ ] Run it under KASAN against every module you have written so far
  - [ ] Fix everything it finds; this harness becomes part of KFuzzRS in Month 10

### 📄 Sunday Reading
- [ ] *Linux Device Drivers 3* Ch. 3 (Char Drivers) and Ch. 6 (Advanced Char Driver Operations) — dated APIs, excellent concepts
- [ ] `Documentation/filesystems/vfs.rst` — the `file_operations` section
- [ ] A real Rust driver's submission thread on `lore.kernel.org`, start to finish

---

## Week 14 — Platform Drivers & Device Tree

### Day 1 — The Platform Bus
- [ ] What the platform bus is for: devices that cannot be discovered (memory-mapped SoC peripherals)
- [ ] `rust/kernel/platform.rs`: the `platform::Driver` trait, `probe`, device ID tables
- [ ] Resources: memory regions, IRQs, and how they arrive from device tree or ACPI
- [ ] `devres`: resources that are freed automatically when the device goes away
- [ ] **Code:** a platform driver in Rust that binds to a device tree node and reads a register

### Day 2 — Device Tree Fundamentals
- [ ] DTS syntax: nodes, properties, `compatible`, `reg`, `interrupts`, phandles
- [ ] The compatible-string matching mechanism, and vendor prefixes
- [ ] `rust/kernel/of.rs`: reading properties from Rust
- [ ] Overlays, and how to add a node for testing without touching the base DTS
- [ ] **Code:** write a DTS overlay for a fake device, apply it in QEMU (`-dtb`), and bind your driver to it

### Day 3 — Device Tree Bindings (The Documentation That Is Code)
- [ ] YAML binding schema format in `Documentation/devicetree/bindings/`
- [ ] `make dt_binding_check` and `make dtbs_check`
- [ ] Binding review culture: the DT maintainers are strict, and correctly so
- [ ] Required vs optional properties; `additionalProperties: false`; examples that must validate
- [ ] **Code:** write a real binding YAML for your fake device and make both checks pass

### Day 4 — ACPI and the Other Discovery Mechanism
- [ ] ACPI basics for drivers: `_HID`, `_CID`, device objects, `acpi_device_id`
- [ ] `rust/kernel/acpi.rs` where available; how a driver supports both DT and ACPI
- [ ] Why x86 uses ACPI and embedded uses DT, and what that means for portability
- [ ] **Explore:** dump your own machine's ACPI tables (`acpidump`) and find a device you recognize

### Day 5 — Bringing Up Real Hardware on Your Tier-3 Board
- [ ] Set up your ARM board: serial console, kernel from source, DT for your board
- [ ] Boot your own kernel on it — this is a different discipline from QEMU
- [ ] Wire up an I2C or SPI device on the header; verify it appears with `i2cdetect`
- [ ] **Code:** a platform or bus driver on real hardware that reads a real chip ID. This is the day hardware becomes real

### 🔨 Saturday Project
- [ ] **Platform Driver + Binding + Overlay, Complete**
  - [ ] A Rust platform driver, its YAML binding, a DT overlay, and a test that binds it in QEMU
  - [ ] Both `dt_binding_check` and `dtbs_check` clean
  - [ ] Bonus: run it on your real board

### 📄 Sunday Reading
- [ ] `Documentation/devicetree/usage-model.rst` and `bindings/writing-schema.rst`
- [ ] The devicetree specification, Ch. 2 (Device Tree structure) — skim
- [ ] Bootlin's kernel and driver development slides — the platform driver and DT sections (free, excellent)

---

## Week 15 — PCI Drivers in Rust

### Day 1 — PCI/PCIe Architecture
- [ ] Bus/device/function addressing; config space layout; vendor/device/class codes
- [ ] BARs: memory vs I/O, sizing, prefetchable, 64-bit BARs
- [ ] Capabilities and extended capabilities; the linked-list walk
- [ ] PCIe topology: root complex, switches, endpoints, link training, speed and width
- [ ] **Explore:** `lspci -vvv` on your machine; decode one device's capability list by hand against the spec

### Day 2 — The Rust PCI Abstractions
- [ ] `rust/kernel/pci.rs`: `pci::Driver`, `pci::Device`, `DeviceId`, `device_table!`
- [ ] Enabling the device, requesting regions, mapping BARs
- [ ] `Devres<Bar0>` and `Revocable` — the answer to "the device was unplugged while I was using it"
- [ ] `rust/kernel/io.rs`: `Io`, `IoRaw`, typed MMIO accessors, and compile-time offset checking
- [ ] **Code:** a PCI driver that probes a QEMU device (`-device edu` or `pci-testdev`), maps BAR0, and reads its identity register

### Day 3 — MMIO Discipline
- [ ] Why MMIO is not memory: no caching, no reordering by the compiler, side effects on read
- [ ] `readl`/`writel` equivalents and the memory barriers they imply
- [ ] Register access patterns: read-modify-write hazards, write-only registers, posted writes and why you sometimes must read back
- [ ] Building a typed register abstraction so `BAR0.status()` cannot be confused with `BAR0.control()`
- [ ] **Code:** build a register definition macro for your driver — typed offsets, named fields, bit accessors. This is the pattern Nova uses

### Day 4 — MSI, MSI-X, and Interrupt Setup
- [ ] Legacy INTx vs MSI vs MSI-X; why MSI-X won
- [ ] Vector allocation, per-vector handlers, affinity
- [ ] Requesting interrupts from a Rust PCI driver
- [ ] Interrupt storms, spurious interrupts, and shared-interrupt etiquette
- [ ] **Code:** set up MSI-X on your QEMU device, trigger an interrupt from the device model, and handle it

### Day 5 — Hotplug, Unbind, and Lifetime Correctness
- [ ] `echo 1 > /sys/bus/pci/devices/*/remove` and what your driver must survive
- [ ] Surprise removal (a real PCIe hotplug event) vs orderly unbind
- [ ] Why `Revocable` exists: the C API can invalidate your BAR mapping at any time
- [ ] `Device<Bound>` vs `Device<Core>` and what the type states prevent
- [ ] **Code:** stress-test unbind/rebind 1000 times under KASAN while userspace hammers the device. Fix what breaks

### 🔨 Saturday Project
- [ ] **VirtToy v0.1** — the QEMU device and its driver
  - [ ] QEMU PCI device model: identity registers, 2 BARs, a mailbox protocol, a doorbell that raises an interrupt, MSI-X
  - [ ] Rust driver: probe, BAR mapping, typed registers, MSI-X handler, misc device for userspace
  - [ ] One-command launch script; a userspace test that exercises every register

### 📄 Sunday Reading
- [ ] `Documentation/PCI/pci.rst` and `msi-howto.rst`
- [ ] *Linux Device Drivers 3* Ch. 12 (PCI Drivers)
- [ ] `rust/kernel/pci.rs` and `io.rs` source, in full

---

## Week 16 — Interrupts, Workqueues, Timers

### Day 1 — The Interrupt Path
- [ ] From device signal to handler: interrupt controller, vector, IRQ number, handler dispatch
- [ ] `rust/kernel/irq/`: requesting an IRQ, handler return values (`Handled`/`None`), shared IRQs
- [ ] What you may not do in hard IRQ context: sleep, allocate with `GFP_KERNEL`, take a mutex, copy to userspace
- [ ] IRQ affinity and per-CPU interrupts
- [ ] **Code:** register a handler for your VirtToy doorbell; deliberately try to sleep in it and watch the kernel complain

### Day 2 — Top Half / Bottom Half
- [ ] Why the split exists: keep hard IRQ context short
- [ ] Threaded IRQs (`request_threaded_irq`) — the modern default answer
- [ ] Softirqs and tasklets: what they are, and why new code should not use tasklets
- [ ] Workqueues as the general-purpose deferral mechanism; the system workqueue vs your own
- [ ] **Code:** convert your handler to a threaded IRQ, then to a hard IRQ + workqueue, and compare the latency

### Day 3 — Timers and Time
- [ ] `jiffies`, `HZ`, and why they are still relevant
- [ ] `timer_list` (low resolution) vs `hrtimer` (high resolution) — when each is right
- [ ] `rust/kernel/time/`: `Instant`, `Delta`, `Ktime`, timer abstractions
- [ ] Delays: `udelay` (busy-wait) vs `msleep` (sleeping) and which contexts allow which
- [ ] **Code:** a periodic hrtimer that polls your device; measure the actual jitter

### Day 4 — Teardown Without Races
- [ ] The canonical bug: free the data while a timer, work item, or IRQ handler still references it
- [ ] Correct order: disable the device's interrupt source → free the IRQ → cancel timers → flush work → free data
- [ ] `cancel_work_sync`, `del_timer_sync`, and why the `_sync` matters
- [ ] What Rust's `Drop` gives you here, and what it does not — `Drop` order is not automatically the correct teardown order
- [ ] **Code:** deliberately get the order wrong and reproduce a UAF under KASAN; then fix it and prove it

### Day 5 — Concurrency Between Contexts
- [ ] Data shared between a process-context file operation and an IRQ handler: which lock, and why `_irqsave`
- [ ] Per-CPU data as an alternative; `local_irq_save` and its dangers
- [ ] Lockless single-producer/single-consumer patterns with correct barriers
- [ ] Read `Documentation/kernel-hacking/locking.rst` and map each rule to a Rust primitive
- [ ] **Code:** a driver where userspace and the IRQ handler share a ring buffer, verified clean under lockdep and KCSAN

### 🔨 Saturday Project
- [ ] **VirtToy v0.2 + PCIScope v0.1**
  - [ ] VirtToy: MSI-X with multiple vectors, threaded IRQ, deferred work, a hardened teardown path proven by 1000 unbind cycles under KASAN
  - [ ] PCIScope: bind to a device, decode config space and all capabilities, expose everything via debugfs, with a userspace pretty-printer
  - [ ] Report your `unsafe` count in both leaf drivers — target zero

### 📄 Sunday Reading
- [ ] `Documentation/core-api/genericirq.rst` and `Documentation/kernel-hacking/locking.rst`
- [ ] `Documentation/timers/` — `hrtimers.rst`, `timers-howto.rst`
- [ ] "Rust Atomics and Locks" Ch. 7-8 (memory ordering in practice, hardware reality)

---

## 🔄 Buffer Week (Month 4 Revision)
- [ ] Revise char devices, file operations, userspace memory safety, adversarial input handling
- [ ] Revise platform drivers, device tree, bindings, and the discovery mechanisms
- [ ] Revise PCI: config space, BARs, MMIO discipline, MSI-X, hotplug lifetime
- [ ] Revise interrupts: contexts, top/bottom half, threaded IRQs, timers, teardown ordering
- [ ] Stress everything: unbind/rebind loops, adversarial userspace, KASAN + lockdep + KCSAN
- [ ] **Build Monthly Project A:** VirtToy — the Hardware-Free PCI Driver Lab
- [ ] **Build Monthly Project B:** PCIScope — Safe-Rust PCI X-Ray Driver
- [ ] Push both; announce VirtToy on Zulip or kernelnewbies — it solves a real newcomer problem
- [ ] **Gate check:** write a PCI driver from a blank file that probes, maps BARs, handles MSI-X interrupts, and survives hot-unplug

---

## Week 17 — Memory & DMA

### Day 1 — Kernel Memory Allocation, Properly
- [ ] The allocators: slab (`kmalloc`), page allocator, `vmalloc` — sizes, alignment, physical contiguity
- [ ] GFP flags in full: `GFP_KERNEL`, `GFP_ATOMIC`, `GFP_NOWAIT`, `GFP_NOIO`, `GFP_DMA`, `__GFP_ZERO`, `__GFP_NOWARN`
- [ ] Allocation context rules: what you may call while holding a spinlock, in IRQ context, in reclaim
- [ ] `rust/kernel/page.rs` and the page abstraction
- [ ] **Code:** allocate in five different contexts with the right flags; use fault injection (`CONFIG_FAILSLAB`) to force failures and verify your error paths

### Day 2 — Physical vs Virtual vs Bus Addresses
- [ ] Virtual, physical, and DMA (bus) addresses are three different things — this trips up everyone
- [ ] Why a device cannot use a kernel virtual address
- [ ] IOMMU: address translation for devices, isolation, and why it changes your DMA addresses
- [ ] `dma_addr_t`, DMA masks, and addressing limits (32-bit devices on 64-bit systems)
- [ ] **Code:** print virtual, physical, and DMA addresses for the same buffer and explain the relationship

### Day 3 — Coherent DMA
- [ ] `rust/kernel/dma.rs`: `CoherentAllocation`, `dma::Device`, mask setting
- [ ] What "coherent" means: the CPU and device see the same data without explicit synchronization
- [ ] Cost: uncached or write-combining memory, so CPU access is slow
- [ ] Descriptor rings as the canonical use case
- [ ] **Code:** add a DMA descriptor ring to VirtToy's QEMU device and drive it with coherent memory from your driver

### Day 4 — Streaming DMA and Cache Coherency
- [ ] Map/unmap lifecycle; `DMA_TO_DEVICE`, `DMA_FROM_DEVICE`, `DMA_BIDIRECTIONAL`
- [ ] Why direction matters: cache flush vs invalidate, and what corruption looks like when it is wrong
- [ ] `dma_sync_*` for partial access while mapped
- [ ] The rules: do not touch a buffer while it is mapped for the device; unmap before freeing
- [ ] **Code:** implement the streaming path; deliberately access a mapped buffer and observe (or fail to observe) corruption — then explain why the failure is architecture-dependent

### Day 5 — Scatter-Gather and IOMMU
- [ ] Why SG lists exist: userspace buffers are physically fragmented
- [ ] `rust/kernel/scatterlist.rs`; building, mapping, and iterating SG lists
- [ ] How the IOMMU can coalesce an SG list into one contiguous device address
- [ ] `rust/kernel/iommu.rs` and what device isolation buys you
- [ ] **Code:** implement the SG path; measure throughput with IOMMU on and off and explain the difference

### 🔨 Saturday Project
- [ ] **DMAForge v0.1** — the DMA lab
  - [ ] VirtToy's QEMU DMA engine: descriptor ring, source/dest/length, completion interrupt
  - [ ] All three driver paths: coherent, streaming, scatter-gather
  - [ ] Benchmark harness: throughput and latency vs transfer size per strategy, with plots
  - [ ] Start the **bug museum**: implement use-after-unmap and wrong-direction bugs, and document what caught them

### 📄 Sunday Reading
- [ ] `Documentation/core-api/dma-api.rst` and `dma-api-howto.rst` — read both completely, they are essential
- [ ] `Documentation/core-api/cachetlb.rst` — the cache coherency reality
- [ ] `Documentation/core-api/memory-allocation.rst`

---

## Week 18 — I2C, SPI, GPIO, clk, regulator, PWM

### Day 1 — I2C
- [ ] I2C protocol: addresses, start/stop, ACK, clock stretching, repeated start, bus speeds
- [ ] `rust/kernel/i2c.rs`: `i2c::Driver`, client devices, transfers
- [ ] Register access patterns over I2C; why regmap exists in C and what Rust offers
- [ ] Error handling: NAK, bus arbitration loss, timeouts — I2C fails often and your driver must cope
- [ ] **Code:** an I2C driver that reads a chip ID; on your real board if possible, otherwise with an emulated I2C device

### Day 2 — SPI
- [ ] SPI protocol: modes 0-3, CS handling, full duplex, word size, bit order
- [ ] SPI driver structure; message and transfer objects; DMA-capable SPI
- [ ] Comparing I2C and SPI: speed, pin count, addressing, error detection
- [ ] **Code:** an SPI driver reading a device register; observe the actual bus traffic if you have a logic analyzer

### Day 3 — GPIO, clk, regulator
- [ ] GPIO: consumer API (request, direction, get/set, IRQ from a GPIO line)
- [ ] Clock framework: get, prepare, enable, rate setting, and why order matters
- [ ] Regulators: get, enable, voltage setting, and the "my device does not respond because it has no power" bug
- [ ] The resource acquisition order in `probe()` — regulators before clocks before resets before register access
- [ ] **Code:** a driver that acquires a regulator, a clock, and a GPIO reset line in the correct order, with correct release on failure

### Day 4 — PWM, and Subsystem Integration Patterns
- [ ] `rust/kernel/pwm.rs`: providing or consuming PWM
- [ ] The consumer/provider pattern that recurs everywhere in the kernel
- [ ] `hwmon` for sensors, `IIO` for industrial I/O: which to choose for what
- [ ] What "integrating with a subsystem" means: your driver implements a contract, and standard userspace tools work for free
- [ ] **Code:** integrate your sensor driver with hwmon or IIO and verify `sensors` or `iio_info` sees it

### Day 5 — Choosing Your Upstream Target
- [ ] Survey: find an I2C or SPI device with a clean, public datasheet and no existing Rust driver
- [ ] Check `lore.kernel.org` that nobody is already doing it
- [ ] Check that the abstractions you need exist — if one is missing, that is a Month 10 project and you should pick differently for now
- [ ] Read three recently-merged C drivers for similar devices, and their review threads
- [ ] **Code:** order the part if you have not; write your driver's skeleton and its binding YAML

### 🔨 Saturday Project
- [ ] **SensorRS v0.1** — the real driver
  - [ ] Probe from device tree, read chip ID, configure, take a measurement
  - [ ] Binding YAML passing `dt_binding_check`
  - [ ] Running on your real board with real readings captured as evidence
  - [ ] `checkpatch` clean; `get_maintainer` recipient list prepared

### 📄 Sunday Reading
- [ ] `Documentation/i2c/writing-clients.rst` and `Documentation/spi/spi-summary.rst`
- [ ] `Documentation/driver-api/gpio/`, `clk.rst`, and `regulator.rst`
- [ ] `Documentation/hwmon/hwmon-kernel-api.rst` or `Documentation/driver-api/iio/` — whichever you chose

---

## Week 19 — sysfs, debugfs, configfs, Module Params

### Day 1 — sysfs and the Device Model's Public Face
- [ ] Attributes, attribute groups, `show`/`store`; one value per file
- [ ] Permissions, and why a writable sysfs file is a security surface
- [ ] `Documentation/ABI/` and the stability classes: `stable`, `testing`, `obsolete`, `removed`
- [ ] The current state of Rust sysfs attribute abstractions (RFC in flight — check `lore.kernel.org` before assuming)
- [ ] **Code:** expose driver state through sysfs, and write the `Documentation/ABI/` entry for it

### Day 2 — debugfs and seq_file
- [ ] debugfs as the unstable, developer-facing counterpart to sysfs — no ABI guarantees, so you can be generous
- [ ] `rust/kernel/debugfs.rs`: creating files and directories with device-tied lifetime
- [ ] `seq_file` for multi-line, iterator-driven output
- [ ] What belongs in debugfs: internal state, statistics, register dumps, injection knobs
- [ ] **Code:** a debugfs tree for VirtToy exposing every register and every internal counter

### Day 3 — configfs and Runtime Object Creation
- [ ] configfs vs sysfs: userspace *creates* objects, rather than just reading kernel-created ones
- [ ] `rust/kernel/configfs.rs`
- [ ] The `null_blk` model: create devices with `mkdir`, configure with attribute writes
- [ ] When configfs is the right interface (and when an ioctl or netlink is better)
- [ ] **Code:** a configfs interface that creates configurable instances of a virtual device

### Day 4 — Module Parameters and Runtime Configuration
- [ ] `rust/kernel/module_param.rs`; types, permissions, `/sys/module/*/parameters/`
- [ ] Read-only at load vs writable at runtime, and the locking implications of the latter
- [ ] When module parameters are the wrong answer (almost always, for new drivers)
- [ ] `dynamic_debug` for runtime log control instead of a debug parameter
- [ ] **Code:** add parameters where appropriate; convert a debug parameter to `pr_debug` + dynamic debug

### Day 5 — Interface Design Judgment
- [ ] The decision table: sysfs vs debugfs vs configfs vs ioctl vs netlink vs a char device
- [ ] One-value-per-file, no parsing in the kernel, no complex formats in sysfs
- [ ] How to add capability without breaking anything: new files, feature flags, versioned structs
- [ ] Review reality: interface design draws the most maintainer scrutiny of anything you will submit
- [ ] **Code:** write your driver's interface design document and critique it against the table

### 🔨 Saturday Project
- [ ] **KModKit v0.4** — module `06-debugfs`, plus full interface coverage
  - [ ] sysfs attributes with an ABI document, debugfs with `seq_file`, configfs instance creation, module parameters
  - [ ] A written interface design rationale explaining each choice
  - [ ] Adversarial tests: what happens if userspace writes garbage to every writable file?

### 📄 Sunday Reading
- [ ] `Documentation/filesystems/sysfs.rst`, `debugfs.rst`, `configfs.rst`
- [ ] `Documentation/ABI/README` and browse a few real ABI entries
- [ ] `Documentation/admin-guide/abi.rst` — the stability promise from the user's side

---

## Week 20 — Power Management

### Day 1 — Runtime PM
- [ ] The idea: power down a device the moment nobody is using it
- [ ] `pm_runtime_get_sync`/`put`, usage counters, autosuspend delay
- [ ] `runtime_suspend`/`runtime_resume`/`runtime_idle` callbacks and what each must do
- [ ] Parent/child dependencies and why the device tree of power domains matters
- [ ] **Code:** implement runtime PM for VirtToy; add tracing to prove the callbacks actually fire

### Day 2 — System Suspend and Resume
- [ ] Suspend-to-idle, standby, suspend-to-RAM, hibernate — what each requires of a driver
- [ ] `suspend`/`resume`, `freeze`/`thaw`, `poweroff`/`restore` callbacks
- [ ] Saving and restoring device state; what survives and what must be reprogrammed
- [ ] The hard cases: in-flight DMA at suspend time, interrupts during resume, wakeup sources
- [ ] **Code:** implement suspend/resume; test with `echo mem > /sys/power/state` (or `rtcwake`) with I/O in flight

### Day 3 — Power Domains, OPP, and cpufreq
- [ ] Generic power domains and why SoCs need them
- [ ] Operating Performance Points: voltage/frequency pairs; `rust/kernel/opp.rs`
- [ ] cpufreq drivers in Rust (`rust/kernel/cpufreq.rs`) and the governor relationship
- [ ] Devfreq for non-CPU devices
- [ ] **Code:** read the Rust cpufreq abstraction and write down how you would use it

### Day 4 — Testing Power Management Properly
- [ ] `/sys/power/pm_test` for exercising suspend paths without a full suspend
- [ ] `pm_trace` for finding which driver broke resume
- [ ] Measuring: does the device actually draw less power, or did you just call the callback?
- [ ] The classic bugs: forgetting to re-enable interrupts, losing register state, deadlocking on a lock held across suspend
- [ ] **Code:** deliberately break resume three ways and diagnose each with the PM debugging tools

### Day 5 — Prepare the SensorRS Submission
- [ ] Complete runtime PM on the real sensor driver, with measured evidence
- [ ] Final review pass against `Documentation/process/submit-checklist.rst`
- [ ] `checkpatch --strict`, `rustfmt`, `clippy`, build with `W=1`
- [ ] Write the cover letter: what, why, how tested, what hardware
- [ ] **Code:** build the patch series with `git format-patch`, review each patch as if you were the maintainer

### 🔨 Saturday Project
- [ ] **SensorRS v1.0 — Submit It**
  - [ ] Full driver: probe, DT binding, hwmon/IIO integration, runtime PM, error paths, teardown
  - [ ] Tested on real hardware with captured evidence
  - [ ] Series sent to the right list with the right people on Cc
  - [ ] **This is your first real driver submission. Whatever the response, this is the milestone.**

### 📄 Sunday Reading
- [ ] `Documentation/power/runtime_pm.rst` — the whole thing
- [ ] `Documentation/power/suspend-and-interrupts.rst` and `pm_qos_interface.rst`
- [ ] `Documentation/process/submit-checklist.rst` — again, now that it means something

---

## 🔄 Buffer Week (Month 5 Revision)
- [ ] Revise memory and DMA: allocators, GFP flags, coherent vs streaming, SG lists, IOMMU
- [ ] Revise buses: I2C, SPI, GPIO, clk, regulator, PWM, and resource acquisition order
- [ ] Revise interfaces: sysfs, debugfs, configfs, module params, and ABI stability
- [ ] Revise power management: runtime PM, suspend/resume, testing and measuring
- [ ] Respond to any review feedback on your SensorRS submission — this takes priority over everything
- [ ] **Build Monthly Project A:** DMAForge — DMA, Scatter-Gather and IOMMU Lab
- [ ] **Build Monthly Project B:** SensorRS — the upstreamable driver (submitted, iterating on review)
- [ ] Push both; publish the DMA bug museum write-up
- [ ] **Gate check:** you have a patch series in review on a real kernel mailing list

---

## Week 21 — RCU, LKMM, lockdep: Concurrency For Real

### Day 1 — RCU From First Principles
- [ ] The problem RCU solves: readers that must never block, with writers that must not corrupt them
- [ ] `rcu_read_lock`/`rcu_read_unlock` — what they actually do (often nothing but disable preemption)
- [ ] Grace periods, `synchronize_rcu`, `call_rcu`, `kfree_rcu`
- [ ] Publish-subscribe: `rcu_assign_pointer`/`rcu_dereference` and the barriers they hide
- [ ] Why RCU is not an rwlock: readers see *either* the old or the new version, and that must be acceptable
- [ ] **Code:** implement an RCU-protected list in a module; verify readers never block under writer load

### Day 2 — RCU in Rust, and Its Limits
- [ ] `rust/kernel/sync/rcu.rs` and what is currently available
- [ ] Why RCU is hard to make safe in Rust: the lifetime of an RCU-protected reference is a dynamic property
- [ ] `RcuRef`-style patterns and their constraints
- [ ] Honest assessment: this is an area where the Rust abstractions are still maturing. Read the discussions
- [ ] **Code:** use the available RCU abstraction; document precisely what invariant you must uphold manually

### Day 3 — The Linux Kernel Memory Model
- [ ] Why the kernel has its own memory model, distinct from C11 and from Rust's
- [ ] `READ_ONCE`/`WRITE_ONCE` and what they prevent
- [ ] Control dependencies, address dependencies, and why the compiler can break them
- [ ] `smp_mb`, `smp_rmb`, `smp_wmb`, `smp_load_acquire`, `smp_store_release`
- [ ] `tools/memory-model/`: run `herd7` on a litmus test and see the model answer a question for you
- [ ] **Code:** write three litmus tests, predict the outcomes, then check with `herd7`

### Day 4 — lockdep and KCSAN in Anger
- [ ] How lockdep builds a lock dependency graph and what it can prove
- [ ] Reading a lockdep report: the two chains, the class names, the "possible unsafe locking scenario"
- [ ] Lock classes for dynamically allocated locks, and why Rust's `LockClassKey` exists
- [ ] KCSAN: what a data race report means, and why "benign" races usually are not
- [ ] **Code:** trigger and fix one lockdep report and one KCSAN report in your own code

### Day 5 — Designing a Locking Scheme
- [ ] The design process: enumerate the data, enumerate the accessors, enumerate the contexts, then choose
- [ ] Documenting the scheme in a comment block — every serious driver does this and reviewers look for it
- [ ] Reducing lock scope; avoiding nested locks; the "one lock per object" default
- [ ] When to reach for RCU, per-CPU data, or lockless patterns instead of a lock
- [ ] **Code:** write the locking design comment for BlockForge before you write BlockForge

### 🔨 Saturday Project
- [ ] **LockProof v0.1** — the concurrency bug museum, kernel edition
  - [ ] Port your userspace bug museum into kernel modules: C version and attempted Rust version for each bug
  - [ ] Harness: build each, boot under lockdep/KCSAN, record which tool caught what
  - [ ] Draft the three-column table: prevented at compile time / caught by tooling / still your problem

### 📄 Sunday Reading
- [ ] `Documentation/RCU/whatisRCU.rst` and `rcu_dereference.rst`
- [ ] **"Is Parallel Programming Hard, And, If So, What Can You Do About It?"** (McKenney, free) — the RCU chapters. This is the definitive source
- [ ] `tools/memory-model/Documentation/explanation.txt` — dense, essential, worth multiple passes

---

## Week 22 — Kernel Data Structures in Rust

### Day 1 — Intrusive Linked Lists
- [ ] Why the kernel uses intrusive lists: no allocation to insert, `container_of` to get back to the object
- [ ] `rust/kernel/list/`: `List`, `ListArc`, `ListLinks`, `impl_list_item!`
- [ ] Why intrusive nodes force pinning — the connection back to Week 7
- [ ] `container_of` in Rust and how the abstraction hides its `unsafe`
- [ ] **Code:** build a driver structure held in an intrusive list; iterate, insert, remove, and prove no leaks

### Day 2 — Trees and Maps
- [ ] `rust/kernel/rbtree.rs`: red-black trees for ordered data
- [ ] `rust/kernel/xarray.rs`: sparse arrays indexed by integer — the modern replacement for `idr` and radix trees
- [ ] `rust/kernel/maple_tree.rs`: range-based storage
- [ ] Choosing between them: access pattern, key type, memory overhead, lock granularity
- [ ] **Code:** implement the same lookup with an `RBTree` and an `XArray`; measure both

### Day 3 — IDs, Bitmaps, and Small Utilities
- [ ] `rust/kernel/id_pool.rs` and `bitmap.rs`: allocating and tracking small integer IDs
- [ ] `rust/kernel/cpumask.rs` for CPU sets
- [ ] `rust/kernel/sizes.rs`, `bits.rs`, `num.rs` — the small helpers that keep code readable
- [ ] `ScopeGuard` for cleanup that does not fit `Drop`
- [ ] **Code:** replace an ad-hoc ID allocation in one of your drivers with `id_pool`

### Day 4 — Reference Counting Patterns at Scale
- [ ] `kref` in C and `AlwaysRefCounted`/`ARef` in Rust
- [ ] The object lifecycle: creation, publication, lookup-and-get, put, release
- [ ] The classic race: lookup finds an object whose refcount just hit zero — and how the lock/RCU combination prevents it
- [ ] Reference-counting bugs and why they are the most common kernel UAF cause
- [ ] **Code:** implement a refcounted object registry with correct lookup-and-get semantics, and stress it

### Day 5 — Per-CPU Data and Scalability
- [ ] Per-CPU variables: why they eliminate cache-line contention
- [ ] `this_cpu_*` semantics and preemption requirements
- [ ] Aggregating per-CPU counters; the read-side cost
- [ ] Cache-line alignment and false sharing — and how to measure it
- [ ] **Code:** convert a globally-locked counter to per-CPU and measure the scalability difference

### 🔨 Saturday Project
- [ ] **BlockForge v0.1** — start the block driver
  - [ ] Register a `gendisk`, handle simple read/write requests, memory-backed storage
  - [ ] Use the data structures from this week for request tracking
  - [ ] The locking design comment written before the code, and lockdep clean

### 📄 Sunday Reading
- [ ] `Documentation/core-api/xarray.rst` and `kernel-api.rst` (data structure sections)
- [ ] `Documentation/core-api/kref.rst`
- [ ] "Learn Rust With Entirely Too Many Linked Lists" — the unsafe/intrusive chapters, for the Rust perspective

---

## Week 23 — The Block Layer in Rust

### Day 1 — Block Layer Architecture
- [ ] The stack: filesystem → page cache → block layer → driver → device
- [ ] `bio` vs `request`; merging, splitting, and why the block layer does it
- [ ] blk-mq: multiple hardware and software queues, per-CPU submission, tag allocation
- [ ] `gendisk`, partitions, and how a block device appears in `/dev`
- [ ] **Read C:** `drivers/block/null_blk/` — the reference implementation for exactly what you are building

### Day 2 — Rust Block Abstractions
- [ ] `rust/kernel/block/mq/`: `Operations`, `TagSet`, `GenDisk`, `Request`, `RequestDataWrapper`
- [ ] Read `drivers/block/rnull.rs` in full — it is short and it is your template
- [ ] Request lifecycle from Rust: `queue_rq`, completion, error return
- [ ] Reference counting on requests and why the abstraction uses `ARef`
- [ ] **Code:** extend BlockForge to handle multi-segment requests correctly

### Day 3 — Correctness: Flush, FUA, and Ordering
- [ ] Write caching and what a filesystem assumes about durability
- [ ] `REQ_PREFLUSH`, `REQ_FUA`, and the contract you must honor
- [ ] Why violating flush semantics silently corrupts filesystems after a power loss
- [ ] Discard, write-zeroes, and other operations you should support or explicitly reject
- [ ] **Code:** implement flush/FUA correctly; then add a mode that violates it deliberately, for testing filesystems

### Day 4 — Fault and Latency Injection
- [ ] Why storage testing needs deterministic failure: real failures are rare and non-reproducible
- [ ] Designing the injection model: what fails, when, how often, and how a user describes it
- [ ] Latency distributions: fixed, uniform, and heavy-tail (because real devices have tail latency)
- [ ] configfs as the configuration interface, matching `null_blk` conventions
- [ ] **Code:** implement error and latency injection with a declarative scenario file format

### Day 5 — Testing With Real Filesystems
- [ ] `fio` for I/O benchmarking: job files, IOPS, latency percentiles, and how to not lie with benchmarks
- [ ] `xfstests`/`fstests`: running a filesystem test suite against your device
- [ ] `blktrace`/`blkparse` for seeing what the block layer actually did
- [ ] The experiment: which filesystems survive which failure patterns?
- [ ] **Code:** run `xfstests` on ext4/xfs/btrfs over BlockForge under 3 failure scenarios; record the matrix

### 🔨 Saturday Project
- [ ] **BlockForge v0.5**
  - [ ] Multi-queue, correct flush/FUA, error and latency injection, configfs configuration
  - [ ] `fio` benchmark vs `null_blk` with latency percentiles
  - [ ] First `xfstests` runs and the failure matrix started
  - [ ] Clean under lockdep and KCSAN

### 📄 Sunday Reading
- [ ] `Documentation/block/` — `blk-mq.rst`, `writeback_cache_control.rst`, `biodoc` if present
- [ ] `drivers/block/rnull.rs` and the `rust/kernel/block/` source in full
- [ ] LWN: search for block layer and blk-mq articles; read two

---

## Week 24 — Networking in Rust

### Day 1 — The Network Stack From a Driver's View
- [ ] `net_device`, `netdev_ops`, and the transmit/receive paths
- [ ] `sk_buff`: the structure everything revolves around — headroom, tailroom, fragments, ownership
- [ ] NAPI: polling instead of per-packet interrupts, and why it exists
- [ ] Queue discipline, multiqueue, and RSS at a conceptual level
- [ ] **Read C:** a simple, real network driver's transmit and receive path

### Day 2 — Rust Networking Abstractions
- [ ] `rust/kernel/net/`: what exists today (`phy`, and the pieces around it)
- [ ] Read `drivers/net/phy/ax88796b_rust.rs` — the first useful Rust driver in the kernel, and short enough to fully understand
- [ ] `rust/kernel/net/phy.rs`: the `Driver` trait, register access, link state
- [ ] Honest gap assessment: full netdev drivers in Rust are not yet a solved problem — note what is missing
- [ ] **Code:** write a PHY driver skeleton for a real PHY; even if you cannot test it, get it to compile and review it against the ASIX driver

### Day 3 — PHY Drivers in Depth
- [ ] What a PHY does: MDIO management interface, auto-negotiation, link status, cable diagnostics
- [ ] MDIO bus, PHY addresses, standard vs vendor registers (IEEE 802.3 clause 22/45)
- [ ] `config_init`, `read_status`, `config_aneg`, `suspend`/`resume` callbacks
- [ ] Why PHYs were the first Rust target: small, well-specified, contained
- [ ] **Code:** implement `read_status` and `config_init` for a documented PHY; validate against the datasheet

### Day 4 — Netlink and Configuration Interfaces
- [ ] Why netlink exists and why it beats ioctl for network configuration
- [ ] `ethtool` operations and what a driver should expose
- [ ] `rtnetlink` and how `ip link` reaches your driver
- [ ] Statistics: what to count and where userspace reads it
- [ ] **Code:** read how `ethtool` ops flow to a driver and document the path

### Day 5 — Six-Month Consolidation
- [ ] Re-read every driver you have written; find the pattern you keep repeating and extract it
- [ ] Audit every `unsafe` block across all your code with SafetyLint; fix every weak comment
- [ ] Run every module under KASAN + KCSAN + lockdep + `kmemleak` in one session; fix everything
- [ ] Update RustScope with what you now know is missing from the abstractions
- [ ] **Journal:** write your six-month retrospective — what you can do now that you could not in Week 0, and what still frightens you

### 🔨 Saturday Project
- [ ] **BlockForge v1.0 + LockProof v1.0** — finish both for the milestone
  - [ ] BlockForge: complete failure matrix across 3 filesystems and 5 scenarios, benchmarks vs `null_blk`, scenario file format documented
  - [ ] LockProof: all 15 bug pairs, automated harness, the three-column analysis written up
  - [ ] Both with READMEs a maintainer would respect

### 📄 Sunday Reading
- [ ] `Documentation/networking/` — `phy.rst`, `netdevices.rst`, `napi.rst`
- [ ] `drivers/net/phy/ax88796b_rust.rs` plus its original submission thread on `lore.kernel.org`
- [ ] Paper: "The benefits and costs of writing a POSIX kernel in a high-level language" (Cutler et al., OSDI 2018) — the honest cost accounting

---

### ✅ Phase 2 Completion Checklist (6-MONTH MILESTONE)
- [ ] Can write a PCI driver in Rust: probe, BARs, typed MMIO, MSI-X, interrupts, clean teardown, hot-unplug safe
- [ ] Can write a platform driver with a device tree binding that passes `dt_binding_check`
- [ ] Can set up coherent, streaming, and scatter-gather DMA correctly and explain the cache coherency rules
- [ ] Can write an I2C or SPI driver for real hardware and integrate it with hwmon or IIO
- [ ] Can design a userspace interface (sysfs/debugfs/configfs/ioctl) and justify the choice
- [ ] Can implement and verify runtime PM and system suspend/resume
- [ ] Can explain RCU, the Linux Kernel Memory Model, and design a documented locking scheme
- [ ] Can read and fix lockdep and KCSAN reports
- [ ] Can write a multi-queue block driver that honors flush/FUA semantics
- [ ] Can read a Rust network PHY driver and explain every line
- [ ] Have a patch series in review on a real kernel mailing list
- [ ] Have zero `unsafe` blocks in your leaf drivers, or a written justification for each one that exists

[⬆ Back to Table of Contents](#toc)

---

## 🔄 Buffer Week (Month 6 Revision) ⭐ 6-MONTH MILESTONE
- [ ] Revise all of Phase 2: char devices, platform, PCI, interrupts, DMA, buses, interfaces, PM, concurrency, block, net
- [ ] Re-derive from memory: the resource acquisition order in `probe()`, the teardown order in `remove()`
- [ ] Re-derive from memory: which sync primitive is legal in which context, and why
- [ ] Rebuild and re-test everything from clean; confirm your whole lab still works
- [ ] **Build Monthly Project A:** BlockForge — Rust Block Driver with Fault Injection ⭐
- [ ] **Build Monthly Project B:** LockProof — What Rust Actually Buys Kernel Concurrency
- [ ] Publish LockProof's findings; consider a Kangrejos or Linux Plumbers lightning talk proposal
- [ ] Push everything; write your six-month portfolio page
- [ ] **Gate check:** you can write a driver you would defend in a mailing-list review, and you have done so

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# PHASE 3: SUBSYSTEM DEPTH (Weeks 25-36, Months 7-9)
# Filesystems, Binder, Tracing, DRM/GPU, Nova
# ═══════════════════════════════════════════════════

> From here the format shifts from day-by-day to **topics + exercises + weekly projects**.
> You have the study habits now; what you need is depth and the freedom to follow the code.
> Each block is 2 weeks. Keep the rhythm: weekdays for topics, Saturday for the build, Sunday for reading.

---

## Week 25-26 — Filesystems in Rust

### Topics
- [ ] VFS object model: `super_block`, `inode`, `dentry`, `file` — and the lifetime rules for each
- [ ] The dcache: how path lookup works, negative dentries, why lookup is the hot path
- [ ] `super_operations`, `inode_operations`, `file_operations`, `address_space_operations` — which does what
- [ ] Mount lifecycle: `fs_context`, mount options, `fill_super`, unmount and the "busy" problem
- [ ] Page cache: how file data is cached, `read_folio`, readahead, and why filesystems rarely do their own I/O
- [ ] `mmap` of file pages and the fault path
- [ ] Read-only filesystem design: the simplest correct thing you can build
- [ ] `rust/kernel/fs.rs` and `rust/kernel/fs/` — what abstractions exist today
- [ ] The in-tree Rust filesystem efforts (tarfs, PuzzleFS) — read what has been posted and what the review said
- [ ] Filesystems as a hostile-input problem: every byte on disk is attacker-controlled
- [ ] Integer overflow, unchecked indexing, and unbounded recursion in image parsers — the classic fs CVE pattern

### Code Exercises
- [ ] Read a small C filesystem completely: `romfs` or `cramfs` — trace mount, lookup, and read
- [ ] Design an on-disk format for your read-only fs: superblock, inode table, directory entries, data blocks
- [ ] Implement mount and `fill_super`; get `mount` to succeed and `umount` to be clean
- [ ] Implement `lookup` and `readdir`; get `ls` to work
- [ ] Implement `read_folio`; get `cat` to work
- [ ] Verify `mmap` on a file works and returns correct data
- [ ] 1000 mount/unmount cycles under KASAN and `kmemleak` with no leaks
- [ ] Write a malformed-image generator: truncated, oversized lengths, cyclic directories, overlapping extents
- [ ] Run the fuzzer for 24+ hours under KASAN; triage and minimize every crash

### 🔨 Saturday Projects
- [ ] **Week 25:** TarFS-RS mounts a valid image; `ls` and `cat` work; mount/unmount is leak-free
- [ ] **Week 26:** Fuzzing harness running; crash corpus triaged; comparison write-up against a C read-only fs

### 📄 Sunday Reading
- [ ] `Documentation/filesystems/vfs.rst` — the whole document, twice
- [ ] `Documentation/filesystems/porting.rst` — a history of every VFS mistake, which is educational
- [ ] `Documentation/filesystems/path-lookup.rst`
- [ ] The tarfs/PuzzleFS submission threads on `lore.kernel.org`

---

## Week 27 — Binder: The Production Rust Driver Case Study

### Topics
- [ ] What Binder is: Android's IPC mechanism, and why it is performance- and security-critical
- [ ] The Binder object model: nodes, references, transactions, death notifications
- [ ] Why Binder was chosen as the flagship Rust rewrite: high security value, well-understood semantics, a maintainer willing to accept it
- [ ] Read `drivers/android/` Rust source in full — it is the largest, most mature Rust driver in the tree
- [ ] Its concurrency design: what locks, what refcounting, what lifetime rules
- [ ] Its `unsafe` usage: find every block and read every safety comment critically
- [ ] Its uAPI compatibility: it must be bit-identical to the C driver, because Android userspace exists
- [ ] The review history: read the submission threads across versions and note what changed and why
- [ ] Performance: how the Rust version was benchmarked against the C version, and what the results were

### Code Exercises
- [ ] Build a kernel with Rust Binder enabled and exercise it (an Android emulator image or a userspace test harness)
- [ ] Draw the object graph: which structures reference which, with refcount ownership marked
- [ ] Extract three design patterns from Binder that you can reuse in your own drivers
- [ ] Find one thing you would have done differently, and write down why — then check whether a reviewer said the same thing
- [ ] Trace one transaction end to end through the Rust code with ftrace

### 🔨 Saturday Project
- [ ] **Binder Study Write-Up** — a genuine technical analysis: architecture, concurrency design, `unsafe` audit, patterns worth stealing, and lessons from its review history
- [ ] Publish it. A careful third-party analysis of Binder's Rust design is a contribution in itself, and it will get read

### 📄 Sunday Reading
- [ ] The Rust Binder submission cover letters on `lore.kernel.org` — all versions, in order
- [ ] LWN's coverage of Rust Binder
- [ ] Any conference talk on Rust Binder you can find (Kangrejos, Linux Plumbers, LSS)

---

## Week 28 — Tracing, ftrace, perf, eBPF Interaction

### Topics
- [ ] Tracepoints: static instrumentation, zero cost when disabled, stable-ish ABI implications
- [ ] `TRACE_EVENT` in C and the current story for defining tracepoints from Rust
- [ ] ftrace: function tracer, function graph tracer, event tracing, trace markers, filters and triggers
- [ ] `trace-cmd` and `kernelshark` for capture and visualization
- [ ] `perf`: sampling, counters, `perf probe` for dynamic tracepoints, flame graphs
- [ ] Static keys / jump labels (`rust/kernel/jump_label.rs`) — how "zero cost when off" actually works
- [ ] eBPF from the kernel side: what a BPF program can attach to, and how your tracepoints become observable
- [ ] `bpftrace` one-liners as a driver developer's best friend
- [ ] `dynamic_debug`: runtime control of `pr_debug`
- [ ] Histogram triggers and latency measurement without userspace involvement
- [ ] Observability design: what state a driver should expose, and at what cost

### Code Exercises
- [ ] Add tracepoints to VirtToy and BlockForge; verify with `trace-cmd record`
- [ ] Build a latency histogram for a driver operation using histogram triggers
- [ ] Write a `bpftrace` script that observes your driver's tracepoints and computes statistics
- [ ] Use the function graph tracer to find where time actually goes in your driver's request path
- [ ] Generate a flame graph of a workload driving your block device
- [ ] Instrument a state machine so every transition is traced with before/after state and reason
- [ ] Find one real performance surprise in your own code using tracing, and fix it

### 🔨 Saturday Project
- [ ] **TraceRust v1.0** — the tracing story for Rust drivers
  - [ ] Ergonomic tracepoint patterns, state-machine instrumentation, latency histograms
  - [ ] A userspace TUI showing live driver state, queue depths, error counters, and an event stream
  - [ ] Retrofitted onto VirtToy and BlockForge; one real bug found with it and documented
  - [ ] The write-up: "how to make a Rust kernel driver observable"

### 📄 Sunday Reading
- [ ] `Documentation/trace/` — `ftrace.rst`, `events.rst`, `tracepoints.rst`, `histogram.rst`
- [ ] `Documentation/staticke*`/`Documentation/core-api/static-keys.rst`
- [ ] Brendan Gregg's writing on flame graphs and kernel tracing methodology

---

## 🔄 Buffer Week (Month 7 Revision)
- [ ] Revise VFS: object model, lifetimes, mount lifecycle, page cache, hostile-input handling
- [ ] Revise Binder's architecture and the patterns you extracted
- [ ] Revise tracing: tracepoints, ftrace, perf, eBPF, static keys, observability design
- [ ] Continue responding to review on any in-flight series — always the priority
- [ ] **Build Monthly Project A:** TarFS-RS — a fuzz-hardened read-only Rust filesystem
- [ ] **Build Monthly Project B:** TraceRust — tracing and live state inspection for Rust drivers
- [ ] Publish the Binder analysis and the observability guide
- [ ] **Gate check:** you can implement against a real subsystem's contract and make your code observable

---

## Week 29-30 — DRM & KMS Fundamentals

### Topics
- [ ] The DRM framework: why GPU drivers are their own world; `drm_device`, driver features, minor nodes
- [ ] Primary node vs render node vs lease — and the security model behind the split
- [ ] KMS object model: CRTC, encoder, connector, plane, framebuffer, property
- [ ] Mode enumeration: EDID, mode validation, and what a connector reports
- [ ] Atomic modesetting: the `check` phase (validate, no side effects) and the `commit` phase (apply, cannot fail)
- [ ] Why atomic replaced the legacy API: all-or-nothing state changes
- [ ] vblank handling, page flips, and event delivery to userspace
- [ ] `drm_gem_shmem` and dumb buffers: the simple path to a working display
- [ ] The DRM uAPI: ioctls, capabilities, and the "your uAPI is forever" rule applied to GPUs
- [ ] `rust/kernel/drm/` — what abstractions exist, what is still C-only
- [ ] `vkms` (virtual KMS, in C) as the reference minimal driver — read it completely

### Code Exercises
- [ ] Read `vkms` end to end; draw its object graph
- [ ] Register a DRM device from Rust with correct feature flags
- [ ] Implement a connector that reports one fixed mode; get `modetest` to enumerate it
- [ ] Implement CRTC + primary plane with atomic check and commit
- [ ] Implement dumb buffer creation and mapping
- [ ] Implement a page flip with vblank event delivery
- [ ] Boot it in QEMU; run `modetest -s` to set a mode; capture the result
- [ ] Get a compositor (Weston headless, or Sway) running on it; screenshot as proof

### 🔨 Saturday Projects
- [ ] **Week 29:** TinyDRM registers, enumerates a mode, and `modetest` sees it
- [ ] **Week 30:** Atomic modeset works, dumb buffers work, page flips deliver vblank events, a compositor runs

### 📄 Sunday Reading
- [ ] `Documentation/gpu/drm-internals.rst`, `drm-kms.rst`, `drm-uapi.rst`
- [ ] `Documentation/gpu/introduction.rst` and `drm-kms-helpers.rst`
- [ ] Any recent XDC talk on DRM internals or the atomic API

---

## Week 31-32 — GEM, dma-fence, Scheduling, GPUVM/VM_BIND

### Topics
- [ ] GEM: buffer object lifecycle, handles vs objects, refcounting, mmap, `dma-buf` export/import
- [ ] Memory domains, CPU/GPU coherency, and cache management for GPU buffers
- [ ] `dma-buf` as the cross-driver sharing mechanism; importing a buffer from another device
- [ ] Command submission: how userspace hands work to the GPU; ring buffers and doorbells
- [ ] `dma-fence`: the contract, signaling rules, `dma_fence_ops`, and the "you must signal eventually" rule
- [ ] `dma_resv`: the reservation object attached to every buffer, and the implicit sync it provides
- [ ] Fence deadlocks: the classic patterns, and why the rules around allocation-in-signaling-path exist
- [ ] The DRM scheduler: entities, jobs, dependencies, timeout handling, and GPU reset
- [ ] DRM GPUVM: managing a GPU's virtual address space in the kernel
- [ ] VM_BIND and EXEC: explicit address-space management, the model Vulkan requires
- [ ] Why VM_BIND replaced implicit per-submission relocation, and what it means for drivers
- [ ] The kernel↔Mesa split: uAPI on one side, NVK/Zink/Vulkan on the other

### Code Exercises
- [ ] Read `drm_gem.c`, `dma-fence` core, and `drm_sched_main` — the three files that define the model
- [ ] Implement GEM object management in TinyDRM with correct refcounting under concurrent close
- [ ] Export a GEM buffer as a `dma-buf` and import it into another driver context
- [ ] Implement a trivial job submission path with a fence that signals on a timer
- [ ] Deliberately create a fence dependency cycle and observe how the kernel reacts
- [ ] Instrument the scheduler and fence paths with tracepoints; capture a trace
- [ ] Study GPUVM's API and write down how you would use it for a real GPU

### 🔨 Saturday Projects
- [ ] **Week 31:** TinyDRM GEM management complete, `dma-buf` export working, `unsafe` census documented
- [ ] **Week 32:** FenceScope v1.0 — timeline rendering, dependency graph with cycle detection, VM_BIND view, validated against TinyDRM

### 📄 Sunday Reading
- [ ] `Documentation/gpu/drm-mm.rst` (memory management), `drm-mm.rst` GPUVM sections
- [ ] `Documentation/driver-api/dma-buf.rst` — including the fence signaling rules
- [ ] `Documentation/gpu/drm-vm-bind-*` / the GPUVM documentation, whichever exists in your tree
- [ ] Faith Ekstrand's NVK talks, and any Danilo Krummrich talk on GPUVM/VM_BIND

---

## 🔄 Buffer Week (Month 8 Revision)
- [ ] Revise DRM/KMS: the object model, atomic modesetting, vblank, dumb buffers
- [ ] Revise GEM, `dma-buf`, `dma-fence`, `dma_resv`, the DRM scheduler, GPUVM/VM_BIND
- [ ] Re-derive the fence signaling rules from memory and explain why they exist
- [ ] **Build Monthly Project A:** TinyDRM — a real Rust DRM/KMS driver you can boot
- [ ] **Build Monthly Project B:** FenceScope — GPU scheduling, dma-fence and VM_BIND visualizer
- [ ] Show TinyDRM in `#dri-devel`; ask for feedback on whether it is worth proposing in-tree
- [ ] **Gate check:** you can write a DRM driver that modesets, and debug a fence problem with a trace

---

## Week 33-34 — Nova Core: PCI, VBIOS, Falcon, GSP Boot

> **Sources for these four weeks are entirely public:** the upstream source in
> `drivers/gpu/nova-core/`, the documentation at [docs.kernel.org/gpu/nova/](https://docs.kernel.org/gpu/nova/),
> the patch archives on `lore.kernel.org` and `lore.freedesktop.org`, and Nouveau's reverse-engineering
> documentation. Work only from these.

### Topics
- [ ] Nova's place in the world: the Rust successor to Nouveau for GSP-based NVIDIA GPUs
- [ ] The architecture split: `drivers/gpu/nova-core/` (base: PCI, VBIOS, GSP boot, RPC) and `drivers/gpu/drm/nova/` (the DRM driver and uAPI)
- [ ] `probe()` walkthrough: PCI enablement, BAR0 mapping via `Devres<Bar0>`/`Revocable`
- [ ] Chip identification: `NV_PMC_BOOT_0` / `NV_PMC_BOOT_42`, architecture and implementation decoding
- [ ] The register definition system in `regs.rs`: the macro conventions, field definitions, and why they are typed
- [ ] The HAL / chip-generation abstraction: how per-chip differences are isolated
- [ ] VBIOS: what it contains, how Nova parses it, and which tables matter
- [ ] Falcon microcontrollers: what they are, how they boot, secure vs non-secure modes
- [ ] Firmware images: formats (including TLV), signing, and what each blob is for
- [ ] WPR2 and secure memory regions: why the GPU carves out protected memory
- [ ] The GSP (GPU System Processor): what it is, what it runs (GSP-RM), and why NVIDIA's architecture centers on it
- [ ] The GSP boot sequence, stage by stage
- [ ] Nova's coding guidelines and the TODO list — the two documents that govern your contributions

### Code Exercises
- [ ] Build a kernel from `drm-rust-next` with `nova-core` and `nova-drm` enabled
- [ ] Boot it on real hardware if you have it; use virtme-ng for the non-GPU parts if you do not
- [ ] Read `nova-core` in full: `probe()`, `regs.rs`, the VBIOS parser, Falcon boot, GSP boot
- [ ] Trace the boot path in the source and write it out as a numbered sequence
- [ ] Read the debugfs GSP log buffers (`LOGINIT`, `LOGINTR`, `LOGRM`) from a real boot
- [ ] Cross-reference Nova's register definitions against public documentation and note gaps
- [ ] Add or annotate register definitions in `regs.rs` locally — practice the conventions before you submit
- [ ] Deliberately break the boot (bad register write, wrong firmware) and learn to diagnose from the logs

### 🔨 Saturday Projects
- [ ] **Week 33:** Nova builds and boots (on hardware or as far as possible without); the boot path written out as a sequence you can narrate
- [ ] **Week 34:** NovaScope v0.5 — register definition validator, plus a first-pass GSP-RM log decoder

### 📄 Sunday Reading
- [ ] [docs.kernel.org/gpu/nova/](https://docs.kernel.org/gpu/nova/) — the index, the **coding guidelines**, and the **TODO list** in full
- [ ] Nouveau documentation and any public GSP documentation you can find
- [ ] `nouveau@lists.freedesktop.org` and `dri-devel@` archives: read the last three months of Nova traffic

---

## Week 35-36 — Nova DRM: uAPI, RPC, and Your First Nova Patch

### Topics
- [ ] `nova-drm`: the DRM driver skeleton, its current IOCTLs, and the explicit "not a stable uAPI yet" disclaimer
- [ ] The GSP-RM RPC protocol: message framing, command/response pairing, sequence numbers, timeouts
- [ ] How Nova's host-side code drives GSP-RM and what the failure modes look like
- [ ] The relationship between `nova-core` and `nova-drm`: what belongs where and why the split exists
- [ ] Where Nova is going: memory management, engine enablement, and the path to rendering
- [ ] The `drm-rust-next` tree and how Nova patches flow upstream
- [ ] Nova's TODO list task ratings (Beginner → Expert) and how to pick honestly
- [ ] Community etiquette for a fast-moving driver: claim work publicly, do not duplicate, ask before big changes
- [ ] The Mesa side: NVK as the Vulkan userspace, and what the kernel must provide it

### Code Exercises
- [ ] Read `nova-drm` in full; document every IOCTL and what it currently does
- [ ] Instrument the RPC path and capture a full host↔GSP conversation from a real boot
- [ ] Build the RPC decoder: message types, request/response correlation, timeout detection
- [ ] Generate the boot-path documentation from the source with GSPAtlas
- [ ] Verify every generated diagram against a real hardware boot log — no diagram may lie
- [ ] Pick a Beginner or Intermediate TODO item; announce your intent on the list or Zulip
- [ ] Implement it; match the coding guidelines exactly; test on hardware
- [ ] `checkpatch.pl`, `rustfmt`, `clippy`, `rustdoc` all clean; write the commit message carefully
- [ ] **Send the patch.** `git format-patch` → `get_maintainer.pl` → `git send-email`. No GitHub PRs
- [ ] Respond to review; send v2, v3 as asked. This is the expected path, not a setback

### 🔨 Saturday Projects
- [ ] **Week 35:** NovaScope v1.0 — register validator/generator, GSP log decoder, RPC tracer, boot timeline
- [ ] **Week 36:** GSPAtlas v1.0 — generated `.rst` documentation for Nova's boot path, verified against hardware, **submitted as a documentation patch series**

### 📄 Sunday Reading
- [ ] The Nova TODO list again, now that you understand it — and pick your next three targets
- [ ] Recent Nova patch series on `lore.kernel.org`: read the code *and* the review comments
- [ ] Any Kangrejos or Linux Plumbers talk on Nova, Tyr, or Rust DRM abstractions

---

## 🔄 Buffer Week (Month 9 Revision)
- [ ] Revise Nova: the architecture split, boot sequence, register system, HAL, VBIOS, Falcon, GSP, RPC
- [ ] Re-narrate the boot path from memory, without looking at the code
- [ ] Revise DRM: how `nova-drm` fits the framework you learned in Month 8
- [ ] Respond to review on your Nova documentation series — this is the priority
- [ ] **Build Monthly Project A:** NovaScope — Nova register and GSP RPC toolkit ⭐
- [ ] **Build Monthly Project B:** GSPAtlas — generated documentation for Nova's boot path
- [ ] **Gate check:** you can explain Nova's GSP boot path to another engineer, and you have a Nova patch in review

---

### ✅ Phase 3 Completion Checklist
- [ ] Can implement a read-only filesystem against the VFS contract, and reason about hostile on-disk input
- [ ] Can fuzz a kernel interface and triage the crashes
- [ ] Can read the Rust Binder driver and explain its architecture, concurrency, and `unsafe` usage
- [ ] Can make a Rust driver observable with tracepoints, ftrace, and eBPF
- [ ] Can write a DRM driver that registers, modesets atomically, and manages GEM objects
- [ ] Can explain `dma-fence` signaling rules, the DRM scheduler, and GPUVM/VM_BIND
- [ ] Can build, boot, and debug Nova, and narrate its GSP boot path from the source
- [ ] Can add register definitions in Nova's conventions
- [ ] Have submitted patches to at least two different subsystems
- [ ] Have published technical writing that other people have read

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# PHASE 4: UPSTREAM ENGINEER (Weeks 37-52, Months 10-13)
# Abstractions, Security, Review, Porting, CI, Production
# ═══════════════════════════════════════════════════

---

## Week 37-38 — Designing Sound Abstractions

### Topics
- [ ] The doctrine: `rust/bindings/` is unsafe and raw, `rust/kernel/` is where `unsafe` lives and is justified, leaf code should be safe
- [ ] What "sound" means: no safe API usage can cause undefined behavior, ever, by any caller
- [ ] Encoding invariants in types: newtypes, typestate, lifetime parameters, `PhantomData`, sealed traits
- [ ] Ownership modeling: who owns the C object, who may free it, what happens on `Drop`
- [ ] Lifetime modeling: tying a resource to a device, a lock, or a scope so it cannot escape
- [ ] Refcounting: `AlwaysRefCounted`, `ARef`, and when to wrap a C `kref`
- [ ] Handling C callbacks: `#[vtable]`, trampolines, and recovering `self` from a C pointer safely
- [ ] `Opaque<T>` and pinning for C objects that must not move
- [ ] The `Devres`/`Revocable` pattern for resources that the C side can invalidate
- [ ] Writing a safety contract: preconditions on `unsafe fn`, and `# Safety` doc sections
- [ ] Deliberate omission: it is correct to expose less than the C API if the rest cannot be made safe
- [ ] Reviewing for soundness: how to find the counterexample in someone else's abstraction
- [ ] Case studies: read the review threads for two merged abstractions and see what reviewers objected to

### Code Exercises
- [ ] Survey `rust/kernel/` against the C subsystems that exist; produce the gap list (extend RustScope)
- [ ] Pick your target subsystem; read **every** C function you intend to wrap, plus its locking and lifetime rules
- [ ] Write the design document first: API sketch, ownership model, invariants encoded, what is deliberately excluded
- [ ] Post the design for feedback on Zulip or the list **before** implementing
- [ ] Implement the abstraction following in-tree conventions exactly
- [ ] Write a `// SAFETY:` comment for every `unsafe` block that would survive a hostile review
- [ ] Write a sample driver in `samples/rust/` using only the safe API — target zero `unsafe`
- [ ] Write KUnit tests, including allocation-failure and error paths
- [ ] Write the soundness argument: why no safe usage can cause UB
- [ ] Try to break your own abstraction: write three misuse attempts and confirm they do not compile

### 🔨 Saturday Projects
- [ ] **Week 37:** Gap survey published; target chosen; design document written and posted for feedback
- [ ] **Week 38:** Abstraction implemented with sample driver, KUnit tests, and soundness argument

### 📄 Sunday Reading
- [ ] `Documentation/rust/general-information.rst` (abstractions vs bindings) and `coding-guidelines.rst` — again, with new eyes
- [ ] The review threads for two recently merged `rust/kernel/` abstractions
- [ ] Paper: "Stacked Borrows: An Aliasing Model for Rust" (Jung et al., POPL 2020) and "Tree Borrows" (Villani et al., PLDI 2025) — the formal aliasing rules your `unsafe` must respect

---

## Week 39-40 — Security, Sanitizers, Fuzzing

### Topics
- [ ] The kernel threat model: unprivileged local users, containers, malicious devices, hostile hosts
- [ ] Attack surfaces: syscalls, ioctls, sysfs writes, network input, filesystem images, device DMA
- [ ] The bug classes that matter: UAF, OOB, double-free, type confusion, integer overflow, race conditions, info leaks
- [ ] Real CVE analysis: pick three kernel CVEs, understand the primitive, and assess honestly whether Rust would have prevented each
- [ ] KASAN modes (generic, software tag-based, hardware tag-based) and their costs
- [ ] KCSAN and the "benign race" fallacy
- [ ] UBSAN, KMSAN, `kmemleak`, `slub_debug`, and the `CONFIG_DEBUG_*` menu worth knowing
- [ ] Hardening: `CONFIG_FORTIFY_SOURCE`, stack protector, KASLR, CFI, `init_on_alloc`, and their performance cost
- [ ] syzkaller and syzbot: how the kernel's most productive bug finder works
- [ ] syzlang: describing your driver's ioctl and file interfaces so the fuzzer can reach deep code
- [ ] Coverage-guided fuzzing, `KCOV`, and why coverage matters more than volume
- [ ] Crash triage: dedupe, minimize, reproduce, bisect, report
- [ ] Responsible disclosure: `security@kernel.org`, the process, and what not to do

### Code Exercises
- [ ] Build kernels with each sanitizer via KernelForge profiles; measure the performance cost of each
- [ ] Write syzlang descriptions for VirtToy, KModKit's ioctl module, BlockForge's configfs, and TarFS-RS's mount path
- [ ] Set up `syz-manager` against your QEMU images and run an unattended campaign
- [ ] Automate crash triage through OopsLens: dedupe, minimize, classify
- [ ] Threat-model your own drivers: write down what a malicious userspace can attempt, and verify each is handled
- [ ] Fix every bug the fuzzer finds in your code; report anything you find in in-tree code properly
- [ ] Analyze three real kernel CVEs and write the honest "would Rust have prevented this?" assessment
- [ ] Run your adversarial test harness (Week 13) against every driver you have written

### 🔨 Saturday Projects
- [ ] **Week 39:** Sanitizer profiles complete; syzlang descriptions written; fuzzing campaign running
- [ ] **Week 40:** KFuzzRS v1.0 — full playbook, triage automation, and the results report with CPU-hours and bug classes

### 📄 Sunday Reading
- [ ] `Documentation/dev-tools/kasan.rst`, `kcsan.rst`, `kmsan.rst`, `ubsan.rst`, `kcov.rst`
- [ ] `Documentation/process/security-bugs.rst`
- [ ] The syzkaller documentation, especially the syzlang description guide
- [ ] Paper: "Understanding Memory and Thread Safety Practices and Issues in Real-World Rust Programs" (Qin et al., PLDI 2020)

---

## 🔄 Buffer Week (Month 10 Revision)
- [ ] Revise abstraction design: soundness, invariant encoding, ownership and lifetime modeling, safety contracts
- [ ] Revise security: threat model, bug classes, sanitizers, hardening, fuzzing, triage, disclosure
- [ ] Re-read your abstraction's soundness argument and try harder to break it
- [ ] **Build Monthly Project A:** SafeAbstract — ship a new kernel Rust abstraction upstream (RFC sent)
- [ ] **Build Monthly Project B:** KFuzzRS — syzkaller harness for Rust drivers
- [ ] Publish the fuzzing playbook and the CVE analysis
- [ ] **Gate check:** you have an abstraction RFC in review and can defend its soundness

---

## Week 41-42 — The Upstream Machine: Trees, linux-next, Merge Windows

### Topics
- [ ] The tree hierarchy: Linus's tree, subsystem maintainer trees, `linux-next`, and how code flows upward
- [ ] The release cycle: merge window, `-rc1` through `-rc7`, release, and what is acceptable at each stage
- [ ] `MAINTAINERS` in depth: how to find the right tree, list, and person for any file
- [ ] `lore.kernel.org` as the archive of record; message IDs as permanent references
- [ ] `b4`: `b4 mbox`, `b4 shazam`, `b4 am`, `b4 diff`, `b4 prep`, `b4 send` — the modern workflow
- [ ] Patch series structure: one logical change per patch, each building and booting independently
- [ ] Commit messages: the subject-line convention, the imperative mood, the "why not what" rule, `Link:` tags
- [ ] Cover letters: what a maintainer needs in the first 60 seconds
- [ ] Trailers: `Signed-off-by:` (DCO), `Reviewed-by:`, `Tested-by:`, `Acked-by:`, `Reported-by:`, `Suggested-by:`, `Closes:`, `Fixes:`
- [ ] `Fixes:` tags: the exact format, and how to find the commit that introduced a bug
- [ ] Stable/LTS: what qualifies, `Cc: stable@vger.kernel.org # 6.x+`, and the backport process
- [ ] `git bisect` for regressions, including `git bisect run` with an automated predicate
- [ ] Handling conflict: rebasing onto a maintainer's tree, resolving review disagreement, when to escalate and when to yield
- [ ] What gets patches ignored: wrong list, wrong base, HTML mail, top-posting, no testing, no explanation

### Code Exercises
- [ ] Add all the relevant remotes to your tree: `linux-next`, Rust-for-Linux, DRM, and your target subsystem's tree
- [ ] Use `b4` to fetch, apply, and review three real in-flight series from `lore.kernel.org`
- [ ] Practice: take one of your own multi-commit branches and restructure it into a clean, logical series
- [ ] Write a cover letter for it that a busy maintainer could act on immediately
- [ ] Find a real bug in a recent commit and write a correct `Fixes:` tag for it
- [ ] Bisect a deliberately-introduced regression with `git bisect run` and your KernelForge boot test
- [ ] Read `linux-next` merge conflict reports and understand what causes them
- [ ] Send one genuinely trivial but real patch (a documentation fix, a `checkpatch` cleanup) through the full process, end to end

### 🔨 Saturday Projects
- [ ] **Week 41:** PatchPilot v0.5 — `check`, `recipients`, and `cover` commands working against your own branches
- [ ] **Week 42:** PatchPilot v0.8 — `send` with a dry-run diff, plus `track` polling `lore` for replies to your series

### 📄 Sunday Reading
- [ ] `Documentation/process/` — read the whole directory: `submitting-patches`, `submit-checklist`, `email-clients`, `development-process`, `stable-kernel-rules`, `handling-regressions`, `maintainer-*`
- [ ] The `b4` documentation, completely
- [ ] LWN's coverage of a recent merge window — to see the machine from the outside

---

## Week 43-44 — Reviewing Patches & Porting C to Rust

### Topics
- [ ] Review as a skill: what a good review finds, and what a bad review wastes time on
- [ ] Reading a patch critically: does it compile, does it boot, does it handle errors, does it break ABI, is the locking right
- [ ] Rust-specific review: is `unsafe` justified, is the safety comment real, is the abstraction sound, is allocation fallible
- [ ] Giving feedback that helps: be specific, be kind, be direct, suggest the fix
- [ ] Receiving feedback: separate the technical content from the tone, answer every point, do not go quiet
- [ ] `Reviewed-by:` and `Tested-by:` — what you are actually asserting when you give them
- [ ] Disagreeing productively: making the technical case, and knowing when the maintainer's call is final
- [ ] Porting methodology: understand the C completely before writing any Rust
- [ ] Feature parity as a hard requirement: same sysfs paths, same values, same error codes, same module params, same quirks
- [ ] Parity testing: how to prove behavior is identical, not just similar
- [ ] Performance parity: benchmarking honestly, including the cases where Rust is slower
- [ ] The historical-bug argument: mining `git log` for bugs the borrow checker would have caught
- [ ] Handling the political dimension: some maintainers will not want the port, and that is information

### Code Exercises
- [ ] Review five real Rust patches from `rust-for-linux@`; write your comments privately first, then compare with what others said
- [ ] Post at least two real review comments on the list; give at least one `Tested-by:` after actually testing
- [ ] Choose your port target: small, self-contained, testable, hardware you can access, subsystem not hostile
- [ ] Read and annotate the entire C driver — a function-by-function walkthrough in your journal
- [ ] Mine its `git log` for historical bug fixes; classify which Rust would have prevented
- [ ] Implement the Rust port with full feature parity, including the ugly legacy corners
- [ ] Write the parity test suite: same interfaces, same values, same errors
- [ ] Benchmark both; report honestly, including regressions
- [ ] Write the analysis: LOC, `unsafe` count, error-path count, historical bugs prevented, what got harder

### 🔨 Saturday Projects
- [ ] **Week 43:** Five reviews done, two posted; port target chosen and the C driver fully annotated
- [ ] **Week 44:** PortToRust v1.0 — the port with parity tests, benchmarks, and the analysis write-up

### 📄 Sunday Reading
- [ ] `Documentation/maintainer/` — the maintainer's perspective, which makes you a better contributor
- [ ] The Rust-for-Linux mailing list archive for the past month — read everything, including what you do not understand
- [ ] A long, contentious patch thread of your choosing, read to the end. This is anthropology and it is useful

---

## 🔄 Buffer Week (Month 11 Revision)
- [ ] Revise the upstream machine: trees, cycle, `MAINTAINERS`, `b4`, series structure, trailers, stable rules
- [ ] Revise review skills: what to look for, how to give and receive feedback
- [ ] Revise porting methodology and parity proof
- [ ] Respond to review on your SafeAbstract RFC and your port series
- [ ] **Build Monthly Project A:** PortToRust — port a real C driver to Rust, upstream-quality (submitted)
- [ ] **Build Monthly Project B:** PatchPilot — the contribution workflow CLI
- [ ] Use PatchPilot for every submission from now on
- [ ] **Gate check:** you can run the full upstream workflow without notes, and your reviews are useful to others

---

## Week 45-46 — Testing Infrastructure: KUnit & kselftest

### Topics
- [ ] KUnit architecture: suites, cases, assertions vs expectations, fixtures, parameterized tests
- [ ] `kunit_tool` (`tools/testing/kunit/kunit.py`): running tests in QEMU in seconds
- [ ] Testing kernel Rust: the `#[test]`-style macros, `rust/kernel/kunit.rs`, and doctests as tests
- [ ] What to test in kernel code: error paths, allocation failure, boundary values, teardown, concurrency
- [ ] Testing allocation failure deliberately: `CONFIG_FAILSLAB`, `CONFIG_FAIL_PAGE_ALLOC`, and fault injection via debugfs
- [ ] Mocking in kernel tests: what is possible, and how to design code to be testable
- [ ] `kselftest`: userspace-driven tests for uAPI behavior; structure and conventions
- [ ] Test coverage: `CONFIG_GCOV_KERNEL`, KCOV, and interpreting coverage for kernel code
- [ ] What "tested" means in a patch: the `Testing:` section maintainers actually want to see
- [ ] Regression tests: every bug you fix should come with a test that would have caught it

### Code Exercises
- [ ] Survey `rust/kernel/` test coverage: which modules have tests, which do not, which have only doctests
- [ ] Pick 3-5 under-tested modules; write thorough KUnit tests including error and allocation-failure paths
- [ ] Add fault injection to your own drivers and prove every error path executes correctly
- [ ] Write kselftests for the uAPI of your own drivers
- [ ] Measure coverage on your abstraction and identify the untested branches that matter
- [ ] For every bug you have ever fixed in your own code, write the regression test you should have written
- [ ] Set up `kunit.py` in your workflow so tests run on every build

### 🔨 Saturday Projects
- [ ] **Week 45:** Coverage survey of `rust/kernel/` published; tests written for the first two modules
- [ ] **Week 46:** KUnitRS v1.0 — tests for 3-5 modules, **submitted upstream, one module per series**

### 📄 Sunday Reading
- [ ] `Documentation/dev-tools/kunit/` — the whole directory
- [ ] `Documentation/dev-tools/kselftest.rst` and `fault-injection/`
- [ ] Existing KUnit tests in `rust/kernel/` — read them as style examples

---

## Week 47-48 — Multi-Arch, Cross-Compilation & CI

### Topics
- [ ] Cross-compilation: `ARCH=`, `CROSS_COMPILE=`, and the Rust target triple for each architecture
- [ ] Rust kernel architecture support: which architectures work, which are in progress (check `Documentation/rust/arch-support.rst`)
- [ ] QEMU recipes per architecture: arm64 `virt`, riscv64 `virt`, s390x, and the console/boot differences
- [ ] Portability traps: pointer width, alignment requirements, endianness (s390x is big-endian), atomic availability, `unsigned long` vs `u64`
- [ ] Struct layout differences across architectures — the uAPI killer
- [ ] Per-architecture Kconfig differences and why "it builds on x86" means little
- [ ] KernelCI and LKFT: how the community tests, and how to read their reports
- [ ] Building your own CI: matrix builds, artifact caching, boot tests, test result aggregation
- [ ] What to put in a cover letter's testing section: architectures, configs, sanitizers, test suites, hardware

### Code Exercises
- [ ] Install cross toolchains for arm64, riscv64, and s390x; get each to build a Rust-enabled kernel
- [ ] Write per-arch QEMU boot recipes and verify each reaches a shell
- [ ] Run your KUnit tests on all four architectures; fix everything that breaks
- [ ] Deliberately introduce a portability bug (assume 64-bit pointers, assume little-endian) and confirm your matrix catches it
- [ ] Add sanitizer variants to the matrix: at least one arch each with KASAN and KCSAN
- [ ] Wire the whole thing into GitHub Actions (or a local runner) so it runs on every push
- [ ] Generate a markdown matrix suitable for pasting into a patch cover letter
- [ ] Retest all your previous drivers on all architectures and fix the surprises

### 🔨 Saturday Projects
- [ ] **Week 47:** Cross toolchains and per-arch boots working; KUnit passing on 4 architectures
- [ ] **Week 48:** BootMatrix v1.0 — full matrix with sanitizer variants, triage via OopsLens, CI integration, and cover-letter-ready output

### 📄 Sunday Reading
- [ ] `Documentation/rust/arch-support.rst` and `Documentation/kbuild/kbuild.rst`
- [ ] The KernelCI documentation and a recent KernelCI report
- [ ] `Documentation/process/submitting-patches.rst` — the testing expectations section, again

---

## 🔄 Buffer Week (Month 12 Revision)
- [ ] Revise testing: KUnit, kselftest, fault injection, coverage, regression tests
- [ ] Revise multi-arch: cross-compilation, portability traps, per-arch QEMU, CI
- [ ] Respond to review on your KUnitRS test series
- [ ] **Build Monthly Project A:** KUnitRS — test coverage for the `kernel` crate (submitted)
- [ ] **Build Monthly Project B:** BootMatrix — multi-arch Rust kernel CI in QEMU
- [ ] From now on, every series you send includes a BootMatrix-generated testing section
- [ ] **Gate check:** you can test kernel Rust properly across architectures, and have tests merged upstream

---

## Week 49-50 — Performance Engineering & Benchmarking

### Topics
- [ ] Measurement discipline: what to measure, how to avoid lying to yourself, statistical significance in benchmarks
- [ ] `perf` in depth: sampling, hardware counters, `perf stat`, `perf record`/`report`, `perf annotate`
- [ ] Flame graphs and off-CPU analysis
- [ ] Cache behavior: cache lines, false sharing, alignment, prefetching, and how to measure each
- [ ] Lock contention: measuring it, and the standard remedies (finer granularity, per-CPU, RCU, lockless)
- [ ] Interrupt and softirq overhead; NAPI-style batching as a general pattern
- [ ] Memory allocation cost and the case for object caches and preallocation
- [ ] Does Rust cost anything? Bounds checking, `Option` discriminants, iterator codegen — measure, do not assume
- [ ] Reading generated assembly for kernel Rust: `objdump`, and checking that the optimizer did what you expected
- [ ] Benchmarking a driver: latency percentiles, throughput, CPU per operation, and why averages hide everything
- [ ] Regression testing performance: catching a slowdown before a maintainer does

### Code Exercises
- [ ] Profile BlockForge under `fio` load with `perf`; find the top three cost centers
- [ ] Generate a flame graph and identify one surprise
- [ ] Measure false sharing in a deliberately-bad data structure, then fix the alignment and re-measure
- [ ] Measure lock contention in one of your drivers; fix it with finer granularity or per-CPU data
- [ ] Compare the generated assembly for a Rust hot path against the equivalent C; account for every difference
- [ ] Measure the cost of bounds checking in a hot loop; decide honestly whether it matters
- [ ] Build a repeatable benchmark harness with latency percentiles, and add it to your CI
- [ ] Optimize one driver measurably and document the before/after with methodology

### 🔨 Saturday Projects
- [ ] **Week 49:** A rigorous benchmark harness for your drivers, with percentiles and statistical treatment
- [ ] **Week 50:** A measured optimization with a full write-up: hypothesis, measurement, change, result, and what you learned

### 📄 Sunday Reading
- [ ] `Documentation/admin-guide/perf/` and the `perf` tutorial material
- [ ] Paper: "An Analysis of Performance Evolution of Linux's Core Operations" (SOSP 2019)
- [ ] Paper: "The Linux Scheduler: A Decade of Wasted Cores" (EuroSys 2016) — a lesson in how invisible bugs cost performance

---

## Week 51-52 — Production Quality, ABI, Stable/LTS

### Topics
- [ ] The production checklist: what separates merged code from hobby code
- [ ] Error path completeness: every failure leaves the system consistent; proven by fault injection, not inspection
- [ ] Teardown correctness: 1000 unbind/rebind cycles, `kmemleak` clean, KASAN clean
- [ ] Full power management with edge cases: suspend during I/O, resume failure, wakeup sources
- [ ] `Documentation/ABI/` entries with declared stability classes
- [ ] Device tree binding schemas that pass `dt_binding_check` and satisfy the DT maintainers
- [ ] uAPI design for the long term: struct layout stability, extension mechanisms, feature flags, versioning
- [ ] "We do not break userspace" applied to your own interfaces, forever
- [ ] `MAINTAINERS` ownership: what you are signing up for, and how to be a good maintainer of a small thing
- [ ] Stable/LTS: what qualifies as a stable fix, the backport process, distribution consumption
- [ ] Deprecation: how to remove something you should not have added
- [ ] The regression handling process and what happens when your patch breaks someone

### Code Exercises
- [ ] Full error-path audit on your best driver, with fault injection on every allocation and every C call that can fail
- [ ] 1000 unbind/rebind cycles under KASAN + `kmemleak`; fix everything
- [ ] Suspend/resume with I/O in flight; suspend failure injection; wakeup source verification
- [ ] Write `Documentation/ABI/` entries for every sysfs file you expose
- [ ] Make `dt_binding_check` and `dtbs_check` clean
- [ ] Run AbiGuard against your own uAPI across architectures; fix any layout instability
- [ ] Add your `MAINTAINERS` entry
- [ ] Full BootMatrix run plus every sanitizer; `checkpatch --strict` clean; `clippy` clean; `W=1` clean
- [ ] Prepare and send the final series; drive it to merge

### 🔨 Saturday Projects
- [ ] **Week 51:** AbiGuard v1.0 — uAPI/sysfs break detector, validated against real kernel releases
- [ ] **Week 52:** ProdDriver — the production-quality series sent, and driven through review to merge

### 📄 Sunday Reading
- [ ] `Documentation/process/stable-kernel-rules.rst` and `handling-regressions.rst`
- [ ] `Documentation/admin-guide/abi-stable.rst` and the `Documentation/ABI/README`
- [ ] `Documentation/process/maintainer-handbooks.rst` and one subsystem's handbook

---

## 🔄 Buffer Week (Month 13 Revision)
- [ ] Revise production quality: error paths, teardown, PM, ABI documentation, bindings, `MAINTAINERS`
- [ ] Revise performance: measurement discipline, `perf`, cache behavior, lock contention
- [ ] Revise stable/LTS rules and regression handling
- [ ] Drive your ProdDriver series through review — merging it is the deliverable
- [ ] **Build Monthly Project A:** ProdDriver — take one driver to production and merge it
- [ ] **Build Monthly Project B:** AbiGuard — uAPI/sysfs ABI break detector
- [ ] **Gate check:** you have a driver merged in mainline that other people's machines will run

---

### ✅ Phase 4 Completion Checklist
- [ ] Can design a safe abstraction over a C subsystem and defend its soundness in review
- [ ] Can write safety contracts and safety comments that survive hostile review
- [ ] Can build with every sanitizer and interpret every report
- [ ] Can write syzkaller descriptions and run a fuzzing campaign against your own code
- [ ] Can run the full upstream workflow fluently with `b4` and `git send-email`
- [ ] Can structure a multi-patch series that reviews cleanly
- [ ] Can review someone else's Rust patch usefully and give a meaningful `Reviewed-by:`
- [ ] Can port a C driver to Rust with proven parity and honest benchmarks
- [ ] Can write KUnit and kselftest coverage, including allocation-failure paths
- [ ] Can build and boot Rust-enabled kernels on four architectures and catch portability bugs
- [ ] Can profile a driver and make a measured, documented optimization
- [ ] Have code merged in mainline Linux
- [ ] Have an entry in `MAINTAINERS`

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# PHASE 5: MASTERY (Weeks 53-64, Months 14-16)
# Virtualization, Advanced MM, Major Contribution, Ecosystem
# ═══════════════════════════════════════════════════

---

## Week 53-54 — Virtualization: virtio, VFIO, KVM

### Topics
- [ ] The virtio specification: device types, transports (PCI, MMIO, channel I/O), feature negotiation
- [ ] Virtqueues: split ring (descriptor, available, used) and packed ring
- [ ] Descriptor chains, indirect descriptors, and the memory barriers the shared ring requires
- [ ] Notification and interrupt suppression; `VIRTIO_F_EVENT_IDX`
- [ ] The hostile-host threat model: every field the host writes is attacker-controlled
- [ ] `VIRTIO_F_ACCESS_PLATFORM` and DMA through the IOMMU
- [ ] KVM from the host side: `vcpu`, memory slots, `ioctl` interface, MMIO and PIO exits (connect to your `LINUX/kvm-virtualization` reading)
- [ ] VFIO: device passthrough, IOMMU groups, `vfio-pci`, and userspace drivers
- [ ] Mediated devices and vDPA: the middle grounds between emulation and passthrough
- [ ] `vhost` and `vhost-user`: moving the device backend into the kernel or another process
- [ ] Where Rust fits: guest drivers, `rust-vmm` on the userspace side, and the abstraction gaps

### Code Exercises
- [ ] Read the virtio specification's ring layout section and implement the descriptor logic on paper first
- [ ] Implement a virtio guest driver in Rust: feature negotiation, virtqueue setup, descriptor handling, notifications
- [ ] Place every memory barrier explicitly and write a comment justifying each one
- [ ] Build the other side: a QEMU device model or a `vhost-user` backend you control
- [ ] Write a deliberately hostile backend that lies about lengths, indices, and available entries; harden the driver until it survives
- [ ] Benchmark against the equivalent C driver
- [ ] Set up `vfio-pci` passthrough of a real device to a guest and observe the IOMMU group requirements
- [ ] Explore `rust-vmm` crates and note what a Rust VMM shares with a Rust kernel driver

### 🔨 Saturday Projects
- [ ] **Week 53:** The virtio driver working against your own backend, with barriers documented
- [ ] **Week 54:** VirtioRS v1.0 — hostile-backend test suite, hardening, benchmarks, and the write-up

### 📄 Sunday Reading
- [ ] The VIRTIO specification (OASIS) — Ch. 2 (basic facilities) and the split/packed ring chapters
- [ ] `Documentation/driver-api/vfio.rst` and `Documentation/virt/kvm/api.rst` (skim the API, read the concepts)
- [ ] Your `LINUX/kvm-virtualization` notes — now they connect to kernel-side reality

---

## Week 55-56 — Advanced Memory Management

### Topics
- [ ] Pages and folios: the transition, and what a folio buys
- [ ] Page refcounting and mapcounting; `get_page`/`put_page` semantics and the races they hide
- [ ] VMAs: `vm_area_struct`, `vm_operations_struct`, and the mmap lifecycle
- [ ] Implementing `mmap` from a driver: `remap_pfn_range` vs a fault handler, and when each is right
- [ ] The fault path: `fault`, `huge_fault`, `page_mkwrite`, and what you must guarantee
- [ ] Huge pages and THP: when they help a driver, and the alignment requirements
- [ ] Reclaim: the LRU lists, `kswapd`, direct reclaim, and writeback
- [ ] Shrinkers: registering one, `count_objects`/`scan_objects`, and the rules (no allocation, no deadlock)
- [ ] Memory pressure and OOM: what your driver must do to degrade rather than deadlock
- [ ] `GFP_NOIO`/`GFP_NOFS` and the reclaim recursion problem
- [ ] Memory cgroups and accounting driver allocations correctly
- [ ] `kmemleak`, `page_owner`, and allocation debugging at scale

### Code Exercises
- [ ] Implement `mmap` on a driver with a fault handler; verify correctness under concurrent unmapping
- [ ] Get page refcounting right: unmap under load and prove no leak and no double-free with KASAN and `page_owner`
- [ ] Add huge page support where the buffer allows it; measure the fault-count difference
- [ ] Register a shrinker for a driver cache; drive the system into reclaim and prove it frees memory
- [ ] Use allocation fault injection to force OOM conditions; prove your driver degrades gracefully
- [ ] Trace the reclaim path with ftrace during pressure and understand what actually happened
- [ ] Measure: page fault cost, reclaim latency, memory returned under pressure

### 🔨 Saturday Projects
- [ ] **Week 55:** `mmap` with a fault handler, correct refcounting, huge page support, all stress-tested
- [ ] **Week 56:** MemLab v1.0 — shrinker, OOM behavior, measurements, and the guide: "mmap and shrinkers from a Rust kernel driver"

### 📄 Sunday Reading
- [ ] `Documentation/mm/` — `folio`, `page_frags`, `physical_memory`, `unevictable-lru`
- [ ] `Documentation/core-api/mm-api.rst` and the shrinker documentation
- [ ] LWN's folio conversion coverage — it explains the *why* better than the code does

---

## 🔄 Buffer Week (Month 14 Revision)
- [ ] Revise virtualization: virtio rings and barriers, hostile-host hardening, VFIO, KVM concepts
- [ ] Revise memory management: pages/folios, VMAs, `mmap`, fault handling, shrinkers, reclaim, OOM
- [ ] **Build Monthly Project A:** VirtioRS — a Rust virtio driver end to end
- [ ] **Build Monthly Project B:** MemLab — `mmap`, folios, shrinkers and memory pressure in Rust
- [ ] Publish the MemLab guide — it will be the only one of its kind
- [ ] **Gate check:** you can implement `mmap` and a shrinker correctly, and harden a driver against a hostile peer

---

## Week 57-60 — Major Contribution + Authoring

### Focus
This is a four-week block with two parallel tracks. Do not treat them as separate projects — the writing makes the code better, and the code makes the writing credible.

### Track 1 — The Major Contribution (Weeks 57-60)
- [ ] **Week 57:** Choose the target. Read the current TODO/wishlist for your subsystem; check `lore.kernel.org` for in-flight work; **ask a maintainer directly** what is needed and unclaimed
- [ ] **Week 57:** Post a design note or RFC *before* writing significant code. Getting told "no, do it differently" now costs a day; later it costs a month
- [ ] **Week 58:** Implement, matching the subsystem's conventions exactly. Tests and documentation alongside the code, not after
- [ ] **Week 59:** Test hard: real hardware where applicable, multiple chip generations if you can, BootMatrix across architectures, every sanitizer
- [ ] **Week 59:** Self-review as a hostile reviewer. Then have an actual person review it before you post
- [ ] **Week 60:** Send the series. Respond to every comment. Send v2, v3, vN. Do not go quiet — silence kills series more often than technical objections
- [ ] **Nova track:** if your target is Nova, coordinate with the maintainers first, pick from the TODO list, and test on at least two GPU generations if you can get them

### Track 2 — The Book (Weeks 57-60)
- [ ] **Week 57:** Outline the curriculum: 15+ chapters mapping this roadmap's arc, each with a lab
- [ ] **Week 57:** Choose the toolchain (mdBook or Sphinx) and set up CI that builds and boot-tests every example
- [ ] **Week 58:** Write the foundation chapters (Phase 1 material), each with a runnable QEMU lab derived from KModKit
- [ ] **Week 58:** Add compile-fail examples that teach the borrow checker's kernel-specific lessons
- [ ] **Week 59:** Write the driver chapters (Phase 2 material), labs derived from VirtToy, DMAForge, BlockForge
- [ ] **Week 59:** Write the honest chapters: what Rust does not fix, where abstractions are thin, what is still C-only
- [ ] **Week 60:** Write the upstream chapter, ending with the reader sending a real trivial patch
- [ ] **Week 60:** Publish; announce on the Rust-for-Linux Zulip and kernelnewbies; collect feedback and iterate

### 🔨 Saturday Projects
- [ ] **Week 57:** Design note posted; book outline and CI skeleton done
- [ ] **Week 58:** Implementation core complete; foundation chapters published
- [ ] **Week 59:** Tested across hardware/architectures; driver chapters published
- [ ] **Week 60:** Series sent and iterating; book v1.0 announced

### 📄 Sunday Reading
- [ ] Recent series in your target subsystem — read the code and the reviews as your quality bar
- [ ] `Documentation/doc-guide/` — how kernel documentation is written and built
- [ ] Two or three technical books you admire, read for *structure* rather than content

---

## 🔄 Buffer Week (Month 15 Revision)
- [ ] Drive the major contribution series forward — review response is the priority over everything else
- [ ] Iterate the book based on the first round of external feedback
- [ ] Revise anything the review process exposed as a gap in your understanding
- [ ] **Build Monthly Project A:** NovaFeature (or your chosen major contribution) ⭐
- [ ] **Build Monthly Project B:** KernelRustBook — the course and labs
- [ ] **Gate check:** a substantial contribution in serious review, and a published resource other people use

---

## Week 61-64 — Sustained Upstream & Ecosystem

### Focus
The goal of this block is not a new artifact. It is *rate*: becoming someone whose patches arrive regularly, whose reviews are trusted, and whose name a maintainer recognizes with relief rather than dread.

### Topics & Activities
- [ ] **Contribution cadence:** aim for at least one patch per week for four weeks. Small is fine; consistent is the point
- [ ] **Find your own bugs:** run SafetyLint, KFuzzRS, AbiGuard, and BootMatrix against the current tree and fix what they find
- [ ] **Fix bugs with `Fixes:` tags:** find real regressions, write correct tags, and `Cc: stable@` where warranted
- [ ] **Give reviews:** at least five substantive reviews with `Reviewed-by:` or `Tested-by:` on other people's patches
- [ ] **Answer questions:** on the Rust-for-Linux Zulip, on kernelnewbies, in patch threads. Teaching consolidates your own knowledge
- [ ] **Take on a small maintenance burden:** offer to be `R:` (reviewer) for an area you know well
- [ ] **Cross three subsystems:** deliberately contribute outside your comfort zone — a different subsystem's culture teaches you something
- [ ] **Ecosystem contributions:** land at least one meaningful change in each of two non-kernel projects
  - [ ] `pin-init` or `bindgen`: something that directly benefits kernel Rust
  - [ ] QEMU: a device model improvement — consider upstreaming the VirtToy device itself
  - [ ] `syzkaller`: descriptions or Rust-driver support improvements
  - [ ] `virtme-ng` or `b4`: workflow improvements you already prototyped in PatchPilot
  - [ ] `rustc`/`clippy`: a kernel-relevant issue, even a small one
  - [ ] Mesa/NVK: the userspace half of the GPU stack, if Nova is your direction
- [ ] **Compare cultures:** write up how mailing-list and GitHub contribution models differ, and what each does better
- [ ] **Mentor:** help one person send their first kernel patch, start to finish

### 🔨 Saturday Projects
- [ ] **Week 61:** Contribution log started; three patches sent; two reviews given
- [ ] **Week 62:** First ecosystem contribution landed; two more kernel patches
- [ ] **Week 63:** Second ecosystem contribution landed; reviewer role offered or taken
- [ ] **Week 64:** UpstreamRun complete — 10+ merged patches across 3+ subsystems, documented in a table; retrospective written

### 📄 Sunday Reading
- [ ] Read the full week's `rust-for-linux@` traffic every Sunday — this is now a habit, not an assignment
- [ ] One LWN Kernel page per week, minimum. Consider paying for a subscription; it is the best value in kernel development
- [ ] A Kangrejos or Linux Plumbers Rust microconference talk each week

---

## 🔄 Buffer Week (Month 16 Revision)
- [ ] Consolidate: revisit any subsystem the last four weeks exposed as a weak spot
- [ ] Update your contribution log and portfolio
- [ ] Choose your Magnum Opus direction and, critically, **validate it with a maintainer before Week 65**
- [ ] **Build Monthly Project A:** UpstreamRun — 10+ merged patches across 3+ subsystems
- [ ] **Build Monthly Project B:** EcosystemContrib — contributions beyond the kernel tree
- [ ] **Gate check:** you are a known, trusted regular whose reviews carry weight

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# PHASE 6: MAGNUM OPUS & PORTFOLIO (Weeks 65-78)
# Months 17-18: The Signature Contribution
# ═══════════════════════════════════════════════════

---

## Week 65-72 — Magnum Opus Build

Pick ONE option from the [Magnum Opus catalog](#month-17-18-project-magnum-opus--your-signature-kernel-contribution) and commit to it. Eight weeks is enough for something real and not enough for something unfocused.

### Milestones
- [ ] **Week 65 — Scope and validate.** Write the design document. Post it. Get maintainer feedback *before* implementing. If the feedback is discouraging, change direction now — that is a success, not a failure
- [ ] **Week 66 — Architecture.** Module boundaries, type design, ownership model, invariants encoded, test strategy. Write it down
- [ ] **Week 67-68 — Core implementation.** The main body of work. Tests and documentation written alongside, not deferred
- [ ] **Week 69 — Hardening.** Every error path, every teardown path, every sanitizer, every architecture, fault injection throughout
- [ ] **Week 70 — Evidence.** Benchmarks with methodology, test results, hardware validation, the BootMatrix table
- [ ] **Week 71 — Self-review and external review.** Read your own series as a hostile maintainer. Then get a real human to review it privately before posting
- [ ] **Week 72 — Post the series.** Cover letter that earns 60 seconds of attention. Then engage relentlessly with review
- [ ] **Ongoing from Week 72:** vN iterations until merged or definitively closed. Merged is the goal; a well-fought series that did not merge still built the skill

### Non-negotiable deliverables
- [ ] A 2000+ word technical deep-dive with architecture diagrams
- [ ] Complete test coverage: KUnit, kselftest, fuzzing, multi-arch boot matrix
- [ ] Every `unsafe` block justified; a written soundness argument for anything new in `rust/kernel/`
- [ ] Reproducible setup: someone else can build, boot, and test it from your instructions
- [ ] Honest limitations section: what it does not do, what is unsound, what is next

---

## Week 73-78 — Portfolio, Talk, Maintainership Path

### Week 73-74 — Portfolio
- [ ] A portfolio page linking all 36 monthly projects with results, evidence, and lessons
- [ ] A merged-contribution table: commit, subsystem, what it does, why it mattered
- [ ] Every project README brought to a consistent, high standard
- [ ] Demo recordings for the visual projects: TinyDRM modesetting, FenceScope timelines, TraceRust's TUI, VirtToy's one-command lab
- [ ] A résumé rewritten around demonstrated capability rather than claimed familiarity

### Week 75-76 — Writing and Speaking
- [ ] Two technical deep-dives published: your Magnum Opus, plus your strongest analytical piece (LockProof, the DMA bug museum, or the Binder analysis)
- [ ] A conference talk proposal submitted: **Kangrejos** (the Rust-for-Linux workshop), **Linux Plumbers Rust microconference**, **XDC** if GPU, **FOSDEM**, or a local meetup to start
- [ ] Practice the talk out loud, timed, at least three times. Kernel audiences are unforgiving of hand-waving
- [ ] Give a dry run to a friendly audience first — a local meetup, a study group, or a few colleagues — before the real thing

### Week 77-78 — What Next
- [ ] Honest retrospective: what you can do now, what still frightens you, what you got wrong in this roadmap
- [ ] Decide what you want to **own**: a driver, an abstraction, a subsystem area, a piece of tooling
- [ ] Make the maintainership case: propose yourself as `R:` or `M:` for something you have earned
- [ ] Set up your ongoing habits: weekly LWN, weekly list reading, monthly contribution target, quarterly deep-dive
- [ ] Choose the next specialization: GPU (Nova depth), storage, networking, virtualization, security, or the Rust abstraction layer itself
- [ ] Plan the next 18 months. You are not finished; you are equipped

### Ongoing habits (from Week 8, forever)
- [ ] **Read the lists weekly.** You learn the culture by osmosis and the technology by exposure
- [ ] **Boot every change.** No exceptions
- [ ] **Submit the kernel way:** `format-patch` → `checkpatch` → `get_maintainer` → `send-email` → `Signed-off-by:` → review → vN. No GitHub PRs
- [ ] **Never paste code you do not understand into a patch.** Your reputation is the only currency you have
- [ ] **Keep the journal.** Every failure, every measurement, every surprise
- [ ] **Conferences:** Kangrejos, Linux Plumbers (Rust MC), XDC, FOSDEM, Embedded Open Source Summit

[⬆ Back to Table of Contents](#toc)

---

# ═══════════════════════════════════════════════════
# APPENDIX: ESSENTIAL RESOURCES
# ═══════════════════════════════════════════════════

## Books

### Rust
- [ ] **"The Rust Programming Language"** (Klabnik & Nichols, free online) — the baseline. Ch. 4, 10, 13, 15, 16, 19 matter most
- [ ] **"Rust Atomics and Locks"** (Mara Bos, free online) — *the* book for Month 2 and Month 6. Read it twice
- [ ] **"The Rustonomicon"** (free online) — `unsafe`, aliasing, layout, variance. Non-optional for kernel work
- [ ] **"Rust for Rustaceans"** (Jon Gjengset) — the intermediate-to-advanced gap-filler: traits, lifetimes, `unsafe`, FFI, testing
- [ ] **"Programming Rust"** (Blandy, Orendorff, Tindall) — the best treatment of the ownership/borrow model for systems programmers
- [ ] **"Comprehensive Rust"** (Google, free online) — includes a **bare-metal / `no_std`** section directly relevant to kernel work
- [ ] **"Learn Rust With Entirely Too Many Linked Lists"** (free online) — the unsafe/intrusive chapters teach exactly what kernel lists need
- [ ] **"Writing an OS in Rust"** (Philipp Oppermann, free online) — `no_std` from first principles; excellent intuition builder

### Linux Kernel
- [ ] **"Linux Kernel Programming"** + **"Linux Kernel Programming Part 2"** (Kaiwan N. Billimoria) — the most modern hands-on pair; start here
- [ ] **"Linux Device Drivers, 3rd ed."** (Corbet, Rubini, Kroah-Hartman, free PDF) — APIs are dated, the mental model is timeless
- [ ] **"Linux Device Driver Development"** (John Madieu) — modern APIs, device tree, subsystem integration
- [ ] **"Linux Kernel Development, 3rd ed."** (Robert Love) — the clearest explanation of scheduling, memory, and synchronization concepts
- [ ] **"Is Parallel Programming Hard, And, If So, What Can You Do About It?"** (Paul McKenney, free) — the definitive source on RCU, memory ordering, and kernel concurrency
- [ ] **"Understanding the Linux Kernel"** (Bovet & Cesati) — very dated, still useful for architectural intuition
- [ ] **"The Linux Programming Interface"** (Kerrisk) — you have it in `LINUX/`. The userspace side of every interface you will build
- [ ] **"Mastering KVM Virtualization"** — you have it in `LINUX/kvm-virtualization/`. Directly supports Month 14
- [ ] **"Operating Systems: Three Easy Pieces"** (free online) — if any OS fundamental feels shaky, this fixes it fast

## Courses, Labs & Training
- [ ] **LFD103: A Beginner's Guide to Linux Kernel Development** (Linux Foundation, free) — do this in Month 1
- [ ] **Linux Kernel Labs** ([linux-kernel-labs.github.io](https://linux-kernel-labs.github.io/)) — hands-on labs with QEMU; includes Rust material
- [ ] **Bootlin training materials** (free slides + labs) — the best free kernel and driver development curriculum in existence
- [ ] **kernelnewbies.org** — the newcomer's map, including first-patch guidance
- [ ] **The Eudyptula Challenge** task list (the original program is defunct, the tasks circulate) — an excellent self-directed exercise ladder
- [ ] **Rustlings** — quick syntax reps for Month 1
- [ ] **Exercism Rust track** — mentored practice if you want feedback on style
- [ ] **Kangrejos** talk archives — the Rust-for-Linux workshop; watch everything
- [ ] **Linux Plumbers Rust microconference** archives — the design discussions that shape the future
- [ ] **Kernel Recipes** and **XDC** talk archives — kernel and GPU internals from the people who write them

## Code To Study (In-Tree and Out)

### In-tree Rust — read these in this order
- [ ] `samples/rust/` — the minimal examples; start here
- [ ] `rust/kernel/prelude.rs`, `error.rs`, `alloc/` — the foundations
- [ ] `drivers/net/phy/ax88796b_rust.rs` — the first useful Rust driver; short enough to fully understand
- [ ] `drivers/block/rnull.rs` — the Rust null block driver; your BlockForge template
- [ ] `rust/kernel/sync/` — locks, `Arc`, `CondVar`; the concurrency foundations
- [ ] `rust/kernel/pci.rs`, `platform.rs`, `device.rs`, `devres.rs`, `revocable.rs` — the driver model
- [ ] `rust/pin-init/` and `rust/kernel/init.rs` — pinning and in-place initialization
- [ ] `drivers/android/` (Rust Binder) — the largest, most mature Rust driver in the tree
- [ ] `rust/kernel/drm/` — the GPU abstractions
- [ ] `drivers/gpu/nova-core/` and `drivers/gpu/drm/nova/` — Nova
- [ ] `rust/macros/` — how `module!`, `#[vtable]`, and `#[pin_data]` work

### In-tree C — read these to build C literacy
- [ ] `drivers/char/misc.c` — the misc device layer you will build on
- [ ] `drivers/block/null_blk/` — the C reference for BlockForge
- [ ] `drivers/gpu/drm/vkms/` — the minimal C DRM driver; TinyDRM's reference
- [ ] `fs/romfs/` or `fs/cramfs/` — a complete, small, read-only filesystem
- [ ] `drivers/pci/probe.c` and `drivers/pci/msi/` — how PCI enumeration and MSI-X actually work
- [ ] Any I2C or SPI sensor driver in `drivers/hwmon/` or `drivers/iio/` — your SensorRS reference

### Out-of-tree
- [ ] [Rust-for-Linux/linux](https://github.com/Rust-for-Linux/linux) — the RfL development tree
- [ ] [Rust-for-Linux/pin-init](https://github.com/Rust-for-Linux/pin-init) — the standalone `pin-init` crate
- [ ] **drm-rust-next** (freedesktop GitLab) — where Nova and Tyr move fastest
- [ ] [AsahiLinux/linux](https://github.com/AsahiLinux/linux) — the Apple AGX Rust GPU driver
- [ ] [rust-vmm](https://github.com/rust-vmm) — Rust virtualization crates; the userspace counterpart to Month 14
- [ ] [virtme-ng](https://github.com/arighi/virtme-ng) — your fast boot loop
- [ ] [b4](https://git.kernel.org/pub/scm/utils/b4/b4.git) — the modern patch workflow tool
- [ ] [syzkaller](https://github.com/google/syzkaller) — the kernel fuzzer
- [ ] [drgn](https://github.com/osandov/drgn) — programmable kernel debugging; underused and excellent
- [ ] [Mesa](https://gitlab.freedesktop.org/mesa/mesa) — NVK and Zink, the userspace half of the GPU stack

## Master Reading List (45 Items)

### Kernel documentation you must read (in-tree, always current)
- [ ] 1. `Documentation/rust/index.rst` — quick-start, general-information, coding-guidelines, arch-support
- [ ] 2. `Documentation/process/submitting-patches.rst`
- [ ] 3. `Documentation/process/submit-checklist.rst`
- [ ] 4. `Documentation/process/coding-style.rst`
- [ ] 5. `Documentation/process/development-process.rst`
- [ ] 6. `Documentation/process/email-clients.rst`
- [ ] 7. `Documentation/process/stable-kernel-rules.rst`
- [ ] 8. `Documentation/process/handling-regressions.rst`
- [ ] 9. `Documentation/process/stable-api-nonsense.rst`
- [ ] 10. `Documentation/process/security-bugs.rst`
- [ ] 11. `Documentation/driver-api/driver-model/` (overview, device, driver, binding, bus)
- [ ] 12. `Documentation/core-api/dma-api.rst` and `dma-api-howto.rst`
- [ ] 13. `Documentation/core-api/memory-allocation.rst`
- [ ] 14. `Documentation/core-api/cachetlb.rst`
- [ ] 15. `Documentation/core-api/workqueue.rst`
- [ ] 16. `Documentation/core-api/genericirq.rst`
- [ ] 17. `Documentation/core-api/xarray.rst`
- [ ] 18. `Documentation/core-api/kref.rst`
- [ ] 19. `Documentation/locking/` (locktypes, lockdep-design, mutex-design)
- [ ] 20. `Documentation/kernel-hacking/locking.rst`
- [ ] 21. `Documentation/memory-barriers.txt`
- [ ] 22. `tools/memory-model/Documentation/explanation.txt` (LKMM)
- [ ] 23. `Documentation/RCU/whatisRCU.rst` and `rcu_dereference.rst`
- [ ] 24. `Documentation/filesystems/vfs.rst`
- [ ] 25. `Documentation/filesystems/path-lookup.rst`
- [ ] 26. `Documentation/block/blk-mq.rst` and `writeback_cache_control.rst`
- [ ] 27. `Documentation/PCI/pci.rst` and `msi-howto.rst`
- [ ] 28. `Documentation/devicetree/usage-model.rst` and `bindings/writing-schema.rst`
- [ ] 29. `Documentation/power/runtime_pm.rst`
- [ ] 30. `Documentation/gpu/drm-internals.rst`, `drm-kms.rst`, `drm-mm.rst`, `drm-uapi.rst`
- [ ] 31. `Documentation/driver-api/dma-buf.rst` (including the fence signaling rules)
- [ ] 32. [`docs.kernel.org/gpu/nova/`](https://docs.kernel.org/gpu/nova/) — index, guidelines, and the **TODO list**
- [ ] 33. `Documentation/dev-tools/` (kasan, kcsan, kmsan, ubsan, kunit, kgdb, kmemleak, kcov)
- [ ] 34. `Documentation/trace/` (ftrace, events, tracepoints, histogram)
- [ ] 35. `Documentation/ABI/README` and `Documentation/admin-guide/abi.rst`

### Papers worth reading
- [ ] 36. **"RustBelt: Securing the Foundations of the Rust Programming Language"** (Jung et al., POPL 2018) — the formal case that safe Rust is actually safe
- [ ] 37. **"Safe Systems Programming in Rust"** (Jung et al., CACM 2021) — the accessible version of the above
- [ ] 38. **"Stacked Borrows: An Aliasing Model for Rust"** (Jung et al., POPL 2020) — the aliasing rules your `unsafe` must respect
- [ ] 39. **"Tree Borrows"** (Villani et al., PLDI 2025) — the successor aliasing model
- [ ] 40. **"An Empirical Study of Rust-for-Linux: The Success, Dissatisfaction, and Compromise"** (Li et al., USENIX ATC 2024) — the honest account of what is hard
- [ ] 41. **"Understanding Memory and Thread Safety Practices and Issues in Real-World Rust Programs"** (Qin et al., PLDI 2020) — where real Rust code still goes wrong
- [ ] 42. **"Frightening small children and disconcerting grown-ups: Concurrency in the Linux kernel"** (Alglave et al., ASPLOS 2018) — the LKMM paper
- [ ] 43. **"The benefits and costs of writing a POSIX kernel in a high-level language"** (Cutler et al., OSDI 2018) — Biscuit; the honest cost accounting
- [ ] 44. **"Tock: Multiprogramming a 64kB Computer Safely and Efficiently"** (Levy et al., SOSP 2017) — Rust OS design; the `unsafe`-minimization argument
- [ ] 45. **"Theseus: an Experiment in Operating System Structure and State Management"** (Boos et al., OSDI 2020) and **"RedLeaf"** (Narayanan et al., OSDI 2020) — how far Rust's type system can be pushed in an OS

### Read continuously, not once
- [ ] **LWN.net** — the Kernel page weekly. A subscription is the single best value in kernel development
- [ ] **`rust-for-linux@vger.kernel.org`** — weekly, via `lore` if not subscribed
- [ ] **`lore.kernel.org`** — read the review threads for every patch you find interesting

## Kernel Rust Abstraction Checklist

Track which `rust/kernel` modules you have actually read and used. The list evolves — verify against [rust.docs.kernel.org](https://rust.docs.kernel.org/kernel/).

### Core
- [ ] `prelude` — what every module imports
- [ ] `error` — `Error`, `Result`, error codes
- [ ] `alloc` — `KBox`, `KVec`, allocators, GFP flags
- [ ] `types` — `Opaque`, `ARef`, `AlwaysRefCounted`, `ForeignOwnable`, `ScopeGuard`
- [ ] `init` / `pin-init` — `#[pin_data]`, `pin_init!`, in-place initialization
- [ ] `str` / `fmt` — `CStr`, `CString`, formatting
- [ ] `print` — `pr_*!` and `dev_*!` macros
- [ ] `sync` — `SpinLock`, `Mutex`, `CondVar`, `Arc`, `UniqueArc`, atomics, RCU
- [ ] `workqueue` — deferred work
- [ ] `time` — `Instant`, `Delta`, timers, hrtimer
- [ ] `task` — process/task abstractions
- [ ] `uaccess` — `UserSlice` and userspace copying

### Device model & buses
- [ ] `device` / `device_id` — `Device`, lifetime states
- [ ] `driver` — generic registration machinery
- [ ] `devres` / `revocable` — device-lifetime-bound resources
- [ ] `pci` — PCI driver and device
- [ ] `platform` — platform bus
- [ ] `of` — device tree / open firmware
- [ ] `auxiliary` / `faux` — auxiliary and faux buses
- [ ] `i2c` — I2C driver subsystem
- [ ] `io` — memory-mapped I/O
- [ ] `irq` — interrupt abstractions
- [ ] `dma` — DMA mappings, `CoherentAllocation`
- [ ] `scatterlist` — scatter-gather lists
- [ ] `iommu` — IOMMU support
- [ ] `firmware` — firmware loading

### Power & clocks
- [ ] `clk` — clock framework
- [ ] `regulator` — voltage regulators
- [ ] `opp` — operating performance points
- [ ] `cpufreq` / `cpu` / `cpumask` — CPU frequency and masks
- [ ] `pwm` — PWM subsystem
- [ ] `processor` — processor primitives

### Interfaces
- [ ] `miscdevice` — misc device registration
- [ ] `ioctl` — ioctl number helpers
- [ ] `debugfs` — debugfs abstraction
- [ ] `configfs` — userspace-driven object creation
- [ ] `seq_file` — sequential file output
- [ ] `module_param` — module parameters
- [ ] `sysfs` — device attributes *(check current status; was in RFC)*

### Data structures
- [ ] `list` — intrusive linked lists
- [ ] `rbtree` — red-black trees
- [ ] `xarray` — sparse arrays
- [ ] `maple_tree` — range storage
- [ ] `bitmap` / `bits` / `id_pool` — bit and ID management
- [ ] `num` / `sizes` / `ptr` — numeric and pointer helpers

### Subsystems
- [ ] `block` — block layer (blk-mq)
- [ ] `fs` — filesystem support
- [ ] `net` — networking, including `net::phy`
- [ ] `drm` — DRM/GPU abstractions
- [ ] `gpu` — GPU subsystem abstractions
- [ ] `mm` / `page` — memory management
- [ ] `iov` — I/O vectors
- [ ] `cred` / `security` — credentials and security
- [ ] `pid_namespace` — PID namespaces
- [ ] `usb` — USB support *(check current status; was in RFC)*

### Meta
- [ ] `kunit` — kernel unit testing
- [ ] `interop` — C interfacing infrastructure
- [ ] `jump_label` — static keys
- [ ] `bug` — `BUG`/`WARN` support
- [ ] `build_assert` — build-time assertions
- [ ] `transmute` / `zerocopy` — safe byte reinterpretation
- [ ] `tracepoint` — tracepoints from Rust

## Kernel Internals Knowledge Checklist
- [ ] Source tree layout and how to find anything in it
- [ ] Kconfig and Kbuild, including fragments and `merge_config.sh`
- [ ] Module lifecycle: init, exit, refcounting, and why unload can fail
- [ ] Device/driver model: buses, `probe`/`remove`, matching, refcounting
- [ ] Device tree and ACPI as discovery mechanisms
- [ ] PCI: config space, BARs, capabilities, MSI/MSI-X, hotplug
- [ ] MMIO discipline: barriers, posted writes, why MMIO is not memory
- [ ] Interrupts: contexts, top/bottom half, threaded IRQs, affinity
- [ ] Memory: slab vs page vs vmalloc, GFP flags, allocation contexts
- [ ] DMA: coherent vs streaming, direction, masks, cache coherency, IOMMU, scatter-gather
- [ ] Locking: spinlock vs mutex, IRQ-safe variants, lockdep, lock ordering
- [ ] RCU: read-side, grace periods, publish-subscribe, when it applies
- [ ] The Linux Kernel Memory Model and memory barriers
- [ ] Per-CPU data, false sharing, cache-line alignment
- [ ] Reference counting patterns and the lookup-and-get race
- [ ] Userspace interfaces: sysfs, debugfs, configfs, ioctl, netlink, char devices
- [ ] uAPI stability: struct layout, extension mechanisms, "we do not break userspace"
- [ ] Power management: runtime PM, suspend/resume, power domains, OPP
- [ ] VFS: superblocks, inodes, dentries, page cache, mount lifecycle
- [ ] Block layer: bio/request, blk-mq, flush/FUA semantics
- [ ] Networking: `net_device`, `sk_buff`, NAPI, PHY/MDIO
- [ ] DRM/GPU: KMS, GEM, `dma-buf`, `dma-fence`, scheduler, GPUVM/VM_BIND
- [ ] Virtualization: virtio rings, VFIO, KVM concepts, vhost
- [ ] Memory management internals: pages/folios, VMAs, fault handling, shrinkers, reclaim
- [ ] Tracing: tracepoints, ftrace, perf, eBPF, static keys
- [ ] Debugging: oops anatomy, KASAN/KCSAN/UBSAN, `kmemleak`, kgdb, drgn
- [ ] Testing: KUnit, kselftest, fault injection, coverage
- [ ] Security: threat model, bug classes, hardening, fuzzing, disclosure

## Upstream Workflow Checklist
- [ ] `git send-email` configured and verified by mailing yourself
- [ ] `b4` installed and used to fetch, apply, and track real series
- [ ] `scripts/checkpatch.pl` — run with `--strict` on every patch
- [ ] `scripts/get_maintainer.pl` — and knowing when to add a list it missed
- [ ] `rustfmt`, `clippy`, `rustdoc`, and `make W=1` all clean
- [ ] Commit message conventions: subject prefix, imperative mood, why-not-what body
- [ ] Series structure: one logical change per patch, each building and booting alone
- [ ] Cover letter that a maintainer can act on in 60 seconds
- [ ] Trailers: `Signed-off-by:` (DCO), `Reviewed-by:`, `Tested-by:`, `Acked-by:`, `Reported-by:`, `Suggested-by:`, `Closes:`
- [ ] `Fixes:` tag format, and finding the introducing commit
- [ ] `Cc: stable@vger.kernel.org # 6.x+` when a fix qualifies
- [ ] Correct base tree, and stating it in the cover letter
- [ ] Testing section: architectures, configs, sanitizers, suites, hardware
- [ ] Plain-text mail, no HTML, no top-posting, reply inline
- [ ] Answering **every** review comment, in code or in prose
- [ ] Versioning: `[PATCH v2]` with a changelog per patch and in the cover letter
- [ ] Never going quiet on a series — silence kills more patches than objections do
- [ ] Giving reviews as well as receiving them

## Communities, Lists & Conferences

### Mailing lists
- [ ] `rust-for-linux@vger.kernel.org` — **your home list**
- [ ] `linux-kernel@vger.kernel.org` — read via `lore`; subscribing is a firehose
- [ ] `kernelnewbies@kernelnewbies.org` — the friendly place to ask beginner questions
- [ ] `dri-devel@lists.freedesktop.org` — DRM/GPU
- [ ] `nouveau@lists.freedesktop.org` — Nouveau and Nova
- [ ] Your target subsystem's list (find it with `get_maintainer.pl`)
- [ ] `lore.kernel.org` — the archive; learn to search it well

### Chat
- [ ] **Rust-for-Linux Zulip** — the primary discussion venue; read daily, ask when stuck
- [ ] **OFTC IRC:** `#dri-devel`, `#nouveau`, `#kernelnewbies`, `#linux-rust`
- [ ] `#rust-embedded` / the Rust community Discord for language-level questions

### Conferences
- [ ] **Kangrejos** — the Rust-for-Linux workshop. The single most relevant event
- [ ] **Linux Plumbers Conference** — the Rust microconference is where design gets decided
- [ ] **XDC (X.Org Developers Conference)** — GPU/DRM
- [ ] **FOSDEM** — accessible, broad, good first conference
- [ ] **Embedded Open Source Summit** — driver and BSP focus
- [ ] **Linux Storage, Filesystem, MM & BPF Summit** — if you go the storage route

## Lab & Hardware Checklist
- [ ] WSL2 Ubuntu (or a native Linux box) with 40+ GB free and `ccache` configured
- [ ] `/dev/kvm` available and verified
- [ ] QEMU for x86_64, aarch64, riscv64, s390x
- [ ] `virtme-ng` for sub-60-second boot loops
- [ ] Serial console capture to a file, always on
- [ ] Cross toolchains for at least four architectures
- [ ] `git send-email` working, verified
- [ ] `b4`, `drgn`, `trace-cmd`, `perf`, `fio`, `xfstests` installed
- [ ] **A cheap ARM board** (Raspberry Pi or similar) with exposed I2C, SPI, and GPIO — needed by Month 5
- [ ] **An I2C or SPI sensor** with a public datasheet — needed by Month 5
- [ ] A logic analyzer (optional, ~$15 for a basic one) — makes bus debugging enormously easier
- [ ] A sacrificial x86 box or dual-boot partition — needed for bare-metal and real PCI work
- [ ] **A GA102 GPU (RTX 3090 / 3090 Ti)** — required for Nova hardware work by Month 9
- [ ] A second machine for serial console and network boot (nice to have, not required)

## Troubleshooting Cheat Sheet

| Symptom | Likely Cause | What To Do |
|---------|--------------|------------|
| `make LLVM=1 rustavailable` says no | `rustc`/`bindgen`/`libclang` version mismatch | Read its exact output; check `scripts/min-tool-version.sh`; install the pinned version with `rustup`. Never trust a blog's version number |
| `CONFIG_RUST` will not enable | Toolchain not satisfied, or a conflicting option | Fix `rustavailable` first. Then check for `CONFIG_MODVERSIONS`, `CONFIG_GCC_PLUGINS`, or LTO conflicts |
| `rust-analyzer` sees nothing | Missing generated config | `make LLVM=1 rust-analyzer`, then point your editor at the generated `rust-project.json` |
| Module builds but will not load | Symbol mismatch, or built against a different kernel | Check `dmesg`; verify `vermagic` matches; rebuild against the running kernel's tree |
| Kernel panics on module load | Bad init, unwrap on `None`, or an `unsafe` bug | Decode with OopsLens; rebuild with KASAN; check for `unwrap()`/`expect()` in your init path |
| KASAN reports use-after-free | Teardown ordering, or a refcount bug | Check the free stack against the access stack. Usual cause: freeing before cancelling a timer, work item, or IRQ |
| lockdep report on load | Lock ordering inversion, or a missing lock class | Read both chains in the report carefully; the fix is usually reordering, not adding a lock |
| KCSAN reports a data race | Genuinely missing synchronization | "Benign" races usually are not. Add the lock, or use `READ_ONCE`/`WRITE_ONCE` with a written justification |
| Driver probes but device does nothing | Power, clocks, or reset not set up | Check regulator → clock → reset → register access order. This is the single most common bring-up bug |
| DMA transfers give garbage | Wrong direction, missing sync, or touching a mapped buffer | Re-read `dma-api-howto.rst`. Test with the IOMMU on and off; behavior differs by architecture |
| Works on x86, breaks on arm64 | Alignment, pointer width, or a missing barrier | Run BootMatrix. Check for `unsigned long` assumptions and unaligned access |
| Suspend hangs | A lock held across suspend, or an interrupt not disabled | Use `/sys/power/pm_test` to isolate the phase; `pm_trace` to find the driver |
| Patch got no reply | Wrong list, wrong base, HTML mail, or bad timing (merge window) | Check `get_maintainer.pl` again; verify plain text; wait a week, then ping politely with a link to the original |
| Patch got a harsh reply | Normal | Separate the technical content from the tone. Answer every point. Send v2. This is how it works |
| Boot loop is too slow | Not using `virtme-ng`, or rebuilding too much | `ccache`, `make -j$(nproc)`, `virtme-ng`, and build only the module when you can |
| Nova will not boot on hardware | Firmware, chip generation, or an unsupported GPU | Read the debugfs GSP log buffers. Confirm your GPU generation is supported in your tree |

---

*Current week: Week 0 — Day 3 (fast boot loop)*
*Days completed: D1 (lab) ✅, D2 (clone + build) ✅ — kernel 7.2.0-rc7, 31.8 s warm rebuild*
*Monthly projects completed: 0 / 34 (17 Project A + 17 Project B)*
*Merged upstream patches: 0*

> **The only metric that matters at the end:** commits in `git.kernel.org/torvalds/linux` with your name on them.

[⬆ Back to Table of Contents](#toc)

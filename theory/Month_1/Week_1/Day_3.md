# M1W1D3 — The Kernel Source Tree ✅ COMPLETED

> **What you need to know already:** your kernel tree from Week 0 (at `$LINUX_TREE`), and Days 1–2.
> Today is not about Rust syntax — it is about finding your way around 95,000 files. Every new tool is
> explained in a **🆕 New tool** box at the moment it first appears.
>
> **Time:** about 90 minutes. Nothing is built or changed today — you only read and search.

After two days of Rust, today is about the kernel itself.

From now on, almost every task starts with the same two questions: *where is the code for this?* and
*who looks after it?* A driver bug, a Rust API you want to use, a patch you want to send — all of them
begin there. Today you learn to answer both quickly, in a codebase of almost forty million lines.

You will not read the kernel today; nobody reads all of it. You will learn its **map**: what lives in
each folder, how to find the driver for a device, how to read the file that says who maintains what,
where all the Rust lives, and how to search the whole tree in a few seconds.

All the numbers below come from your own tree: kernel **7.2.0-rc7** on branch `sanu0`. If your
version is different, your numbers will be a little different, but every method works the same way.

| Part | What you will learn | Time |
|---|---|---|
| Before you start | Get into your tree | 5 min |
| 1 | The map: what each top-level folder holds | 10 min |
| 2 | `drivers/`, and the drivers your machine is using right now | 15 min |
| 3 | `MAINTAINERS`: who looks after what | 15 min |
| 4 | Where the Rust lives | 15 min |
| 5 | Searching the tree fast | 15 min |
| 6 | The Rust census | 10 min |
| Your turn | Three things to find, and check yourself | 5 min |

---

## Before You Start (5 minutes)

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

cd "$LINUX_TREE"
git status -sb
make -s kernelversion
```

`git status -sb` should show you on `sanu0` with nothing changed, and `make -s kernelversion` prints
the version of the source you are reading. If `$LINUX_TREE` is empty, use the path directly:
`cd ~/LKD_RUST/kernel/linux`.

Every command today is safe to run. Nothing you do changes the kernel source.

---

## Part 1 — The Map (10 minutes)

Your tree holds **94,857 files**. Start by looking at the top level:

```bash
ls
```

Here is what the main folders hold, with how many files each one has in your tree:

| Folder | What lives there | Files |
|---|---|---|
| `drivers/` | Code that talks to hardware: network cards, disks, GPUs, USB, sensors | 37,498 |
| `arch/` | Code for one particular kind of CPU: `x86`, `arm64`, `riscv`, and others | 18,521 |
| `Documentation/` | The kernel's own documentation, including the process docs from Week 0 | 11,301 |
| `tools/` | Programs that ship with the kernel but run outside it, like `perf` | 9,397 |
| `include/` | Header files: shared definitions that C code across the kernel uses | 6,675 |
| `sound/` | Audio drivers | 2,981 |
| `fs/` | Filesystems: ext4, btrfs, the 9p filesystem `vng` uses, and more | 2,369 |
| `net/` | Networking protocols, such as TCP/IP | 1,906 |
| `lib/` | General helpers: string handling, lists, compression | 905 |
| `kernel/` | The core: scheduling, timers, signals, loading modules | 722 |
| `scripts/` | Build and helper scripts, including `checkpatch.pl` and `get_maintainer.pl` | 694 |
| `rust/` | Rust support: the safe kernel API and everything it needs | 585 |
| `samples/` | Small example modules, including `samples/rust/` | 293 |
| `mm/` | Memory management | 201 |
| `block/` | The block layer: what all disks have in common | 103 |

There are a few smaller folders too, such as `security/`, `crypto/`, `io_uring/` and `init/`.

### Machinery versus drivers

Notice that some names appear twice. There is `net/` and also `drivers/net/`. There is `block/` and
also `drivers/block/`. This is one of the most useful things to understand about the layout.

The top-level folder holds the **general machinery** that works the same for everyone. `net/` knows how
TCP works, but it has no idea what network card you own. `drivers/net/` holds the code for each
**specific** network card, which turns "send this packet" into whatever that particular card
understands. The same split applies to `block/` (what all disks share) and `drivers/block/` (code for
specific kinds of disk).

### `drivers/` is most of the kernel

`drivers/` holds 37,498 files — far more than any other folder. Counting lines of C and Rust code, it is
**26 million of the tree's 37.7 million lines: about 69%, more than two thirds.**

The reason is simple. Linux runs on an enormous range of hardware — phones, servers, laptops, cars,
routers — and every kind of device needs its own driver. The core of the kernel, by contrast, is
surprisingly small: `kernel/` has 722 files and `mm/` has 201.

This is good news for you. Most kernel work, and most beginner-friendly kernel work, is driver work.

> **▶ Try it.** Run `ls` in your tree and find each folder from the table. Then run `ls drivers` to see
> how many kinds of driver there are.

---

## Part 2 — `drivers/`, and the Drivers Your Machine Is Using Right Now (15 minutes)

### What a driver is

A **driver** is the part of the kernel that knows how to talk to one kind of device. The rest of the
kernel speaks in general terms — "send this packet", "read this block from the disk" — and the driver
translates that into the exact commands its device understands.

`drivers/` has **144 subfolders**, one for each kind of device or bus. The biggest, by number of files:

| Subfolder | Holds | Files |
|---|---|---|
| `drivers/gpu/` | Graphics cards | 8,160 |
| `drivers/net/` | Network cards | 6,794 |
| `drivers/media/` | Cameras, TV tuners, video | 3,066 |
| `drivers/clk/` | Clock controllers inside chips | 1,426 |
| `drivers/staging/` | Drivers not yet good enough for the main tree | 1,140 |
| `drivers/usb/` | USB | 868 |
| `drivers/scsi/` | Disk controllers | 855 |

`drivers/staging/` is worth a moment. It holds drivers that do not yet meet the kernel's normal quality
standard but are useful enough to include while they improve. Its own description says these drivers
"are not of the 'normal' Linux kernel quality level". It is also a classic place for first patches.

### Which drivers is *your* machine using?

The best way to learn `drivers/` is to find the drivers you are using at this moment.

Your WSL is a virtual machine run by Windows' Hyper-V. Its "hardware" is mostly virtual devices that
Hyper-V provides, connected through a virtual bus called **VMBus**. Linux has drivers for these, just
like for real hardware. Let us ask the kernel which ones are in use.

> **🆕 New tool — `/sys` and `readlink`**
>
> `/sys` is a special folder that the running kernel fills with live information about devices and
> drivers. Nothing in it is stored on disk; it is the kernel describing itself. Many entries in `/sys`
> are links to other entries, and `readlink -f` shows where a link finally points.

Your network card shows up in Linux as `eth0`. Ask which driver runs it:

```bash
readlink -f /sys/class/net/eth0/device/driver
```

```text
/sys/bus/vmbus/drivers/hv_netvsc
```

Your network card is driven by **`hv_netvsc`**. Now list every VMBus driver that is loaded:

```bash
ls /sys/bus/vmbus/drivers
```

```text
dxgkrnl  hv_balloon  hv_netvsc  hv_pci  hv_sock  hv_storvsc  hv_utils  hyperv_keyboard
```

These are the drivers your machine is using right now: the network card (`hv_netvsc`), the disk
controller (`hv_storvsc`), giving unused memory back to Windows (`hv_balloon`), the keyboard, and
others.

### From a driver's name to its source code

You have a name. How do you find the code? **Search the Makefiles.** Every kernel module is built by a
line in some `Makefile`, and that line uses the module's name:

```bash
git grep -n 'hv_netvsc' -- '*Makefile'
```

```text
drivers/net/hyperv/Makefile:2:obj-$(CONFIG_HYPERV_NET) += hv_netvsc.o
drivers/net/hyperv/Makefile:4:hv_netvsc-y := netvsc_drv.o netvsc.o rndis_filter.o netvsc_trace.o netvsc_bpf.o
```

(`git grep` is today's most important tool — Part 5 explains it properly. For now, read it as "search the
kernel's files".)

Read those two lines in plain words. The first says: *if the `HYPERV_NET` option is turned on, build a
module called `hv_netvsc`.* The second says *what it is made of*: `netvsc_drv.c`, `netvsc.c`,
`rndis_filter.c`, and two more. So your network card's driver lives in `drivers/net/hyperv/`, and the
main file is `netvsc_drv.c`. (You will learn exactly how Makefiles and options work on Day 5.)

The same search finds your other two most important drivers:

```text
drivers/scsi/Makefile:142:obj-$(CONFIG_HYPERV_STORAGE)	+= hv_storvsc.o
drivers/scsi/Makefile:172:hv_storvsc-y			:= storvsc_drv.o
drivers/hv/Makefile:2:obj-$(CONFIG_HYPERV_VMBUS)	+= hv_vmbus.o
drivers/hv/Makefile:11:hv_vmbus-y := vmbus_drv.o \
```

So the three drivers your machine depends on most are:

| Device | Driver | Source |
|---|---|---|
| Network card | `hv_netvsc` | `drivers/net/hyperv/netvsc_drv.c` |
| Disk controller | `hv_storvsc` | `drivers/scsi/storvsc_drv.c` |
| The VMBus itself | `hv_vmbus` | `drivers/hv/vmbus_drv.c` |

**Two catches when you use this method on other machines.** First, module names in `/sys` and `lsmod`
use underscores, but Makefiles often use hyphens — `snd_hda_intel` is built from `snd-hda-intel.o`. The
kernel treats the two as the same, so put `[-_]` in their place when you search:
`git grep -n -E 'snd[-_]hda[-_]intel\.o' -- '*Makefile'`. Second, some folders use a file called
`Kbuild` instead of `Makefile` — the open-source NVIDIA driver, `nouveau`, has 61 of them and no
`Makefile` at all — so search both: `-- '*Makefile' '*Kbuild'`.

**On a native Linux machine** there is no `/sys/bus/vmbus` at all: real hardware sits on real buses,
mostly PCI, plus USB and "platform" devices built into the chipset. `ls /sys/bus/` lists every bus,
the `readlink` trick above works on any device, and `lspci -k` (from the `pciutils` package) prints
every PCI device with a `Kernel driver in use:` line. A typical laptop would show drivers such as
`iwlwifi` (Intel Wi-Fi, `drivers/net/wireless/intel/iwlwifi/`), `nvme` (the SSD,
`drivers/nvme/host/`) and `i915` or `xe` (Intel graphics, `drivers/gpu/drm/`).

> **▶ Try it.** Run the `readlink`, `ls` and `git grep` commands above. Then repeat the search for
> `hv_storvsc` and `hv_vmbus`, and open one of the source files with `less` to see what a driver looks
> like. Press `q` to leave `less`.

### The surprise in the list

One name in the VMBus list is different: **`dxgkrnl`**, the driver that lets WSL use your graphics card.
Search for it:

```bash
git grep -il dxgkrnl | wc -l
```

```text
0
```

Zero. It is not in your tree at all. Why?

Because **the kernel your WSL is running is not the kernel you cloned.** Check the running kernel:

```bash
uname -r
```

```text
6.18.54.1-microsoft-standard-WSL2
```

WSL runs Microsoft's own build of Linux, version 6.18, with extra drivers added that were never
accepted into the official kernel. The tree you cloned is upstream Linux 7.2.0-rc7, exactly as Linus
publishes it. Companies and Linux distributions often run upstream plus their own additions. Upstream
is the shared base that everyone starts from — and it is what you are learning to contribute to.

This is also why the kernel you build only ever runs inside QEMU, and never replaces WSL's own kernel.

---

## Part 3 — `MAINTAINERS`: Who Looks After What (15 minutes)

In Week 0 you ran `scripts/get_maintainer.pl` to find out who to send a patch to. Today you read the
file it reads.

`MAINTAINERS` is a plain text file at the top of the tree. In your version it is **29,847 lines** long,
made of one entry for each area of the kernel. The top of the file explains what each field means, and
it is worth reading in the kernel's own words:

```bash
sed -n '5,22p' MAINTAINERS
```

```text
	M: *Mail* patches to: FullName <address@domain>
	R: Designated *Reviewer*: FullName <address@domain>
	   These reviewers should be CCed on patches.
	L: *Mailing list* that is relevant to this area
	S: *Status*, one of the following:
	   Supported:	Someone is actually paid to look after this.
	   Maintained:	Someone actually looks after it.
	   Odd Fixes:	It has a maintainer but they don't have time to do
			much other than throw the odd patch in. See below..
	   Orphan:	No current maintainer [but maybe you could take the
			role as you write your new code].
	   Obsolete:	Old code. Something tagged obsolete generally means
			it has been replaced by a better system and you
			should be using that.
	W: *Web-page* with status/info
	Q: *Patchwork* web based patch tracking system site
```

### Reading a real entry: Rust

> **🆕 New tool — `sed -n '/A/,/B/p'`**
>
> `sed` is a tool that processes text line by line. `sed -n '/^RUST$/,/^$/p' MAINTAINERS` means: print
> the lines starting at the one that is exactly `RUST`, up to the next empty line. That prints one whole
> entry.

```bash
sed -n '/^RUST$/,/^$/p' MAINTAINERS
```

```text
RUST
M:	Miguel Ojeda <ojeda@kernel.org>
R:	Boqun Feng <boqun@kernel.org>
R:	Gary Guo <gary@garyguo.net>
R:	Björn Roy Baron <bjorn3_gh@protonmail.com>
R:	Benno Lossin <lossin@kernel.org>
R:	Andreas Hindborg <a.hindborg@kernel.org>
R:	Alice Ryhl <aliceryhl@google.com>
R:	Trevor Gross <tmgross@umich.edu>
R:	Danilo Krummrich <dakr@kernel.org>
R:	Daniel Almeida <daniel.almeida@collabora.com>
R:	Tamir Duberstein <tamird@kernel.org>
R:	Alexandre Courbot <acourbot@nvidia.com>
R:	Onur Özkan <work@onurozkan.dev>
L:	rust-for-linux@vger.kernel.org
S:	Supported
W:	https://rust-for-linux.com
B:	https://github.com/Rust-for-Linux/linux/issues
C:	zulip://rust-for-linux.zulipchat.com
P:	https://rust-for-linux.com/contributing
T:	git https://github.com/Rust-for-Linux/linux.git rust-next
F:	.clippy.toml
F:	.rustfmt.toml
F:	Documentation/rust/
F:	include/trace/events/rust_sample.h
F:	rust/
F:	samples/rust/
F:	scripts/*rust*
F:	tools/testing/selftests/rust/
K:	\b(?i:rust)\b
```

Read it top to bottom, and it tells you everything about working on kernel Rust.

**`M:` Miguel Ojeda** is the maintainer: the person with the final say, who applies patches. **`R:`** are
the reviewers — twelve people who want to see Rust patches and comment on them.

**`L:`** is the mailing list where Rust patches and discussion go — the list Week 0 Day 5 suggested
subscribing to.

**`S: Supported`** means someone is paid to look after this area — the strongest status there is.

**`W:`**, **`B:`**, **`C:`** and **`P:`** are the website, where to report bugs, the chat (the Zulip from
Week 0 Day 5), and a guide to contributing.

**`T:`** is the most important line for sending patches. It names the **git tree** this area's patches go
into: the `rust-next` branch of the Rust-for-Linux repository. This is why, in Week 0, you learned to
base Rust patches on `rfl/rust-next` rather than on Linus's `master`.

**`F:`** lines list the files this entry covers. `F: rust/` means "everything under `rust/`", and
`scripts/*rust*` means "any file in `scripts/` with `rust` in its name". The whole file has 9,738 `F:`
lines, and they are how `get_maintainer.pl` connects a file to the people who look after it.

**`K:`** is a keyword pattern. Any patch that mentions the word "rust" — in any letter case — is also
matched to this entry, even if it changes files outside `rust/`.

### One file, several entries

A single file is often covered by more than one entry. Your network card driver is a good example:

```bash
scripts/get_maintainer.pl --no-rolestats -f drivers/net/hyperv/netvsc_drv.c
```

```text
"K. Y. Srinivasan" <kys@microsoft.com>
Haiyang Zhang <haiyangz@microsoft.com>
Wei Liu <wei.liu@kernel.org>
Dexuan Cui <decui@microsoft.com>
Long Li <longli@microsoft.com>
Andrew Lunn <andrew+netdev@lunn.ch>
"David S. Miller" <davem@davemloft.net>
Eric Dumazet <edumazet@google.com>
Jakub Kicinski <kuba@kernel.org>
Paolo Abeni <pabeni@redhat.com>
linux-hyperv@vger.kernel.org
netdev@vger.kernel.org
linux-kernel@vger.kernel.org
```

Two groups of people appear, because two entries match. The **Hyper-V/Azure** entry covers
`drivers/net/hyperv/` (those are the Microsoft engineers), and the **NETWORKING DRIVERS** entry covers
all of `drivers/net/` (the networking maintainers). `get_maintainer.pl` combines every entry that
matches, and adds `linux-kernel@vger.kernel.org` for everything.

The same happens with Rust's memory allocation code. `rust/kernel/alloc/kbox.rs` matches the `RUST`
entry *and* a smaller entry called `RUST [ALLOC]`, whose reviewers are memory-management experts —
which makes sense for code that hands out memory.

> **▶ Try it.** Print the Rust entry with the `sed` command above. Then run `get_maintainer.pl` on your
> network driver, and on `drivers/gpu/nova-core/` — the NVIDIA GPU driver you will study in Month 9.
> Which tree does nova-core's entry name?

---

## Part 4 — Where the Rust Lives (15 minutes)

### The `rust/` folder

```bash
ls -d rust/*/
```

```text
rust/bindings/
rust/helpers/
rust/kernel/
rust/macros/
rust/pin-init/
rust/proc-macro2/
rust/quote/
rust/syn/
rust/uapi/
rust/zerocopy-derive/
rust/zerocopy/
```

(Plain `ls rust/` also shows files ending in `.o` and `.rmeta`. Those are build output from Week 0,
not source.)

Remember the three layers from Week 0 Day 4: C headers become raw Rust through `bindgen`, a safe layer
is written on top, and drivers use only the safe layer. Each of these folders is one part of that
picture.

**`rust/bindings/`** is where the raw, automatically generated Rust versions of the kernel's C
declarations live. Almost nothing here is written by hand — the big generated file only appears when you
build. Everything that comes out of it is `unsafe`.

**`rust/helpers/`** is surprising: it holds **63 C files**, inside the Rust folder. Some things in the
kernel's C code are macros or very small "inline" functions that `bindgen` cannot turn into something
Rust can call. So for each one, a tiny C function is written that just calls it, and Rust calls that
instead.

**`rust/kernel/`** is the heart of it all: the safe Rust API that drivers use. It has 156 Rust files and
over 55,000 lines. `KBox` and `KVec` live here (in `alloc/`), `pr_info!` lives here (in `print.rs`), and so
do locks, devices and drivers. This is the folder you will spend the next eighteen months learning.

**`rust/macros/`** holds the kernel's own macros — including `module!`, the one you used in
`hello_rust.rs`.

**`rust/pin-init/`** is a library for safely creating values that must never move in memory once
created, such as locks. You will meet it in Month 2.

**`rust/uapi/`** holds Rust versions of the definitions that userspace programs also see.

**`rust/syn/`, `rust/quote/`, `rust/proc-macro2/`, `rust/zerocopy/` and `rust/zerocopy-derive/`** are
outside libraries that the kernel needs. Remember from Week 0 that the kernel never downloads code with
Cargo: when it needs an outside library, the library is **copied into the tree** and reviewed like any
other kernel code. These five are those copies.

### `samples/rust/`

```bash
ls samples/rust/*.rs
```

Your tree has 15 upstream samples, plus one more: your own `hello_rust.rs`. Each sample shows one part of
the kernel's Rust API — a minimal module, a misc device, a PCI driver, an I2C driver, DMA, and so on.
When you write your first PCI driver in Month 4, `rust_driver_pci.rs` is the first file you will open.

### The Rust drivers already in the kernel

Your tree has **87 Rust files under `drivers/`**. These are the real Rust drivers in the kernel today:

| Where | What it is |
|---|---|
| `drivers/net/phy/ax88796b_rust.rs`, `qt2025.rs` | Drivers for network PHY chips — `ax88796b_rust.rs` was the first Rust driver ever merged |
| `drivers/block/rnull/` | A pretend disk, used for testing the block layer |
| `drivers/android/binder/` | Android's Binder (how Android apps talk to each other), rewritten in Rust |
| `drivers/gpu/nova-core/`, `drivers/gpu/drm/nova/` | **Nova**, the new driver for NVIDIA GPUs — Month 9 |
| `drivers/gpu/drm/tyr/` | Tyr, a driver for Arm Mali GPUs |
| `drivers/gpu/drm/drm_panic_qr.rs` | Draws a QR code on screen when the kernel panics |
| `drivers/cpufreq/rcpufreq_dt.rs` | Controls CPU speed on boards described by a device tree |
| `drivers/pwm/pwm_th1520.rs` | A PWM controller on the T-Head TH1520 chip |

(The roadmap lists `drivers/block/rnull.rs`. In newer kernels it has become a folder,
`drivers/block/rnull/` — which is a small example of why you check your own tree rather than trusting
any written guide, including this one.)

### Look at a real Rust driver

`drivers/net/phy/ax88796b_rust.rs` is only 133 lines long. Its comment says something nice: the C
version of the same driver is right next to it, `ax88796b.c`, at 130 lines. The Rust version is not
longer — and it is the first Rust driver that was ever merged, added on 13 December 2023 and released
in Linux 6.8.

Open it with `less drivers/net/phy/ax88796b_rust.rs`. Here is how it begins:

```rust
use kernel::{
    net::phy::{self, reg::C22, DeviceId, Driver},
    prelude::*,
    uapi,
};

kernel::module_phy_driver! {
    drivers: [PhyAX88772A, PhyAX88772C, PhyAX88796B],
    device_table: [
        DeviceId::new_with_driver::<PhyAX88772A>(),
        DeviceId::new_with_driver::<PhyAX88772C>(),
        DeviceId::new_with_driver::<PhyAX88796B>()
    ],
    name: "rust_asix_phy",
    authors: ["FUJITA Tomonori <fujita.tomonori@gmail.com>"],
    description: "Rust Asix PHYs driver",
    license: "GPL",
}
```

You are **not** expected to understand every line today. The goal is to recognise the shape, and you
already know more of it than you might think.

> **🆕 New Rust — `use` with paths and braces**
>
> `use kernel::{ ... }` brings several names from the `kernel` crate into this file at once. It is
> the same idea as `use std::mem;` from Day 1, just listing several names together. `kernel` here means
> `rust/kernel/` — the safe API from the folder above.

`kernel::module_phy_driver! { ... }` is a macro, like `module!` in your `hello_rust.rs` — the same
`name:`, `authors:`, `description:` and `license:` fields, plus a list of the chips this driver
supports. Further down, you will find a struct for each chip and `impl Driver for PhyAX88772A`. That
is a trait, just like `impl Drop for Noisy` from Day 1: "this chip provides what the `Driver` trait asks
for". And its functions return `Result` and use `?`, exactly as in Day 1's `raii_probe.rs`.

> **▶ Try it.** Run `less drivers/net/phy/ax88796b_rust.rs` and find: the macro at the top, the three
> structs, an `impl Driver for` block, and a function that uses `?`. Then compare it with
> `less drivers/net/phy/ax88796b.c`.

---

## Part 5 — Searching the Tree Fast (15 minutes)

### `git grep`

> **🆕 New tool — `git grep`**
>
> `git grep 'text'` searches every file that git tracks for `text`, and prints each matching line.
> It works in any git repository, with nothing to install.

You might wonder why not use the normal `grep -r` command. Here is the same search with each, timed on
your tree:

```text
git grep: 3.3 s
grep -r:  27.9 s
```

`git grep` is more than eight times faster, and the reason also explains why its answer is better.
`git grep` searches only the files that are part of the kernel source. `grep -r` searches **everything**
in the folder — including your build output. After building in Week 0, your tree has **73,246** extra
files that git ignores, and the whole folder takes 8.7 GB. So `grep -r` wastes time reading compiled
files, and also finds matches you did not want:

```text
./rust/kernel/print.rs:369:macro_rules! pr_info (
./rust/kernel/print.rs:574:macro_rules! pr_info_once (
./Documentation/output/rust/rustdoc/kernel/macro.pr_info_once.html:1:<!DOCTYPE html>...
./Documentation/output/rust/rustdoc/kernel/macro.pr_info.html:1:<!DOCTYPE html>...
```

Those last two lines come from the documentation you generated with `make rustdoc` in Week 0. `git grep`
gives you only the first two — the real source.

### The five things you will do most

**Find where something is defined.** Search for how a definition begins: `struct Name`, `fn name`,
`macro_rules! name`, or `pub type Name`.

```bash
git grep -n 'macro_rules! pr_info'
```

```text
rust/kernel/print.rs:369:macro_rules! pr_info (
rust/kernel/print.rs:574:macro_rules! pr_info_once (
```

`-n` adds line numbers, so you know exactly where to look: `pr_info!` is defined on line 369 of
`rust/kernel/print.rs`. In the same way, `git grep -n 'pub type KBox'` takes you to
`rust/kernel/alloc/kbox.rs` line 116.

**Search only part of the tree.** Put `--` and then a folder or a file pattern at the end:

```bash
git grep -n 'fn probe' -- 'drivers/*.rs'
```

```text
drivers/cpufreq/rcpufreq_dt.rs:207:    fn probe<'bound>(
drivers/gpu/drm/nova/driver.rs:59:    fn probe<'bound>(
drivers/gpu/drm/tyr/driver.rs:103:    fn probe<'bound>(
drivers/gpu/nova-core/driver.rs:71:    fn probe<'bound>(
drivers/net/phy/qt2025.rs:43:    fn probe(dev: &mut phy::Device) -> Result<()> {
drivers/pwm/pwm_th1520.rs:316:    fn probe<'bound>(
```

That is every Rust driver's `probe` function — the function a driver runs when it finds its device.
(`'drivers/*.rs'` matches Rust files at any depth under `drivers/`. Always put patterns in quotes.)

**List only the files, not the lines.** Add `-l`:

```bash
git grep -l 'module_phy_driver!' -- drivers
```

```text
drivers/net/phy/ax88796b_rust.rs
drivers/net/phy/qt2025.rs
```

This is the fastest way to answer "who uses this?" For example, `git grep -l 'KVec' -- 'drivers/*.rs'`
shows that 11 Rust driver files use `KVec`.

**Count matches in each file.** Add `-c`:

```bash
git grep -c 'pr_info!' -- samples/rust
```

```text
samples/rust/hello_rust.rs:2
samples/rust/rust_configfs.rs:6
samples/rust/rust_driver_faux.rs:1
samples/rust/rust_minimal.rs:5
samples/rust/rust_misc_device.rs:1
samples/rust/rust_print_main.rs:10
```

There is your own `hello_rust.rs`, with its two `pr_info!` calls.

**See what changed in a file recently.** This one is `git log`, not `git grep`, but you will use it
just as often:

```bash
git log --oneline -3 -- rust/kernel/alloc/kbox.rs
```

```text
36808d5e9839 Merge tag 'driver-core-7.2-rc1' of gitolite.kernel.org:pub/scm/linux/kernel/git/driver-core/driver-core
0bf626dc90ff rust: inline some init methods
e9df918d61e0 rust: alloc: remove `'static` bound on `ForeignOwnable`
```

Two more options are worth knowing: `-w` matches whole words only (so searching for `KBox` does not
also match longer names that contain it), and `-i` ignores upper and lower case.

> **▶ Try it.** Run each search above. Then find where `module_phy_driver!` itself is defined — search
> for `macro_rules! module_phy_driver`.

### Other tools

`git grep` always works, needs no setup, and is all you need today. Two other tools are worth knowing
about.

**ripgrep** (the `rg` command) is another fast search tool that skips build output by itself. It is not
installed on your machine; `sudo apt install ripgrep` adds it if you want it.

**rust-analyzer** gives you "jump to definition" inside an editor. It is already installed on your
machine, and Week 0 created `rust-project.json`, the file that tells it how the kernel's Rust fits
together. Setting up an editor is optional, and described in "If You Have More Time" below.

---

## Part 6 — The Rust Census (10 minutes)

Now you will count all the Rust in the kernel, by joining small commands together — and save the
numbers, so you can watch them grow.

> **🆕 New tool — pipes and counting tools**
>
> The `|` symbol, called a **pipe**, sends one command's output into the next command. These small tools
> are often joined this way:
>
> `git ls-files` lists every file git tracks. `wc -l` counts lines. `cut -d/ -f1` keeps only the
> text before the first `/` on each line. `sort` puts lines in order. `uniq -c` collapses repeated
> lines into one and puts how many there were in front. `sort -rn` sorts by number, biggest first.

Build the census one step at a time, looking at the result of each step.

**Step 1 — list the Rust files.** `-- '*.rs'` keeps only files ending in `.rs`:

```bash
git ls-files -- '*.rs' | head -5
```

```text
drivers/android/binder/allocation.rs
drivers/android/binder/context.rs
drivers/android/binder/deferred_close.rs
drivers/android/binder/defs.rs
drivers/android/binder/error.rs
```

**Step 2 — count them.**

```bash
git ls-files -- '*.rs' | wc -l
```

```text
474
```

**Step 3 — keep only the top-level folder of each.**

```bash
git ls-files -- '*.rs' | cut -d/ -f1 | head -5
```

```text
drivers
drivers
drivers
drivers
drivers
```

**Step 4 — count how many files each folder has.**

```bash
git ls-files -- '*.rs' | cut -d/ -f1 | sort | uniq -c | sort -rn
```

```text
    362 rust
     87 drivers
     19 samples
      3 scripts
      1 tools
      1 mm
      1 lib
```

**Step 5 — count the lines of Rust.** `xargs -0 cat` reads every file in the list, one after another,
and `wc -l` counts the lines of all of them together:

```bash
git ls-files -z -- '*.rs' | xargs -0 cat | wc -l
```

```text
182621
```

(`-z` and `-0` make file names arrive safely even if one contained a space.)

### Save it

`rust_census.sh` puts all of this together, adds lines per folder and a comparison with C, and saves
the result, named after your kernel version:

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/rust_census.sh --save
```

```text
Totals:
  Rust    474 files     182621 lines
  C     63818 files   37173581 lines
  Rust is 0.49% of all C and Rust lines
```

**Rust is about half of one percent of the kernel.** That matches the language bar you saw on your
GitHub fork, which showed Rust at 0.4%. Most of that Rust is the support code in `rust/` — the
biggest piece being `rust/kernel/` at 55,326 lines — while the biggest area of actual Rust drivers is
`drivers/gpu/`, at 16,860 lines.

Save the census into the repository:

```bash
bash ~/LKD_RUST/codes/sync_to_repo.sh
```

Run the census again in a few months and compare. Watching those numbers grow — and finding out which
parts of the kernel gained Rust — is exactly what RustScope, this month's second project, will do in
detail.

---

## Your Turn (5 minutes)

Find these three things on your own, using only `git grep`, `get_maintainer.pl` and `git ls-files`.

1. Which file, and which line, defines the `module!` macro you used in `hello_rust.rs`?
2. Who maintains `drivers/gpu/nova-core/`, which mailing list do patches go to, and which tree?
3. How many Rust files are there under `drivers/gpu/`?

<details>
<summary>Answers</summary>

1. `rust/macros/lib.rs`, line 138: `pub fn module(input: TokenStream) -> TokenStream {`. You can find
   it with `git grep -n 'pub fn module' -- rust/macros/`. Macros live in `rust/macros/`.
2. The entry is called `CORE DRIVER FOR NVIDIA GPUS [RUST]`. The maintainers are Danilo Krummrich and
   Alexandre Courbot, the list is `nova-gpu@lists.linux.dev`, and the tree is `drm-rust-next`.
   `get_maintainer.pl` also adds the DRM maintainers and `dri-devel`, because a second entry matches.
3. 63. One way: `git ls-files -- 'drivers/gpu/*.rs' | wc -l`.

</details>

Then run the check:

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/check_day3.sh
```

---

## Checking Yourself

Without searching, say which folder each of these lives in. Then check yourself with `ls` or
`git grep`.

1. A driver for a network PHY chip
2. The process scheduler
3. The ext4 filesystem
4. The TCP protocol
5. The definition of `pr_info!` for Rust
6. The `module!` macro
7. Shared C header definitions

And one practical question: someone reports a crash in the Rust Binder driver. Which folder do you
look in, and how do you find out who to email?

<details>
<summary>Answers</summary>

1. `drivers/net/phy/`
2. `kernel/sched/`
3. `fs/ext4/`
4. `net/ipv4/` — for example `net/ipv4/tcp.c`. Protocols are machinery, so they live in `net/`, not
   `drivers/net/`.
5. `rust/kernel/print.rs`
6. `rust/macros/`
7. `include/`, mostly `include/linux/`

For Binder: the code is in `drivers/android/binder/`. Run
`scripts/get_maintainer.pl --no-rolestats -f drivers/android/binder/`. In your tree it names Greg
Kroah-Hartman, the Android Binder maintainers, Rust Binder's authors including Alice Ryhl, and
`linux-kernel@vger.kernel.org`.

</details>

---

## Common Confusions

**"`net/` and `drivers/net/` hold the same kind of code."** No. `net/` is the general networking
machinery, such as TCP. `drivers/net/` is code for specific network cards.

**"The kernel I am running is the kernel I cloned."** Not in WSL. WSL runs Microsoft's 6.18 kernel with
extra drivers like `dxgkrnl`. Your clone is upstream 7.2.0-rc7, and it only runs in QEMU.

**"`grep -r` is fine for searching the kernel."** It works, but it is slow and noisy, because it also
searches your build output. Use `git grep`.

**"Each file has one maintainer."** Several entries often match one file, and `get_maintainer.pl`
combines them all. That is why your network driver gets both the Hyper-V and the networking
maintainers.

**"Everything in `rust/` is Rust."** `rust/helpers/` is C — small wrapper functions for things `bindgen`
cannot handle.

**"Rust is a big part of the kernel now."** It is about 0.5% of the lines. It is growing, and it is where
much of the newest work happens, but most of the kernel is still C — which is why reading C stays part
of this roadmap.

**"I need to understand all of `ax88796b_rust.rs`."** Not today. Recognising its shape is the goal.
Understanding it fully is what the next few months are for.

---

## My Notes

### The drivers my machine uses

| Device | Driver name | Source file | How I found it |
|---|---|---|---|
| Network card | | | |
| Disk controller | | | |
| VMBus | | | |

### MAINTAINERS fields, in my own words

| Field | Means |
|---|---|
| `M:` | |
| `R:` | |
| `L:` | |
| `S:` | |
| `T:` | |
| `F:` | |

### My census

| | Files | Lines |
|---|---|---|
| Rust | | |
| C | | |
| Rust share | | |

### Searches I want to remember

### What I still do not understand

---

## Done When

You can name the main top-level folders and what each holds, and explain the difference between
machinery folders like `net/` and driver folders like `drivers/net/`.

You know that `drivers/` is about two thirds of the kernel's code, and why.

You found the drivers your own machine is using through `/sys`, and traced each one to its source file
through its Makefile. You can explain why `dxgkrnl` is not in your tree.

You can read a `MAINTAINERS` entry — `M:`, `R:`, `L:`, `S:`, `T:`, `F:`, `K:` — and you know that Rust
patches go to the `rust-next` tree, and how you found that out.

You can say what lives in `rust/bindings/`, `rust/helpers/`, `rust/kernel/` and `rust/macros/`, and name
three Rust drivers that are in the kernel today.

You can use `git grep` with `-n`, `-l`, `-c` and a `--` path, and explain why it beats `grep -r`.

You built the census pipeline step by step, and saved your census into the repository.

---

## Further Reading

**`Documentation/process/maintainers.rst`** in your tree is the kernel's own explanation of the
`MAINTAINERS` file.

**`Documentation/rust/index.rst`** is the start of the kernel's Rust documentation. Today, just read its
list of contents, to see what topics exist.

---

## If You Have More Time (optional)

**See the drivers inside your own kernel.** Your QEMU kernel uses different, "virtio" virtual devices.
Run `vng --exec 'ls /sys/bus/virtio/drivers'` from your tree, then find each driver's source with the
Makefile method from Part 2.

**Compare C and Rust side by side.** Open `drivers/net/phy/ax88796b.c` and
`drivers/net/phy/ax88796b_rust.rs` together, and match up the functions in one with the functions in the
other.

**Install ripgrep.** Run `sudo apt install ripgrep`, then try `rg 'macro_rules! pr_info'` in your tree
and compare it with `git grep`.

**Set up jump-to-definition.** In Cursor, use "Connect to WSL", open `~/LKD_RUST/kernel/linux`, and
install the rust-analyzer extension. It reads the `rust-project.json` that Week 0 created. The first
time, it takes several minutes to look through the whole tree.

---

## 📖 Revision — Read This First When You Come Back

### The day as a story

The kernel tree has about 95,000 files and 38 million lines, and nobody reads all of it. You learn its
map. `drivers/` is about two thirds of the code, because every device needs its own driver. `arch/` holds
code for each kind of CPU, `include/` the shared headers, `kernel/` and `mm/` the small core, `fs/` and
`net/` the filesystems and protocols, and `rust/` the Rust support. A top-level folder like `net/` is
general machinery; `drivers/net/` is code for specific devices.

To find the driver for a device, ask `/sys` for the driver's name, then search the Makefiles for that
name: the Makefile line names the source files. On WSL, the network card uses `hv_netvsc`
(`drivers/net/hyperv/`), the disk controller `hv_storvsc` (`drivers/scsi/storvsc_drv.c`), and the bus
`hv_vmbus` (`drivers/hv/`). The GPU driver `dxgkrnl` is not in upstream at all, because WSL runs
Microsoft's own kernel, not the one you cloned.

`MAINTAINERS` says who looks after what. `M:` is the maintainer, `R:` the reviewers, `L:` the mailing
list, `S:` the status, `T:` the git tree to base patches on, and `F:` the files covered. Rust patches go to
`rust-for-linux@vger.kernel.org` and the `rust-next` tree. Several entries can match one file, and
`get_maintainer.pl` combines them.

In `rust/`, `bindings/` holds the generated raw bindings, `helpers/` holds small C wrappers, `kernel/` is
the safe API drivers use, and `macros/` holds macros like `module!`. Outside libraries are copied into
the tree, never downloaded. Rust drivers already in the kernel include the ASIX PHY driver (the first,
in 6.8), Android Binder, Nova for NVIDIA GPUs, and Tyr for Arm Mali GPUs.

`git grep` searches only tracked source, so it is fast and skips build output. Rust is about 0.5% of the
kernel's lines, and you saved a census to watch it grow.

### If you remember only five things

1. **`drivers/` is about two thirds of the kernel** — most kernel work is driver work.
2. **Driver name → Makefile → source file.** Search the Makefiles for the name.
3. **`MAINTAINERS`: `M:` decides, `L:` is where to send, `T:` is the tree to base on.**
4. **`rust/kernel/` is the safe API**; `rust/bindings/` is the raw, unsafe layer underneath.
5. **Use `git grep`, not `grep -r`** — faster, and it skips build output.

### Quick recall

Answer each one out loud before opening the answers.

1. About what share of the kernel's code is in `drivers/`, and why?
2. What is the difference between `net/` and `drivers/net/`?
3. How do you find which driver runs your network card?
4. Once you have a driver's name, how do you find its source?
5. Why is `dxgkrnl` not in your tree?
6. What do `M:`, `L:` and `T:` mean in `MAINTAINERS`?
7. Which tree do Rust patches go to?
8. What is in `rust/helpers/`, and why is it there?
9. Name three Rust drivers that are in the kernel today.
10. Why is `git grep` faster than `grep -r` in your tree?

<details>
<summary>Answers</summary>

1. About two thirds — 26 million of 37.7 million lines — because every kind of device needs its own
   driver.
2. `net/` is general networking machinery, such as TCP; `drivers/net/` is code for specific network
   cards.
3. `readlink -f /sys/class/net/eth0/device/driver` — on WSL it is `hv_netvsc`.
4. `git grep -n 'name' -- '*Makefile'`; the Makefile line lists the source files.
5. WSL runs Microsoft's own kernel with extra drivers that are not in upstream Linux.
6. `M:` is the maintainer, `L:` the mailing list, `T:` the git tree to base patches on.
7. `rust-next`, in the Rust-for-Linux repository — from the `T:` line of the `RUST` entry.
8. Small C functions that wrap macros and inline functions `bindgen` cannot turn into Rust.
9. Any three of: the ASIX and QT2025 PHY drivers, rnull, Binder, Nova (nova-core and nova), Tyr, the
   DRM panic QR code, rcpufreq-dt, pwm-th1520.
10. It searches only the files git tracks, so it skips the 73,246 files of build output and does not
    match generated documentation.

</details>

### The commands, in order

```bash
cd "$LINUX_TREE"
ls                                                  # the map
readlink -f /sys/class/net/eth0/device/driver       # which driver runs eth0
ls /sys/bus/vmbus/drivers                           # every VMBus driver in use
git grep -n 'hv_netvsc' -- '*Makefile'              # driver name -> source
git grep -il dxgkrnl | wc -l                        # 0: not upstream
uname -r                                            # the kernel WSL actually runs

sed -n '/^RUST$/,/^$/p' MAINTAINERS                 # read the Rust entry
scripts/get_maintainer.pl --no-rolestats -f drivers/net/hyperv/netvsc_drv.c

ls -d rust/*/                                       # where the Rust lives
git grep -n 'macro_rules! pr_info'                  # where is it defined
git grep -n 'fn probe' -- 'drivers/*.rs'            # search part of the tree
git grep -l 'module_phy_driver!' -- drivers         # only the file names

git ls-files -- '*.rs' | cut -d/ -f1 | sort | uniq -c | sort -rn
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/rust_census.sh --save
```

---

**Next:** M1W1D4 — Structs, Enums, and Pattern Matching. Back to Rust: you will learn enums properly —
the type behind `Option` and `Result` — and `match`, and use them to model a device's states so that
illegal state changes simply cannot be written.

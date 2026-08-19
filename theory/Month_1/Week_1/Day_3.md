# M1W1D3 — The Fast Boot Loop ✅ COMPLETED

> **Completed:** 2026-08-17. QEMU 10.2.1, virtme-ng 1.40 (from `apt`, not pip — see Phase 1).
> Manual QEMU boot reached `VFS: Unable to mount root fs` in **1.7 s** — a clean boot with no root
> filesystem, exactly as intended. After `vng --kconfig` + rebuild (4m58s, build `#3`),
> `vng` gave an interactive shell: hostname `virtme-ng`, kernel `7.2.0-rc7+`, home directory shared in.
>
> **Two real bugs found and fixed in this day's material:**
> - `pip3 install --user virtme-ng` fails on Ubuntu 24.04+ under PEP 668. Use `sudo apt install virtme-ng`.
> - Wrapping `vng` in bare `timeout` freezes the whole process tree in state `T`. `timeout` without
>   `--foreground` moves the child to a new process group, QEMU then counts as a background job, and
>   its terminal access raises SIGTTOU/SIGTTIN — whose default action is *stop*. Fixed in both scripts.

> **Goal:** boot the kernel you built yesterday, get a shell inside it, and get the whole
> edit → build → boot → shell cycle under 60 seconds.
>
> **Time:** 2-3 hours.
>
> **Why this matters:** yesterday's `bzImage` is inert until you can run it. But the real point of
> today is *speed*. Kernel development has no REPL — the only way to know whether your code works is to
> boot it. If that costs five minutes you will test rarely, batch changes, and debug three things at
> once. If it costs thirty seconds you will test constantly and stay in flow. **The length of this loop
> silently determines how much you learn over the next 18 months**, which is why it gets a whole day.

---

## Today's Checklist

- [x] Install QEMU and `virtme-ng`
- [x] Boot your kernel manually with a raw `qemu-system-x86_64` command — and understand the panic
- [x] Understand what a kernel needs in order to reach userspace
- [x] Boot with `vng` and get a real shell inside your own kernel
- [x] Understand what `vng` did that the raw command could not
- [x] Capture the serial console to a file so you never lose an oops
- [x] Measure the full edit → build → boot loop; get it under 60 seconds
- [x] Save your boot commands as scripts you will reuse for 18 months
- [x] Journal: loop time, boot time, and the exact commands

---

## Concepts

### 1. Why you do not boot this on your real machine

You could install your kernel on your laptop and reboot into it. Do not. A kernel bug does not throw an
exception — it panics, hangs, or silently corrupts memory. Recovering means a rescue USB and an
unpleasant evening.

A **virtual machine** gives you three things that matter more than convenience:

- **Crashes are free.** A panic kills a QEMU process. You press up-arrow and try again.
- **The state is fresh every time.** No leftovers from the last broken run confusing your next test.
- **It is fast.** Seconds, not a hardware reboot.

This is why Day 1 spent effort on KVM: your entire development loop lives inside QEMU.

### 2. QEMU: emulator and virtualizer

QEMU does two jobs that people conflate:

**It emulates hardware.** A virtual disk, network card, serial port, PCI bus, interrupt controller. Your
kernel probes these and finds real-looking devices. This is what lets you write a PCI driver in Month 4
without owning the device — you will build the *device* in QEMU and the *driver* in the kernel.

**It executes guest CPU instructions**, in one of two ways:

| Mode | How | Speed |
|---|---|---|
| **KVM** | guest instructions run directly on your CPU via VT-x; only privileged operations trap to the host | near-native |
| **TCG** | QEMU translates guest instructions to host instructions in software | roughly 10-20× slower |

You confirmed `/dev/kvm` on Day 1, so you get the fast path with `-enable-kvm`. TCG still matters later:
it is how you boot an arm64 or riscv64 kernel on an x86 machine in Month 12.

### 3. What a kernel needs to reach userspace

On Day 2 you booted your kernel manually and it panicked. That was not a failure — it means the kernel
booted **perfectly** and then found nothing to hand control to.

A running Linux system needs three things:

1. **A kernel image** — you have this: `bzImage`
2. **A root filesystem** — somewhere `/bin`, `/etc`, `/lib` live
3. **An init process** — the first userspace program, PID 1

The kernel's last act at boot is to execute PID 1. With no root filesystem there is no program to
execute, so it panics. It is the kernel equivalent of a computer with no operating system installed.

The boot sequence, roughly:

```text
QEMU loads bzImage
  -> the compressed image decompresses itself
  -> start_kernel(): set up memory, interrupts, scheduler, drivers
  -> mount the root filesystem
  -> execute /sbin/init as PID 1
  -> userspace runs; you get a shell
```

Day 2 got as far as step 4 and stopped.

### 4. initramfs, and the chicken-and-egg it solves

There is a bootstrapping problem. To mount your root filesystem the kernel may need a driver — for the
NVMe controller, say, or the RAID array, or to decrypt the disk. But that driver is a module, and
modules live on the root filesystem you cannot mount yet.

**initramfs** breaks the loop. It is a small compressed archive of a minimal filesystem that the
bootloader loads into memory alongside the kernel. The kernel unpacks it into a RAM-backed filesystem,
runs the init inside it, and *that* init loads whatever drivers are needed to reach the real root — then
hands over.

Your distribution does this on every boot: `/boot/initrd.img-*` is exactly this file.

For kernel development this matters because an initramfs is often all you need — a kernel plus a
few megabytes of userspace in RAM, no virtual disk at all. That is essentially the trick `virtme-ng`
uses.

### 5. Why serial console, not a graphical one

Everything today uses `-nographic` and `console=ttyS0`. Two reasons.

**Practical:** a serial console is *text in your terminal*. You can scroll it, grep it, pipe it to a
file, and paste it into a bug report. A graphical console is pixels — useless for that.

**Structural:** the serial driver initializes very early in boot, long before graphics. If your kernel
dies in the first two seconds, serial is the only thing that will have printed anything. This is not
nostalgia; it is why every real kernel developer and every server BMC uses serial.

`console=ttyS0` is a **kernel command-line parameter** telling the kernel to send its messages to the
first serial port. `-nographic` tells QEMU to wire that port to your terminal instead of opening a
window.

### 6. The kernel command line

That `-append "..."` string is how you configure a kernel at boot, before any userspace exists. You will
use it constantly:

| Parameter | Effect |
|---|---|
| `console=ttyS0` | send kernel messages to the serial port |
| `panic=1` | reboot 1 second after a panic instead of hanging forever |
| `nokaslr` | disable address randomisation — **essential** when debugging with gdb, so addresses match |
| `loglevel=7` | show all messages including debug |
| `earlyprintk=serial` | print during very early boot, before the console is properly up |
| `init=/bin/sh` | run a shell as PID 1 instead of the normal init |
| `root=/dev/vda` | which device holds the root filesystem |

The full list is in `Documentation/admin-guide/kernel-parameters.txt`. It is enormous, and worth
knowing exists.

### 7. What virtme-ng actually does

Building a disk image and an initramfs by hand for every boot would be miserable. `virtme-ng` removes
that entirely with a neat trick:

**It boots your kernel using your existing WSL filesystem as the guest's root**, shared in via virtio,
with a generated in-memory init. No disk image, no initramfs to build, no installation. Your home
directory, your tools, and your kernel tree are all just *there* inside the guest.

That means `vng --exec ./my_test.sh` builds nothing, copies nothing, and boots your kernel in a couple of
seconds — and your test script is already present because it is the same filesystem.

One thing to know: `defconfig` does not enable the virtio and 9p/virtiofs options `virtme-ng` needs to
share the filesystem. So you configure once with virtme-ng's own config step, which adds those options
on top of your existing `.config`, and rebuild. After that every boot is instant.

### 8. Why 60 seconds is the target

This is the part to take seriously.

| Loop time | What you actually do |
|---|---|
| **30 seconds** | test every change. When something breaks you know exactly which line did it |
| **2 minutes** | batch three or four changes per test. When it breaks, you bisect your own work |
| **10 minutes** | avoid testing. Read code and hope. Debug several problems simultaneously |

The difference is not 20× productivity, it is a different *activity*. A fast loop makes kernel
development experimental — change something, see what happens, build intuition. A slow loop makes it
theoretical, and you learn far less.

The three things that keep the loop fast: **ccache** (you proved this yesterday with a 31.8 s rebuild),
**incremental builds** (only touched files recompile), and **virtme-ng** (no image to rebuild). All
three are already in place.

### 9. Never lose an oops

When your kernel panics, the message is everything — the register state, the call trace, the faulting
address. It scrolls past, and if the terminal eats it you have to reproduce the crash to see it again.

So: **always capture the console to a file.** `tee` is enough. From Day 12, `OopsLens` will parse these
files; from Month 10, so will your fuzzing harness. Building the habit now costs nothing.

---

## Step-by-Step

### Phase 0 — Sync and confirm

```bash
bash ~/LKD_RUST/codes/sync_from_repo.sh

cd "$LINUX_TREE"
ls -lh arch/x86/boot/bzImage vmlinux
ls -l /dev/kvm
```

### Phase 1 — Install the boot tools

```bash
sudo apt install -y qemu-system-x86 qemu-utils

# Ubuntu packages virtme-ng, which is the least fragile way to get it.
sudo apt install -y virtme-ng

qemu-system-x86_64 --version | head -1
vng --version
```

> **Do not use `pip3 install --user virtme-ng`.** On Ubuntu 24.04 and later it fails with
> `error: externally-managed-environment`. That is **PEP 668**: the distribution owns its Python
> installation — `apt` packages depend on specific versions of those libraries — so `pip` is blocked
> from writing into it, precisely so a stray `pip install` cannot break system tools.
>
> The right responses, in order of preference:
>
> 1. **Use the distro package** — `sudo apt install -y virtme-ng`. Ubuntu 26.04 ships 1.40 against
>    upstream's 1.41, so you lose essentially nothing.
> 2. **Use `pipx`** if your distro does not package the tool — it gives each tool its own private
>    virtualenv, which is what you actually wanted from `pip --user` anyway:
>    `sudo apt install -y pipx && pipx ensurepath && pipx install virtme-ng`
> 3. **Do not reach for `--break-system-packages`.** It does exactly what it says.
>
> You will hit this again in the roadmap — `b4` (Week 41) is also packaged by Ubuntu, and `dtschema`
> (Week 14) is not, so that one genuinely needs `pipx`.

### Phase 2 — Boot it the hard way, and read the panic

Do this before touching `vng`, so you understand what `vng` is doing for you.

```bash
cd "$LINUX_TREE"

qemu-system-x86_64 \
  -enable-kvm \
  -m 2G -smp 4 \
  -kernel arch/x86/boot/bzImage \
  -append "console=ttyS0 panic=-1" \
  -nographic \
  -no-reboot
```

Watch the whole boot go past. You are seeing `start_kernel` do its work: memory init, CPU bring-up,
scheduler, then device probing. Then:

```text
List of all bdev filesystems:
 ext3
 ext2
 ext4
 vfat
 msdos
 iso9660

Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

**That is success.** Your kernel booted completely and then had nowhere to go — concept 3.

There are two different "no userspace" panics, and which one you get tells you how far the kernel got:

| Panic | Means |
|---|---|
| `VFS: Unable to mount root fs on unknown-block(0,0)` | no root device at all. `(0,0)` is a null major/minor — nothing was specified and nothing was found. **This is what you get here**, since you passed no `root=` and no `-initrd` |
| `No working init found` | the root filesystem *was* mounted, but there is no executable init inside it |

The `List of all bdev filesystems` above the panic is the kernel being helpful: these are the filesystem
types it is able to mount. It had the drivers ready and no device to point them at.

Exit QEMU with **`Ctrl-A`** then **`X`**.

> `Ctrl-A` is QEMU's escape key in `-nographic` mode. `Ctrl-A X` quits, `Ctrl-A C` switches to the QEMU
> monitor. Worth remembering — otherwise your only escape is another terminal and `pkill qemu`.

Now capture it instead of watching it scroll:

```bash
qemu-system-x86_64 -enable-kvm -m 2G -smp 4 \
  -kernel arch/x86/boot/bzImage \
  -append "console=ttyS0 panic=-1" -nographic -no-reboot \
  2>&1 | tee ~/LKD_RUST/Month_1/Week_1/boot_manual.log

grep -iE 'panic|Linux version|Command line' ~/LKD_RUST/Month_1/Week_1/boot_manual.log
```

### Phase 3 — Configure for virtme-ng and rebuild

`defconfig` lacks the virtio and filesystem-sharing options `vng` needs, so add them once:

```bash
cd "$LINUX_TREE"
vng --kconfig          # adds virtme's required options on top of your .config
                       # (older versions: use `vng --build` which configures and builds in one step)

grep -E 'CONFIG_VIRTIO=|CONFIG_VIRTIO_PCI=|CONFIG_NET_9P' .config | head

time make -j"$(nproc)"
```

This rebuild is incremental and ccache-warm, so expect well under a minute.

### Phase 4 — Get a shell inside your own kernel

```bash
cd "$LINUX_TREE"
vng
```

You should land at a prompt. Confirm it is genuinely your kernel:

```bash
uname -a                 # your version, your build timestamp
cat /proc/version
ls ~                     # your real home directory, shared in
exit
```

The first time this works is worth pausing on. You are in a shell running on a kernel you compiled, and
it has your files.

Now the mode you will use constantly — run one command in the guest and come straight back:

```bash
vng --exec 'uname -r'
vng --exec 'dmesg | tail -20'
vng --exec 'ls /sys/kernel/debug | head'
```

### Phase 5 — Measure the loop

The number that matters. Touch a file, rebuild, boot, get output:

```bash
cd "$LINUX_TREE"
time ( touch kernel/sched/core.c && make -j"$(nproc)" > /dev/null 2>&1 && vng --exec 'uname -r' )
```

**Target: under 60 seconds.** If it is slower:

- confirm `which gcc` is `/usr/lib/ccache/gcc`
- confirm the tree is not on `/mnt/`
- raise `processors` in `.wslconfig`
- check `ccache -s` is showing hits

Also time a boot on its own, with nothing to rebuild:

```bash
time vng --exec true
```

That is your floor — pure boot cost, usually a couple of seconds.

### Phase 6 — Save your commands

You will run these thousands of times. The repo has them in
`codes/Month_1/Week_1/Day_3/`; check they work and adjust to taste:

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/boot_manual.sh
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/time_loop.sh
```

Add a shell alias while you are at it:

```bash
echo "alias kb='cd \"\$LINUX_TREE\" && make -j\$(nproc)'" >> ~/.bashrc
source ~/.bashrc
```

### Phase 7 — Verify and record

```bash
bash ~/LKD_RUST/codes/Month_1/Week_1/Day_3/check_day3.sh
```

---

## Verification

```bash
qemu-system-x86_64 --version | head -1
vng --version
cd "$LINUX_TREE" && vng --exec 'uname -r'          # prints YOUR kernel version
grep -c CONFIG_VIRTIO .config                # virtio options present
ls -lh ~/LKD_RUST/Month_1/Week_1/boot_manual.log
```

---

## Gotchas

- **Stuck in QEMU with no way out.** `Ctrl-A` then `X`. Not `Ctrl-C` — that goes to the guest. If truly
  stuck, `pkill qemu-system-x86_64` from another terminal.
- **`Ctrl-A` also being your shell's "start of line" key.** In `-nographic` QEMU intercepts it. That is
  expected, and it stops when QEMU exits.
- **No output at all from the manual boot.** You forgot `console=ttyS0` in `-append`, or `-nographic`.
  The kernel is booting fine and talking to a console you cannot see.
- **`vng` not found after install.** `~/.local/bin` is not on `PATH`. Add it and open a new shell.
- **`vng` boots but cannot find your files.** The virtio/9p options are missing — run `vng --kconfig`
  and rebuild.
- **Treating the panic as a failure.** `No working init found` means everything worked. The kernel had
  nowhere to go, which is the expected result of booting a kernel with no root filesystem.
- **Testing on your host.** Never `insmod` your experimental module outside a VM. That is what the guest
  is for.
- **Forgetting `nokaslr` when debugging.** From Day 12 with gdb, addresses will not match your symbols
  unless address randomisation is off.
- **Not capturing output.** The one crash you fail to capture will be the interesting one.
- **Accepting a slow loop "for now."** It compounds over 18 months. Fix it today.

---

## My Notes

### Timings

| Measurement | Value |
|---|---|
| Pure boot (`time vng --exec true`) | |
| Incremental rebuild after touching one file | |
| **Full loop: touch → build → boot → output** | |
| Manual QEMU boot to panic | |

### My commands

Manual QEMU boot line I settled on:

`vng` invocation I will use daily:

### What went wrong, and how I fixed it

### What surprised me about the boot output

Three things I saw scroll past that I did not recognise, and want to look up:

---

## Done When

- [x] QEMU and `vng` both installed and reporting versions
- [x] You booted manually with a raw `qemu-system-x86_64` command and can explain the panic
- [x] You can explain what a kernel needs to reach userspace, and what an initramfs solves
- [x] You know how to exit QEMU (`Ctrl-A X`) without needing a second terminal
- [x] You can explain why kernel developers use a serial console
- [x] You can name four kernel command-line parameters and what each does
- [x] `vng` gives you a shell, `uname -a` shows your kernel, and your home directory is there
- [x] `vng --exec '<cmd>'` runs a single command and returns
- [x] A boot log captured to a file
- [x] **Full loop measured and under 60 seconds**
- [x] Boot commands saved as scripts
- [x] Journal filled in

---

## Reading

- `Documentation/admin-guide/kernel-parameters.txt` — skim it; know it exists and roughly what it covers
- `Documentation/admin-guide/initrd.rst` — how initramfs actually works
- The `virtme-ng` README — worth ten minutes, it has flags you will want later
- Optional: `init/main.c`, and find `start_kernel()`. You do not need to understand it yet. Seeing that
  the kernel's entry point is a readable C function is the point.

---

**Next:** M1W1D4 — The Rust Toolchain. You get `make LLVM=1 rustavailable` to say yes, enable
`CONFIG_RUST`, and load your first Rust kernel module. Everything so far has been C; tomorrow the
roadmap's actual subject begins.

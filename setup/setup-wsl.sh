#!/bin/bash
# setup-wsl.sh — full Linux kernel + Rust development setup inside WSL2.
#
# From a bare Ubuntu-on-WSL2 install to a booted, Rust-enabled kernel you built,
# with your own module loadable in a QEMU guest.
#
# Usage:
#   bash setup-wsl.sh                      # clone clean upstream Linux
#   KERNEL_SRC=fork bash setup-wsl.sh      # clone your fork instead (keeps your branches)
#   KERNEL_SRC=fork FORK_BRANCH=sanu0 bash setup-wsl.sh
#   LKD_ROOT=~/kdev JOBS=8 bash setup-wsl.sh
#
# Safe to re-run. Every step checks before acting.

set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=lib-common.sh
. ./lib-common.sh

printf '%s\n' "════════════════════════════════════════════════════════"
printf '%s\n' "  Linux Kernel + Rust development setup  —  WSL2"
printf '%s\n' "════════════════════════════════════════════════════════"
printf '  root       : %s\n' "$LKD_ROOT"
printf '  kernel src : %s\n' "$KERNEL_SRC"
printf '  jobs       : -j%s\n' "$JOBS"

# ─── WSL sanity ──────────────────────────────────────────────────
say "WSL environment"
if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  warn "this does not look like WSL — you may want setup-baremetal.sh instead"
else
  ok "WSL detected: $(uname -r)"
fi

# The single most consequential misconfiguration. A tree on /mnt/c is reached over
# the 9p bridge: builds run several times slower, and NTFS preserves neither the
# executable bit nor the symlinks the kernel tree relies on.
case "$LKD_ROOT" in
  /mnt/*) die "LKD_ROOT is on the Windows filesystem. Use a path under \$HOME." ;;
  *)      ok "working on WSL's native filesystem" ;;
esac

WIN_USER="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true)"
[ -n "$WIN_USER" ] && info "Windows user detected: $WIN_USER"

detect_pkg_mgr
check_disk

# ─── Common toolchain ────────────────────────────────────────────
install_build_deps
install_llvm
install_boot_tools
setup_ccache
write_env

# ─── KVM, which needs nested virtualization under WSL2 ───────────
say "KVM (hardware virtualization)"
VENDOR="$(grep -o -m1 -E 'vmx|svm' /proc/cpuinfo || true)"
case "$VENDOR" in
  vmx) KVM_MOD=kvm_intel; ok "CPU exposes Intel VT-x" ;;
  svm) KVM_MOD=kvm_amd;   ok "CPU exposes AMD-V" ;;
  *)   KVM_MOD=""; warn "no vmx/svm flag — nested virtualization not exposed to this VM" ;;
esac

if [ -e /dev/kvm ]; then
  ok "/dev/kvm present"
elif [ -n "$KVM_MOD" ]; then
  info "loading $KVM_MOD"
  sudo modprobe "$KVM_MOD" 2>/dev/null || warn "modprobe failed"
fi

if [ -e /dev/kvm ]; then
  sudo chown root:kvm /dev/kvm 2>/dev/null || true
  sudo chmod 660 /dev/kvm 2>/dev/null || true
  id -nG "$USER" | tr ' ' '\n' | grep -qx kvm || {
    sudo usermod -aG kvm "$USER" && ok "added $USER to the kvm group (needs 'wsl --shutdown')"
  }
  ok "/dev/kvm usable — boots run at near-native speed"
else
  warn "no /dev/kvm — QEMU will use software emulation (10-20x slower, still works)"
fi

# modprobe returns before the device node necessarily appears, so a boot script
# that chowns immediately can race. Hence the wait loop.
say "Persisting KVM across WSL restarts (/etc/wsl.conf)"
if [ -n "$KVM_MOD" ]; then
  if grep -q 'modprobe kvm' /etc/wsl.conf 2>/dev/null; then
    ok "/etc/wsl.conf already loads $KVM_MOD at boot"
  else
    info "writing [boot] command to /etc/wsl.conf"
    sudo tee -a /etc/wsl.conf > /dev/null <<EOF

[boot]
command = "modprobe $KVM_MOD && while [ ! -e /dev/kvm ]; do sleep 0.1; done && chown root:kvm /dev/kvm && chmod 660 /dev/kvm"
EOF
    ok "written — takes effect after 'wsl --shutdown'"
  fi
fi

# ─── .wslconfig, which lives on the Windows side ─────────────────
say "Windows-side VM settings (.wslconfig)"
CPUS_TOTAL=$(nproc)
MEM_TOTAL_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
# Give WSL roughly two thirds and leave the rest to Windows; starving Windows
# makes the whole machine feel broken and you will blame the kernel work.
WSL_CPUS=$(( CPUS_TOTAL * 2 / 3 ));   [ "$WSL_CPUS" -lt 2 ] && WSL_CPUS=2
WSL_MEM=$(( MEM_TOTAL_GB * 2 / 3 ));  [ "$WSL_MEM"  -lt 4 ] && WSL_MEM=4

WSLCONF_BODY=$(cat <<EOF
[wsl2]
# 'memory' is a CEILING, not a reservation: Windows does not lose this RAM while
# WSL is idle. The VM grows into it only as the guest actually allocates.
memory=${WSL_MEM}GB
# vCPUs the guest sees. Not pinned, not reserved — idle vCPUs cost nothing.
processors=${WSL_CPUS}
swap=8GB
# Required for QEMU/KVM inside WSL2, since WSL2 is itself a VM.
nestedVirtualization=true
# Milliseconds idle before the VM shuts down, returning all memory to Windows.
vmIdleTimeout=60000

[experimental]
# The Linux guest spends free RAM on page cache, and a kernel build reads tens of
# thousands of files. This hands cached memory back once idle.
# NOTE: must be under [experimental]; under [wsl2] it is an unknown key.
autoMemoryReclaim=gradual
EOF
)

WSLCONF_PATH=""
[ -n "$WIN_USER" ] && [ -d "/mnt/c/Users/$WIN_USER" ] && WSLCONF_PATH="/mnt/c/Users/$WIN_USER/.wslconfig"

if [ -n "$WSLCONF_PATH" ] && [ ! -e "$WSLCONF_PATH" ]; then
  printf '%s\n' "$WSLCONF_BODY" > "$WSLCONF_PATH" 2>/dev/null \
    && ok "wrote $WSLCONF_PATH (host: ${CPUS_TOTAL} CPUs, ${MEM_TOTAL_GB} GB)" \
    || warn "could not write $WSLCONF_PATH — create it by hand (contents below)"
elif [ -n "$WSLCONF_PATH" ]; then
  ok "$WSLCONF_PATH already exists — leaving it alone"
  info "review it against the recommended contents below"
else
  warn "could not locate your Windows profile — create %USERPROFILE%\\.wslconfig by hand"
fi
printf '\n%s--- recommended .wslconfig ---%s\n' "$C_B" "$C_N"
printf '%s\n' "$WSLCONF_BODY" | sed 's/^/    /'
printf '\n'
info "apply with:  wsl --shutdown   (from PowerShell)"

# ─── Kernel ──────────────────────────────────────────────────────
clone_kernel
install_rust
install_bindgen
rust_gate
configure_kernel
build_kernel
setup_editor
final_summary

cat <<EOF

  ${C_Y}WSL-specific reminders:${C_N}
    • Run 'wsl --shutdown' from PowerShell to apply .wslconfig and /etc/wsl.conf
    • Never move the kernel tree onto /mnt/c — builds get several times slower
    • You boot your kernel in QEMU, never as the WSL kernel itself
    • 'vng' needs a real terminal; it fails with "not a valid pts" from a pipe
EOF

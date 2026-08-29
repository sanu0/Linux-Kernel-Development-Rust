#!/bin/bash
# setup-baremetal.sh — full Linux kernel + Rust development setup on a native
# Linux machine (not WSL).
#
# Same toolchain as the WSL script, plus the things only real hardware gives you:
# native KVM, actual PCI devices to write drivers for, and the option to boot your
# own kernel as the real operating system.
#
# Usage:
#   bash setup-baremetal.sh                     # clone clean upstream Linux
#   KERNEL_SRC=fork bash setup-baremetal.sh     # clone your fork (keeps your branches)
#   KERNEL_SRC=fork FORK_BRANCH=sanu0 bash setup-baremetal.sh
#   INSTALL_KERNEL=1 bash setup-baremetal.sh    # also install to /boot (see warning)
#
# Safe to re-run. Every step checks before acting.

set -uo pipefail
cd "$(dirname "$0")" || exit 1
# shellcheck source=lib-common.sh
. ./lib-common.sh

INSTALL_KERNEL="${INSTALL_KERNEL:-0}"

printf '%s\n' "════════════════════════════════════════════════════════"
printf '%s\n' "  Linux Kernel + Rust development setup  —  bare metal"
printf '%s\n' "════════════════════════════════════════════════════════"
printf '  root       : %s\n' "$LKD_ROOT"
printf '  kernel src : %s\n' "$KERNEL_SRC"
printf '  jobs       : -j%s\n' "$JOBS"

say "Host"
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  warn "this looks like WSL — setup-wsl.sh handles KVM and .wslconfig for you"
fi
if [ -r /etc/os-release ]; then
  ok "$(. /etc/os-release && echo "$PRETTY_NAME")"
fi
ok "kernel $(uname -r), $(nproc) CPUs, $(free -h | awk '/^Mem:/{print $2}') RAM"

detect_pkg_mgr
check_disk

# ─── Common toolchain ────────────────────────────────────────────
install_build_deps
install_llvm
install_boot_tools
setup_ccache
write_env

# ─── KVM — native here, no nesting involved ──────────────────────
say "KVM (hardware virtualization)"
VENDOR="$(grep -o -m1 -E 'vmx|svm' /proc/cpuinfo || true)"
case "$VENDOR" in
  vmx) KVM_MOD=kvm_intel; ok "Intel VT-x present" ;;
  svm) KVM_MOD=kvm_amd;   ok "AMD-V present" ;;
  *)   KVM_MOD=""; warn "no vmx/svm — check that virtualization is enabled in BIOS/UEFI" ;;
esac

[ -e /dev/kvm ] || { [ -n "$KVM_MOD" ] && sudo modprobe "$KVM_MOD" 2>/dev/null || true; }

if [ -e /dev/kvm ]; then
  ok "/dev/kvm present — $(stat -c '%A %U:%G' /dev/kvm)"
  if id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
    ok "you are in the kvm group"
  else
    sudo usermod -aG kvm "$USER" \
      && warn "added $USER to the kvm group — log out and back in for it to apply"
  fi
  # Load at boot so it survives a reboot.
  if [ -n "$KVM_MOD" ] && [ -d /etc/modules-load.d ]; then
    if [ -f /etc/modules-load.d/kvm.conf ]; then
      ok "/etc/modules-load.d/kvm.conf exists"
    else
      echo "$KVM_MOD" | sudo tee /etc/modules-load.d/kvm.conf > /dev/null \
        && ok "$KVM_MOD will load at boot"
    fi
  fi
else
  warn "no /dev/kvm — QEMU falls back to software emulation (much slower)"
fi

# ─── Hardware you can actually write drivers for ─────────────────
say "Hardware inventory (things bare metal gives you that WSL does not)"
if have lspci; then
  ok "$(lspci 2>/dev/null | wc -l) PCI devices"
  GPUS=$(lspci 2>/dev/null | grep -icE 'vga|3d controller|display' || true)
  [ "${GPUS:-0}" -gt 0 ] && ok "$GPUS graphics/display device(s)"
  info "GPU work needs a GA102 (RTX 3090/3090 Ti) for Nova — see Month 9"
else
  warn "lspci not found — install pciutils"
fi
if [ -d /sys/kernel/iommu_groups ]; then
  ok "$(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l) IOMMU groups (needed for VFIO passthrough, Month 14)"
else
  warn "no IOMMU groups — add intel_iommu=on / amd_iommu=on to your boot cmdline for Month 14"
fi
I2C=$(ls -d /dev/i2c-* 2>/dev/null | wc -l)
SPI=$(ls -d /dev/spidev* 2>/dev/null | wc -l)
[ "$I2C" -gt 0 ] && ok "$I2C I2C bus(es) exposed" || info "no /dev/i2c-* nodes"
[ "$SPI" -gt 0 ] && ok "$SPI SPI device(s) exposed" || info "no /dev/spidev* nodes"
info "for Month 5 (I2C/SPI sensor drivers) you still want a cheap ARM SBC with exposed pins"

# ─── Kernel ──────────────────────────────────────────────────────
clone_kernel
install_rust
install_bindgen
rust_gate
configure_kernel
build_kernel
setup_editor

# ─── Optionally install for real booting ─────────────────────────
if [ "$INSTALL_KERNEL" = 1 ]; then
  say "Installing the kernel to /boot"
  printf '  %s⚠  This makes your kernel bootable on this machine.%s\n' "$C_Y" "$C_N"
  printf '     A broken kernel here means an unbootable machine, not a dead QEMU process.\n'
  printf '     Your distro kernel stays in the boot menu as a fallback — keep it.\n\n'
  read -r -p "  Type INSTALL to proceed: " confirm
  if [ "$confirm" = "INSTALL" ]; then
    cd "$KERNEL_DIR" || die "no kernel tree"
    sudo make LLVM=1 modules_install || die "modules_install failed"
    sudo make LLVM=1 install || die "install failed"
    ok "installed — select it from the boot menu on next reboot"
    info "GRUB users: verify with 'grep menuentry /boot/grub/grub.cfg'"
    warn "do NOT remove your distro kernel from the boot menu"
  else
    info "skipped"
  fi
else
  say "Booting your kernel"
  info "QEMU (safe, recommended):  vng --exec 'uname -r'"
  info "On real hardware:          re-run with INSTALL_KERNEL=1"
  info "Do the QEMU route until you are confident. A bad kernel in QEMU costs nothing."
fi

final_summary

cat <<EOF

  ${C_Y}Bare-metal advantages to remember:${C_N}
    • Real PCI devices — you can write drivers for hardware you actually own
    • Native KVM, so QEMU guests are fast
    • IOMMU groups for VFIO passthrough experiments (Month 14)
    • You can boot your own kernel for real (INSTALL_KERNEL=1) — keep a fallback

  ${C_Y}And the corresponding risk:${C_N}
    • A panic on bare metal is a rescue-USB evening. In QEMU it is Ctrl-A X.
    • Develop in QEMU; boot on metal only when you need real hardware.
EOF

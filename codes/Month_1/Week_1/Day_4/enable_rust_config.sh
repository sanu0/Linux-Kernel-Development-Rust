#!/bin/bash
# M1W1D4 - turn on CONFIG_RUST and the sample modules, WITHOUT destroying the virtio
# options that `vng --kconfig` added on Day 3.
#
# This is the whole point of the script: `make defconfig` would give you Rust and take away
# your working boot loop. Editing the existing .config in place keeps both.
#
# Usage:  bash enable_rust_config.sh

set -uo pipefail

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

: "${LINUX_TREE:?LINUX_TREE not set - open a new shell or re-check ~/.bashrc}"
cd "$LINUX_TREE" || exit 1
[ -f .config ] || { echo "No .config - you need Day 2 and Day 3 done first."; exit 1; }

say "Pre-flight"
if ! make LLVM=1 rustavailable > /dev/null 2>&1; then
  echo "  rustavailable says NO. CONFIG_RUST depends on RUST_IS_AVAILABLE, so it cannot"
  echo "  be enabled until that passes. Run install_rust_toolchain.sh first."
  exit 1
fi
echo "  rustavailable: yes"

# Record what Day 3 gave us so we can prove it survived.
VIRTIO_BEFORE=$(grep -cE '^CONFIG_(VIRTIO|NET_9P|9P_FS)' .config || true)
echo "  virtio/9p options currently set: $VIRTIO_BEFORE"

say "Backup"
BK=".config.pre-rust.$(date +%Y%m%d-%H%M%S)"
cp .config "$BK"
echo "  saved $BK"

say "Enabling Rust"
scripts/config --enable RUST
scripts/config --enable SAMPLES
scripts/config --enable SAMPLES_RUST

# Build the samples as MODULES (=m), not built-in (=y): a built-in sample cannot be
# insmod'd or rmmod'd, which is exactly the cycle that makes them useful to learn from.
for s in SAMPLE_RUST_MINIMAL SAMPLE_RUST_PRINT SAMPLE_RUST_MISC_DEVICE; do
  scripts/config --module "$s"
  echo "  $s=m"
done

# Rust-specific runtime checks. Cheap during development, and they turn silent
# miscompilation into a loud failure.
scripts/config --enable RUST_DEBUG_ASSERTIONS
scripts/config --enable RUST_OVERFLOW_CHECKS
echo "  RUST_DEBUG_ASSERTIONS, RUST_OVERFLOW_CHECKS"

say "Re-resolving dependencies"
# scripts/config edits text; olddefconfig makes Kconfig re-evaluate every dependency and
# fill in anything newly reachable. Skipping this leaves a contradictory .config.
make LLVM=1 olddefconfig

say "Result"
if grep -q '^CONFIG_RUST=y' .config; then
  echo "  CONFIG_RUST=y"
else
  echo "  CONFIG_RUST is NOT set - a dependency is blocking it. Check:"
  grep -E '^# CONFIG_(RUST|MODVERSIONS|RANDSTRUCT|DEBUG_INFO_BTF)' .config | head
  echo "  and re-read the 'depends on' list in init/Kconfig."
  exit 1
fi

grep -E '^CONFIG_SAMPLE_RUST' .config | sed 's/^/  /'

VIRTIO_AFTER=$(grep -cE '^CONFIG_(VIRTIO|NET_9P|9P_FS)' .config || true)
echo "  virtio/9p options still set: $VIRTIO_AFTER (was $VIRTIO_BEFORE)"
if [ "$VIRTIO_AFTER" -lt "$VIRTIO_BEFORE" ]; then
  echo "  WARNING: you lost virtio options - vng may stop working. Restore with:"
  echo "    cp $BK .config && make LLVM=1 olddefconfig"
fi

cat <<EOF

Next - expect roughly 5 minutes, since a config change invalidates most of the tree
and you are now also compiling core, alloc, and the kernel crate:

  time make LLVM=1 -j\$(nproc)

Watch for these, which you have never seen before:
  RUSTC L core.o                              compiling the Rust standard library
  BINDGEN rust/bindings/bindings_generated.rs  generating Rust views of C headers
  RUSTC M samples/rust/rust_minimal.o          your first Rust kernel module

Then load it (from a real terminal, vng needs a TTY):
  vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail -10; rmmod rust_minimal'
EOF

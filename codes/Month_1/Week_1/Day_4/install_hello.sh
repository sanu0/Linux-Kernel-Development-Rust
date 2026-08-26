#!/bin/bash
# M1W1D4 activity - wire hello_rust.rs into the kernel tree's build system.
#
# Kernel Rust has thin support for out-of-tree modules, so the path of least resistance
# is to develop IN-tree: drop the source into samples/rust/, give it a Kconfig entry and
# a Makefile line, and let Kbuild treat it exactly like an upstream sample. That is what
# codes/README.md recommends, and it is what this script automates.
#
# Three files get touched inside $LINUX_TREE (all additive, all idempotent):
#   samples/rust/hello_rust.rs   copied from this directory
#   samples/rust/Kconfig         one new `config SAMPLE_RUST_HELLO` block
#   samples/rust/Makefile        one new obj-$(CONFIG_SAMPLE_RUST_HELLO) line
#
# Usage:
#   bash install_hello.sh              # build as a loadable module (=m)  [default]
#   bash install_hello.sh --builtin    # compile into vmlinux (=y), greets you at boot
#
# To undo everything and get a clean tree back:
#   cd "$LINUX_TREE"
#   git checkout samples/rust/Kconfig samples/rust/Makefile
#   rm -f samples/rust/hello_rust.rs
#   scripts/config --disable SAMPLE_RUST_HELLO && make LLVM=1 olddefconfig

set -uo pipefail

MODE=module
for a in "$@"; do
  case "$a" in
    --module)  MODE=module ;;
    --builtin) MODE=builtin ;;
    *) echo "usage: install_hello.sh [--module|--builtin]"; exit 2 ;;
  esac
done

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

: "${LINUX_TREE:?LINUX_TREE not set - open a new shell or re-check ~/.bashrc}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/hello_rust.rs"
[ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }

cd "$LINUX_TREE" || exit 1
[ -f .config ] || { echo "No .config in $LINUX_TREE - Day 2 and Day 3 come first."; exit 1; }

KCONFIG=samples/rust/Kconfig
MAKEFILE=samples/rust/Makefile
[ -f "$KCONFIG" ] && [ -f "$MAKEFILE" ] || { echo "$LINUX_TREE does not look like a tree with samples/rust"; exit 1; }

say "Pre-flight"
if ! grep -q '^CONFIG_RUST=y' .config; then
  echo "  CONFIG_RUST is not enabled. Run Day 4 first:"
  echo "    bash \"\$LKDRUST_REPO/codes/Month_1/Week_1/Day_4/install_rust_toolchain.sh\""
  echo "    bash \"\$LKDRUST_REPO/codes/Month_1/Week_1/Day_4/enable_rust_config.sh\""
  exit 1
fi
echo "  CONFIG_RUST=y"
grep -q '^CONFIG_SAMPLES_RUST=y' .config \
  && echo "  CONFIG_SAMPLES_RUST=y" \
  || echo "  WARNING: CONFIG_SAMPLES_RUST is not set; olddefconfig below may drop the new symbol"

say "Copying the source"
install -m 644 "$SRC" samples/rust/hello_rust.rs
# NTFS gives us CRLF. A \r inside a kernel source file is a patch you cannot submit,
# and checkpatch.pl rejects it outright, so normalise on the way in.
sed -i 's/\r$//' samples/rust/hello_rust.rs
echo "  -> samples/rust/hello_rust.rs ($(wc -l < samples/rust/hello_rust.rs) lines, LF)"

say "Kconfig entry"
if grep -q 'SAMPLE_RUST_HELLO' "$KCONFIG"; then
  echo "  already present"
else
  # The new block has to land INSIDE the `if SAMPLES_RUST` guard, so lift the closing
  # endif, append, then put it back. Simpler and more legible than an in-place insert.
  sed -i '/^endif # SAMPLES_RUST/d' "$KCONFIG"
  cat >> "$KCONFIG" <<'EOF'
config SAMPLE_RUST_HELLO
	tristate "Hello world (hand-written, M1W1D4 activity)"
	help
	  Your own first Rust kernel module, kept under version control at
	  codes/Month_1/Week_1/Day_4/hello_rust.rs in the LKD_RUST repo.

	  Choose M to build hello_rust.ko and load it with insmod, so you can
	  watch both init and exit.

	  Choose Y to compile it into vmlinux, so it greets you during boot.
	  Built in, it can never be unloaded, so its Drop never runs.

	  If unsure, say N.

EOF
  echo 'endif # SAMPLES_RUST' >> "$KCONFIG"
  echo "  added config SAMPLE_RUST_HELLO"
fi

say "Makefile entry"
if grep -q 'SAMPLE_RUST_HELLO' "$MAKEFILE"; then
  echo "  already present"
else
  # Single quotes keep $(CONFIG_...) literal so make expands it, not bash.
  printf 'obj-$(CONFIG_SAMPLE_RUST_HELLO)\t\t+= hello_rust.o\n' >> "$MAKEFILE"
  echo "  added obj-\$(CONFIG_SAMPLE_RUST_HELLO) += hello_rust.o"
fi

say "Selecting $MODE"
case "$MODE" in
  module)  scripts/config --module SAMPLE_RUST_HELLO ;;
  builtin) scripts/config --enable SAMPLE_RUST_HELLO ;;
esac

# scripts/config only edits text. olddefconfig makes Kconfig re-read the tree, notice the
# symbol we just declared, and resolve its dependencies.
make LLVM=1 olddefconfig > /dev/null 2>&1

say "Result"
if grep -q '^CONFIG_SAMPLE_RUST_HELLO=' .config; then
  grep '^CONFIG_SAMPLE_RUST_HELLO=' .config | sed 's/^/  /'
else
  echo "  CONFIG_SAMPLE_RUST_HELLO did not survive olddefconfig."
  echo "  Usually means CONFIG_SAMPLES_RUST is off. Check: grep SAMPLES_RUST .config"
  exit 1
fi

if [ "$MODE" = module ]; then
  cat <<'EOF'

Next:

  cd "$LINUX_TREE"
  make LLVM=1 -j"$(nproc)"

Watch for this line, which is your own code being compiled by rustc:

  RUSTC [M] samples/rust/hello_rust.o

Then boot it and load the module. vng wants a real terminal, so run this in your
own shell rather than through an editor task:

  vng --exec 'insmod samples/rust/hello_rust.ko; dmesg | tail -15; rmmod hello_rust; dmesg | tail -3'

Try the parameter too, and note the clamp refusing a silly value:

  vng --exec 'insmod samples/rust/hello_rust.ko greetings=7; dmesg | tail -14'
  vng --exec 'insmod samples/rust/hello_rust.ko greetings=9999; dmesg | tail -14'
EOF
else
  cat <<'EOF'

Next:

  cd "$LINUX_TREE"
  make LLVM=1 -j"$(nproc)"

Then just boot. Do NOT insmod anything - the code is inside vmlinux now, so it has
already run by the time you get a prompt:

  vng --exec 'dmesg | grep -A6 "Hello, World"'

Two things to notice, and they are the whole point of building it this way:
  - "running as: compiled into vmlinux", because cfg!(MODULE) is now false
  - there is no goodbye message anywhere, because built-in code is never unloaded
    and so its Drop never runs

  vng --exec 'lsmod | grep hello_rust || echo "not a module - it is part of the kernel"'
EOF
fi

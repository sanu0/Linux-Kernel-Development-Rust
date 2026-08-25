#!/bin/bash
# M1W1D4 - install the Rust toolchain the kernel tree demands, and verify the gate.
#
# Asks the TREE what it needs rather than hardcoding versions, because those change every
# release. See theory/Month_1/Week_1/Day_4.md concept 1.
#
# Safe to re-run.
#
# Usage:
#   bash install_rust_toolchain.sh            # install the minimum version the tree names
#   bash install_rust_toolchain.sh --latest   # use latest stable instead (usually fine)

set -uo pipefail

USE_LATEST=0
for a in "$@"; do
  case "$a" in
    --latest) USE_LATEST=1 ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

: "${LINUX_TREE:?LINUX_TREE not set - open a new shell or re-check ~/.bashrc}"
cd "$LINUX_TREE" || exit 1

say "What this tree demands"
RUSTC_WANT="$(scripts/min-tool-version.sh rustc 2>/dev/null)"
BINDGEN_WANT="$(scripts/min-tool-version.sh bindgen 2>/dev/null)"
LLVM_WANT="$(scripts/min-tool-version.sh llvm 2>/dev/null)"
echo "  rustc   >= $RUSTC_WANT"
echo "  bindgen >= $BINDGEN_WANT"
echo "  llvm    >= $LLVM_WANT   (installed: $(clang --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"

[ -n "$RUSTC_WANT" ] || { echo "could not read min-tool-version.sh - is this a kernel tree?"; exit 1; }

say "rustup"
if command -v rustup > /dev/null 2>&1; then
  echo "  already installed: $(rustup --version 2>/dev/null | head -1)"
else
  echo "  installing..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
if ! grep -q '.cargo/env' "$HOME/.bashrc" 2>/dev/null; then
  echo '. "$HOME/.cargo/env"' >> "$HOME/.bashrc"
  echo "  added cargo to ~/.bashrc"
fi

say "Toolchain + components"
if [ "$USE_LATEST" = 1 ]; then TC=stable; else TC="$RUSTC_WANT"; fi
echo "  target toolchain: $TC"
rustup toolchain install "$TC"
# rust-src is not optional: the kernel builds core and alloc FROM SOURCE for its own
# custom target, because no prebuilt core exists for "x86_64 kernel with these flags".
rustup component add rust-src rustfmt clippy --toolchain "$TC"

# Pin per-tree so a later global toolchain change cannot break this kernel build.
rustup override set "$TC"
echo "  pinned $LINUX_TREE to $TC"
rustc --version
cargo --version

say "bindgen"
NEED_BINDGEN=1
if command -v bindgen > /dev/null 2>&1; then
  HAVE="$(bindgen --version 2>/dev/null | awk '{print $2}')"
  echo "  installed: $HAVE (want >= $BINDGEN_WANT)"
  [ "$HAVE" = "$BINDGEN_WANT" ] && NEED_BINDGEN=0
fi
if [ "$NEED_BINDGEN" = 1 ]; then
  echo "  installing bindgen-cli $BINDGEN_WANT (compiles from source, a few minutes)..."
  # --locked uses the crate's own lockfile, so the build is reproducible rather than
  # resolving whatever dependency versions happen to be newest today.
  cargo install --locked --version "$BINDGEN_WANT" bindgen-cli
fi
bindgen --version

say "libclang"
# bindgen links against libclang to parse C headers. On Ubuntu it lives in a versioned
# directory that is not on the default library search path, so it needs pointing at.
if [ -n "${LIBCLANG_PATH:-}" ] && [ -d "$LIBCLANG_PATH" ]; then
  echo "  LIBCLANG_PATH=$LIBCLANG_PATH"
else
  FOUND=$(find /usr/lib -name 'libclang.so*' 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    DIR=$(dirname "$FOUND")
    echo "  LIBCLANG_PATH unset; found libclang at $DIR"
    export LIBCLANG_PATH="$DIR"
    if ! grep -q 'LIBCLANG_PATH' "$HOME/.bashrc" 2>/dev/null; then
      printf 'export LIBCLANG_PATH="%s"\n' "$DIR" >> "$HOME/.bashrc"
      echo "  added LIBCLANG_PATH to ~/.bashrc"
    fi
  else
    echo "  WARNING: libclang not found - install libclang-dev"
  fi
fi

say "The gate: make LLVM=1 rustavailable"
if make LLVM=1 rustavailable; then
  printf '\n  \033[32mRust is available. Continue to Day 4 Phase 4 (enable CONFIG_RUST).\033[0m\n\n'
else
  printf '\n  \033[31mNot yet.\033[0m Read the message above literally - it names the tool and the problem.\n'
  echo "  Common fixes are tabulated in theory/Month_1/Week_1/Day_4.md Phase 3."
  exit 1
fi

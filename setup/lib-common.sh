#!/bin/bash
# lib-common.sh — shared setup logic for setup-wsl.sh and setup-baremetal.sh.
#
# Not meant to be run directly; it is sourced. Every function is idempotent, so
# re-running a setup script is always safe.
#
# Tunables (export before running, or accept the defaults):
#   LKD_ROOT     where everything lives          default: $HOME/LKD_RUST
#   KERNEL_SRC   upstream | fork                 default: upstream
#   FORK_URL     your kernel fork                default: https://github.com/sanu0/linux.git
#   FORK_BRANCH  branch to check out from fork   default: (none)
#   JOBS         build parallelism               default: nproc

set -uo pipefail

# ─── Tunables ────────────────────────────────────────────────────
# Exported, not just assigned, so they reach child processes (make, vng, git)
# and survive however this file gets sourced.
export LKD_ROOT="${LKD_ROOT:-$HOME/LKD_RUST}"
export KERNEL_SRC="${KERNEL_SRC:-upstream}"
export FORK_URL="${FORK_URL:-https://github.com/sanu0/linux.git}"
export FORK_BRANCH="${FORK_BRANCH:-}"
export JOBS="${JOBS:-$(nproc)}"

export KERNEL_DIR="$LKD_ROOT/kernel/linux"
# A standalone env file rather than exports appended to ~/.bashrc. Distro .bashrc
# files begin with `case $- in *i*) ;; *) return;; esac`, so anything appended
# there is invisible to non-interactive shells — which is every script, cron job
# and CI run. This file has no such guard and can be sourced from anywhere.
ENV_FILE="$HOME/.lkdrust_env"
UPSTREAM_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
NEXT_URL="https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
RFL_URL="https://github.com/Rust-for-Linux/linux.git"

# ─── Output ──────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[1m'; C_N=$'\e[0m'
else
  C_R=''; C_G=''; C_Y=''; C_B=''; C_N=''
fi
STEP=0
say()  { STEP=$((STEP+1)); printf '\n%s━━ [%d] %s ━━%s\n' "$C_B" "$STEP" "$1" "$C_N"; }
ok()   { printf '  %s✓%s %s\n' "$C_G" "$C_N" "$1"; }
warn() { printf '  %s!%s %s\n' "$C_Y" "$C_N" "$1"; }
die()  { printf '  %s✗%s %s\n' "$C_R" "$C_N" "$1"; exit 1; }
info() { printf '    %s\n' "$1"; }

have() { command -v "$1" > /dev/null 2>&1; }

# Append a line to ~/.bashrc only if it is not already present, so re-running
# does not accumulate duplicates.
bashrc_add() {
  local line="$1" marker="$2"
  if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
    info "already in ~/.bashrc: $marker"
  else
    printf '%s\n' "$line" >> "$HOME/.bashrc"
    ok "added to ~/.bashrc: $marker"
  fi
}

# Numeric dotted-version comparison: ver_ge 1.10.0 1.9.0 is true.
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# ─── Package manager abstraction ─────────────────────────────────
PKG=""
detect_pkg_mgr() {
  if   have apt-get; then PKG=apt
  elif have dnf;     then PKG=dnf
  elif have pacman;  then PKG=pacman
  else PKG=unknown
  fi
  info "package manager: $PKG"
}

pkg_install() {
  case "$PKG" in
    apt)    sudo apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
    *)      warn "unknown package manager; install manually: $*"; return 1 ;;
  esac
}

pkg_update() {
  case "$PKG" in
    apt)    sudo apt-get update ;;
    dnf)    sudo dnf check-update || true ;;
    pacman) sudo pacman -Sy ;;
  esac
}

# ─── Steps ───────────────────────────────────────────────────────

check_disk() {
  say "Disk space"
  mkdir -p "$LKD_ROOT"
  local avail_gb
  avail_gb=$(( $(df -Pk "$LKD_ROOT" | awk 'NR==2{print $4}') / 1024 / 1024 ))
  info "$avail_gb GB free at $LKD_ROOT"
  if   [ "$avail_gb" -ge 60 ]; then ok "plenty of room"
  elif [ "$avail_gb" -ge 40 ]; then ok "enough (60+ GB is comfortable)"
  else die "need at least 40 GB free — a kernel tree is ~6 GB and a debug build 15-25 GB"
  fi
}

install_build_deps() {
  say "Kernel build dependencies"
  pkg_update
  case "$PKG" in
    apt)
      # flex/bison build the Kconfig parser; bc computes timer constants;
      # libelf is for objtool; dwarves provides pahole (DWARF -> BTF).
      pkg_install build-essential flex bison bc libssl-dev libelf-dev \
        libncurses-dev dwarves cpio rsync zstd kmod git ccache pkg-config \
        python3 python3-pip file wget curl unzip
      ;;
    dnf)
      pkg_install gcc gcc-c++ make flex bison bc openssl-devel elfutils-libelf-devel \
        ncurses-devel dwarves cpio rsync zstd kmod git ccache pkgconf-pkg-config \
        python3 python3-pip
      ;;
    pacman)
      pkg_install base-devel flex bison bc openssl libelf ncurses pahole cpio \
        rsync zstd kmod git ccache python python-pip
      ;;
    *) warn "install kernel build deps manually" ;;
  esac
  for c in gcc make flex bison bc pahole; do
    have "$c" && ok "$c" || warn "$c missing"
  done
}

install_llvm() {
  say "LLVM / Clang toolchain (needed for LLVM=1 and bindgen)"
  case "$PKG" in
    apt)    pkg_install clang lld llvm libclang-dev ;;
    dnf)    pkg_install clang lld llvm clang-devel ;;
    pacman) pkg_install clang lld llvm ;;
    *)      warn "install clang, lld, llvm and libclang headers manually" ;;
  esac
  for c in clang ld.lld llvm-objcopy; do
    have "$c" && ok "$c — $("$c" --version 2>&1 | head -1 | cut -c1-50)" || warn "$c missing"
  done

  # bindgen links against libclang, which lives in a versioned directory that is
  # not on the default library search path. Without LIBCLANG_PATH it fails with
  # an unhelpful error.
  local lib
  lib=$(find /usr/lib /usr/lib64 -name 'libclang.so*' 2>/dev/null | head -1)
  if [ -n "$lib" ]; then
    LIBCLANG_DIR=$(dirname "$lib")
    export LIBCLANG_PATH="$LIBCLANG_DIR"
    ok "libclang at $LIBCLANG_DIR"
  else
    warn "libclang not found — kernel Rust will not build. Install libclang-dev / clang-devel"
  fi
}

install_boot_tools() {
  say "QEMU and virtme-ng (the fast boot loop)"
  case "$PKG" in
    apt)
      pkg_install qemu-system-x86 qemu-utils cpu-checker
      # Ubuntu/Debian package virtme-ng. Do NOT use pip: modern distros mark
      # their Python "externally managed" (PEP 668) and refuse it.
      if ! have vng; then
        pkg_install virtme-ng || warn "virtme-ng not in your repos; try: pipx install virtme-ng"
      fi
      ;;
    dnf)
      pkg_install qemu-system-x86 qemu-img
      have vng || pkg_install virtme-ng || warn "install virtme-ng via pipx"
      ;;
    pacman)
      pkg_install qemu-system-x86 qemu-img
      have vng || warn "virtme-ng is in the AUR; install with your AUR helper"
      ;;
  esac
  have qemu-system-x86_64 && ok "qemu $(qemu-system-x86_64 --version | head -1 | awk '{print $4}')" || warn "qemu missing"
  have vng && ok "vng $(vng --version 2>&1 | head -1)" || warn "vng missing"

  say "Debug and benchmark tools"
  case "$PKG" in
    apt) pkg_install gdb trace-cmd fio device-tree-compiler 2>/dev/null || true ;;
    dnf) pkg_install gdb trace-cmd fio dtc 2>/dev/null || true ;;
    *)   : ;;
  esac
}

setup_ccache() {
  say "ccache"
  have ccache || { warn "ccache not installed"; return; }
  ccache --max-size=20G > /dev/null 2>&1
  ok "cache limit 20G"
  # The whole mechanism is PATH order: /usr/lib/ccache holds symlinks named gcc,
  # cc, clang... and must come BEFORE /usr/bin for them to be used.
  local d=""
  for cand in /usr/lib/ccache /usr/lib64/ccache /usr/lib/ccache/bin; do
    [ -d "$cand" ] && { d="$cand"; break; }
  done
  if [ -n "$d" ]; then
    CCACHE_BIN_DIR="$d"
    export PATH="$d:$PATH"
    ok "ccache dir will be put on PATH: $d"
  else
    warn "no ccache compiler-symlink dir found; set CC=\"ccache gcc\" instead"
  fi
}

write_env() {
  say "Environment"
  # Regenerated wholesale each run, so it is idempotent by construction and
  # never accumulates stale duplicate exports.
  cat > "$ENV_FILE" <<EOF
# ~/.lkdrust_env — generated by LKD_RUST/setup. Safe to regenerate.
# Sourced by ~/.bashrc AND directly by the setup scripts, because a distro
# ~/.bashrc returns early for non-interactive shells.

export LKD_ROOT="$LKD_ROOT"
export LINUX_TREE="$KERNEL_DIR"
EOF
  [ -n "${LIBCLANG_DIR:-}" ] && echo "export LIBCLANG_PATH=\"$LIBCLANG_DIR\"" >> "$ENV_FILE"
  # ccache works purely by PATH order: its dir holds symlinks named gcc, cc,
  # clang and must come before /usr/bin. The guard keeps re-sourcing idempotent.
  if [ -n "${CCACHE_BIN_DIR:-}" ]; then
    cat >> "$ENV_FILE" <<EOF

case ":\$PATH:" in
  *":$CCACHE_BIN_DIR:"*) ;;
  *) export PATH="$CCACHE_BIN_DIR:\$PATH" ;;
esac
EOF
  fi
  cat >> "$ENV_FILE" <<'EOF'

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
EOF
  ok "wrote $ENV_FILE"

  # Hook it into interactive shells too. The guard makes this a one-time append.
  local hook='[ -f "$HOME/.lkdrust_env" ] && . "$HOME/.lkdrust_env"'
  bashrc_add "$hook" '.lkdrust_env'
  [ -f "$HOME/.profile" ] && ! grep -qF '.lkdrust_env' "$HOME/.profile" 2>/dev/null \
    && printf '%s\n' "$hook" >> "$HOME/.profile" && ok "hooked into ~/.profile (login shells)"

  # shellcheck disable=SC1090
  . "$ENV_FILE"
  ok "LINUX_TREE=$LINUX_TREE"
  [ -n "${LIBCLANG_PATH:-}" ] && ok "LIBCLANG_PATH=$LIBCLANG_PATH"
  info "any script can now use it with:  . ~/.lkdrust_env"
}

clone_kernel() {
  say "Kernel source"
  mkdir -p "$LKD_ROOT/kernel"

  case "$KERNEL_DIR" in
    /mnt/*) die "KERNEL_DIR is under /mnt/ — builds there are several times slower and NTFS loses symlinks and the +x bit. Set LKD_ROOT to a native Linux path." ;;
  esac

  if [ -d "$KERNEL_DIR/.git" ]; then
    ok "tree already present"
  else
    local url="$UPSTREAM_URL"
    [ "$KERNEL_SRC" = fork ] && url="$FORK_URL"
    info "cloning from: $url"
    info "this is the slow part — roughly 6 GB, 10-40 minutes"
    git clone "$url" "$KERNEL_DIR" || die "clone failed"
  fi

  cd "$KERNEL_DIR" || die "cannot enter $KERNEL_DIR"

  # Convention: origin is ALWAYS upstream (fetch from), github is your fork (push to).
  # A fork never auto-updates, so pointing origin at it would silently freeze you
  # at whenever you forked.
  if [ "$KERNEL_SRC" = fork ]; then
    git remote get-url github > /dev/null 2>&1 || git remote rename origin github 2>/dev/null || true
  fi
  add_remote() {
    git remote get-url "$1" > /dev/null 2>&1 && info "remote $1 exists" \
      || { git remote add "$1" "$2" && ok "remote $1 → $2"; }
  }
  add_remote origin "$UPSTREAM_URL"
  add_remote next   "$NEXT_URL"
  add_remote stable "$STABLE_URL"
  add_remote rfl    "$RFL_URL"
  [ -n "$FORK_URL" ] && add_remote github "$FORK_URL"

  if [ -f .git/shallow ]; then
    warn "SHALLOW clone — blame, bisect and Fixes: tags will not work"
    info "fix with: git fetch --unshallow"
  fi

  if [ -n "$FORK_BRANCH" ]; then
    git fetch github "$FORK_BRANCH" 2>/dev/null \
      && git checkout -B "$FORK_BRANCH" "github/$FORK_BRANCH" \
      && ok "checked out $FORK_BRANCH from your fork" \
      || warn "could not fetch $FORK_BRANCH from github"
  fi

  ok "version $(make -s kernelversion 2>/dev/null), HEAD $(git log --oneline -1 2>/dev/null | cut -c1-60)"
}

install_rust() {
  say "Rust toolchain"
  cd "$KERNEL_DIR" || die "no kernel tree"

  if ! have rustup; then
    info "installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
      || die "rustup install failed"
  fi
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  # No .bashrc entry needed: $ENV_FILE already sources ~/.cargo/env if present.

  local want have_v
  want=$(scripts/min-tool-version.sh rustc 2>/dev/null) || die "cannot read min-tool-version.sh"
  have_v=$(rustc --version 2>/dev/null | awk '{print $2}')
  info "tree wants rustc >= $want; installed: ${have_v:-none}"

  # min-tool-version.sh reports a MINIMUM. rustup gives current stable, which is
  # usually well past it — so downloading a pinned old toolchain is pure cost, and
  # on a slow network it fails outright.
  if [ -n "$have_v" ] && ver_ge "$have_v" "$want"; then
    ok "installed rustc already meets the minimum — no download needed"
    rustup component add rust-src rustfmt clippy
  else
    info "installing rustc $want"
    rustup toolchain install "$want" || die "toolchain install failed"
    rustup component add rust-src rustfmt clippy --toolchain "$want"
    rustup override set "$want"
    ok "pinned this tree to $want"
  fi
  # rust-src is mandatory: the kernel compiles core and alloc FROM SOURCE for its
  # own custom target, because no prebuilt core exists for "kernel".
  rustup component list --installed 2>/dev/null | grep -q '^rust-src' \
    && ok "rust-src present" || warn "rust-src missing"
  ok "$(rustc --version)"
}

install_bindgen() {
  say "bindgen (generates Rust views of C headers)"
  cd "$KERNEL_DIR" || die "no kernel tree"
  local want have_v
  want=$(scripts/min-tool-version.sh bindgen 2>/dev/null)
  have_v=$(bindgen --version 2>/dev/null | awk '{print $2}')
  if [ -n "$have_v" ] && [ "$have_v" = "$want" ]; then
    ok "bindgen $have_v already installed"
  else
    info "installing bindgen-cli $want (compiles from source, a few minutes)"
    # --locked uses the crate's own lockfile so the build is reproducible.
    cargo install --locked --version "$want" bindgen-cli || die "bindgen install failed"
    ok "bindgen $(bindgen --version | awk '{print $2}')"
  fi
}

rust_gate() {
  say "The gate: make LLVM=1 rustavailable"
  cd "$KERNEL_DIR" || die "no kernel tree"
  if make LLVM=1 rustavailable; then
    ok "Rust is available"
  else
    die "rustavailable says no — read the message above, it names the tool and the problem"
  fi
}

configure_kernel() {
  say "Kernel configuration"
  cd "$KERNEL_DIR" || die "no kernel tree"

  if [ -f .config ]; then
    cp .config ".config.backup.$(date +%Y%m%d-%H%M%S)"
    ok "backed up existing .config"
  else
    make LLVM=1 defconfig || die "defconfig failed"
    ok "defconfig written"
  fi

  # virtme-ng needs virtio/9p to share the host filesystem into the guest, and
  # defconfig does not enable them. --kconfig only edits .config; it builds nothing.
  if have vng; then
    vng --kconfig > /dev/null 2>&1 && ok "virtme options added" \
      || warn "vng --kconfig failed; boots may not share your filesystem"
  fi

  scripts/config --enable RUST
  scripts/config --enable SAMPLES
  scripts/config --enable SAMPLES_RUST
  # =m not =y: a built-in sample cannot be insmod'd, which is the whole point.
  for s in SAMPLE_RUST_MINIMAL SAMPLE_RUST_PRINT SAMPLE_RUST_MISC_DEVICE; do
    scripts/config --module "$s"
  done
  scripts/config --enable RUST_DEBUG_ASSERTIONS
  scripts/config --enable RUST_OVERFLOW_CHECKS
  scripts/config --enable DEBUG_KERNEL
  scripts/config --enable DEBUG_FS
  scripts/config --enable PROVE_LOCKING
  scripts/config --enable DEBUG_ATOMIC_SLEEP

  # scripts/config edits text; olddefconfig makes Kconfig re-resolve every
  # dependency. Skipping it leaves a contradictory .config.
  make LLVM=1 olddefconfig || die "olddefconfig failed"

  grep -q '^CONFIG_RUST=y' .config && ok "CONFIG_RUST=y" \
    || die "CONFIG_RUST did not stick — a dependency is blocking it"
  local v
  v=$(grep -cE '^CONFIG_(VIRTIO|NET_9P|9P_FS)' .config || true)
  [ "${v:-0}" -ge 3 ] && ok "virtio/9p options present ($v)" \
    || warn "virtio/9p options thin ($v) — vng may not share your filesystem"
}

build_kernel() {
  say "Building (this takes a while — 5-20 minutes)"
  cd "$KERNEL_DIR" || die "no kernel tree"
  local start end
  start=$(date +%s)
  make LLVM=1 -j"$JOBS" || die "build failed"
  end=$(date +%s)
  ok "built in $(( (end-start)/60 ))m $(( (end-start)%60 ))s with -j$JOBS"
  [ -f vmlinux ] && ok "vmlinux $(du -h vmlinux | cut -f1) (for debugging)"
  local bz
  bz=$(ls arch/*/boot/bzImage 2>/dev/null | head -1)
  [ -n "$bz" ] && ok "$bz $(du -h "$bz" | cut -f1) (bootable)"
  local n
  n=$(ls samples/rust/*.ko 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && ok "$n Rust sample module(s) built"
}

setup_editor() {
  say "Editor support"
  cd "$KERNEL_DIR" || return
  make LLVM=1 rust-analyzer > /dev/null 2>&1 && ok "rust-project.json (rust-analyzer)" \
    || warn "rust-analyzer config generation failed"
  info "browse the kernel Rust API docs with: make LLVM=1 rustdoc"
}

final_summary() {
  say "Done"
  cat <<EOF
  tree     : $KERNEL_DIR
  version  : $(cd "$KERNEL_DIR" && make -s kernelversion 2>/dev/null)
  branch   : $(cd "$KERNEL_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null)

  env      : $ENV_FILE  (source it from anywhere: . ~/.lkdrust_env)

  Open a NEW shell, or run '. ~/.lkdrust_env', then:

    cd "\$LINUX_TREE"
    vng --exec 'uname -r'                                   # boot your kernel
    vng --exec 'insmod samples/rust/rust_minimal.ko; dmesg | tail'

  To get ready to send patches upstream (git identity, SMTP, b4):

    bash setup/setup-upstream.sh

  To verify everything:

    bash setup/verify.sh
EOF
}

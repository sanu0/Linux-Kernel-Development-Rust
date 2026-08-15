#!/bin/bash
# M1W1D2 - clone mainline Linux into $LINUX_TREE and add the remotes you will need later.
#
# Safe to re-run: skips the clone if the tree already exists, and skips remotes already present.
#
# Usage:
#   bash clone_kernel.sh              # full clone (recommended)
#   bash clone_kernel.sh --blobless   # full commit history, file contents fetched on demand
#   bash clone_kernel.sh --mirror-gh  # clone from the GitHub mirror (often faster), then
#                                     # point origin back at kernel.org
#
# NOTE: --depth=1 is deliberately NOT offered. git history is a kernel development tool:
# blame, bisect, and Fixes: tags all need it. See theory/Month_1/Week_1/Day_2.md concept 2.

set -euo pipefail

MAINLINE="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
GH_MIRROR="https://github.com/torvalds/linux.git"

BLOBLESS=0
USE_MIRROR=0
for a in "$@"; do
  case "$a" in
    --blobless)  BLOBLESS=1 ;;
    --mirror-gh) USE_MIRROR=1 ;;
    *) echo "unknown option: $a"; exit 2 ;;
  esac
done

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

: "${LINUX_TREE:?LINUX_TREE is not set. Open a new shell, or re-check ~/.bashrc from Day 1 Phase 7.}"

case "$LINUX_TREE" in
  /mnt/*)
    echo "REFUSING: \$LINUX_TREE is under /mnt/ (the Windows filesystem)."
    echo "Builds there are several times slower, and NTFS does not preserve the"
    echo "executable bit or the symlinks the kernel tree needs."
    echo "Set it to something under \$HOME and try again."
    exit 1
    ;;
esac

say "Pre-flight"
echo "  LINUX_TREE : $LINUX_TREE"
echo "  free disk  : $(df -h "$HOME" | awk 'NR==2{print $4}')"
AVAIL_GB=$(( $(df -Pk "$HOME" | awk 'NR==2{print $4}') / 1024 / 1024 ))
if [ "$AVAIL_GB" -lt 15 ]; then
  echo "  WARNING: only ${AVAIL_GB} GB free. The clone alone wants ~6 GB, a build wants 2-3 GB more."
fi

if [ -d "$LINUX_TREE/.git" ]; then
  say "Tree already present - skipping clone"
  cd "$LINUX_TREE"
  echo "  version : $(make -s kernelversion 2>/dev/null)"
  echo "  HEAD    : $(git log --oneline -1)"
else
  say "Cloning (this is the long part: expect 10-40 minutes, ~6 GB)"
  mkdir -p "$(dirname "$LINUX_TREE")"

  URL="$MAINLINE"
  [ "$USE_MIRROR" = 1 ] && URL="$GH_MIRROR"

  ARGS=()
  [ "$BLOBLESS" = 1 ] && ARGS+=(--filter=blob:none)

  echo "  from: $URL"
  [ "$BLOBLESS" = 1 ] && echo "  mode: blobless partial clone"

  time git clone "${ARGS[@]}" "$URL" "$LINUX_TREE"

  cd "$LINUX_TREE"
  if [ "$USE_MIRROR" = 1 ]; then
    # Track the canonical tree even though we fetched from the mirror.
    git remote set-url origin "$MAINLINE"
    echo "  origin repointed at kernel.org"
  fi
fi

say "Adding remotes (URLs only - nothing is fetched)"
add_remote() {
  local name="$1" url="$2"
  if git remote get-url "$name" > /dev/null 2>&1; then
    echo "  $name already present"
  else
    git remote add "$name" "$url"
    echo "  added $name -> $url"
  fi
}
cd "$LINUX_TREE"
add_remote next   "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
add_remote stable "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
add_remote rfl    "https://github.com/Rust-for-Linux/linux.git"

say "Result"
git remote -v
echo
echo "  version   : $(make -s kernelversion)"
echo "  HEAD      : $(git log --oneline -1)"
echo "  .git size : $(du -sh .git | cut -f1)"
echo "  tree size : $(du -sh --exclude=.git . | cut -f1)"

cat <<EOF

Next:
  cd "\$LINUX_TREE"
  make defconfig
  bash ~/LKD_RUST/codes/Month_1/Week_1/Day_2/first_build.sh

Do NOT fetch the other remotes today - each is another multi-GB download and you
need none of it yet. The URLs are the point.
EOF

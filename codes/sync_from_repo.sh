#!/bin/bash
# Sync REPO -> WSL: copy the git repo's codes/ into ~/LKD_RUST/codes/ so you can BUILD and RUN.
# Also normalizes line endings (Windows CRLF -> LF) and restores the +x bit on .sh files,
# because NTFS doesn't preserve Unix permissions.
#
# CRLF matters more here than in most projects: checkpatch.pl rejects DOS line endings, and a
# kernel source file with \r in it is a patch you cannot submit.
#
# One-time setup — add your paths to ~/.bashrc (stays local, never committed):
#   echo 'export LKDRUST_REPO="/mnt/c/Users/<you>/path/to/LKD_RUST"' >> ~/.bashrc && source ~/.bashrc
#
# Usage:  bash sync_from_repo.sh
set -e

: "${LKDRUST_REPO:?Set LKDRUST_REPO to your LKD_RUST folder. See header.}"
SRC="$LKDRUST_REPO/codes"
DST="$HOME/LKD_RUST/codes"

[ -d "$SRC" ] || { echo "Source not found: $SRC"; exit 1; }
mkdir -p "$DST"

echo "REPO -> WSL"
echo "  from: $SRC"
echo "  to:   $DST"

if command -v rsync > /dev/null 2>&1; then
  rsync -a --exclude '.git' --exclude 'target' --exclude '*.ko' --exclude '*.o' \
        "$SRC"/ "$DST"/
else
  cp -r "$SRC"/. "$DST"/
fi

# Windows editors may save CRLF; bash chokes on \r and checkpatch rejects it in kernel sources.
find "$DST" -type f \
  \( -name '*.sh' -o -name '*.rs' -o -name '*.c' -o -name '*.h' -o -name '*.py' \
     -o -name '*.dts' -o -name '*.dtsi' -o -name '*.yaml' -o -name '*.toml' \
     -o -name 'Makefile' -o -name 'Kconfig' \) \
  -exec sed -i 's/\r$//' {} +

find "$DST" -type f -name '*.sh' -exec chmod +x {} +

echo "Done. Files now in WSL:"
find "$DST" -type f -not -path '*/target/*' | sed "s|$DST/|  |" | sort

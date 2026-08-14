#!/bin/bash
# Sync WSL -> REPO: copy ~/LKD_RUST/codes/ back into the git repo so you can commit + push.
# Run this after writing or editing code in WSL, then commit from Windows (or via git in WSL).
#
# One-time setup — add your paths to ~/.bashrc (stays local, never committed):
#   echo 'export LKDRUST_REPO="/mnt/c/Users/<you>/path/to/LKD_RUST"' >> ~/.bashrc && source ~/.bashrc
#
# Usage:  bash sync_to_repo.sh
# Note:   this ADDS/UPDATES files; it never deletes. Remove files from the repo by hand
#         (or with `git rm`) if you delete them in WSL.
set -e

: "${LKDRUST_REPO:?Set LKDRUST_REPO to your LKD_RUST folder. See header.}"
SRC="$HOME/LKD_RUST/codes"
DST="$LKDRUST_REPO/codes"

[ -d "$SRC" ] || { echo "Source not found: $SRC — run sync_from_repo.sh first."; exit 1; }
mkdir -p "$DST"

echo "WSL -> REPO"
echo "  from: $SRC"
echo "  to:   $DST"

# Exclude everything that must never reach git: build output, Cargo targets, module objects.
if command -v rsync > /dev/null 2>&1; then
  rsync -a \
    --exclude '__pycache__' --exclude '.venv' --exclude 'target' \
    --exclude '*.ko' --exclude '*.o' --exclude '*.mod' --exclude '*.mod.c' \
    --exclude '*.cmd' --exclude '.tmp_versions' --exclude 'Module.symvers' \
    --exclude 'modules.order' --exclude '*.symvers' --exclude '*.order' \
    "$SRC"/ "$DST"/
else
  cp -r "$SRC"/. "$DST"/
  echo "WARNING: rsync not found; build artifacts may have been copied. Check 'git status'."
fi

echo
echo "Done. Review before committing — .gitignore should catch strays, but look anyway:"
echo "  cd \"$LKDRUST_REPO\" && git status --short"
echo "  git add codes && git commit -m \"Update kernel Rust code\" && git push origin main"

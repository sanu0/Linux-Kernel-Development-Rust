#!/bin/bash
# rust_census.sh — M1W1D3. Count the Rust in your kernel tree, and save the numbers.
#
#   bash rust_census.sh            print the census
#   bash rust_census.sh --save     also save it next to this script, named by kernel version
#
# Every number comes from `git ls-files`, so only files that are part of the kernel
# source are counted — never your build output (.o, .ko, and so on).
#
# This is the seed of RustScope: run it again in a few months and compare the files.

DAY_DIR="$(cd "$(dirname "$0")" && pwd)"
TREE="${LINUX_TREE:-$HOME/LKD_RUST/kernel/linux}"
cd "$TREE" || { echo "no kernel tree at $TREE — set LINUX_TREE"; exit 1; }

census() {
  echo "Rust census — kernel $(make -s kernelversion), branch $(git rev-parse --abbrev-ref HEAD), $(date +%Y-%m-%d)"
  echo
  echo "Rust files per top-level directory:"
  git ls-files -- '*.rs' | cut -d/ -f1 | sort | uniq -c | sort -rn
  echo
  echo "Rust lines and files per directory (top 15 by lines):"
  git ls-files -z -- '*.rs' | xargs -0 wc -l \
    | awk '$2 != "total" { split($2, p, "/"); d = p[1] "/" p[2]; files[d]++; lines[d] += $1 }
           END { for (d in lines) printf "%8d lines %5d files   %s\n", lines[d], files[d], d }' \
    | sort -rn | head -15
  echo
  local rs_files rs_lines c_files c_lines
  rs_files=$(git ls-files -- '*.rs' | wc -l)
  rs_lines=$(git ls-files -z -- '*.rs' | xargs -0 cat | wc -l)
  c_files=$(git ls-files -- '*.c' '*.h' | wc -l)
  c_lines=$(git ls-files -z -- '*.c' '*.h' | xargs -0 cat | wc -l)
  echo "Totals:"
  printf "  Rust %6d files %10d lines\n" "$rs_files" "$rs_lines"
  printf "  C    %6d files %10d lines\n" "$c_files" "$c_lines"
  awk -v r="$rs_lines" -v c="$c_lines" \
    'BEGIN { printf "  Rust is %.2f%% of all C and Rust lines\n", 100 * r / (r + c) }'
}

if [ "${1:-}" = "--save" ]; then
  out="$DAY_DIR/census_$(make -s kernelversion).txt"
  census | tee "$out"
  echo
  echo "saved to $out"
else
  census
fi

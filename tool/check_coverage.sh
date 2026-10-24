#!/usr/bin/env bash
# Fails when the line coverage in an lcov file is below a threshold.
# Usage: tool/check_coverage.sh <lcov.info> <minimum percent> [exclude regex]
# Files whose path matches the optional regex are left out (for example
# widgets, whose coverage is not part of the app logic gate, ADR 0015).
set -euo pipefail

lcov_file="$1"
minimum="$2"
exclude="${3:-^$}"

read -r hit found < <(awk -F: -v exclude="$exclude" '
  /^SF:/ { skip = ($2 ~ exclude) }
  /^LH:/ && !skip { hit += $2 }
  /^LF:/ && !skip { found += $2 }
  END { print hit + 0, found + 0 }
' "$lcov_file")

if [ "$found" -eq 0 ]; then
  echo "No lines found in $lcov_file" >&2
  exit 1
fi

percent=$(awk -v h="$hit" -v f="$found" 'BEGIN { printf "%.1f", h * 100 / f }')
echo "Line coverage: $percent% ($hit/$found), minimum $minimum%"
awk -v p="$percent" -v m="$minimum" 'BEGIN { exit !(p >= m) }' || {
  echo "Coverage is below $minimum%" >&2
  exit 1
}

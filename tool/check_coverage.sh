#!/usr/bin/env bash
# Fails when the line coverage in an lcov file is below a threshold.
# Usage: tool/check_coverage.sh <lcov.info> <minimum percent>
set -euo pipefail

lcov_file="$1"
minimum="$2"

read -r hit found < <(awk -F: '
  /^LH:/ { hit += $2 }
  /^LF:/ { found += $2 }
  END { print hit, found }
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

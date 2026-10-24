#!/usr/bin/env bash
# Fails when a release APK requests network permissions (ADR 0003).
# Usage: tool/check_permissions.sh <app-release.apk>
set -euo pipefail

apk="$1"
aapt=$(find "${ANDROID_HOME:-$ANDROID_SDK_ROOT}/build-tools" -name aapt -type f | sort | tail -n 1)
if [ -z "$aapt" ]; then
  echo "aapt not found in the Android SDK build-tools" >&2
  exit 1
fi

permissions=$("$aapt" dump permissions "$apk")
echo "$permissions"

forbidden='android.permission.(INTERNET|ACCESS_NETWORK_STATE|ACCESS_WIFI_STATE)'
if echo "$permissions" | grep -Eq "$forbidden"; then
  echo "The release build must not request network permissions." >&2
  exit 1
fi
echo "OK: no network permission requested."

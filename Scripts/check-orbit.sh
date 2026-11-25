#!/bin/sh
set -eu
task_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
task_build="$(mktemp -d /private/tmp/budget-orbit-checks.XXXXXX)"
trap 'rm -rf "$task_build"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
  -module-cache-path "$task_build/modules" \
  "$task_root/Personal Budget App/Features/Home/SpendingOrbitGeometry.swift" \
  "$task_root/Tests/SpendingOrbitChecks.swift" -o "$task_build/checks"
"$task_build/checks"

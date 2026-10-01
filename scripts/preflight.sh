#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
DERIVED_DATA=$(mktemp -d /private/tmp/mbx7-preflight.XXXXXX)
trap 'rm -rf "$DERIVED_DATA"' EXIT

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
    -project "$PROJECT_ROOT/X7Control.xcodeproj" \
    -scheme X7Control \
    -configuration Release \
    -sdk macosx \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    clean build analyze

APP_PATH="$DERIVED_DATA/Build/Products/Release/MB X7 Control.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/MB X7 Control"

file "$EXECUTABLE" | grep -q 'arm64'
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
if codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -q 'get-task-allow'; then
    print -u2 'Release build unexpectedly contains get-task-allow.'
    exit 1
fi
if otool -L "$EXECUTABLE" | grep -qi 'creative'; then
    print -u2 'Release build unexpectedly links a Creative runtime.'
    exit 1
fi

print 'Preflight passed: Release build, analysis, arm64 architecture, signature, entitlements, and linked runtimes.'

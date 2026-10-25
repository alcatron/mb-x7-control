#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
TEST_DIR=$(mktemp -d /private/tmp/mbx7-protocol-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swiftc \
    -parse-as-library \
    -module-cache-path "$TEST_DIR/ModuleCache" \
    "$PROJECT_ROOT/X7Control/Models/X7Protocol.swift" \
    "$PROJECT_ROOT/Tools/ProtocolSelfTest.swift" \
    -o "$TEST_DIR/protocol-self-test"

"$TEST_DIR/protocol-self-test"

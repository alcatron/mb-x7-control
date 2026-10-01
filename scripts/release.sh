#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
PROJECT="$PROJECT_ROOT/X7Control.xcodeproj"
SCHEME="X7Control"
PRODUCT_NAME="MB X7 Control"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/X7Control/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_ROOT/X7Control/Info.plist")
DIST_DIR="$PROJECT_ROOT/dist"
ARCHIVE_PATH="$DIST_DIR/$PRODUCT_NAME-$VERSION-$BUILD_NUMBER.xcarchive"
EXPORT_PATH="$DIST_DIR/export"
DMG_PATH="$DIST_DIR/$PRODUCT_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the Apple Developer Team ID}"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to the full Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"

if [[ -e "$ARCHIVE_PATH" || -e "$EXPORT_PATH" || -e "$DMG_PATH" || -e "$CHECKSUM_PATH" ]]; then
    print -u2 "Release output already exists in $DIST_DIR. Move it aside before continuing."
    exit 1
fi

mkdir -p "$DIST_DIR"
EXPORT_OPTIONS=$(mktemp /private/tmp/mbx7-export-options.XXXXXX.plist)
STAGING_DIR=$(mktemp -d /private/tmp/mbx7-dmg.XXXXXX)
trap 'rm -f "$EXPORT_OPTIONS"; rm -rf "$STAGING_DIR"' EXIT

plutil -create xml1 "$EXPORT_OPTIONS"
plutil -insert method -string developer-id "$EXPORT_OPTIONS"
plutil -insert destination -string export "$EXPORT_OPTIONS"
plutil -insert signingStyle -string manual "$EXPORT_OPTIONS"
plutil -insert signingCertificate -string "$DEVELOPER_ID_APPLICATION" "$EXPORT_OPTIONS"
plutil -insert teamID -string "$DEVELOPMENT_TEAM" "$EXPORT_OPTIONS"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="$EXPORT_PATH/$PRODUCT_NAME.app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
file "$APP_PATH/Contents/MacOS/$PRODUCT_NAME" | grep -q 'arm64'
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q 'Authority=Developer ID Application:'
if codesign -d --entitlements - "$APP_PATH" 2>&1 | grep -q 'get-task-allow'; then
    print -u2 'Exported app unexpectedly contains get-task-allow.'
    exit 1
fi

ditto "$APP_PATH" "$STAGING_DIR/$PRODUCT_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
hdiutil verify "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

print "Release candidate created:"
print "  $DMG_PATH"
print "  $CHECKSUM_PATH"

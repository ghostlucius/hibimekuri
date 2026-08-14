#!/bin/bash
set -euo pipefail

# Builds a release .app bundle and packages it into a .dmg for install
# testing. No Xcode required — assembles the bundle by hand from the SPM
# release build, since this machine only has Command Line Tools.
#
# The app bundle is assembled and signed in a /tmp staging area, not
# inside the project directory: this project lives on iCloud Drive, which
# tags copied files with a com.apple.provenance extended attribute that
# `xattr -c` cannot strip (it's a protected attribute) and that codesign
# rejects as "detritus." Building outside iCloud Drive avoids the tag
# ever being applied in the first place.

cd "$(dirname "$0")/.."

APP_NAME="Hibimekuri"
BUNDLE_ID="com.himekuri.tearoffdiary"
VERSION="1.0.0"
DIST_DIR="dist"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hibimekuri_build.XXXXXX")"
APP_DIR="$STAGING_ROOT/$APP_NAME.app"

# Keep the signed app for local testing on success, but remove this private
# staging directory if packaging stops midway. mktemp creates an owner-only,
# unique directory so another local process cannot pre-populate it.
cleanup_staging_on_failure() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup_staging_on_failure ERR INT TERM
SIGN_IDENTITY="${HIMEKURI_SIGN_IDENTITY:--}"

echo "==> Building release binary (arm64 + x86_64, merged into a universal binary)"
# Distributed outside the App Store to other people's Macs, some of which
# may be Intel — a plain `swift build -c release` only produces a binary
# for the host machine's own architecture (arm64 here), which won't launch
# at all on an Intel Mac (there's no Rosetta translation in that
# direction). Building each slice separately and merging with `lipo`
# matches Apple's documented approach for a universal macOS binary built
# outside Xcode.
swift build -c release --arch arm64
swift build -c release --arch x86_64

echo "==> Assembling $APP_NAME.app (staged outside iCloud Drive at $STAGING_ROOT)"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

lipo -create -output "$APP_DIR/Contents/MacOS/$APP_NAME" \
    ".build/arm64-apple-macosx/release/$APP_NAME" \
    ".build/x86_64-apple-macosx/release/$APP_NAME"
lipo "$APP_DIR/Contents/MacOS/$APP_NAME" -verify_arch arm64 x86_64

RESOURCE_BUNDLE=".build/arm64-apple-macosx/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

# App icon: two light/dark variants (see scripts/generate_app_icon.swift)
# copied to the top level of Contents/Resources — CFBundleIconFile below
# points at the static one Finder/Dock show before launch; AppIconManager
# swaps the running app's Dock tile to the dark one at runtime.
if [ -f "AppIcon/AppIcon.icns" ]; then
    cp "AppIcon/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
if [ -f "AppIcon/AppIconDark.icns" ]; then
    cp "AppIcon/AppIconDark.icns" "$APP_DIR/Contents/Resources/AppIconDark.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

echo "==> Stripping extended attributes (belt-and-suspenders)"
find "$APP_DIR" -name ".DS_Store" -delete
find "$APP_DIR" -name "._*" -delete
xattr -cr "$APP_DIR" 2>/dev/null || true

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "==> Ad-hoc code signing"
    codesign --force --deep --sign - "$APP_DIR"
else
    echo "==> Developer ID code signing ($SIGN_IDENTITY)"
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

echo "==> Packaging .dmg"
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"
ln -sf /Applications "$STAGING_ROOT/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_ROOT" -ov -format UDZO "/tmp/${APP_NAME}.dmg"
cp "/tmp/${APP_NAME}.dmg" "$DMG_PATH"
rm -f "/tmp/${APP_NAME}.dmg"

if [ "$SIGN_IDENTITY" != "-" ]; then
    echo "==> Signing .dmg"
    codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [ -n "${HIMEKURI_NOTARY_APPLE_ID:-}" ] && [ -n "${HIMEKURI_NOTARY_TEAM_ID:-}" ] && [ -n "${HIMEKURI_NOTARY_PASSWORD:-}" ]; then
    echo "==> Notarizing .dmg"
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$HIMEKURI_NOTARY_APPLE_ID" \
        --team-id "$HIMEKURI_NOTARY_TEAM_ID" \
        --password "$HIMEKURI_NOTARY_PASSWORD" \
        --wait
    xcrun stapler staple "$DMG_PATH"
else
    echo "==> Skipping notarization (set HIMEKURI_NOTARY_APPLE_ID, HIMEKURI_NOTARY_TEAM_ID, and HIMEKURI_NOTARY_PASSWORD to enable it)"
fi

echo "==> Removing stale copied .app from dist"
rm -rf "$DIST_DIR/$APP_NAME.app"

echo "==> Done: $DMG_PATH"
echo "==> Signed app left in staging for local testing: $APP_DIR"

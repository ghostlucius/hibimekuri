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

APP_NAME="TearOffDiary"
BUNDLE_ID="com.himekuri.tearoffdiary"
VERSION="1.0.0"
DIST_DIR="dist"
STAGING_ROOT="/tmp/himekuri_build_staging"
APP_DIR="$STAGING_ROOT/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP_NAME.app (staged outside iCloud Drive at $STAGING_ROOT)"
rm -rf "$STAGING_ROOT"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

RESOURCE_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
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

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Packaging .dmg"
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"
ln -sf /Applications "$STAGING_ROOT/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_ROOT" -ov -format UDZO "/tmp/${APP_NAME}.dmg"
cp "/tmp/${APP_NAME}.dmg" "$DMG_PATH"
rm -f "/tmp/${APP_NAME}.dmg"

echo "==> Copying signed .app back for local testing (open dist/$APP_NAME.app)"
rm -rf "$DIST_DIR/$APP_NAME.app"
cp -R "$APP_DIR" "$DIST_DIR/$APP_NAME.app"

echo "==> Done: $DMG_PATH"

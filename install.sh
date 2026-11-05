#!/bin/sh
# Build TranslationReview in release mode and install it as /Applications/TranslationReview.app.
# Run again any time the code changes.
set -e
cd "$(dirname "$0")"

swift build -c release

APP="/Applications/TranslationReview.app"

# Quit any running copy (including one launched from Xcode) so the binary can be replaced
# and two instances don't fight over the same global hotkey. -f matches the full path:
# macOS truncates bare process names to 15 chars, so -x would miss this one.
pkill -f '/TranslationReview$' 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp -f .build/release/TranslationReview "$APP/Contents/MacOS/TranslationReview"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>TranslationReview</string>
	<key>CFBundleIdentifier</key><string>com.chloeshen.TranslationReview</string>
	<key>CFBundleName</key><string>Translation Review</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Installed $APP"

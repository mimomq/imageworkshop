#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

if [[ -d "/Applications/Xcode-beta.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

BUILD_DIR="${TMPDIR:-/tmp}/ImageWorkshopBuild-${UID}"
STAGE_DIR="${TMPDIR:-/tmp}/ImageWorkshopStage-${UID}"
xcrun swift build -c release --scratch-path "$BUILD_DIR"

APP_DIR="$PROJECT_DIR/dist/图匠.app"
STAGED_APP="$STAGE_DIR/图匠.app"
CONTENTS_DIR="$STAGED_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/release/ImageWorkshop" "$MACOS_DIR/ImageWorkshop"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/ImageWorkshop"

codesign --force --deep --sign - "$STAGED_APP"
mkdir -p "$PROJECT_DIR/dist"
ditto "$STAGED_APP" "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d com.apple.ResourceFork "$APP_DIR" 2>/dev/null || true
echo "已生成：$APP_DIR"

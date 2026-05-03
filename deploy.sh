#!/bin/bash
# Build APK debug y copia a /home/robertdev/apk-releases con timestamp.
# URL servidor: http://45.10.154.187/apk/<filename>.apk

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_RELEASES_DIR="/home/robertdev/apk-releases"

export JAVA_HOME="/home/robertdev/.dev-tools/jdk-17.0.13+11"
export PATH="$JAVA_HOME/bin:/home/robertdev/.dev-tools/flutter/bin:$PATH"

cd "$PROJECT_DIR"

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
TIMESTAMP=$(date +%Y%m%d-%H%M)
APK_NAME="memora-v${VERSION}-${TIMESTAMP}.apk"
LATEST_NAME="memora-latest.apk"

echo "==> Building APK debug for memora v${VERSION}..."
flutter build apk --debug

BUILT_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

if [ ! -f "$BUILT_APK" ]; then
    echo "ERROR: APK not found at $BUILT_APK"
    exit 1
fi

mkdir -p "$APK_RELEASES_DIR"
cp "$BUILT_APK" "$APK_RELEASES_DIR/$APK_NAME"
cp "$BUILT_APK" "$APK_RELEASES_DIR/$LATEST_NAME"

SIZE=$(du -h "$APK_RELEASES_DIR/$APK_NAME" | cut -f1)

echo ""
echo "==> Build done."
echo "    File: $APK_RELEASES_DIR/$APK_NAME ($SIZE)"
echo "    URL:  http://45.10.154.187/apk/$APK_NAME"
echo "    Latest URL: http://45.10.154.187/apk/$LATEST_NAME"

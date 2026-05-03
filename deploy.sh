#!/bin/bash
# Build APK release (firmado) y copia a /home/robertdev/apk-releases con timestamp.
# URL pública: https://apk.a-robertdev.com/<filename>.apk
# Tras el build:
#   - regenera index.html
#   - envía un mensaje a Telegram con el link
#   - si el APK <49MB, envía también el archivo (sendDocument)
#
# Uso: ./deploy.sh [--debug]   (default: release)

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_RELEASES_DIR="/home/robertdev/apk-releases"
BASE_URL="https://apk.a-robertdev.com"
TELEGRAM_ENV_FILE="/home/robertdev/telegram-claude-bot/.env"
PYTHON312="/home/robertdev/.pyenv/versions/3.12.11/bin/python3"

export JAVA_HOME="/home/robertdev/.dev-tools/jdk-17.0.13+11"
export PATH="$JAVA_HOME/bin:/home/robertdev/.dev-tools/flutter/bin:$PATH"

cd "$PROJECT_DIR"

BUILD_MODE="release"
if [ "$1" = "--debug" ]; then
    BUILD_MODE="debug"
fi

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
TIMESTAMP=$(date +%Y%m%d-%H%M)

if [ "$BUILD_MODE" = "release" ]; then
    APK_NAME="memora-v${VERSION}-${TIMESTAMP}-arm64.apk"
    LATEST_NAME="memora-latest.apk"
    echo "==> Building APK release (split per ABI) for memora v${VERSION}..."
    flutter build apk --release --split-per-abi
    BUILT_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
else
    APK_NAME="memora-v${VERSION}-${TIMESTAMP}-debug.apk"
    LATEST_NAME="memora-latest-debug.apk"
    echo "==> Building APK debug for memora v${VERSION}..."
    flutter build apk --debug
    BUILT_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ ! -f "$BUILT_APK" ]; then
    echo "ERROR: APK not found at $BUILT_APK"
    exit 1
fi

mkdir -p "$APK_RELEASES_DIR"
cp "$BUILT_APK" "$APK_RELEASES_DIR/$APK_NAME"
cp "$BUILT_APK" "$APK_RELEASES_DIR/$LATEST_NAME"

SIZE=$(du -h "$APK_RELEASES_DIR/$APK_NAME" | cut -f1)
SIZE_BYTES=$(stat -c '%s' "$APK_RELEASES_DIR/$APK_NAME")
APK_URL="$BASE_URL/$APK_NAME"
LATEST_URL="$BASE_URL/$LATEST_NAME"

if [ -x "$PYTHON312" ] && [ -f "$APK_RELEASES_DIR/_generate_index.py" ]; then
    "$PYTHON312" "$APK_RELEASES_DIR/_generate_index.py" >/dev/null && \
        echo "    Index page regenerated"
fi

echo ""
echo "==> Build done."
echo "    Mode: $BUILD_MODE"
echo "    File: $APK_RELEASES_DIR/$APK_NAME ($SIZE)"
echo "    URL:  $APK_URL"
echo "    Latest URL: $LATEST_URL"

# Telegram (silencioso si falla)
if [ -f "$TELEGRAM_ENV_FILE" ]; then
    set +e
    TG_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV_FILE" | cut -d'=' -f2-)
    TG_USER=$(grep '^AUTHORIZED_USER_ID=' "$TELEGRAM_ENV_FILE" | cut -d'=' -f2-)

    if [ -n "$TG_TOKEN" ] && [ -n "$TG_USER" ]; then
        TEXT="🚀 *Memora v${VERSION}* (${BUILD_MODE})
Tamaño: ${SIZE}
[Descargar APK](${APK_URL})
[Latest siempre actualizada](${LATEST_URL})"

        HTTP_CODE=$(curl -s -o /tmp/memora_tg_resp.json -w "%{http_code}" \
            -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${TG_USER}" \
            --data-urlencode "text=${TEXT}" \
            --data-urlencode "parse_mode=Markdown" \
            --data-urlencode "disable_web_page_preview=true")

        if [ "$HTTP_CODE" = "200" ]; then
            echo "    Telegram: mensaje enviado"
        else
            echo "    Telegram: fallo sendMessage HTTP $HTTP_CODE"
        fi

        # sendDocument si APK <49MB (límite del bot API es 50MB)
        if [ "$SIZE_BYTES" -lt $((49 * 1024 * 1024)) ]; then
            DOC_CODE=$(curl -s -o /tmp/memora_tg_doc.json -w "%{http_code}" \
                -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
                -F "chat_id=${TG_USER}" \
                -F "document=@${APK_RELEASES_DIR}/${APK_NAME}" \
                -F "caption=Memora v${VERSION} (${BUILD_MODE})")
            if [ "$DOC_CODE" = "200" ]; then
                echo "    Telegram: APK enviado como documento"
            else
                echo "    Telegram: fallo sendDocument HTTP $DOC_CODE"
            fi
        else
            echo "    Telegram: APK >49MB — solo enlace (no document)"
        fi
    else
        echo "    Telegram: TELEGRAM_BOT_TOKEN o AUTHORIZED_USER_ID no en $TELEGRAM_ENV_FILE"
    fi
    set -e
else
    echo "    Telegram: $TELEGRAM_ENV_FILE no existe — skip"
fi

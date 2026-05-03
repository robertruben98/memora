#!/bin/bash
# Build APK debug y copia a /home/robertdev/apk-releases con timestamp.
# URL pública: https://apk.a-robertdev.com/<filename>.apk
# Tras el build, envía un mensaje a Telegram con el link de descarga.

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_RELEASES_DIR="/home/robertdev/apk-releases"
BASE_URL="https://apk.a-robertdev.com"
TELEGRAM_ENV_FILE="/home/robertdev/telegram-claude-bot/.env"

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
APK_URL="$BASE_URL/$APK_NAME"
LATEST_URL="$BASE_URL/$LATEST_NAME"

# Regenerar index.html con la lista actualizada
PYTHON312="/home/robertdev/.pyenv/versions/3.12.11/bin/python3"
if [ -x "$PYTHON312" ] && [ -f "$APK_RELEASES_DIR/_generate_index.py" ]; then
    "$PYTHON312" "$APK_RELEASES_DIR/_generate_index.py" >/dev/null && \
        echo "    Index page regenerated"
fi

echo ""
echo "==> Build done."
echo "    File: $APK_RELEASES_DIR/$APK_NAME ($SIZE)"
echo "    URL:  $APK_URL"
echo "    Latest URL: $LATEST_URL"

# Notificación a Telegram (silenciosa si falla — no bloqueamos el deploy)
if [ -f "$TELEGRAM_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set +e
    # Lee solo las dos vars que necesitamos sin contaminar el shell
    TG_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$TELEGRAM_ENV_FILE" | cut -d'=' -f2-)
    TG_USER=$(grep '^AUTHORIZED_USER_ID=' "$TELEGRAM_ENV_FILE" | cut -d'=' -f2-)

    if [ -n "$TG_TOKEN" ] && [ -n "$TG_USER" ]; then
        TEXT="🚀 *Memora v${VERSION}* lista
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
            echo "    Telegram: notificación enviada"
        else
            echo "    Telegram: fallo (HTTP $HTTP_CODE) — ver /tmp/memora_tg_resp.json"
        fi
    else
        echo "    Telegram: TELEGRAM_BOT_TOKEN o AUTHORIZED_USER_ID no encontrados en $TELEGRAM_ENV_FILE"
    fi
    set -e
else
    echo "    Telegram: $TELEGRAM_ENV_FILE no existe — skip"
fi

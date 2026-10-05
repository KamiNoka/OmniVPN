#!/usr/bin/env bash
set -e

FRAMEWORKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Frameworks"
TARGET_DIR="${FRAMEWORKS_DIR}/Libbox.xcframework"

echo "==> Загрузка полнофункционального Libbox.xcframework с ядром Sing-box..."
DOWNLOAD_URL="https://github.com/folexz/libbox-build/releases/download/v1.13.7/Libbox.xcframework.zip"

mkdir -p "${FRAMEWORKS_DIR}"
TMP_ZIP=$(mktemp /tmp/libbox_XXXXXX.zip)

echo "Скачивание из ${DOWNLOAD_URL}..."
if curl -sL --fail "${DOWNLOAD_URL}" -o "${TMP_ZIP}"; then
    echo "Распаковка Libbox.xcframework..."
    rm -rf "${TARGET_DIR}"
    unzip -q -o "${TMP_ZIP}" -d "${FRAMEWORKS_DIR}/"
    rm -f "${TMP_ZIP}"
    echo "✓ Настоящее ядро Sing-box успешно распаковано в ${TARGET_DIR}"
    ls -lh "${TARGET_DIR}"
else
    echo "❌ Ошибка скачивания Libbox.xcframework"
    rm -f "${TMP_ZIP}"
    exit 1
fi

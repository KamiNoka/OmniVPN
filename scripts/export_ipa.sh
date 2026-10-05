#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Генерация проекта XcodeGen..."
if command -v xcodegen &> /dev/null; then
    xcodegen generate
else
    echo "⚠️ xcodegen не найден на этой машине. В GitHub Actions CI он будет установлен автоматически."
fi

ARCHIVE_PATH="${PROJECT_ROOT}/build/VpnClient.xcarchive"
EXPORT_PATH="${PROJECT_ROOT}/build/out"

echo "==> Сборка архива приложения..."
xcodebuild -project VpnClient.xcodeproj \
    -scheme VpnClient \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "${ARCHIVE_PATH}" \
    clean archive \
    CODE_SIGN_STYLE="Automatic"

echo "==> Экспорт IPA файла..."
mkdir -p "${EXPORT_PATH}"

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist exportOptions.plist \
    -exportPath "${EXPORT_PATH}"

echo "✓ Готово! IPA файл сохранен в: ${EXPORT_PATH}"
ls -lh "${EXPORT_PATH}"/*.ipa

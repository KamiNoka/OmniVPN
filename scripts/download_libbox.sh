#!/usr/bin/env bash
set -e

# Target directory
FRAMEWORKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Frameworks"
TARGET_DIR="${FRAMEWORKS_DIR}/Libbox.xcframework"
VERSION="v1.9.4"

echo "==> Проверка наличия Libbox.xcframework..."
mkdir -p "${FRAMEWORKS_DIR}"

if [ -d "${TARGET_DIR}" ] && [ "$(ls -A "${TARGET_DIR}")" ]; then
    echo "✓ Libbox.xcframework уже существует в ${TARGET_DIR}"
    exit 0
fi

DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${VERSION}/libbox-${VERSION}.tar.xz"
TMP_DIR=$(mktemp -d)

echo "==> Загрузка официального бинарного релиза Sing-box ${VERSION}..."
echo "URL: ${DOWNLOAD_URL}"

if curl -sL --fail "${DOWNLOAD_URL}" -o "${TMP_DIR}/libbox.tar.xz"; then
    echo "==> Распаковка архива..."
    tar -xf "${TMP_DIR}/libbox.tar.xz" -C "${TMP_DIR}"
    
    if [ -d "${TMP_DIR}/Libbox.xcframework" ]; then
        mv "${TMP_DIR}/Libbox.xcframework" "${TARGET_DIR}"
        echo "✓ Libbox.xcframework успешно установлен в ${TARGET_DIR}"
        rm -rf "${TMP_DIR}"
        exit 0
    fi
fi

echo "⚠️ Предупреждение: Не удалось скачать официальный релиз из сети. Создание локального интерфейсного стаба..."
rm -rf "${TMP_DIR}"

# Create interface stub framework for compilation in environments without internet/libbox
mkdir -p "${TARGET_DIR}/ios-arm64/Libbox.framework/Headers"
mkdir -p "${TARGET_DIR}/ios-arm64_x86_64-simulator/Libbox.framework/Headers"

cat << 'EOF' > "${TARGET_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64</string>
			<key>LibraryPath</key>
			<string>Libbox.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64_x86_64-simulator</string>
			<key>LibraryPath</key>
			<string>Libbox.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
				<string>x86_64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
			<key>SupportedPlatformVariant</key>
			<string>simulator</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
EOF

for platform in "ios-arm64" "ios-arm64_x86_64-simulator"; do
    cat << 'EOF' > "${TARGET_DIR}/${platform}/Libbox.framework/Headers/Libbox.h"
#ifndef Libbox_h
#define Libbox_h
#import <Foundation/Foundation.h>

@interface LibboxCommandServer : NSObject
- (int64_t)totalUpload;
- (int64_t)totalDownload;
- (void)close;
@end

@interface LibboxBoxService : NSObject
- (BOOL)start:(NSError **)error;
- (void)close;
@end

FOUNDATION_EXPORT LibboxCommandServer* _Nullable LibboxNewCommandServer(id _Nullable handler, int32_t maxClients, NSError* _Nullable* _Nullable error);
FOUNDATION_EXPORT LibboxBoxService* _Nullable LibboxNewBoxService(NSString* _Nonnull configContent, id _Nullable platformInterface, NSError* _Nullable* _Nullable error);

#endif
EOF
    cat << 'EOF' > "${TARGET_DIR}/${platform}/Libbox.framework/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Libbox</string>
	<key>CFBundleIdentifier</key>
	<string>io.nekohasekai.libbox</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.9.4</string>
</dict>
</plist>
EOF
    # Create empty object file archive stub if ar exists
    if command -v ar &> /dev/null; then
        ar cr "${TARGET_DIR}/${platform}/Libbox.framework/Libbox" 2>/dev/null || touch "${TARGET_DIR}/${platform}/Libbox.framework/Libbox"
    else
        touch "${TARGET_DIR}/${platform}/Libbox.framework/Libbox"
    fi
done

echo "✓ Установлен интерфейсный стаб Libbox.xcframework"

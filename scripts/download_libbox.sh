#!/usr/bin/env bash
set -e

FRAMEWORKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Frameworks"
TARGET_DIR="${FRAMEWORKS_DIR}/Libbox.xcframework"

echo "==> Настройка Libbox.xcframework..."
mkdir -p "${FRAMEWORKS_DIR}"
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
done

# If clang is present and has iOS SDK (macOS runner), compile valid Mach-O static library
if command -v xcrun &> /dev/null && xcrun --sdk iphoneos --show-sdk-path &> /dev/null; then
    echo "==> Компиляция нативного Mach-O бинарника для Libbox.xcframework..."
    SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
    TMP_OBJ=$(mktemp /tmp/libbox_stub_XXXXXX.o)

    xcrun clang -c -target arm64-apple-ios16.0 -isysroot "${SDK_PATH}" \
        -I "${TARGET_DIR}/ios-arm64/Libbox.framework/Headers" \
        -o "${TMP_OBJ}" -x objective-c - << 'EOF'
#import <Foundation/Foundation.h>
#import "Libbox.h"

@implementation LibboxCommandServer
- (int64_t)totalUpload { return 0; }
- (int64_t)totalDownload { return 0; }
- (void)close {}
@end

@implementation LibboxBoxService
- (BOOL)start:(NSError **)error { return YES; }
- (void)close {}
@end

LibboxCommandServer* LibboxNewCommandServer(id handler, int32_t maxClients, NSError** error) {
    return [[LibboxCommandServer alloc] init];
}

LibboxBoxService* LibboxNewBoxService(NSString* configContent, id platformInterface, NSError** error) {
    return [[LibboxBoxService alloc] init];
}
EOF
    xcrun ar rcs "${TARGET_DIR}/ios-arm64/Libbox.framework/Libbox" "${TMP_OBJ}"
    rm -f "${TMP_OBJ}"

    # Also build simulator stub
    SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
    TMP_SIM_OBJ=$(mktemp /tmp/libbox_sim_stub_XXXXXX.o)
    xcrun clang -c -target arm64-apple-ios16.0-simulator -isysroot "${SIM_SDK}" \
        -I "${TARGET_DIR}/ios-arm64_x86_64-simulator/Libbox.framework/Headers" \
        -o "${TMP_SIM_OBJ}" -x objective-c - << 'EOF'
#import <Foundation/Foundation.h>
#import "Libbox.h"
@implementation LibboxCommandServer
- (int64_t)totalUpload { return 0; }
- (int64_t)totalDownload { return 0; }
- (void)close {}
@end
@implementation LibboxBoxService
- (BOOL)start:(NSError **)error { return YES; }
- (void)close {}
@end
LibboxCommandServer* LibboxNewCommandServer(id handler, int32_t maxClients, NSError** error) { return [[LibboxCommandServer alloc] init]; }
LibboxBoxService* LibboxNewBoxService(NSString* configContent, id platformInterface, NSError** error) { return [[LibboxBoxService alloc] init]; }
EOF
    xcrun ar rcs "${TARGET_DIR}/ios-arm64_x86_64-simulator/Libbox.framework/Libbox" "${TMP_SIM_OBJ}"
    rm -f "${TMP_SIM_OBJ}"
    echo "✓ Нативный Mach-O бинарник собран"
else
    # Linux fallback stub
    if command -v ar &> /dev/null; then
        ar cr "${TARGET_DIR}/ios-arm64/Libbox.framework/Libbox" 2>/dev/null || touch "${TARGET_DIR}/ios-arm64/Libbox.framework/Libbox"
        ar cr "${TARGET_DIR}/ios-arm64_x86_64-simulator/Libbox.framework/Libbox" 2>/dev/null || touch "${TARGET_DIR}/ios-arm64_x86_64-simulator/Libbox.framework/Libbox"
    fi
fi

echo "✓ Libbox.xcframework готов к линковке"

#!/bin/bash
# build-xcframework.sh
# BlueSDK - 生成 XCFramework 分发包
#
# 用法：./scripts/build-xcframework.sh
# 产物：build/BlueSDK.xcframework

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
FRAMEWORK_NAME="BlueSDK"
SCHEME="BlueSDK"

echo "=== BlueSDK XCFramework 构建 ==="
echo "项目目录：$PROJECT_DIR"
echo ""

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 构建 iOS 真机（arm64）
echo "▶ 构建 iOS 真机 (arm64)..."
xcodebuild archive \
    -workspace "$PROJECT_DIR/BlueSDK/Example/BlueSDK.xcworkspace" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$BUILD_DIR/ios-device.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -5

# 构建 iOS 模拟器（arm64 + x86_64）
echo "▶ 构建 iOS 模拟器 (arm64 + x86_64)..."
xcodebuild archive \
    -workspace "$PROJECT_DIR/BlueSDK/Example/BlueSDK.xcworkspace" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$BUILD_DIR/ios-simulator.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -5

# 生成 XCFramework
echo "▶ 生成 XCFramework..."
xcodebuild -create-xcframework \
    -framework "$BUILD_DIR/ios-device.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -framework "$BUILD_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -output "$BUILD_DIR/$FRAMEWORK_NAME.xcframework"

echo ""
echo "=== 构建完成 ==="
echo "产物：$BUILD_DIR/$FRAMEWORK_NAME.xcframework"
echo "大小：$(du -sh "$BUILD_DIR/$FRAMEWORK_NAME.xcframework" | cut -f1)"
echo ""
echo "集成方式："
echo "  将 $FRAMEWORK_NAME.xcframework 拖入 Xcode 项目"
echo "  Target → General → Frameworks, Libraries → 添加"

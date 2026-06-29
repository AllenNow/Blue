#!/bin/bash
# ============================================================
# BlueSDK - 生成 XCFramework
# 使用 xcodebuild 从 Package.swift 构建，无需 workspace
#
# 用法：./scripts/build-xcframework.sh
# 产物：build/BlueSDK.xcframework
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
FRAMEWORK_NAME="BlueSDK"

echo "=== BlueSDK XCFramework 构建 ==="
echo "项目目录：$PROJECT_DIR"
echo ""

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

DERIVED_DATA="$BUILD_DIR/DerivedData"

# 构建 iOS 真机（arm64）
echo "▶ 构建 iOS 真机 (arm64)..."
xcrun xcodebuild build \
    -scheme "$FRAMEWORK_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -packagePath "$PROJECT_DIR" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    -quiet

# 构建 iOS 模拟器（arm64 + x86_64）
echo "▶ 构建 iOS 模拟器 (arm64 + x86_64)..."
xcrun xcodebuild build \
    -scheme "$FRAMEWORK_NAME" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    -packagePath "$PROJECT_DIR" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    -quiet

# 查找 framework 路径
DEVICE_FW=$(find "$DERIVED_DATA" -path "*Release-iphoneos/$FRAMEWORK_NAME.framework" -type d | head -1)
SIM_FW=$(find "$DERIVED_DATA" -path "*Release-iphonesimulator/$FRAMEWORK_NAME.framework" -type d | head -1)

if [ -z "$DEVICE_FW" ] || [ -z "$SIM_FW" ]; then
    echo "❌ Framework 未找到，尝试从 .o 构建静态库..."
    # fallback: 用 swift build 生成静态库
    echo "▶ swift build (iOS arm64)..."
    cd "$PROJECT_DIR"
    swift build -c release --triple arm64-apple-ios13.0 \
        --build-path "$BUILD_DIR/swift-build" 2>/dev/null || true
    echo "⚠️ 请在 Xcode 中打开项目手动 Archive，或使用 CocoaPods 分发"
    exit 1
fi

# 生成 XCFramework
echo "▶ 生成 XCFramework..."
xcrun xcodebuild -create-xcframework \
    -framework "$DEVICE_FW" \
    -framework "$SIM_FW" \
    -output "$BUILD_DIR/$FRAMEWORK_NAME.xcframework"

echo ""
echo "=== ✅ 构建完成 ==="
echo "产物：$BUILD_DIR/$FRAMEWORK_NAME.xcframework"
echo "大小：$(du -sh "$BUILD_DIR/$FRAMEWORK_NAME.xcframework" | cut -f1)"

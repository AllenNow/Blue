#!/bin/bash
# ============================================================
# BlueSDK Android 交付包打包脚本
# 执行后生成 delivery/ 目录，可直接交付第三方
# ============================================================

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$PROJECT_DIR/delivery"

echo "🔨 编译 Release AAR..."
cd "$PROJECT_DIR"
GRADLE_BIN=$(find ~/.gradle/wrapper/dists -name "gradle" -path "*/bin/gradle" 2>/dev/null | head -1)
if [ -z "$GRADLE_BIN" ]; then
    echo "❌ 未找到 Gradle，请先在 Android Studio 中同步一次项目"
    exit 1
fi
"$GRADLE_BIN" -p "$PROJECT_DIR" :blue-sdk:assembleRelease --quiet

echo "📦 生成交付包..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/sdk"
mkdir -p "$OUTPUT_DIR/demo"
mkdir -p "$OUTPUT_DIR/docs"

# SDK AAR
cp "$PROJECT_DIR/blue-sdk/build/outputs/aar/blue-sdk-release.aar" "$OUTPUT_DIR/sdk/"

# 文档（面向第三方，不含协议细节）
cp "$PROJECT_DIR/docs/README.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/CHANGELOG.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/PRIVACY.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/DELIVERY.md" "$OUTPUT_DIR/docs/"

# Demo 源码（去掉 build 产物和 IDE 配置）
rsync -a --exclude='build/' --exclude='.gradle/' --exclude='.idea/' \
    --exclude='*.iml' --exclude='local.properties' \
    "$PROJECT_DIR/app/" "$OUTPUT_DIR/demo/"

# 复制 gradle 配置（Demo 编译需要）
cp "$PROJECT_DIR/build.gradle.kts" "$OUTPUT_DIR/demo/"
cp "$PROJECT_DIR/settings.gradle.kts" "$OUTPUT_DIR/demo/"
cp "$PROJECT_DIR/gradle.properties" "$OUTPUT_DIR/demo/"
cp -r "$PROJECT_DIR/gradle/" "$OUTPUT_DIR/demo/gradle/"

echo ""
echo "✅ 交付包已生成：$OUTPUT_DIR"
echo ""
echo "目录结构："
echo "  delivery/"
echo "  ├── sdk/"
echo "  │   └── blue-sdk-release.aar    ← SDK 库文件"
echo "  ├── demo/"
echo "  │   └── (Demo App 完整源码)     ← 参考实现"
echo "  └── docs/"
echo "      ├── README.md               ← 集成文档"
echo "      ├── CHANGELOG.md            ← 版本记录"
echo "      ├── PRIVACY.md              ← 隐私说明"
echo "      └── DELIVERY.md             ← 交付清单+Checklist"

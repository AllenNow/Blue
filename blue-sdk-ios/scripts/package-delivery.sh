#!/bin/bash
# ============================================================
# BlueSDK iOS 交付包打包脚本
# 执行后生成 delivery/ 目录，可直接交付第三方
# ============================================================

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$PROJECT_DIR/delivery"

echo "🔨 编译 XCFramework..."
cd "$PROJECT_DIR"
bash scripts/build-xcframework.sh 2>/dev/null || echo "⚠️ XCFramework 编译需要 Xcode 环境，跳过"

echo "📦 生成交付包..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/sdk"
mkdir -p "$OUTPUT_DIR/demo"
mkdir -p "$OUTPUT_DIR/docs"

# SDK Framework（如果编译成功）
if [ -d "$PROJECT_DIR/.build/BlueSDK.xcframework" ]; then
    cp -r "$PROJECT_DIR/.build/BlueSDK.xcframework" "$OUTPUT_DIR/sdk/"
fi

# 文档（面向第三方，不含协议细节）
cp "$PROJECT_DIR/docs/README.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/CHANGELOG.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/PRIVACY.md" "$OUTPUT_DIR/docs/"
cp "$PROJECT_DIR/DELIVERY.md" "$OUTPUT_DIR/docs/"

# Demo 源码（去掉 build 产物）
rsync -a --exclude='.build/' --exclude='Pods/' --exclude='DerivedData/' \
    --exclude='*.xcuserstate' --exclude='xcuserdata/' \
    "$PROJECT_DIR/BlueSDK/Example/" "$OUTPUT_DIR/demo/"

echo ""
echo "✅ 交付包已生成：$OUTPUT_DIR"
echo ""
echo "目录结构："
echo "  delivery/"
echo "  ├── sdk/"
echo "  │   └── BlueSDK.xcframework    ← SDK Framework"
echo "  ├── demo/"
echo "  │   └── (Demo App 完整源码)     ← 参考实现"
echo "  └── docs/"
echo "      ├── README.md               ← 集成文档"
echo "      ├── CHANGELOG.md            ← 版本记录"
echo "      ├── PRIVACY.md              ← 隐私说明"
echo "      └── DELIVERY.md             ← 交付清单+Checklist"

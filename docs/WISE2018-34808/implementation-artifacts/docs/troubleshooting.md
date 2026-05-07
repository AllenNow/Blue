# Picture Viewer Troubleshooting Guide - 故障排除指南

**项目**: WISE2018-34808 - Picture Viewer  
**版本**: 1.0.0  
**最后更新**: 2026-03-05

---

## 📖 概述

本文档提供 Picture Viewer 常见问题的解决方案和调试技巧。

---

## 🐛 常见问题

### 问题 1: 图片无法加载

**症状**:
- 显示加载指示器但图片不出现
- 显示错误消息 "Failed to load image"
- 图片位置显示空白

**可能原因**:
1. 网络连接问题
2. 图片 URL 无效或过期
3. 图片服务器不可访问
4. CORS 问题（Web 平台）
5. 图片格式不支持

**解决方案**:

#### 方案 1: 检查网络连接
```dart
// 测试网络连接
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivity = await Connectivity().checkConnectivity();
if (connectivity == ConnectivityResult.none) {
  print('无网络连接');
}
```

#### 方案 2: 验证图片 URL
```dart
// 检查 URL 格式
bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    return false;
  }
}

// 使用
if (!isValidUrl(imageUrl)) {
  print('无效的图片 URL: $imageUrl');
}
```

#### 方案 3: 测试图片可访问性
```dart
Future<bool> testImageUrl(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    return response.statusCode == 200;
  } catch (e) {
    print('图片不可访问: $e');
    return false;
  }
}
```

#### 方案 4: 添加错误处理
```dart
ExtendedImage.network(
  url,
  loadStateChanged: (state) {
    if (state.extendedImageLoadState == LoadState.failed) {
      print('加载失败: ${state.lastException}');
      return Center(
        child: Column(
          children: [
            Icon(Icons.error),
            Text('加载失败'),
            ElevatedButton(
              onPressed: () => state.reLoadImage(),
              child: Text('重试'),
            ),
          ],
        ),
      );
    }
    return null;
  },
)
```

---

### 问题 2: 保存图片失败

**症状**:
- 点击保存按钮无反应
- 显示 "Failed to save image" 错误
- 权限请求对话框不出现

**可能原因**:
1. 没有相册权限
2. 权限被永久拒绝
3. 存储空间不足
4. 图片下载失败
5. 插件未正确配置

**解决方案**:

#### 方案 1: 检查权限状态
```dart
final saveService = Get.find<ImageSaveService>();

// 检查权限
final hasPermission = await saveService.hasPermission();
print('有权限: $hasPermission');

// 检查是否永久拒绝
final isPermanentlyDenied = await saveService.isPermissionPermanentlyDenied();
if (isPermanentlyDenied) {
  // 引导用户到设置
  Get.dialog(
    AlertDialog(
      title: Text('需要权限'),
      content: Text('请在设置中允许访问相册'),
      actions: [
        TextButton(
          onPressed: () => openAppSettings(),
          child: Text('打开设置'),
        ),
      ],
    ),
  );
}
```

#### 方案 2: 手动请求权限
```dart
Future<void> ensurePermission() async {
  final saveService = Get.find<ImageSaveService>();
  
  if (!await saveService.hasPermission()) {
    final status = await saveService.requestPermission();
    
    if (status.isDenied) {
      Get.snackbar('权限拒绝', '无法保存图片');
    } else if (status.isPermanentlyDenied) {
      Get.snackbar('权限拒绝', '请在设置中允许访问相册');
    } else if (status.isGranted) {
      Get.snackbar('成功', '权限已授予');
    }
  }
}
```

#### 方案 3: 检查存储空间
```dart
import 'package:disk_space/disk_space.dart';

Future<bool> hasEnoughSpace() async {
  try {
    final freeSpace = await DiskSpace.getFreeDiskSpace;
    print('剩余空间: ${freeSpace}MB');
    return freeSpace! > 10; // 至少 10MB
  } catch (e) {
    print('无法检查存储空间: $e');
    return true; // 假设有足够空间
  }
}
```

#### 方案 4: 添加详细日志
```dart
Future<void> saveImageWithLogging(String url) async {
  final saveService = Get.find<ImageSaveService>();
  
  print('开始保存图片: $url');
  
  try {
    // 检查权限
    print('检查权限...');
    if (!await saveService.hasPermission()) {
      print('请求权限...');
      final status = await saveService.requestPermission();
      print('权限状态: $status');
      
      if (!status.isGranted) {
        print('权限被拒绝');
        return;
      }
    }
    
    // 下载图片
    print('下载图片...');
    final bytes = await saveService.downloadImageWithCache(url);
    print('下载完成: ${bytes.length} bytes');
    
    // 保存到相册
    print('保存到相册...');
    final success = await saveService.saveToGallery(bytes);
    print('保存结果: $success');
    
    if (success) {
      Get.snackbar('成功', '图片已保存');
    } else {
      Get.snackbar('失败', '保存失败');
    }
  } catch (e, stackTrace) {
    print('保存失败: $e');
    print('堆栈跟踪: $stackTrace');
    Get.snackbar('错误', e.toString());
  }
}
```

---

### 问题 3: 分享功能不工作

**症状**:
- 点击分享按钮无反应
- 分享面板不出现
- 显示 "Failed to share" 错误

**可能原因**:
1. share_plus 插件未配置
2. 临时文件创建失败
3. 图片下载失败
4. iPad 未设置 sharePositionOrigin
5. 模拟器不支持分享

**解决方案**:

#### 方案 1: 检查插件配置
```yaml
# pubspec.yaml
dependencies:
  share_plus: ^10.1.2
```

```bash
# 重新获取依赖
flutter pub get

# 清理构建
flutter clean
flutter pub get
```

#### 方案 2: iPad 分享位置修复
```dart
Future<void> shareImage() async {
  try {
    // 下载图片
    final bytes = await downloadImage(url);
    
    // 保存到临时文件
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/share_image.jpg');
    await file.writeAsBytes(bytes);
    
    // iPad 需要设置分享位置
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    
    // 分享
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: sharePositionOrigin, // iPad 必需
    );
    
    // 清理
    await file.delete();
  } catch (e) {
    print('分享失败: $e');
  }
}
```

#### 方案 3: 添加分享回退方案
```dart
Future<void> shareImageWithFallback(String url) async {
  try {
    // 尝试分享文件
    await shareImageFile(url);
  } catch (e) {
    print('文件分享失败，尝试分享 URL: $e');
    
    // 回退到分享 URL
    await Share.share(
      '查看图片: $url',
      subject: '图片分享',
    );
  }
}
```

---

### 问题 4: 手势冲突

**症状**:
- 缩放不流畅
- 点击工具栏切换不工作
- 滑动切换图片失败
- 垂直滑动关闭不响应

**可能原因**:
1. 手势优先级配置错误
2. 多个 GestureDetector 冲突
3. ExtendedImage 手势配置问题

**解决方案**:

#### 方案 1: 正确配置手势优先级
```dart
GestureDetector(
  onTap: controller.toggleToolbar,
  behavior: HitTestBehavior.translucent,
  child: ExtendedImageGesturePageView.builder(
    // ExtendedImage 手势优先
    itemBuilder: (context, index) {
      return ExtendedImage.network(
        url,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: (state) {
          return GestureConfig(
            minScale: 0.5,
            maxScale: 3.0,
            animationMinScale: 0.3,
            animationMaxScale: 5.0,
            speed: 1.0,
            inertialSpeed: 100.0,
            initialScale: 1.0,
            inPageView: true, // 重要：在 PageView 中
          );
        },
      );
    },
  ),
)
```

#### 方案 2: 禁用冲突手势
```dart
// 在缩放时禁用页面切换
ExtendedImageGesturePageView.builder(
  physics: controller.isZoomed.value 
      ? NeverScrollableScrollPhysics() 
      : PageScrollPhysics(),
  // ...
)
```

---

### 问题 5: 内存泄漏

**症状**:
- 应用内存持续增长
- 多次打开查看器后变慢
- 应用崩溃（OOM）

**可能原因**:
1. 图片缓存未限制
2. 控制器未正确释放
3. 监听器未取消
4. 大图片未压缩

**解决方案**:

#### 方案 1: 限制图片缓存大小
```dart
ExtendedImage.network(
  url,
  cache: true,
  cacheWidth: 1080,  // 限制宽度
  cacheHeight: 1920, // 限制高度
)
```

#### 方案 2: 确保资源清理
```dart
class ImageViewerController extends GetxController {
  @override
  void onClose() {
    // 清理 PageController
    pageController.dispose();
    
    // 清理图片缓存（可选）
    images.clear();
    rotationAngles.clear();
    
    super.onClose();
  }
}
```

#### 方案 3: 使用 RepaintBoundary
```dart
RepaintBoundary(
  child: ExtendedImage.network(url),
)
```

#### 方案 4: 监控内存使用
```dart
import 'dart:developer' as developer;

void logMemoryUsage() {
  developer.Timeline.startSync('Memory Check');
  
  // 触发 GC
  developer.Timeline.finishSync();
  
  print('Memory usage logged');
}
```

---

### 问题 6: 旋转后图片模糊

**症状**:
- 旋转后图片质量下降
- 图片边缘锯齿
- 旋转动画卡顿

**可能原因**:
1. 使用了低质量的变换
2. 抗锯齿未启用
3. 图片分辨率不足

**解决方案**:

#### 方案 1: 使用高质量变换
```dart
Transform.rotate(
  angle: rotationAngle * pi / 180,
  filterQuality: FilterQuality.high, // 高质量
  child: ExtendedImage.network(url),
)
```

#### 方案 2: 使用 AnimatedRotation
```dart
AnimatedRotation(
  turns: rotationAngle / 360,
  duration: Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  filterQuality: FilterQuality.high,
  child: ExtendedImage.network(url),
)
```

---

### 问题 7: Hero 动画不流畅

**症状**:
- 打开查看器时动画卡顿
- Hero 动画不出现
- 图片闪烁

**可能原因**:
1. Hero 标签不匹配
2. 图片尺寸差异太大
3. 缓存未命中

**解决方案**:

#### 方案 1: 确保 Hero 标签一致
```dart
// 聊天界面
Hero(
  tag: 'hero_${message.id}',
  child: Image.network(url),
)

// 查看器
Hero(
  tag: 'hero_${message.id}', // 必须相同
  child: ExtendedImage.network(url),
)
```

#### 方案 2: 使用 FadeTransition
```dart
Hero(
  tag: heroTag,
  flightShuttleBuilder: (
    flightContext,
    animation,
    flightDirection,
    fromHeroContext,
    toHeroContext,
  ) {
    return FadeTransition(
      opacity: animation,
      child: toHeroContext.widget,
    );
  },
  child: ExtendedImage.network(url),
)
```

---

## 🔍 调试技巧

### 技巧 1: 启用详细日志

```dart
// 在 main.dart 中
void main() {
  // 启用 Flutter 日志
  debugPrintGestureArenaDiagnostics = true;
  debugPrintHitTestResults = true;
  
  runApp(MyApp());
}

// 在 ImageViewerController 中
class ImageViewerController extends GetxController {
  static const bool _debug = true;
  
  void _log(String message) {
    if (_debug) {
      print('[ImageViewer] $message');
    }
  }
  
  @override
  void onInit() {
    super.onInit();
    _log('Controller initialized');
  }
  
  void nextImage() {
    _log('Next image: ${currentIndex.value} -> ${currentIndex.value + 1}');
    // ...
  }
}
```

---

### 技巧 2: 使用 Flutter DevTools

```bash
# 启动应用
flutter run

# 打开 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**检查项目**:
- Performance: 查看帧率和渲染时间
- Memory: 监控内存使用和泄漏
- Network: 查看图片下载请求
- Logging: 查看应用日志

---

### 技巧 3: 性能分析

```dart
import 'dart:developer' as developer;

Future<void> saveImageWithProfiling() async {
  developer.Timeline.startSync('Save Image');
  
  try {
    await controller.saveImage();
  } finally {
    developer.Timeline.finishSync();
  }
}
```

---

### 技巧 4: 网络请求调试

```dart
class DebugHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('Request: ${request.method} ${request.url}');
    
    final response = await _inner.send(request);
    
    print('Response: ${response.statusCode}');
    print('Headers: ${response.headers}');
    
    return response;
  }
}

// 使用
final saveService = ImageSaveService(
  httpClient: DebugHttpClient(),
);
```

---

## 📱 平台特定问题

### iOS 问题

#### 问题: 权限请求不出现
**解决方案**: 检查 Info.plist 配置
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要访问相册以保存图片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册以保存图片</string>
```

#### 问题: 分享面板位置错误
**解决方案**: 设置 sharePositionOrigin（见问题 3）

---

### Android 问题

#### 问题: Android 11+ 保存失败
**解决方案**: 使用 Scoped Storage
```xml
<!-- AndroidManifest.xml -->
<application
    android:requestLegacyExternalStorage="true">
</application>
```

#### 问题: 权限请求循环
**解决方案**: 检查权限配置
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## 🆘 获取帮助

### 报告问题

创建 GitHub Issue 时请包含:

1. **问题描述**: 详细描述问题
2. **复现步骤**: 如何触发问题
3. **预期行为**: 应该发生什么
4. **实际行为**: 实际发生了什么
5. **环境信息**:
   - Flutter 版本
   - Dart 版本
   - 设备型号
   - 操作系统版本
6. **日志输出**: 相关错误日志
7. **代码示例**: 最小复现代码

### 示例 Issue

```markdown
## 问题描述
保存图片时应用崩溃

## 复现步骤
1. 打开图片查看器
2. 点击保存按钮
3. 应用崩溃

## 预期行为
图片应该保存到相册

## 实际行为
应用崩溃并显示错误

## 环境信息
- Flutter: 3.16.0
- Dart: 3.2.0
- 设备: iPhone 14 Pro
- iOS: 17.0

## 日志输出
```
[ERROR] Failed to save image: ...
```

## 代码示例
```dart
await controller.saveImage();
```
```

---

## 📚 相关文档

- [Feature Overview](./picture-viewer-feature.md) - 功能概述
- [Architecture Documentation](./architecture.md) - 架构设计
- [API Documentation](./api-documentation.md) - API 参考
- [Usage Examples](./usage-examples.md) - 使用示例

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-05  
**维护者**: allen

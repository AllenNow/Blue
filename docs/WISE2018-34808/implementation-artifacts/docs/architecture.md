# Picture Viewer Architecture - 架构文档

**项目**: WISE2018-34808 - Picture Viewer  
**版本**: 1.0.0  
**最后更新**: 2026-03-05

---

## 📐 架构概览

Picture Viewer 采用 MVC (Model-View-Controller) 架构模式，结合 GetX 状态管理，实现清晰的职责分离和高效的状态管理。

---

## 🏗️ 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        Chat Interface                        │
│                    (SdkChatDetailPage)                      │
└────────────────────┬────────────────────────────────────────┘
                     │ User taps image
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                    Navigation Layer                          │
│                      (GetX Router)                          │
└────────────────────┬────────────────────────────────────────┘
                     │ Route to ImageViewerPage
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   ImageViewerPage (View)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ImageViewerTopBar                        │  │
│  │         (Close button + Image counter)                │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         ExtendedImageGesturePageView                  │  │
│  │    (Zoom, Pan, Swipe, Rotate, Drag gestures)         │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │             ImageViewerBottomBar                      │  │
│  │      (Save, Share, Rotate action buttons)             │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │ User actions
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              ImageViewerController (Controller)             │
│  • State Management (GetX)                                  │
│  • Navigation Logic                                         │
│  • Action Handlers (save, share, rotate)                   │
└────────────────────┬────────────────────────────────────────┘
                     │ Calls services
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ ImageSaveService │  │  Share Service   │                │
│  │  • Download      │  │  • Share files   │                │
│  │  • Permissions   │  │  • Temp cleanup  │                │
│  │  • Save gallery  │  └──────────────────┘                │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ImageViewerItem   │  │ ImageMessageHelper│               │
│  │  (Model)         │  │   (Utility)       │               │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧩 组件说明

### 1. View Layer (视图层)

#### ImageViewerPage
**职责**: 主页面容器，管理整体布局和手势

**功能**:
- 全屏黑色背景
- ExtendedImageGesturePageView 集成
- 手势检测（点击切换工具栏、垂直滑动关闭）
- 系统 UI 管理（隐藏状态栏）
- Hero 动画支持

**关键代码**:
```dart
class ImageViewerPage extends GetView<ImageViewerController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: controller.toggleToolbar,
        child: Stack(
          children: [
            _buildImagePageView(),
            _buildTopBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
}
```

#### ImageViewerTopBar
**职责**: 顶部工具栏，显示关闭按钮和图片计数

**功能**:
- 关闭按钮（返回聊天界面）
- 图片计数器（如 "3/10"）
- 渐变背景（黑色到透明）
- 响应式显示/隐藏
- Safe Area 支持

#### ImageViewerBottomBar
**职责**: 底部工具栏，提供操作按钮

**功能**:
- 保存按钮（带加载状态）
- 分享按钮
- 旋转按钮
- 渐变背景
- 响应式显示/隐藏
- Safe Area 支持

### 2. Controller Layer (控制器层)

#### ImageViewerController
**职责**: 状态管理和业务逻辑

**状态管理**:
```dart
class ImageViewerController extends GetxController {
  // Observable state
  final images = <ImageViewerItem>[].obs;
  final currentIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isSharing = false.obs;
  final error = Rxn<String>();
  final showToolbar = true.obs;
  final rotationAngles = <int, double>{}.obs;
  
  // Controllers
  late ExtendedPageController pageController;
}
```

**核心方法**:
- `nextImage()` / `previousImage()` - 图片导航
- `jumpToImage(index)` - 跳转到指定图片
- `saveImage()` - 保存图片到相册
- `shareImage()` - 分享图片
- `rotateImage()` - 旋转图片
- `toggleToolbar()` - 切换工具栏显示

### 3. Service Layer (服务层)

#### ImageSaveService
**职责**: 图片下载和保存

**功能**:
- 权限检查和请求
- 图片下载（带缓存优化）
- 保存到相册
- 错误处理
- 资源清理

**关键方法**:
```dart
class ImageSaveService {
  Future<bool> hasPermission();
  Future<PermissionStatus> requestPermission();
  Future<Uint8List> downloadImage(String url);
  Future<Uint8List?> getImageFromCache(String url);
  Future<bool> saveToGallery(Uint8List imageBytes);
  Future<SaveImageResult> saveImage(String imageUrl);
}
```

#### Share Service (share_plus)
**职责**: 系统分享集成

**功能**:
- 临时文件创建
- 系统分享面板调用
- 文件清理

### 4. Data Layer (数据层)

#### ImageViewerItem
**职责**: 图片数据模型

**属性**:
```dart
class ImageViewerItem {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? senderName;
  final DateTime timestamp;
  final String? heroTag;
  
  // Computed properties
  String get formattedTimestamp;
  double? get aspectRatio;
  bool get hasThumbnail;
}
```

#### ImageMessageHelper
**职责**: 图片消息处理工具

**功能**:
- 从消息列表提取图片
- 查找图片索引
- 过滤图片消息
- 验证图片消息

---

## 🔄 数据流

### 1. 打开图片查看器

```
User taps image in chat
  ↓
ImageMessageBubble.onTap()
  ↓
SdkChatDetailController.openImageViewer(message)
  ↓
ImageMessageHelper.extractImages(messages)
  ↓
ImageMessageHelper.findImageIndex(images, messageId)
  ↓
Get.toNamed(SdkRoutes.imageViewer, arguments: {...})
  ↓
ImageViewerPage created
  ↓
ImageViewerController initialized
  ↓
Images displayed
```

### 2. 保存图片

```
User taps save button
  ↓
ImageViewerController.saveImage()
  ↓
Set isSaving = true
  ↓
ImageSaveService.saveImage(url)
  ↓
Check/request permission
  ↓
Download image (cache-first)
  ↓
Save to gallery
  ↓
Show success/error snackbar
  ↓
Set isSaving = false
```

### 3. 分享图片

```
User taps share button
  ↓
ImageViewerController.shareImage()
  ↓
Set isSharing = true
  ↓
Download image to temp file
  ↓
Share.shareXFiles([tempFile])
  ↓
System share sheet opens
  ↓
User completes share
  ↓
Delete temp file
  ↓
Set isSharing = false
```

### 4. 旋转图片

```
User taps rotate button
  ↓
ImageViewerController.rotateImage()
  ↓
Get current rotation angle
  ↓
Increment by 90°
  ↓
Update rotationAngles[currentIndex]
  ↓
UI rebuilds with new rotation
  ↓
Animate rotation (200ms)
```

---

## 🎯 状态管理

### GetX 响应式状态

Picture Viewer 使用 GetX 的响应式状态管理：

```dart
// Observable state
final images = <ImageViewerItem>[].obs;
final currentIndex = 0.obs;

// Reactive UI
Obx(() => Text('${controller.currentIndex.value + 1}/${controller.images.length}'))
```

**优势**:
- 自动 UI 更新
- 最小化重建
- 简洁的语法
- 高性能

### 状态生命周期

```
Controller Created (onInit)
  ↓
Initialize state
  ↓
Create PageController
  ↓
Preload adjacent images
  ↓
Controller Ready
  ↓
User interactions
  ↓
State updates
  ↓
UI rebuilds
  ↓
Controller Disposed (onClose)
  ↓
Cleanup resources
```

---

## 🔌 依赖注入

### GetX DI 模式

```dart
// Service registration (SDK Initializer)
Get.put(ImageSaveService(), permanent: true);

// Controller binding (automatic)
class ImageViewerPage extends GetView<ImageViewerController> {
  // Controller auto-injected
}

// Service access
final saveService = Get.find<ImageSaveService>();
```

**优势**:
- 单例模式
- 懒加载
- 自动清理
- 易于测试

---

## 🧪 测试架构

### 测试金字塔

```
        ┌─────────────┐
        │ Integration │  12 tests
        │   Tests     │  (Complete flows)
        └─────────────┘
       ┌───────────────┐
       │ Widget Tests  │  55 tests
       │  (UI Tests)   │  (Component behavior)
       └───────────────┘
      ┌─────────────────┐
      │  Unit Tests     │  74 tests
      │ (Logic Tests)   │  (Business logic)
      └─────────────────┘
```

### 测试策略

**Unit Tests** (74 tests):
- Models: 数据转换、验证
- Controllers: 状态管理、业务逻辑
- Services: 网络请求、文件操作
- Utilities: 辅助函数

**Widget Tests** (55 tests):
- Pages: 页面结构、交互
- Widgets: 组件渲染、事件
- Accessibility: 语义标签

**Integration Tests** (12 tests):
- Complete flows: 端到端场景
- Error scenarios: 异常处理
- Performance: 性能验证

---

## 🚀 性能优化

### 1. 图片加载优化

**缓存策略**:
```dart
ExtendedImage.network(
  url,
  cache: true,
  cacheWidth: 1080,  // Limit memory
  cacheHeight: 1920,
)
```

**预加载**:
```dart
void _preloadAdjacentImages() {
  if (currentIndex > 0) {
    precacheImage(NetworkImage(images[currentIndex - 1].imageUrl), context);
  }
  if (currentIndex < images.length - 1) {
    precacheImage(NetworkImage(images[currentIndex + 1].imageUrl), context);
  }
}
```

**缓存优先下载**:
```dart
Future<Uint8List> downloadImageWithCache(String url) async {
  // Try cache first (0.3s)
  final cachedBytes = await getImageFromCache(url);
  if (cachedBytes != null) return cachedBytes;
  
  // Fallback to network (3-6s)
  return await downloadImage(url);
}
```

### 2. 渲染优化

**RepaintBoundary**:
```dart
RepaintBoundary(
  child: ExtendedImage.network(url),
)
```

**最小化重建**:
```dart
Obx(() => controller.showToolbar.value 
  ? ImageViewerTopBar() 
  : SizedBox.shrink()
)
```

### 3. 内存优化

- 限制缓存图片尺寸
- 及时释放资源
- 避免内存泄漏

---

## 🔐 安全考虑

### 1. 权限管理
- 运行时权限请求
- 权限拒绝处理
- 永久拒绝引导

### 2. 网络安全
- HTTPS 验证
- 超时处理
- 错误重试

### 3. 文件安全
- 临时文件清理
- 路径验证
- 权限检查

---

## 📈 可扩展性

### 1. 新增功能
- 插件化设计
- 接口抽象
- 依赖注入

### 2. 自定义配置
```dart
ImageViewerConfig(
  maxZoomScale: 5.0,
  minZoomScale: 0.3,
  animationDuration: Duration(milliseconds: 300),
  backgroundColor: Colors.black,
)
```

### 3. 主题定制
- 颜色方案
- 图标样式
- 动画效果

---

## 🔧 技术决策

### 1. 为什么选择 ExtendedImage？
- 功能完整（缩放、平移、旋转）
- 性能优秀（缓存、预加载）
- 手势支持完善
- 社区活跃

### 2. 为什么选择 GetX？
- 轻量级（无需 context）
- 高性能（最小化重建）
- 易用性（简洁语法）
- 功能完整（状态管理 + 路由 + DI）

### 3. 为什么使用 Plain Dart Class？
- 避免 Freezed 兼容性问题
- 简化代码生成
- 提高可维护性
- 减少依赖

---

## 📚 相关文档

- [Feature Overview](./picture-viewer-feature.md) - 功能概述
- [API Documentation](./api-documentation.md) - API 参考
- [Usage Examples](./usage-examples.md) - 使用示例
- [Troubleshooting Guide](./troubleshooting.md) - 故障排除

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-05  
**维护者**: allen
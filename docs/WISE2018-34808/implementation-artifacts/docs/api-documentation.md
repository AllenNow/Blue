# Picture Viewer API Documentation - API 参考

**项目**: WISE2018-34808 - Picture Viewer  
**版本**: 1.0.0  
**最后更新**: 2026-03-05

---

## 📖 概述

本文档提供 Picture Viewer 所有公共 API 的详细说明，包括类、方法、参数和返回值。

---

## 🎯 核心 API

### ImageViewerController

图片查看器控制器，管理状态和业务逻辑。

#### 构造函数

```dart
ImageViewerController({
  List<ImageViewerItem>? initialImages,
  int initialIndex = 0,
})
```

**参数**:
- `initialImages` (可选): 初始图片列表
- `initialIndex` (可选): 初始显示的图片索引，默认 0

**示例**:
```dart
final controller = ImageViewerController(
  initialImages: imageList,
  initialIndex: 2,
);
```

---

#### 属性

##### images
```dart
RxList<ImageViewerItem> images
```
**说明**: 图片列表（响应式）  
**类型**: `RxList<ImageViewerItem>`  
**访问**: 只读

##### currentIndex
```dart
RxInt currentIndex
```
**说明**: 当前图片索引（响应式）  
**类型**: `RxInt`  
**访问**: 只读

##### isLoading
```dart
RxBool isLoading
```
**说明**: 是否正在加载（响应式）  
**类型**: `RxBool`  
**访问**: 只读

##### isSaving
```dart
RxBool isSaving
```
**说明**: 是否正在保存（响应式）  
**类型**: `RxBool`  
**访问**: 只读

##### isSharing
```dart
RxBool isSharing
```
**说明**: 是否正在分享（响应式）  
**类型**: `RxBool`  
**访问**: 只读

##### showToolbar
```dart
RxBool showToolbar
```
**说明**: 是否显示工具栏（响应式）  
**类型**: `RxBool`  
**访问**: 只读

##### error
```dart
Rxn<String> error
```
**说明**: 错误消息（响应式，可为 null）  
**类型**: `Rxn<String>`  
**访问**: 只读

##### rotationAngles
```dart
RxMap<int, double> rotationAngles
```
**说明**: 每张图片的旋转角度（响应式）  
**类型**: `RxMap<int, double>`  
**访问**: 只读

##### pageController
```dart
ExtendedPageController pageController
```
**说明**: 页面控制器  
**类型**: `ExtendedPageController`  
**访问**: 只读

---

#### 方法

##### initialize()
```dart
void initialize({
  required List<ImageViewerItem> images,
  int initialIndex = 0,
})
```
**说明**: 初始化控制器

**参数**:
- `images` (必需): 图片列表
- `initialIndex` (可选): 初始索引，默认 0

**示例**:
```dart
controller.initialize(
  images: imageList,
  initialIndex: 2,
);
```

---

##### nextImage()
```dart
void nextImage()
```
**说明**: 切换到下一张图片

**示例**:
```dart
controller.nextImage();
```

---

##### previousImage()
```dart
void previousImage()
```
**说明**: 切换到上一张图片

**示例**:
```dart
controller.previousImage();
```

---

##### jumpToImage()
```dart
void jumpToImage(int index)
```
**说明**: 跳转到指定索引的图片

**参数**:
- `index` (必需): 目标图片索引

**异常**:
- 如果索引超出范围，不执行任何操作

**示例**:
```dart
controller.jumpToImage(5);
```

---

##### onPageChanged()
```dart
void onPageChanged(int index)
```
**说明**: 页面切换回调

**参数**:
- `index` (必需): 新的页面索引

**注意**: 通常由 PageView 自动调用，不需要手动调用

---

##### saveImage()
```dart
Future<void> saveImage()
```
**说明**: 保存当前图片到相册

**返回**: `Future<void>`

**副作用**:
- 设置 `isSaving` 为 true
- 请求权限（如需要）
- 下载并保存图片
- 显示成功/失败提示
- 设置 `isSaving` 为 false

**示例**:
```dart
await controller.saveImage();
```

---

##### shareImage()
```dart
Future<void> shareImage()
```
**说明**: 分享当前图片

**返回**: `Future<void>`

**副作用**:
- 设置 `isSharing` 为 true
- 下载图片到临时文件
- 打开系统分享面板
- 清理临时文件
- 设置 `isSharing` 为 false

**示例**:
```dart
await controller.shareImage();
```

---

##### rotateImage()
```dart
void rotateImage()
```
**说明**: 旋转当前图片 90° 顺时针

**副作用**:
- 更新 `rotationAngles[currentIndex]`
- 触发 UI 重建

**示例**:
```dart
controller.rotateImage();
```

---

##### toggleToolbar()
```dart
void toggleToolbar()
```
**说明**: 切换工具栏显示/隐藏

**副作用**:
- 切换 `showToolbar` 值
- 触发 UI 重建

**示例**:
```dart
controller.toggleToolbar();
```

---

##### getCurrentRotation()
```dart
double getCurrentRotation()
```
**说明**: 获取当前图片的旋转角度

**返回**: `double` - 旋转角度（度）

**示例**:
```dart
final rotation = controller.getCurrentRotation();
print('Current rotation: $rotation°');
```

---

### ImageViewerItem

图片数据模型。

#### 构造函数

```dart
ImageViewerItem({
  required this.id,
  required this.imageUrl,
  this.thumbnailUrl,
  this.senderName,
  required this.timestamp,
  this.heroTag,
})
```

**参数**:
- `id` (必需): 图片唯一标识
- `imageUrl` (必需): 图片 URL
- `thumbnailUrl` (可选): 缩略图 URL
- `senderName` (可选): 发送者名称
- `timestamp` (必需): 时间戳
- `heroTag` (可选): Hero 动画标签

**示例**:
```dart
final item = ImageViewerItem(
  id: 'msg_123',
  imageUrl: 'https://example.com/image.jpg',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  senderName: 'John Doe',
  timestamp: DateTime.now(),
  heroTag: 'hero_msg_123',
);
```

---

#### 工厂构造函数

##### fromMessage()
```dart
factory ImageViewerItem.fromMessage(SdkMessage message)
```
**说明**: 从聊天消息创建图片项

**参数**:
- `message` (必需): SDK 消息对象

**返回**: `ImageViewerItem`

**异常**:
- 如果消息不是图片类型，抛出 `ArgumentError`

**示例**:
```dart
final item = ImageViewerItem.fromMessage(message);
```

---

#### 属性

##### id
```dart
final String id
```
**说明**: 图片唯一标识  
**类型**: `String`

##### imageUrl
```dart
final String imageUrl
```
**说明**: 图片 URL  
**类型**: `String`

##### thumbnailUrl
```dart
final String? thumbnailUrl
```
**说明**: 缩略图 URL（可选）  
**类型**: `String?`

##### senderName
```dart
final String? senderName
```
**说明**: 发送者名称（可选）  
**类型**: `String?`

##### timestamp
```dart
final DateTime timestamp
```
**说明**: 时间戳  
**类型**: `DateTime`

##### heroTag
```dart
final String? heroTag
```
**说明**: Hero 动画标签（可选）  
**类型**: `String?`

---

#### 计算属性

##### formattedTimestamp
```dart
String get formattedTimestamp
```
**说明**: 格式化的时间戳字符串  
**返回**: `String` - 格式: "yyyy-MM-dd HH:mm"

**示例**:
```dart
print(item.formattedTimestamp); // "2026-03-05 14:30"
```

##### aspectRatio
```dart
double? get aspectRatio
```
**说明**: 图片宽高比（如果可用）  
**返回**: `double?` - 宽高比或 null

##### hasThumbnail
```dart
bool get hasThumbnail
```
**说明**: 是否有缩略图  
**返回**: `bool`

**示例**:
```dart
if (item.hasThumbnail) {
  // Load thumbnail first
}
```

---

#### 方法

##### copyWith()
```dart
ImageViewerItem copyWith({
  String? id,
  String? imageUrl,
  String? thumbnailUrl,
  String? senderName,
  DateTime? timestamp,
  String? heroTag,
})
```
**说明**: 创建副本并修改指定字段

**参数**: 所有参数可选，未指定的保持原值

**返回**: `ImageViewerItem` - 新的实例

**示例**:
```dart
final updated = item.copyWith(
  senderName: 'Jane Doe',
);
```

---

##### toJson()
```dart
Map<String, dynamic> toJson()
```
**说明**: 转换为 JSON 对象

**返回**: `Map<String, dynamic>`

**示例**:
```dart
final json = item.toJson();
print(json);
```

---

##### fromJson()
```dart
factory ImageViewerItem.fromJson(Map<String, dynamic> json)
```
**说明**: 从 JSON 对象创建实例

**参数**:
- `json` (必需): JSON 对象

**返回**: `ImageViewerItem`

**示例**:
```dart
final item = ImageViewerItem.fromJson(jsonData);
```

---

### ImageSaveService

图片保存服务。

#### 构造函数

```dart
ImageSaveService({
  http.Client? httpClient,
  this.timeout = const Duration(seconds: 30),
})
```

**参数**:
- `httpClient` (可选): HTTP 客户端，默认创建新实例
- `timeout` (可选): 超时时长，默认 30 秒

**示例**:
```dart
final service = ImageSaveService(
  timeout: Duration(seconds: 60),
);
```

---

#### 方法

##### hasPermission()
```dart
Future<bool> hasPermission()
```
**说明**: 检查是否有相册权限

**返回**: `Future<bool>` - true 表示有权限

**示例**:
```dart
final hasPermission = await service.hasPermission();
```

---

##### requestPermission()
```dart
Future<PermissionStatus> requestPermission()
```
**说明**: 请求相册权限

**返回**: `Future<PermissionStatus>` - 权限状态

**示例**:
```dart
final status = await service.requestPermission();
if (status.isGranted) {
  // Permission granted
}
```

---

##### isPermissionPermanentlyDenied()
```dart
Future<bool> isPermissionPermanentlyDenied()
```
**说明**: 检查权限是否被永久拒绝

**返回**: `Future<bool>` - true 表示永久拒绝

**示例**:
```dart
if (await service.isPermissionPermanentlyDenied()) {
  // Guide user to settings
}
```

---

##### downloadImage()
```dart
Future<Uint8List> downloadImage(String url)
```
**说明**: 从 URL 下载图片

**参数**:
- `url` (必需): 图片 URL

**返回**: `Future<Uint8List>` - 图片数据

**异常**:
- `Exception` - 下载失败或超时

**示例**:
```dart
try {
  final bytes = await service.downloadImage(imageUrl);
} catch (e) {
  print('Download failed: $e');
}
```

---

##### getImageFromCache()
```dart
Future<Uint8List?> getImageFromCache(String url)
```
**说明**: 从缓存获取图片

**参数**:
- `url` (必需): 图片 URL

**返回**: `Future<Uint8List?>` - 图片数据或 null

**示例**:
```dart
final cachedBytes = await service.getImageFromCache(imageUrl);
if (cachedBytes != null) {
  // Use cached image
}
```

---

##### downloadImageWithCache()
```dart
Future<Uint8List> downloadImageWithCache(String url)
```
**说明**: 优先从缓存获取，缓存未命中则下载

**参数**:
- `url` (必需): 图片 URL

**返回**: `Future<Uint8List>` - 图片数据

**示例**:
```dart
final bytes = await service.downloadImageWithCache(imageUrl);
```

---

##### saveToGallery()
```dart
Future<bool> saveToGallery(
  Uint8List imageBytes, {
  String? name,
})
```
**说明**: 保存图片到相册

**参数**:
- `imageBytes` (必需): 图片数据
- `name` (可选): 文件名

**返回**: `Future<bool>` - true 表示保存成功

**示例**:
```dart
final success = await service.saveToGallery(
  imageBytes,
  name: 'my_image',
);
```

---

##### saveImage()
```dart
Future<SaveImageResult> saveImage(String imageUrl)
```
**说明**: 完整的保存流程（权限 + 下载 + 保存）

**参数**:
- `imageUrl` (必需): 图片 URL

**返回**: `Future<SaveImageResult>` - 保存结果

**示例**:
```dart
final result = await service.saveImage(imageUrl);
if (result.success) {
  print('Image saved successfully');
} else if (result.permissionDenied) {
  print('Permission denied');
} else {
  print('Error: ${result.error}');
}
```

---

##### dispose()
```dart
void dispose()
```
**说明**: 释放资源

**示例**:
```dart
service.dispose();
```

---

### SaveImageResult

保存结果类。

#### 工厂构造函数

##### success()
```dart
factory SaveImageResult.success()
```
**说明**: 创建成功结果

**返回**: `SaveImageResult`

##### failed()
```dart
factory SaveImageResult.failed(String error)
```
**说明**: 创建失败结果

**参数**:
- `error` (必需): 错误消息

**返回**: `SaveImageResult`

##### permissionDenied()
```dart
factory SaveImageResult.permissionDenied()
```
**说明**: 创建权限拒绝结果

**返回**: `SaveImageResult`

---

#### 属性

##### success
```dart
final bool success
```
**说明**: 是否成功  
**类型**: `bool`

##### error
```dart
final String? error
```
**说明**: 错误消息（如果失败）  
**类型**: `String?`

##### permissionDenied
```dart
final bool permissionDenied
```
**说明**: 是否因权限拒绝失败  
**类型**: `bool`

---

### ImageMessageHelper

图片消息辅助工具类（静态方法）。

#### 方法

##### extractImages()
```dart
static List<ImageViewerItem> extractImages(List<SdkMessage> messages)
```
**说明**: 从消息列表提取图片

**参数**:
- `messages` (必需): 消息列表

**返回**: `List<ImageViewerItem>` - 图片列表

**示例**:
```dart
final images = ImageMessageHelper.extractImages(messages);
```

---

##### findImageIndex()
```dart
static int findImageIndex(
  List<ImageViewerItem> images,
  String messageId,
)
```
**说明**: 查找图片索引

**参数**:
- `images` (必需): 图片列表
- `messageId` (必需): 消息 ID

**返回**: `int` - 索引，未找到返回 -1

**示例**:
```dart
final index = ImageMessageHelper.findImageIndex(images, messageId);
```

---

##### filterImageMessages()
```dart
static List<SdkMessage> filterImageMessages(List<SdkMessage> messages)
```
**说明**: 过滤出图片消息

**参数**:
- `messages` (必需): 消息列表

**返回**: `List<SdkMessage>` - 图片消息列表

**示例**:
```dart
final imageMessages = ImageMessageHelper.filterImageMessages(messages);
```

---

##### isImageMessage()
```dart
static bool isImageMessage(SdkMessage message)
```
**说明**: 判断是否为图片消息

**参数**:
- `message` (必需): 消息对象

**返回**: `bool` - true 表示是图片消息

**示例**:
```dart
if (ImageMessageHelper.isImageMessage(message)) {
  // Handle image message
}
```

---

##### getImageCount()
```dart
static int getImageCount(List<SdkMessage> messages)
```
**说明**: 获取图片消息数量

**参数**:
- `messages` (必需): 消息列表

**返回**: `int` - 图片数量

**示例**:
```dart
final count = ImageMessageHelper.getImageCount(messages);
```

---

##### getImagePositionBefore()
```dart
static int getImagePositionBefore(
  List<SdkMessage> messages,
  String messageId,
)
```
**说明**: 获取指定消息之前的图片数量

**参数**:
- `messages` (必需): 消息列表
- `messageId` (必需): 消息 ID

**返回**: `int` - 图片数量

**示例**:
```dart
final position = ImageMessageHelper.getImagePositionBefore(messages, messageId);
```

---

##### hasImages()
```dart
static bool hasImages(List<SdkMessage> messages)
```
**说明**: 判断是否包含图片消息

**参数**:
- `messages` (必需): 消息列表

**返回**: `bool` - true 表示包含图片

**示例**:
```dart
if (ImageMessageHelper.hasImages(messages)) {
  // Show image viewer button
}
```

---

##### hasNoImages()
```dart
static bool hasNoImages(List<SdkMessage> messages)
```
**说明**: 判断是否不包含图片消息

**参数**:
- `messages` (必需): 消息列表

**返回**: `bool` - true 表示不包含图片

**示例**:
```dart
if (ImageMessageHelper.hasNoImages(messages)) {
  // Hide image viewer button
}
```

---

## 🚀 路由 API

### 打开图片查看器

```dart
Get.toNamed(
  SdkRoutes.imageViewer,
  arguments: {
    'images': List<ImageViewerItem>,
    'initialIndex': int,
  },
)
```

**参数**:
- `images` (必需): 图片列表
- `initialIndex` (可选): 初始索引，默认 0

**示例**:
```dart
Get.toNamed(
  SdkRoutes.imageViewer,
  arguments: {
    'images': imageList,
    'initialIndex': 2,
  },
);
```

---

## 📚 相关文档

- [Feature Overview](./picture-viewer-feature.md) - 功能概述
- [Architecture Documentation](./architecture.md) - 架构设计
- [Usage Examples](./usage-examples.md) - 使用示例
- [Troubleshooting Guide](./troubleshooting.md) - 故障排除

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-05  
**维护者**: allen

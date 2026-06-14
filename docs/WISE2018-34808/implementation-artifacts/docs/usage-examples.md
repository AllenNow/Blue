# Picture Viewer Usage Examples - 使用示例

**项目**: WISE2018-34808 - Picture Viewer  
**版本**: 1.0.0  
**最后更新**: 2026-03-05

---

## 📖 概述

本文档提供 Picture Viewer 的实际使用示例，涵盖基本用法、高级用法和常见场景。

---

## 🚀 基本用法

### 示例 1: 从聊天消息打开图片查看器

这是最常见的使用场景，用户点击聊天中的图片消息。

```dart
// 在 SdkChatDetailController 中
void openImageViewer(SdkMessage message) {
  // 1. 提取所有图片消息
  final images = ImageMessageHelper.extractImages(messages);
  
  // 2. 查找当前图片的索引
  final index = ImageMessageHelper.findImageIndex(
    images,
    message.id,
  );
  
  // 3. 打开图片查看器
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': images,
      'initialIndex': index,
    },
  );
}
```

**说明**:
- 自动提取聊天中的所有图片
- 定位到用户点击的图片
- 支持左右滑动浏览其他图片

---

### 示例 2: 直接打开单张图片

如果只需要查看单张图片，不需要浏览多张。

```dart
void openSingleImage(String imageUrl) {
  final image = ImageViewerItem(
    id: 'single_image',
    imageUrl: imageUrl,
    timestamp: DateTime.now(),
  );
  
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': [image],
      'initialIndex': 0,
    },
  );
}
```

**说明**:
- 只传入一张图片
- 图片计数器会自动隐藏（单张图片时）
- 左右滑动无效（只有一张）

---

### 示例 3: 打开图片列表

从任意图片列表打开查看器。

```dart
void openImageGallery(List<String> imageUrls, int startIndex) {
  // 转换 URL 列表为 ImageViewerItem 列表
  final images = imageUrls.asMap().entries.map((entry) {
    return ImageViewerItem(
      id: 'image_${entry.key}',
      imageUrl: entry.value,
      timestamp: DateTime.now(),
    );
  }).toList();
  
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': images,
      'initialIndex': startIndex,
    },
  );
}

// 使用
openImageGallery(
  ['url1.jpg', 'url2.jpg', 'url3.jpg'],
  1, // 从第二张开始
);
```

---

## 🎯 高级用法

### 示例 4: 自定义 Hero 动画标签

为每张图片设置自定义 Hero 标签，实现平滑过渡动画。

```dart
void openImageWithHero(SdkMessage message) {
  final images = messages
      .where((m) => ImageMessageHelper.isImageMessage(m))
      .map((m) {
        return ImageViewerItem(
          id: m.id,
          imageUrl: m.content,
          timestamp: m.timestamp,
          heroTag: 'hero_${m.id}', // 自定义 Hero 标签
        );
      })
      .toList();
  
  final index = images.indexWhere((img) => img.id == message.id);
  
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': images,
      'initialIndex': index,
    },
  );
}
```

**在聊天界面使用相同的 Hero 标签**:
```dart
Hero(
  tag: 'hero_${message.id}',
  child: Image.network(message.content),
)
```

---

### 示例 5: 带缩略图的图片加载

提供缩略图 URL，实现渐进式加载。

```dart
void openImageWithThumbnail(SdkMessage message) {
  final images = messages
      .where((m) => ImageMessageHelper.isImageMessage(m))
      .map((m) {
        // 解析消息内容获取缩略图
        final content = jsonDecode(m.content);
        return ImageViewerItem(
          id: m.id,
          imageUrl: content['url'],
          thumbnailUrl: content['thumbnail'], // 缩略图
          senderName: m.senderName,
          timestamp: m.timestamp,
        );
      })
      .toList();
  
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': images,
      'initialIndex': 0,
    },
  );
}
```

**说明**:
- 先加载缩略图（快速）
- 再加载原图（高质量）
- 提升用户体验

---

### 示例 6: 程序化控制图片查看器

通过控制器直接控制图片查看器。

```dart
class MyImageViewerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImageViewerController>();
    
    return Scaffold(
      body: Column(
        children: [
          // 自定义导航按钮
          Row(
            children: [
              ElevatedButton(
                onPressed: controller.previousImage,
                child: Text('上一张'),
              ),
              ElevatedButton(
                onPressed: controller.nextImage,
                child: Text('下一张'),
              ),
              ElevatedButton(
                onPressed: () => controller.jumpToImage(0),
                child: Text('第一张'),
              ),
            ],
          ),
          
          // 自定义操作按钮
          Row(
            children: [
              ElevatedButton(
                onPressed: controller.saveImage,
                child: Text('保存'),
              ),
              ElevatedButton(
                onPressed: controller.shareImage,
                child: Text('分享'),
              ),
              ElevatedButton(
                onPressed: controller.rotateImage,
                child: Text('旋转'),
              ),
            ],
          ),
          
          // 显示当前状态
          Obx(() => Text(
            '图片 ${controller.currentIndex.value + 1}/${controller.images.length}',
          )),
        ],
      ),
    );
  }
}
```

---

## 🎨 UI 定制

### 示例 7: 监听状态变化

监听控制器状态，实现自定义 UI 反馈。

```dart
class CustomImageViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImageViewerController>();
    
    return Scaffold(
      body: Stack(
        children: [
          // 图片查看器
          ImageViewerPage(),
          
          // 自定义加载指示器
          Obx(() {
            if (controller.isLoading.value) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('加载中...'),
                  ],
                ),
              );
            }
            return SizedBox.shrink();
          }),
          
          // 自定义保存状态
          Obx(() {
            if (controller.isSaving.value) {
              return Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('正在保存...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return SizedBox.shrink();
          }),
          
          // 自定义错误提示
          Obx(() {
            if (controller.error.value != null) {
              return Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Card(
                  color: Colors.red,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      controller.error.value!,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}
```

---

## 🔧 服务集成

### 示例 8: 直接使用 ImageSaveService

在其他地方使用图片保存服务。

```dart
class MyImageDownloader {
  final ImageSaveService _saveService = Get.find<ImageSaveService>();
  
  Future<void> downloadAndSaveImage(String url) async {
    // 1. 检查权限
    if (!await _saveService.hasPermission()) {
      final status = await _saveService.requestPermission();
      if (!status.isGranted) {
        print('权限被拒绝');
        return;
      }
    }
    
    // 2. 下载图片（优先使用缓存）
    try {
      final bytes = await _saveService.downloadImageWithCache(url);
      
      // 3. 保存到相册
      final success = await _saveService.saveToGallery(
        bytes,
        name: 'my_custom_image',
      );
      
      if (success) {
        print('保存成功');
      } else {
        print('保存失败');
      }
    } catch (e) {
      print('错误: $e');
    }
  }
  
  // 使用简化的 API
  Future<void> quickSave(String url) async {
    final result = await _saveService.saveImage(url);
    
    if (result.success) {
      Get.snackbar('成功', '图片已保存');
    } else if (result.permissionDenied) {
      Get.snackbar('权限拒绝', '请在设置中允许访问相册');
    } else {
      Get.snackbar('失败', result.error ?? '保存失败');
    }
  }
}
```

---

### 示例 9: 批量保存图片

保存多张图片到相册。

```dart
class BatchImageSaver {
  final ImageSaveService _saveService = Get.find<ImageSaveService>();
  
  Future<void> saveMultipleImages(List<String> urls) async {
    // 检查权限
    if (!await _saveService.hasPermission()) {
      final status = await _saveService.requestPermission();
      if (!status.isGranted) {
        Get.snackbar('错误', '需要相册权限');
        return;
      }
    }
    
    int successCount = 0;
    int failCount = 0;
    
    // 显示进度对话框
    Get.dialog(
      AlertDialog(
        title: Text('保存中'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Obx(() => Text('$successCount/${urls.length}')),
          ],
        ),
      ),
      barrierDismissible: false,
    );
    
    // 逐个保存
    for (final url in urls) {
      try {
        final result = await _saveService.saveImage(url);
        if (result.success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    
    // 关闭进度对话框
    Get.back();
    
    // 显示结果
    Get.snackbar(
      '完成',
      '成功: $successCount, 失败: $failCount',
    );
  }
}
```

---

## 🛠️ 工具方法使用

### 示例 10: 使用 ImageMessageHelper

在聊天界面使用辅助方法。

```dart
class ChatController extends GetxController {
  final messages = <SdkMessage>[].obs;
  
  // 检查是否有图片
  bool get hasImages => ImageMessageHelper.hasImages(messages);
  
  // 获取图片数量
  int get imageCount => ImageMessageHelper.getImageCount(messages);
  
  // 获取所有图片消息
  List<SdkMessage> get imageMessages {
    return ImageMessageHelper.filterImageMessages(messages);
  }
  
  // 打开图片查看器
  void openImageViewer(SdkMessage message) {
    if (!ImageMessageHelper.isImageMessage(message)) {
      Get.snackbar('错误', '不是图片消息');
      return;
    }
    
    final images = ImageMessageHelper.extractImages(messages);
    final index = ImageMessageHelper.findImageIndex(images, message.id);
    
    if (index == -1) {
      Get.snackbar('错误', '找不到图片');
      return;
    }
    
    Get.toNamed(
      SdkRoutes.imageViewer,
      arguments: {
        'images': images,
        'initialIndex': index,
      },
    );
  }
  
  // 显示图片统计
  void showImageStats() {
    final count = imageCount;
    final position = ImageMessageHelper.getImagePositionBefore(
      messages,
      messages.last.id,
    );
    
    Get.snackbar(
      '图片统计',
      '共 $count 张图片，当前消息之前有 $position 张',
    );
  }
}
```

---

## 🎭 常见场景

### 示例 11: 图片预览（不保存）

只查看图片，不提供保存/分享功能。

```dart
void previewImage(String url) {
  final image = ImageViewerItem(
    id: 'preview',
    imageUrl: url,
    timestamp: DateTime.now(),
  );
  
  // 打开查看器
  Get.toNamed(
    SdkRoutes.imageViewer,
    arguments: {
      'images': [image],
      'initialIndex': 0,
    },
  );
  
  // 隐藏底部工具栏（可选）
  final controller = Get.find<ImageViewerController>();
  controller.showToolbar.value = false;
}
```

---

### 示例 12: 图片编辑后保存

旋转图片后保存。

```dart
Future<void> rotateAndSave() async {
  final controller = Get.find<ImageViewerController>();
  
  // 1. 旋转图片
  controller.rotateImage();
  
  // 2. 等待动画完成
  await Future.delayed(Duration(milliseconds: 200));
  
  // 3. 保存图片
  await controller.saveImage();
}
```

---

### 示例 13: 分享到特定应用

使用 share_plus 的高级功能。

```dart
Future<void> shareToSpecificApp(String imageUrl) async {
  final saveService = Get.find<ImageSaveService>();
  
  try {
    // 下载图片
    final bytes = await saveService.downloadImageWithCache(imageUrl);
    
    // 保存到临时文件
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/share_image.jpg');
    await file.writeAsBytes(bytes);
    
    // 分享（可以指定 MIME 类型）
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '查看这张图片',
      subject: '图片分享',
    );
    
    // 清理临时文件
    await file.delete();
  } catch (e) {
    Get.snackbar('错误', '分享失败: $e');
  }
}
```

---

### 示例 14: 图片加载失败重试

处理图片加载失败的情况。

```dart
class ImageViewerWithRetry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImageViewerController>();
    
    return Scaffold(
      body: Obx(() {
        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(controller.error.value!),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 重新加载当前图片
                    controller.error.value = null;
                    controller.isLoading.value = true;
                    // 触发重新加载逻辑
                  },
                  child: Text('重试'),
                ),
              ],
            ),
          );
        }
        
        return ImageViewerPage();
      }),
    );
  }
}
```

---

### 示例 15: 图片查看器埋点统计

记录用户行为数据。

```dart
class AnalyticsImageViewerController extends ImageViewerController {
  @override
  void onInit() {
    super.onInit();
    
    // 记录打开事件
    Analytics.logEvent('image_viewer_opened', {
      'image_count': images.length,
      'initial_index': currentIndex.value,
    });
  }
  
  @override
  void onPageChanged(int index) {
    super.onPageChanged(index);
    
    // 记录切换事件
    Analytics.logEvent('image_viewer_page_changed', {
      'from_index': currentIndex.value,
      'to_index': index,
    });
  }
  
  @override
  Future<void> saveImage() async {
    // 记录保存事件
    Analytics.logEvent('image_viewer_save_clicked', {
      'image_index': currentIndex.value,
      'image_url': images[currentIndex.value].imageUrl,
    });
    
    await super.saveImage();
    
    // 记录保存结果
    if (!isSaving.value && error.value == null) {
      Analytics.logEvent('image_viewer_save_success');
    } else if (error.value != null) {
      Analytics.logEvent('image_viewer_save_failed', {
        'error': error.value,
      });
    }
  }
  
  @override
  Future<void> shareImage() async {
    Analytics.logEvent('image_viewer_share_clicked');
    await super.shareImage();
  }
  
  @override
  void rotateImage() {
    Analytics.logEvent('image_viewer_rotate_clicked');
    super.rotateImage();
  }
  
  @override
  void onClose() {
    // 记录关闭事件
    Analytics.logEvent('image_viewer_closed', {
      'duration': DateTime.now().difference(_openTime).inSeconds,
      'images_viewed': _viewedIndices.length,
    });
    
    super.onClose();
  }
}
```

---

## 📚 相关文档

- [Feature Overview](./picture-viewer-feature.md) - 功能概述
- [Architecture Documentation](./architecture.md) - 架构设计
- [API Documentation](./api-documentation.md) - API 参考
- [Troubleshooting Guide](./troubleshooting.md) - 故障排除

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-05  
**维护者**: allen

# Picture Viewer Product Requirements Document (PRD)

## Goals and Background Context

### Goals

- 为聊天中的图片消息提供专业的全屏预览体验
- 支持图片缩放、平移等基础操作
- 支持保存图片到相册
- 支持多图浏览，提升用户体验
- 使用成熟的第三方库快速实现，降低开发和维护成本

### Background Context

当前 Live Chat Flutter SDK 的图片消息只能在聊天列表中以缩略图形式查看，用户无法：
- 放大查看图片细节
- 保存图片到相册
- 在多张图片间快速切换

这导致用户体验不佳，特别是在需要查看图片细节或保存图片时。市场上主流的聊天应用（微信、Telegram、WhatsApp）都提供了完善的图片查看功能，我们需要达到同等水平。

技术上，Flutter 生态有多个成熟的图片查看库可选，其中 **extended_image** 功能最全面，性能优秀，社区活跃，是最佳选择。

### Change Log

| Date | Version | Description | Author |
| :--- | :------ | :---------- | :----- |
| 2026-03-04 | 0.1 | Initial PRD draft | allen (AI-assisted) |

## Requirements

### Functional

- FR1: 用户点击聊天中的图片消息时，打开全屏图片预览界面
- FR2: 预览界面支持双指捏合缩放（缩放范围 0.5x - 3.0x）
- FR3: 预览界面支持双击快速缩放（1x ↔ 2x）
- FR4: 图片放大后支持拖动平移查看不同区域
- FR5: 预览界面提供明显的关闭按钮或手势（点击背景、返回按钮）
- FR6: 预览界面提供保存按钮，可将图片保存到设备相册
- FR7: 首次保存图片时请求相册权限，权限被拒绝时提供友好提示
- FR8: 当聊天中有多张图片时，支持左右滑动浏览其他图片
- FR9: 多图浏览时显示当前图片位置（如 "3/10"）
- FR10: 图片加载时显示加载进度指示器
- FR11: 图片加载失败时显示错误提示和重试选项
- FR12: 从缩略图到全屏预览使用 Hero 动画过渡
- FR13: 预览界面使用深色背景（黑色或深灰色）
- FR14: 预览时自动隐藏系统状态栏，提供沉浸式体验

### Non Functional

- NFR1: 图片加载时间 < 2 秒（正常网络环境，1MB 图片）
- NFR2: 缩放和拖动操作帧率 ≥ 30 FPS，确保流畅体验
- NFR3: 预览功能内存占用增加 < 50MB
- NFR4: 预览界面打开响应时间 < 300ms
- NFR5: 支持 iOS 12.0+ 和 Android 5.0+
- NFR6: 支持常见图片格式（JPEG, PNG, GIF, WebP）
- NFR7: 支持各种屏幕尺寸和分辨率（手机、平板）
- NFR8: 手势操作符合 iOS 和 Android 平台规范
- NFR9: 错误提示清晰友好，提供可操作的解决方案
- NFR10: 代码结构清晰，易于扩展和维护
- NFR11: 使用成熟稳定的第三方库，降低维护成本

## User Interface Design Goals

### 预览界面布局

```
┌─────────────────────────────────────┐
│ [×]                          3/10   │ ← 顶部栏（半透明）
│                                     │
│                                     │
│                                     │
│            [图片显示区域]            │
│                                     │
│                                     │
│                                     │
│                                     │
│ [💾 保存]  [🔄 旋转]  [↗️ 分享]     │ ← 底部工具栏（半透明）
└─────────────────────────────────────┘
```

### 交互设计

1. **打开预览**
   - 点击图片消息 → Hero 动画放大 → 全屏预览
   - 动画时长：300ms
   - 背景渐变为黑色

2. **缩放操作**
   - 双指捏合：连续缩放
   - 双击：1x ↔ 2x 快速切换
   - 缩放动画：200ms

3. **关闭预览**
   - 点击背景 → 淡出动画 → 关闭
   - 返回按钮 → Hero 动画缩小 → 关闭
   - 下滑手势 → 跟手动画 → 关闭（Phase 2）

4. **多图浏览**
   - 左右滑动切换图片
   - 切换动画：平滑过渡
   - 边界反馈：阻尼效果

### 视觉设计

- **背景色**: `Color(0xFF000000)` 纯黑色
- **工具栏背景**: `Color(0x80000000)` 半透明黑色
- **文字颜色**: `Colors.white`
- **图标颜色**: `Colors.white`
- **加载指示器**: `CircularProgressIndicator` 白色
- **按钮样式**: Material Design 3 风格

## Technical Approach

### Technology Stack

**核心库**:
- `extended_image: ^8.2.0` - 图片显示和手势处理
- `image_gallery_saver: ^2.0.3` - 保存图片到相册
- `permission_handler: ^11.0.1` - 权限管理

**架构模式**:
- MVVM (Model-View-ViewModel)
- GetX 状态管理

### Component Architecture

```
ImageMessageBubble (点击触发)
    ↓
Navigator.push()
    ↓
ImageViewerPage (全屏页面)
    ├── ImageViewerController (状态管理)
    ├── ExtendedImageGesturePageView (多图浏览)
    │   └── ExtendedImage (单图显示 + 手势)
    ├── TopBar (关闭按钮 + 计数)
    └── BottomToolBar (保存、分享等)
```

### Key Implementation Details

#### 1. 图片列表获取
```dart
// 从当前聊天获取所有图片消息
List<ImageViewerItem> getImageList(SdkChat chat, String currentMessageId) {
  return chat.messages
    .where((m) => m.type == SdkMessageType.image)
    .map((m) => ImageViewerItem.fromMessage(m))
    .toList();
}
```

#### 2. Hero 动画
```dart
// 缩略图
Hero(
  tag: 'image_${message.uniqueId}',
  child: CachedNetworkImage(imageUrl: imageUrl),
)

// 全屏预览
Hero(
  tag: 'image_${message.uniqueId}',
  child: ExtendedImage.network(imageUrl),
)
```

#### 3. 手势配置
```dart
ExtendedImage.network(
  imageUrl,
  mode: ExtendedImageMode.gesture,
  initGestureConfigHandler: (state) {
    return GestureConfig(
      minScale: 0.5,
      maxScale: 3.0,
      animationMinScale: 0.5,
      animationMaxScale: 3.5,
      speed: 1.0,
      inertialSpeed: 100.0,
      initialScale: 1.0,
      cacheGesture: false,
    );
  },
)
```

#### 4. 保存图片
```dart
Future<void> saveImage(String imageUrl) async {
  // 1. 检查权限
  final status = await Permission.photos.request();
  if (!status.isGranted) {
    showPermissionDeniedDialog();
    return;
  }
  
  // 2. 下载图片
  final response = await http.get(Uri.parse(imageUrl));
  
  // 3. 保存到相册
  final result = await ImageGallerySaver.saveImage(
    response.bodyBytes,
    quality: 100,
  );
  
  // 4. 显示结果
  if (result['isSuccess']) {
    showSuccessToast('图片已保存');
  } else {
    showErrorToast('保存失败');
  }
}
```

### File Structure

```
lib/features/chats/
├── models/
│   └── image_viewer_item.dart          # 新增：图片查看器数据模型
├── controllers/
│   └── image_viewer_controller.dart    # 新增：图片查看器控制器
├── views/
│   ├── pages/
│   │   └── image_viewer_page.dart      # 新增：图片查看器页面
│   └── widgets/
│       ├── bubbles/
│       │   └── image_message_bubble.dart  # 修改：添加点击事件
│       └── image_viewer/
│           ├── image_viewer_top_bar.dart     # 新增：顶部栏
│           ├── image_viewer_bottom_bar.dart  # 新增：底部工具栏
│           └── image_viewer_loading.dart     # 新增：加载状态
└── services/
    └── image_save_service.dart         # 新增：图片保存服务
```

## Implementation Phases

### Phase 1: MVP (3 days) - P0

**目标**: 实现核心图片预览功能

**Day 1: 基础预览**
- Task 1.1: 添加依赖包到 pubspec.yaml
- Task 1.2: 创建 ImageViewerItem 数据模型
- Task 1.3: 创建 ImageViewerController
- Task 1.4: 创建 ImageViewerPage 基础结构
- Task 1.5: 实现单图显示和缩放
- Task 1.6: 添加关闭功能

**Day 2: 多图浏览和保存**
- Task 2.1: 实现多图浏览（ExtendedImageGesturePageView）
- Task 2.2: 添加图片计数显示
- Task 2.3: 创建 ImageSaveService
- Task 2.4: 实现保存功能和权限处理
- Task 2.5: 添加加载状态和错误处理

**Day 3: 动画和优化**
- Task 3.1: 实现 Hero 动画
- Task 3.2: 优化性能（内存、加载速度）
- Task 3.3: 修改 ImageMessageBubble 添加点击事件
- Task 3.4: 测试和修复 bug

**Deliverables**:
- ✅ 可点击预览图片
- ✅ 支持缩放和拖动
- ✅ 支持多图浏览
- ✅ 支持保存图片
- ✅ Hero 动画过渡

### Phase 2: Enhancement (2 days) - P1

**目标**: 增强用户体验

**Features**:
- 分享功能（share_plus）
- 旋转功能（90度旋转）
- 下滑关闭手势
- 发送者信息显示
- 时间戳显示
- 优化工具栏 UI

**Deliverables**:
- ✅ 更丰富的操作选项
- ✅ 更自然的交互体验
- ✅ 更完善的信息展示

### Phase 3: Advanced (2 days) - P2

**目标**: 高级功能（可选）

**Features**:
- 图片编辑（裁剪、标注）
- 图片信息显示（分辨率、大小）
- 复制图片到剪贴板
- 原图/缩略图切换
- 图片质量选择

**Deliverables**:
- ✅ 专业级图片查看体验
- ✅ 满足高级用户需求

## Testing Strategy

### Unit Tests

**ImageViewerController**:
- 图片列表管理
- 当前索引切换
- 保存功能逻辑
- 权限处理逻辑

**ImageSaveService**:
- 权限检查
- 图片下载
- 保存到相册
- 错误处理

### Widget Tests

**ImageViewerPage**:
- 页面渲染
- 手势操作
- 按钮点击
- 状态切换

**ImageViewerTopBar**:
- 关闭按钮
- 计数显示

**ImageViewerBottomBar**:
- 保存按钮
- 工具栏显示/隐藏

### Integration Tests

**完整流程**:
1. 点击图片消息 → 打开预览
2. 缩放和拖动操作
3. 左右滑动切换图片
4. 保存图片到相册
5. 关闭预览返回聊天

**边界情况**:
- 单张图片（无法滑动）
- 网络图片加载失败
- 权限被拒绝
- 内存不足

### Manual Tests

**设备测试**:
- iPhone (iOS 12+)
- iPad (iOS 12+)
- Android 手机 (Android 5.0+)
- Android 平板 (Android 5.0+)

**场景测试**:
- 不同图片格式（JPEG, PNG, GIF, WebP）
- 不同图片尺寸（小图、大图、超大图）
- 不同网络环境（WiFi, 4G, 弱网）
- 不同屏幕方向（竖屏、横屏）

**性能测试**:
- 内存占用监控
- 加载速度测试
- 帧率测试
- 电量消耗测试

## Success Metrics

### Functional Metrics
- ✅ 图片预览功能可用率 > 99%
- ✅ 图片保存成功率 > 95%
- ✅ 多图浏览切换成功率 > 99%
- ✅ Hero 动画流畅度 > 95%

### Performance Metrics
- ✅ 图片加载时间 < 2s (1MB, 正常网络)
- ✅ 预览打开响应时间 < 300ms
- ✅ 缩放拖动帧率 > 30 FPS
- ✅ 内存占用增加 < 50MB

### User Experience Metrics
- ✅ 用户满意度 > 90%
- ✅ 功能使用率 > 50%
- ✅ 用户投诉率 < 1%
- ✅ Bug 报告率 < 0.5%

### Technical Metrics
- ✅ 单元测试覆盖率 > 80%
- ✅ Widget 测试覆盖率 > 70%
- ✅ 代码审查通过率 100%
- ✅ 无内存泄漏

## Risks and Mitigation

### Risk 1: 内存占用过高
**Impact**: High  
**Probability**: Medium  
**Mitigation**:
- 使用 extended_image 的缓存机制
- 限制缓存图片尺寸（cacheWidth, cacheHeight）
- 及时释放不用的图片资源
- 监控内存使用，设置上限

### Risk 2: 图片加载速度慢
**Impact**: High  
**Probability**: Medium  
**Mitigation**:
- 使用渐进式加载（先显示缩略图）
- 预加载相邻图片
- 优化网络请求（HTTP/2, 压缩）
- 提供加载进度反馈

### Risk 3: 手势操作冲突
**Impact**: Medium  
**Probability**: Low  
**Mitigation**:
- 使用 extended_image 的成熟手势配置
- 参考平台规范（iOS HIG, Material Design）
- 充分测试各种手势组合
- 提供手势操作说明

### Risk 4: 权限被拒绝
**Impact**: Medium  
**Probability**: Medium  
**Mitigation**:
- 提供清晰的权限说明
- 权限被拒绝时提供设置跳转
- 提供降级方案（复制图片链接）
- 记录权限状态，避免重复请求

### Risk 5: 不同设备兼容性问题
**Impact**: High  
**Probability**: Low  
**Mitigation**:
- 在多种设备上测试
- 使用 Flutter 的响应式布局
- 处理不同屏幕尺寸和分辨率
- 监控线上崩溃和错误

## Dependencies and Assumptions

### Dependencies

**External Libraries**:
- extended_image: ^8.2.0
- image_gallery_saver: ^2.0.3
- permission_handler: ^11.0.1
- share_plus: ^7.2.1 (Phase 2)

**Internal Dependencies**:
- SdkMessage 模型
- SdkChat 模型
- CachedNetworkImage (已有)
- GetX 状态管理 (已有)

**Platform Dependencies**:
- iOS: Photos framework
- Android: MediaStore API

### Assumptions

1. **网络环境**: 假设用户有稳定的网络连接
2. **存储空间**: 假设设备有足够的存储空间保存图片
3. **权限**: 假设用户会授予相册权限
4. **图片格式**: 假设后端返回的图片格式是标准的
5. **图片大小**: 假设单张图片大小 < 10MB
6. **设备性能**: 假设设备性能足以流畅运行

## Open Questions

1. **Q**: 是否需要支持视频预览？  
   **A**: 不在本期范围，视频预览是独立的 issue

2. **Q**: 是否需要支持 GIF 动图编辑？  
   **A**: Phase 3 可选功能，优先级低

3. **Q**: 是否需要云端存储功能？  
   **A**: 不在范围内，属于云存储功能

4. **Q**: 是否需要支持图片滤镜？  
   **A**: Phase 3 可选功能，优先级低

5. **Q**: 原图和缩略图如何区分？  
   **A**: 使用相同 URL，extended_image 会自动处理缓存

## Appendix

### A. Competitive Analysis

**微信**:
- ✅ 流畅的缩放和拖动
- ✅ 多图左右滑动
- ✅ 保存和分享
- ✅ 下滑关闭手势

**Telegram**:
- ✅ 快速的加载速度
- ✅ 高质量的图片显示
- ✅ 丰富的操作选项
- ✅ 图片编辑功能

**WhatsApp**:
- ✅ 简洁的界面
- ✅ 快速的响应
- ✅ 稳定的性能

### B. Technical References

- [extended_image 文档](https://pub.dev/packages/extended_image)
- [image_gallery_saver 文档](https://pub.dev/packages/image_gallery_saver)
- [Flutter 手势处理](https://docs.flutter.dev/ui/interactivity/gestures)
- [iOS Human Interface Guidelines - Photos](https://developer.apple.com/design/human-interface-guidelines/photos)
- [Material Design - Image Lists](https://m3.material.io/components/image-lists/overview)

### C. Related Issues

- WISE2018-34685: Message Protocol Field Standardization (已完成)
- WISE2018-XXXXX: Video Player (未来)
- WISE2018-XXXXX: File Viewer (未来)

---

**PRD Status**: ✅ Ready for Review  
**Next Step**: Architecture Document  
**Estimated Effort**: 5-7 days  
**Priority**: P1  
**Target Release**: v1.2.0

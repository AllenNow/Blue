# Bug Fix: Image Viewer Route Registration

**日期**: 2026-03-05  
**严重程度**: Critical (P0)  
**状态**: ✅ Fixed  
**修复者**: allen (Dev role)

---

## 🐛 问题描述

### 错误信息
```
Exception caught by gesture
_TypeError: Null check operator used on a null value
at PageRedirect.page (package:get/get_navigation/src/routes/route_middleware.dart:200:49)
```

### 触发场景
用户在聊天界面点击图片消息时，应用崩溃并抛出空指针异常。

### 堆栈跟踪
```
#0  PageRedirect.page
#1  GetMaterialApp.generator
#2  _WidgetsAppState._onGenerateRoute
#3  NavigatorState._routeNamed
#4  NavigatorState.pushNamed
#5  GetNavigation.toNamed
#6  SdkChatDetailController.openImageViewer
#7  SdkChatDetailPage._buildMessageItem.<anonymous closure>
```

---

## 🔍 根本原因

**Image Viewer 路由未注册到 GetPage 列表中**

虽然在 `SdkRoutes` 中定义了路由常量：
```dart
static const String imageViewer = '/sdk/image-viewer';
```

但在 `SdkPages.getPages()` 方法中没有注册对应的 `GetPage`，导致 GetX 路由生成器无法找到页面构建器，从而抛出空指针异常。

---

## ✅ 解决方案

### 1. 添加 ImageViewerPage 导入

**文件**: `packages/live_chat_sdk/lib/core/routes/sdk_pages.dart`

```dart
import '../../features/chats/views/pages/image_viewer_page.dart';
```

### 2. 注册 Image Viewer 路由

在 `getPages()` 方法的路由列表中添加：

```dart
// Image Viewer
GetPage(
  name: SdkRoutes.imageViewer,
  page: () {
    final args = Get.arguments as Map<String, dynamic>?;
    return ImageViewerPage(
      images: args?['images'] ?? [],
      initialIndex: args?['initialIndex'] ?? 0,
      heroTag: args?['heroTag'],
    );
  },
),
```

### 3. 参数处理

- 使用 `Get.arguments` 获取路由参数
- 提供默认值防止空指针
- 支持可选的 `heroTag` 参数

---

## 🧪 测试验证

### 单元测试

创建了 `sdk_pages_test.dart` 验证路由注册：

```dart
test('getPages returns all routes including imageViewer', () {
  final pages = SdkPages.getPages(null);
  final imageViewerRoute = pages.firstWhere(
    (page) => page.name == SdkRoutes.imageViewer,
  );
  
  expect(imageViewerRoute.name, SdkRoutes.imageViewer);
  expect(imageViewerRoute.name, '/sdk/image-viewer');
});
```

**测试结果**: ✅ 5/5 tests passing

### 手动测试

1. ✅ 点击聊天中的图片消息
2. ✅ 成功打开图片查看器
3. ✅ 无崩溃或错误
4. ✅ Hero 动画正常
5. ✅ 所有功能正常（缩放、平移、保存、分享、旋转、滑动关闭）

---

## 📊 影响范围

### 受影响功能
- ✅ 图片消息点击
- ✅ 图片查看器打开
- ✅ 所有图片查看器功能

### 受影响文件
- `packages/live_chat_sdk/lib/core/routes/sdk_pages.dart` (修改)
- `packages/live_chat_sdk/test/core/routes/sdk_pages_test.dart` (新增)

### 向后兼容性
- ✅ 完全兼容
- ✅ 无 API 变更
- ✅ 无破坏性更改

---

## 🎓 经验教训

### 问题根源
1. **路由定义与注册分离**: 定义了路由常量但忘记注册
2. **缺少集成测试**: 没有测试覆盖路由注册
3. **开发流程**: 实现功能时未验证路由配置

### 改进措施
1. ✅ 添加路由注册测试
2. ✅ 在实现新页面时立即注册路由
3. ✅ 添加路由配置检查清单

### 预防措施
- 新增页面时，同步更新 `sdk_pages.dart`
- 运行路由测试验证配置
- 手动测试导航流程

---

## 📝 相关文档

- [Story 3.1: Navigation from Chat](./story-3-1-navigation-from-chat.md)
- [SDK Routes Documentation](../../packages/live_chat_sdk/lib/core/routes/sdk_routes.dart)
- [SDK Pages Configuration](../../packages/live_chat_sdk/lib/core/routes/sdk_pages.dart)

---

## ✅ 验收标准

- [x] 错误已修复
- [x] 点击图片可正常打开查看器
- [x] 无崩溃或异常
- [x] 所有功能正常工作
- [x] 测试覆盖路由注册
- [x] 代码审查通过
- [x] 文档已更新

---

## 🚀 部署状态

**状态**: ✅ Ready for Production  
**修复时间**: 15 minutes  
**测试时间**: 5 minutes  
**总时间**: 20 minutes

---

**修复版本**: 1.0.1  
**修复日期**: 2026-03-05  
**修复者**: allen (Dev role)

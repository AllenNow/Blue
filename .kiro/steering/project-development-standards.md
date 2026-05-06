---
inclusion: auto
---

# WMS Lite Mobile — 项目开发规范

> 本文档是项目所有开发规范的权威来源，AI 和开发者均须遵守。

---

## 1. 项目概述

- **类型**: Flutter 移动应用（iOS + Android）
- **技术栈**: Flutter / Dart / GetX / Dio
- **业务**: WMS（仓库管理系统）移动端，简化版，对标 Android WMS 主应用

---

## 2. 目录结构

```
lib/
├── common/                   # 通用层
│   ├── extensions/           # Dart 扩展
│   ├── models/               # 共享数据模型
│   ├── services/
│   │   ├── network/          # 网络服务（Dio、拦截器、Mock）
│   │   │   ├── mock/         # Mock 数据（pick_mock_data.dart 等）
│   │   │   └── interceptor/  # 拦截器
│   │   ├── routes/           # 路由（route_names.dart、app_pages.dart）
│   │   └── ...
│   └── widgets/              # 共享 UI 组件（ScanInputField、WorkflowStepCard 等）
├── module/                   # 业务模块
│   ├── home/
│   ├── receive/
│   ├── putaway/
│   ├── pick/                 # 拣货模块（示例）
│   │   ├── api/
│   │   ├── bindings/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── pages/
│   │   └── widgets/
│   └── ...
├── style/                    # 主题系统
│   ├── colors.dart
│   ├── theme_extensions.dart # context.cardBackground 等扩展
│   └── ...
└── l10n/                     # 国际化（见第 5 章）
    ├── intl_en.arb
    ├── intl_zh.arb
    ├── intl_ja.arb
    ├── app_localizations.dart      # 生成文件，勿手动修改
    ├── app_localizations_en.dart   # 生成文件，勿手动修改
    ├── app_localizations_zh.dart   # 生成文件，勿手动修改
    ├── app_localizations_ja.dart   # 生成文件，勿手动修改
    └── wording.dart                # 全局访问入口
```

---

## 3. 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | snake_case | `pick_task_entity.dart` |
| 类名 | PascalCase | `PickTaskEntity` |
| 方法/变量 | camelCase | `loadPickTasks()` |
| 常量 | k + PascalCase | `kPageSize` |
| 路由常量 | camelCase | `RouteNames.pickTaskList` |

---

## 4. 架构规范

### 4.1 模块结构（标准）

每个业务模块包含：

```
module/<feature>/
├── api/          <feature>_api.dart          # API 接口
├── bindings/     <feature>_binding.dart      # GetX 依赖注入
├── controllers/  <feature>_controller.dart   # 控制器
├── models/       <feature>_entity.dart       # 数据模型
├── pages/        <feature>_page.dart         # 页面
└── widgets/      <feature>_card.dart         # 模块专用组件
```

### 4.2 Controller 规范

- Controller 负责：响应 UI 事件、调用 API、更新状态、处理 UI 反馈（Toast/Dialog）
- 复杂模块可拆分为 State + Logic + Controller 三层（见 shrimp-rules.md）
- Controller 保持轻量（< 300 行），超出时用 mixin 拆分

```dart
// 推荐：mixin 拆分
class PickStepController extends GetxController
    with PickLocationMixin, PickItemMixin, PickSubmitMixin { ... }
```

### 4.3 页面组件规范

- 需要持有 `TextEditingController` 等需要 dispose 的对象时，**必须使用 `StatefulWidget`**，不能用 `GetView`
- `GetView` 适用于纯展示、无需 dispose 的页面

```dart
// ✅ 正确：需要 dispose 时用 StatefulWidget
class PickStepPage extends StatefulWidget { ... }
class _PickStepPageState extends State<PickStepPage> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
}

// ❌ 错误：GetView 中新建 TextEditingController 会内存泄漏
class PickStepPage extends GetView<PickStepController> {
  Widget build(context) => ScanInputField(controller: TextEditingController()); // 泄漏！
}
```

### 4.4 单一职责规范

- 单个 Widget build 方法超过 50 行时，拆分为独立 Widget 类
- 每个 Widget 只负责一个 UI 区域

```dart
// ✅ 正确：拆分为独立 Widget
class ReturnInventoryPage extends StatefulWidget { ... }
class _ScanSection extends StatelessWidget { ... }
class _InventoryListSection extends StatelessWidget { ... }
class _ReturnWorkSection extends StatelessWidget { ... }

// ❌ 错误：一个方法包含所有 UI 逻辑
Widget _buildAll() { /* 200 行 */ }
```

### 4.5 Obx 内的 TextEditingController

```dart
// ✅ 正确：State 中持有，ever() 监听同步
class _State extends State<MyPage> {
  final _ctrl = TextEditingController();
  @override void initState() {
    super.initState();
    ever(controller.someValue, (v) => _ctrl.text = v ?? '');
  }
}

// ❌ 错误：Obx 内每次 rebuild 新建
Obx(() => ScanInputField(
  controller: TextEditingController(text: controller.value.value), // 每次重建！
))
```

---

## 5. 国际化规范

### 5.1 系统说明

项目使用 **Flutter 官方 gen-l10n** 方案：

```
intl_en.arb  ──┐
intl_zh.arb  ──┼──[flutter gen-l10n]──→ app_localizations*.dart（生成文件）
intl_ja.arb  ──┘
```

- **arb 文件是源文件**，`app_localizations*.dart` 是生成产物，**禁止手动修改生成文件**
- 全局访问：`wording.xxx`（无需 context）
- 带 context 访问：`context.wording.xxx`（两者等价）

### 5.2 新增字符串的正确流程（唯一方式）

**无论后端接口是否就绪，都必须走此流程。**

```bash
# Step 1: 在三个 arb 文件中同时添加 key
# lib/l10n/intl_en.arb
"myNewKey": "My New String",

# lib/l10n/intl_zh.arb
"myNewKey": "我的新字符串",

# lib/l10n/intl_ja.arb
"myNewKey": "新しい文字列",

# Step 2: 重新生成（必须执行）
flutter gen-l10n

# Step 3: 代码中使用
wording.myNewKey
```

### 5.3 禁止事项

```dart
// ❌ 禁止：手动修改生成文件（会被 flutter gen-l10n 覆盖）
// lib/l10n/app_localizations.dart      ← 禁止手动修改
// lib/l10n/app_localizations_en.dart   ← 禁止手动修改
// lib/l10n/app_localizations_zh.dart   ← 禁止手动修改
// lib/l10n/app_localizations_ja.dart   ← 禁止手动修改

// ❌ 禁止：硬编码用户可见文本
Text('Pick Tasks')  // 必须用 wording.pickTaskList

// ❌ 禁止：在 wording.dart 中用 extension 绕过 arb 流程
extension MyModuleLocalizations on AppLocalizations { ... }  // 禁止

// ❌ 禁止：使用已废弃的 S 类
S.current.someKey
```

### 5.4 临时方案（后端接口未就绪时）

当需要快速迭代、暂时不想走完整 arb 流程时，可在 `wording.dart` 末尾添加 extension：

```dart
// lib/l10n/wording.dart 末尾
extension MyModuleLocalizations on AppLocalizations {
  String get myTempKey => localeName.startsWith('zh') ? '中文' : 'English';
}
```

**注意**：临时方案必须在接口稳定后迁移到 arb 文件。

---

## 6. 主题规范

### 6.1 颜色使用

```dart
// ✅ 正确：使用主题扩展
context.cardBackground
context.textPrimary
context.textSecondary
context.safePrimaryColor
context.borderColor
context.successColor
context.warningColor
context.errorColor

// ❌ 错误：硬编码颜色
Color(0xFF1C2938)
Colors.blue
```

### 6.2 尺寸适配

```dart
// ✅ 正确：使用 flutter_screenutil
EdgeInsets.all(12.w)
SizedBox(height: 8.h)
BorderRadius.circular(8.r)
TextStyle(fontSize: 14.sp)

// ❌ 错误：硬编码尺寸
EdgeInsets.all(12)
```

---

## 7. 网络与 Mock 规范

### 7.1 API 注册

所有 API 类必须在 `ApiService` 中注册：

```dart
// lib/common/services/network/api_service.dart
PickTaskApi? _pickTaskApi;
// initialize() 中：
_pickTaskApi = PickTaskApi(dio);
// getter：
PickTaskApi get pickTaskApi { _ensureInitialized(); return _pickTaskApi!; }
```

### 7.2 Mock 数据规范

- Mock 数据文件放在 `lib/common/services/network/mock/` 下
- 在 `MockDataRegistry.registerAll()` 中注册
- Mock 函数使用**无参数**形式，避免 `MockDataProvider` 调用失败

```dart
// ✅ 正确：无参数函数
provider.register('/api/.../search', 'POST', _myMockData);
static Map<String, dynamic> _myMockData() { return {...}; }

// ❌ 错误：带参数函数（MockDataProvider 可能调用失败）
provider.register('/api/.../search', 'POST', (body) => _myMockData(body));
```

### 7.3 Mock 兜底机制

`MockInterceptor` 已实现 `onError` 兜底：当真实 API 返回 404 或连接失败时，自动查找 Mock 数据返回。后端接口未就绪时，只需注册 Mock 数据即可正常跑通流程。

### 7.4 路由注册

```dart
// lib/common/services/routes/route_names.dart
static const String myFeature = '/my-feature';

// lib/common/services/routes/app_pages.dart
GetPage(
  name: RouteNames.myFeature,
  page: () => const MyFeaturePage(),
  binding: BindingsBuilder(() => Get.lazyPut(() => MyFeatureController())),
),
```

---

## 8. 通用组件规范

### 8.1 已有通用组件（优先复用）

| 组件 | 路径 | 用途 |
|------|------|------|
| `ScanInputField` | `common/widgets/scan_input_field.dart` | 扫码输入框（统一 QR 图标） |
| `ThemedAppBar` | `common/widgets/themed_app_bar.dart` | 统一 AppBar |
| `ProgressSummaryBar` | `common/widgets/progress_summary_bar.dart` | 进度摘要条 |
| `QtyAdjuster` | `common/widgets/qty_adjuster.dart` | 数量调整 [-] n [+] |
| `WorkflowStepCard` | `common/widgets/workflow_step_card.dart` | 工作流步骤卡片（三态） |
| `StepNavigationBar` | `common/widgets/step_navigation_bar.dart` | 步骤导航栏 |
| `AuthenticatedNetworkImage` | `common/widgets/authenticated_network_image.dart` | 带认证的网络图片 |
| `TaskStepCard` | `module/receive/widgets/task_step_card.dart` | Task Steps 列表卡片（所有模块统一使用） |
| **`StatusBadge`** | **`common/widgets/status_badge.dart`** | **状态/类型标签（所有模块统一使用）** |
| **`TaskBadge`** | **`common/widgets/task_card_shell.dart`** | **优先级标签（TaskCardShell 内置）** |

### 8.1.1 StatusBadge 使用规范（重要）

**项目中所有状态标签、类型标签、进度标签均必须使用 `StatusBadge`，禁止手写 `Container + BoxDecoration` 实现标签。**

#### 两种模式

| 模式 | 参数 | 外观 | 适用场景 |
|------|------|------|---------|
| 实心（默认） | `solid: true` | 彩色实心背景 + **白色文字** | 任务状态（NEW/IN PROGRESS/DONE）、优先级 |
| 描边 | `solid: false` | 半透明背景 + 彩色边框 + **彩色文字** | 进度标注（Done/Pending/Loaded）、辅助信息 |

#### 颜色规范

```dart
// 成功/完成/已装车
StatusBadge(label: 'Done', color: context.successColor)

// 警告/进行中/待处理
StatusBadge(label: 'Pending', color: context.warningColor, solid: false)

// 错误/取消
StatusBadge(label: 'Cancelled', color: context.errorColor)

// 主要/新建
StatusBadge(label: 'NEW', color: context.safePrimaryColor)

// 次要/禁用
StatusBadge(label: 'N/A', color: context.textSecondary, solid: false)
```

#### 主题适配说明

- **solid 模式**：白色文字在彩色实心背景上，亮色/暗色主题均清晰可见
- **outline 模式**：彩色文字（与边框同色），在半透明背景上，亮色/暗色主题均清晰可见
- **禁止**：`solid: false` 时使用 `Colors.white` 文字（浅色背景上不可见）

#### 禁止的写法

```dart
// ❌ 禁止：手写标签容器
Container(
  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
  decoration: BoxDecoration(
    color: context.successColor.withValues(alpha: 20),
    borderRadius: BorderRadius.circular(4.r),
  ),
  child: Text('Done', style: TextStyle(color: Colors.white)), // 浅背景白字不可见！
)

// ❌ 禁止：硬编码颜色
StatusBadge(label: 'Type', color: const Color(0xFF1976D2))

// ✅ 正确
StatusBadge(label: 'Done', color: context.successColor)
StatusBadge(label: 'Pending', color: context.warningColor, solid: false)
```

### 8.2 新建通用组件规范

- 放在 `lib/common/widgets/` 下
- 不依赖任何业务模块
- 支持 Light/Dark 主题
- 通过构造函数传参，不在内部 `Get.find()`

---

## 8.3 交互一致性原则

**相似功能必须使用统一的交互方式和组件，禁止在不同模块中重复实现相同的 UI 模式。**

### 8.3.1 Task Steps 列表

所有任务类型（Pick、Receive、Load、PutAway 等）的步骤列表页，**必须使用统一的 `TaskStepCard` 组件**：

```dart
// ✅ 正确：统一使用 TaskStepCard
import 'package:wms_lite_mobile/module/receive/widgets/task_step_card.dart';

ListView.separated(
  itemBuilder: (_, i) => TaskStepCard(
    step: steps[i],
    stepNumber: i + 1,
    onTap: () => controller.navigateToStep(steps[i]),
  ),
);

// ❌ 错误：在各模块自己实现 step item
Widget _buildStepItem(...) { /* 重复实现 */ }
```

`TaskStepCard` 的统一样式：序号圆圈（主题色）+ 步骤名 + 状态 Badge + 右箭头。

### 8.3.2 扫码输入框

所有扫码输入框统一使用 `ScanInputField`（`common/widgets/scan_input_field.dart`）：

- Location 扫码框必须传入 `onSearchLocation` 参数，提供搜索入口
- 不允许直接使用 `TextField` 替代

### 8.3.3 步骤导航底部栏

工作流步骤页面的底部导航统一使用 Previous / Next 风格：

- Previous：`OutlinedButton` + 左箭头图标
- Next：`ElevatedButton` + 右箭头图标，未满足条件时禁用（灰色）
- 参考实现：`cycle_count_work_page.dart` 的 `_buildPrevNextBar`

### 8.3.4 新增交互模式时的规范

当需要实现一个新的 UI 交互模式时：

1. 先搜索项目中是否已有相同模式的实现
2. 如果已有，直接复用或将其提升为通用组件
3. 如果没有，在 `common/widgets/` 中创建通用组件，**不在业务模块中创建私有实现**
4. 在本文档 8.1 的组件表中登记新组件

---

## 9. 代码审查检查清单

提交代码前必须确认：

- [ ] 零编译错误（`getDiagnostics` 通过）
- [ ] 无 `TextEditingController` 内存泄漏
- [ ] 无硬编码颜色（使用 `context.xxx` 主题扩展）
- [ ] 无硬编码用户可见文本（使用 `wording.xxx`）
- [ ] 新增字符串已写入三个 arb 文件并运行 `flutter gen-l10n`
- [ ] 新增 API 已在 `ApiService` 注册
- [ ] 新增路由已在 `RouteNames` 和 `app_pages.dart` 注册
- [ ] 新增 Mock 数据已在 `MockDataRegistry` 注册
- [ ] 单个 Widget 方法不超过 50 行（超出则拆分为独立 Widget）
- [ ] 单个文件不超过 300 行（超出则按职责拆分）
- [ ] 需要 dispose 的对象使用 `StatefulWidget`
- [ ] 未使用 `wording.dart` extension 绕过 arb 流程

---

## 10. 大文件拆分规范

**原则：单个文件超过 300 行时，必须评估是否需要拆分。**

### 10.1 触发条件

| 文件类型 | 拆分阈值 | 拆分方式 |
|---------|---------|---------|
| Controller | > 300 行 | 按职责拆分为 mixin |
| Page/Widget | > 200 行 | 拆分为独立 Widget 类 |
| Model | 一类一文件 | 每个实体类单独一个文件，文件名与类名对应 |
| API | > 200 行 | 按功能分组拆分 |
| arb / 多语言 | > 500 key | 按模块拆分（见 10.2） |

### 10.2 多语言文件拆分（arb 文件过大时）

当 arb 文件 key 数量超过 500 时，按模块拆分为独立 arb 文件，通过 `flutter gen-l10n` 的 `synthetic-package` 或分目录方式管理。

**当前状态**：`intl_en.arb` 约 1100 key，已接近需要拆分的阈值。建议在下一个重构 issue 中按模块拆分：

```
lib/l10n/
├── common/
│   ├── intl_en.arb    # 通用字符串（按钮、状态、提示等）
│   └── intl_zh.arb
├── receive/
│   ├── intl_en.arb    # 收货模块字符串
│   └── intl_zh.arb
├── pick/
│   ├── intl_en.arb    # 拣货模块字符串
│   └── intl_zh.arb
└── ...
```

### 10.3 Controller 拆分示例

```dart
// ✅ 正确：mixin 拆分
class PickStepController extends GetxController
    with PickLocationMixin, PickItemMixin, PickSubmitMixin, PickProgressMixin {
  // 主 Controller 只保留初始化和状态机核心逻辑
}

mixin PickLocationMixin on GetxController {
  // 位置相关：scanLocation / overrideLocation / skipLocation
}

mixin PickItemMixin on GetxController {
  // 物品相关：scanItem / scanLp / updateEntireLpPick
}
```

### 10.4 Page 拆分示例

```dart
// ✅ 正确：每个区域独立 Widget
class ReturnInventoryPage extends StatefulWidget { ... }
class _ScanSection extends StatelessWidget { ... }        // 扫码区域
class _InventoryListSection extends StatelessWidget { ... } // 列表区域
class _ReturnWorkSection extends StatelessWidget { ... }  // 工作区域
class _ItemInfoCard extends StatelessWidget { ... }       // 物品信息卡片
class _ReturnQtyCard extends StatelessWidget { ... }      // 数量调整卡片

// ❌ 错误：一个方法包含所有 UI
Widget _buildAll(BuildContext context) {
  // 200+ 行...
}
```

---

## 11. 文档规范

### 10.1 Issue 文档结构

参考 `apple-project-ai-log/allen/WISE2018-34808/` 的格式：

```
apple-project-ai-log/allen/<ISSUE-ID>/
├── README.md                        # 项目概述
├── SUBMISSION_REPORT.md             # 提交报告
├── planning-artifacts/
│   ├── PRD.md                       # 产品需求文档
│   ├── epics-overview.md            # Epic 总览
│   └── epic-N-<name>.md             # 各 Epic 详情
└── implementation-artifacts/
    ├── PROGRESS.md                  # 实施进度（含 Bug 修复记录）
    └── stories/
        └── story-N-N-<name>.md      # Story 实施记录（含 Dev Agent Record）
```

### 10.2 Quick 模式命名

Quick 模式执行的 issue，目录名加 `-Quick` 后缀：

```
WISE2018-35381-Quick/   ← Quick 模式
WISE2018-35382/         ← 正常模式
```

### 10.3 Story 实施记录必填字段

```markdown
## Dev Agent Record

**Agent Model Used**: Claude Sonnet 4.6
**Completion Notes**:
- 关键决策说明
**File List**:
- lib/module/xxx/xxx.dart
```

---

## 11. 禁止事项汇总

| 禁止 | 原因 |
|------|------|
| 手动修改 `app_localizations*.dart` | 生成文件，会被覆盖 |
| 在 `wording.dart` 中用 extension 绕过 arb | 绕过统一管理，造成字符串分散 |
| `GetView` 中持有 `TextEditingController` | 内存泄漏 |
| `Obx` 内 `TextEditingController(text: ...)` | 每次 rebuild 新建 |
| 硬编码颜色 `Color(0xFF...)` | 不支持主题切换 |
| 手写 `Container + BoxDecoration` 实现标签 | 应使用 `StatusBadge`，避免颜色不一致和主题适配问题 |
| `StatusBadge(solid: false)` 时用 `Colors.white` 文字 | 浅色背景上白字不可见 |
| 硬编码用户可见文本 | 不支持多语言 |
| Mock 函数使用带参数形式 | `MockDataProvider` 调用可能失败 |
| 单方法超过 100 行 | 违反单一职责 |
| 单文件超过 300 行不拆分 | 可维护性差，AI 操作不稳定 |
| 使用 `S.current.xxx` | 已废弃的多语言方案 |
| 直接修改 `app_localizations.dart` 抽象类 | 大文件，AI 操作不稳定，且会被覆盖 |

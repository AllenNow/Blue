# BLE-888 - LX-PD02 蓝牙 SDK（Blue SDK）

**项目**: Blue SDK - LX-PD02 智能药盒蓝牙通信 SDK  
**开发者**: Allen  
**开发时间**: 2026-05-07  
**状态**: Epic 1 完成，Epic 2~7 代码实现完成，待硬件联调

---

## 📋 项目概述

为 LX-PD02 智能药盒硬件设计的移动端原生蓝牙通信与控制 SDK，同步支持 Android 和 iOS 双平台。SDK 完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API，使第三方开发者无需了解底层帧结构、CRC 校验、密钥认证等协议细节，即可快速构建具备完整用药提醒闭环能力的移动应用。

### 核心功能
- 🔵 BLE 设备扫描与连接管理（自动重连、指数退避）
- 🔐 密钥认证（手机 MAC + 设备 MAC 累加算法）
- ⏰ 闹钟管理（7 个槽位，设置/删除/清空）
- 💊 用药事件接收（响铃/超时/取药/漏服/提前取药）
- 📋 用药记录上报（含时间戳）
- 🔊 音频与系统设置（音量/铃声/静音/时间格式）
- 📝 日志系统（分级日志 + 可插拔处理器 + 密钥脱敏）

### 技术栈
- **iOS**: Swift 5.7+，CoreBluetooth，iOS 13.0+，CocoaPods + SPM
- **Android**: Kotlin 1.9+，Android BluetoothLE API，API Level 21+，Gradle
- **协议**: LX-PD02 私有二进制帧协议（帧头 0x55 0xAA，CRC8 校验）
- **测试（iOS）**: 65 tests（XCTest），100% passing
- **测试（Android）**: 待 Android Studio 编译验证

---

## 📁 文档结构

```
BLE-888/
├── README.md                        # 项目概述（本文件）
├── SUBMISSION_REPORT.md             # 提交报告
├── planning-artifacts/              # 规划文档
│   ├── prd.md                       # 产品需求文档（FR01~FR36，NFR01~NFR22）
│   ├── architecture.md              # 架构设计文档
│   └── epics.md                     # Epic & Story 拆解（7 个 Epic，29 个 Story）
└── implementation-artifacts/        # 实施文档
    ├── stories/                     # Story 实施记录
    │   ├── spec-1-1-ios-project-structure.md
    │   └── spec-1-2-ios-protocol-constants.md
    └── docs/                        # 技术文档
        ├── integration-guide-ios.md
        ├── integration-guide-android.md
        ├── api-reference.md
        ├── protocol-reference.md
        └── troubleshooting.md
```

---

## 📊 项目统计

### 文档统计
| 类型 | 数量 |
|:-----|:-----|
| 规划文档 | 3（PRD、架构、Epics）|
| Story 实施 | 2（已完成）|
| 技术文档 | 5 |
| 说明文档 | 2 |
| **总计** | **12** |

### 开发统计
| 指标 | 数值 |
|:-----|:-----|
| Epic 完成 | 1/7（Epic 1 代码完成）|
| Story 完成 | Epic 1 全部 8 个 Story |
| iOS 测试用例 | 65（100% passing）|
| Android 测试用例 | 待验证 |
| 功能需求覆盖 | 36/36 FR（100%）|
| 平台 | iOS + Android 双平台 |

---

## 🎯 Epic 进度

### ✅ Epic 1: SDK 基础设施与协议层（iOS 完成）
**Stories**: 8/8 完成
- ✅ S1.1: iOS 项目结构初始化（CocoaPods + SPM）
- ✅ S1.2: 协议常量定义（FrameConstants / CommandCode / DPIDConstants）
- ✅ S1.3: CRC8 计算器（13 个单元测试）
- ✅ S1.4: 帧构建器（9 个单元测试）
- ✅ S1.5: 帧解析器（10 个单元测试）
- ✅ S1.6: 错误类型与枚举定义（BlueError / ConnectionState / MedicationStatus 等）
- ✅ S1.7: 日志系统（BlueLogger + LogFormatter，密钥脱敏）
- ✅ S1.8: SDK 生命周期管理（initialize / destroy）

### 🔄 Epic 2: 设备发现与连接管理（代码完成，待联调）
- ✅ 代码实现：BLEScanner / BLEConnector / ConnectionManager（5 状态机）
- ⏳ 待硬件联调验证

### 🔄 Epic 3: 身份认证与安全绑定（代码完成，待联调）
- ✅ 代码实现：AuthManager（密钥算法验证通过）
- ⏳ 待硬件联调验证

### 🔄 Epic 4: 设备信息与时间同步（代码完成，待确认）
- ✅ 代码实现：DeviceManager
- ⚠️ 时间同步帧格式待硬件方确认（已加 TODO 备注）

### 🔄 Epic 5: 闹钟管理（代码完成，待联调）
- ✅ 代码实现：AlarmManager（7 个单元测试）
- ⏳ 待硬件联调验证

### 🔄 Epic 6: 用药事件与记录（代码完成，待联调）
- ✅ 代码实现：MedicationManager（8 个单元测试）
- ⏳ 待硬件联调验证

### 🔄 Epic 7: 音频与系统设置（代码完成，待联调）
- ✅ 代码实现：AudioManager
- ⏳ 待硬件联调验证

---

## 🐛 已知问题与待确认项

### ⚠️ 待硬件方确认

| # | 问题 | 位置 | 状态 |
|---|------|------|------|
| 1 | 时间同步帧格式（数据段字节数和字段定义） | DeviceManager.buildTimeSyncData() | ⏳ 待确认 |
| 2 | DPID 0x6E/0x6F/0x70 实际用途（文档注释与示例帧不一致） | DPIDConstants | ⏳ 待确认 |
| 3 | BLE GATT 服务/特征 UUID | BLEConnector | ⏳ 待确认 |

### ✅ 已修复问题

| # | 问题 | 修复 |
|---|------|------|
| 1 | AudioManager DPID 常量名称混乱（双平台） | 重命名常量，以示例帧为准 |
| 2 | iOS handleDeviceReport 中 alarm3 死代码 | 合并到闹钟范围判断，按内容区分 |
| 3 | Android 同样的 DPID 路由死代码 | 同步修复 |
| 4 | MedicationManager 解析逻辑 alarmDPID 字段偏移错误 | 修正为从 data[0] 和 data[4] 读取 |

---

## 📚 技术文档

### 1. integration-guide-ios.md
iOS 集成指南：CocoaPods/SPM 集成、权限配置、初始化、完整使用示例

### 2. integration-guide-android.md
Android 集成指南：Gradle 集成、权限配置、初始化、完整使用示例

### 3. api-reference.md
完整 API 参考：BlueSDK 所有公开方法、BlueSDKDelegate/Listener 所有回调、数据模型、枚举类型

### 4. protocol-reference.md
协议参考：帧格式、CMD 命令字、DPID 功能字节、CRC8 算法、密钥算法

### 5. troubleshooting.md
常见问题排查：连接失败、认证失败、指令超时、权限问题、平台兼容性

### 6. privacy-policy.md
SDK 隐私政策说明：数据处理行为、权限用途、集成方责任、合规要求

### 7. permission-manifest.md
权限清单：iOS/Android 完整权限配置、运行时申请代码、隐私合规检查清单

---

## ✅ 验收标准

### 功能验收
- [x] BLE 设备扫描与连接
- [x] 密钥认证
- [x] 闹钟管理（7 槽位）
- [x] 用药事件接收
- [x] 用药记录上报
- [x] 音频与系统设置
- [x] 日志系统（含密钥脱敏）
- [x] SDK 生命周期管理
- [ ] 硬件联调验证（待进行）

### 质量验收
- [x] iOS 测试覆盖率：65 tests，100% passing
- [x] Android 测试文件已编写（待 Android Studio 验证）
- [x] 协议帧 CRC8 算法验证（6 个真实帧数据验证）
- [x] 密钥算法验证（协议文档示例验证）
- [x] 零第三方依赖（NFR19）
- [x] 密钥不输出明文（NFR06/NFR07）

### 代码质量
- [x] 三层架构（Public API / Business Logic / BLE Transport）
- [x] 双平台 API 对称（命名、枚举、数据模型）
- [x] 所有公开 API 有中文注释
- [x] 所有异常转换为 BlueError，不向上抛出
- [x] 所有回调在主线程派发

---

## 📞 联系方式

- **开发者**: Allen
- **Issue**: BLE-888
- **项目**: Blue SDK（LX-PD02 智能药盒蓝牙 SDK）

---

**文档版本**: 1.0  
**创建日期**: 2026-05-07  
**最后更新**: 2026-05-07  
**状态**: Epic 1 完成，Epic 2~7 代码实现完成，待硬件联调

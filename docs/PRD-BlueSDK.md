# BlueSDK 产品需求文档 (PRD)

## 1. 产品概述

BlueSDK 是专为 LX-PD02 智能药盒设计的蓝牙 BLE 通信 SDK，向上层 APP 提供简洁的高层 API，封装底层协议细节。

**目标设备**：LX-PD02 智能药盒（广播名前缀 `LX-PD02-XXXX`）
**通信方式**：Bluetooth 5.0 BLE
**GATT 配置**：Service UUID `D459`，Write Char `0013`，Notify Char `0014`

---

## 2. SDK 核心功能

### 2.1 生命周期管理
| API | 功能 |
|-----|------|
| `initialize()` | 初始化 SDK（≤100ms） |
| `destroy()` | 销毁 SDK，释放资源 |
| `setLogLevel(level)` | 设置日志级别(none/error/warn/info/debug) |
| `setLogHandler(handler)` | 自定义日志处理器 |

### 2.2 连接管理
| API | 功能 |
|-----|------|
| `checkPermissions()` | 查询蓝牙权限状态 |
| `startScan(onFound, onError)` | 扫描 LX-PD02 设备 |
| `stopScan()` | 停止扫描 |
| `connect(device)` | 连接设备（自动认证） |
| `disconnect()` | 断开连接 |
| `clearBinding()` | 清除本地绑定密钥 |
| `connectionState` | 当前连接状态 |

**连接状态机**：
```
DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
                    ↓                         ↓
              RECONNECTING ←──────────────────┘ (异常断开)
```

**自动认证流程**：
1. 连接成功后自动发起
2. `phoneMac`：从 Keychain/SharedPreferences 读取（首次用 UUID 生成并存储）
3. `deviceMac`：从 peripheral/BluetoothDevice UUID 前6字节提取
4. 密钥算法：12字节全部累加取16-bit总和 → 2字节
5. 15秒连接超时

**自动重连**：指数退避 2s/4s/8s，最多5次

### 2.3 认证
| API | 功能 |
|-----|------|
| `authenticate(phoneMac, deviceMac)` | 手动认证 |
| `authenticateWithKey(keyHigh, keyLow)` | 使用指定密钥直接认证 |

### 2.4 设备信息与时间同步
| API | 功能 |
|-----|------|
| `queryDeviceInfo()` | 查询设备MAC和固件版本 |
| `syncTime(date)` | 下发时间（fire-and-forget） |

**时间同步格式（11字节）**：
`[0x00][0x00][年偏移(从2018)][月][日][时][分][秒][星期(1=周一~7=周日)][时区高][时区低]`

### 2.5 闹钟管理（7个槽位）
| API | 功能 |
|-----|------|
| `setAlarm(index, hour, minute, weekMask)` | 设置闹钟 |
| `deleteAlarm(index)` | 删除闹钟 |
| `clearAllAlarms()` | 清空所有闹钟 |

**闹钟帧格式（11字节）**：
`[DPID][0x00][0x00][0x07][使能][小时][分钟][周掩码][0x00][0x00][0x00]`

**周掩码**：bit0=周一, bit1=周二, ..., bit6=周日，0x7F=每天

### 2.6 用药事件
| API | 功能 |
|-----|------|
| `sendMedicationNotification(status)` | 下发用药结果通知 |

**上报事件**：闹钟响铃、超时、用药结果、用药记录

### 2.7 音频与系统设置
| API | DPID | 功能 |
|-----|------|------|
| `setVolume(level)` | 0x6E | 音量（01低/02中/03高） |
| `setSoundType(type)` | 0x6F | 铃声类型（01=A/02=B/03=C） |
| `setAlertDuration(minutes)` | 0x70 | 提醒持续时间 |
| `setTimeFormat(format)` | 0x73 | 时制（0=12H/1=24H） |
| `setSilence(enabled)` | 0x74 | 静音开关 |
| `restoreFactory()` | 0x76 | 恢复出厂设置 |

---

## 3. 事件回调（Delegate/Listener）

| 回调 | 触发时机 |
|------|---------|
| `didChangeConnectionState` | 连接状态变化 |
| `didAuthenticateWithSuccess` | 认证结果 |
| `didRequestTimeSync` | 设备请求时间同步 |
| `didUpdateAlarm` | 设备端闹钟变更 |
| `didAlarmRinging` | 闹钟开始响铃 |
| `didAlarmTimeout` | 超时未取药 |
| `didReceiveMedicationResult` | 用药结果 |
| `didReceiveMedicationRecord` | 用药记录上报 |
| `didChangeSoundType` | 铃声类型变更 |
| `didChangeTimeFormat` | 时间格式变更 |
| `didReportLowBattery` | 低电上报 |
| `didEncounterError` | 连接错误 |

---

## 4. 协议帧结构

```
[0x55][0xAA][版本=0x00][CMD][Len高][Len低][Data...][CRC8]
```

**CRC8**：从帧头第一字节累加和对256求余

| CMD | 方向 | 功能 |
|-----|------|------|
| 0x00 | 下行 | 密钥认证 |
| 0x01 | 下行 | 查询设备信息 |
| 0x06 | 下行 | APP下发指令 |
| 0x07 | 上行 | 设备上报/应答 |
| 0xE1 | 双向 | 时间同步 |

---

## 5. Demo App 功能

### 5.1 主页（紧凑单页布局）
- 连接状态卡片（状态点+文字+扫描/断开按钮）
- 全屏 Loading 遮罩（可取消）
- 快捷操作行：设备信息、同步时间、闹钟管理
- 音频设置卡片：铃声/音量/时制/静音/持续时间
- 工具入口：用药记录、指令验证
- 系统操作：恢复出厂、清除绑定、旧密钥认证
- 实时日志窗口（SDK 所有收发数据）
- Dark/Light Mode 适配

### 5.2 闹钟管理页
- 7个槽位列表（显示时间、周期、状态标签）
- 点击进入编辑（时间选择器+周重复按钮）
- 左滑删除、清空全部

### 5.3 用药记录页
- 日历选择日期查询
- 全部记录列表
- SQLite 持久化存储
- 清空功能

### 5.4 协议验证页
- 15条自动化测试用例
- 逐条执行，失败跳过继续
- 实时收发帧日志窗口（黑底绿字）
- 结果统计

---

## 6. 内部架构

### 6.1 传输层
- `BLECentralManager`：CBCentralManager 单例（iOS）
- `BLEScanner`：设备扫描（过滤前缀 LX-PD02）
- `BLEConnector`：GATT 连接/数据收发
- `StreamFrameParser`：粘包/分包处理（1024字节缓冲）
- `FrameBuilder`/`FrameParser`：帧构建/解析
- `CRC8Calculator`：校验计算

### 6.2 指令队列
- FIFO 串行队列
- 5秒超时，最多重试3次
- 200ms 最小发送间隔
- DPID 匹配（CMD=0x06→0x07 应答需匹配 DPID，避免上报帧误消费）
- `sendDirect`：不入队直接发送（时间同步用）

### 6.3 数据持久化
- `phoneMac`：Keychain（iOS）/ SharedPreferences（Android）
- 用药记录：SQLite（Demo App 层）

---

## 7. DPID 映射表（以帧示例为准）

| DPID | 实际用途 | 帧格式 |
|------|---------|--------|
| 0x65 | 用药记录上报 | 15字节 |
| 0x66~0x6C | 闹钟1~7 | 11字节 |
| 0x6D | 铃声上报（设备→APP） | 5字节 |
| 0x6E | 音量设置（APP→设备） | `6E 04 00 01 XX` |
| 0x6F | 铃声类型设置（APP→设备） | `6F 04 00 01 XX` |
| 0x70 | 提醒持续时间（APP→设备） | `70 02 00 04 00 00 00 XX` |
| 0x73 | 时制 | `73 04 00 01 XX` |
| 0x74 | 静音 | `74 04 00 01 XX` |
| 0x75 | 低电上报 | — |
| 0x76 | 恢复出厂 | `76 01 00 01 01` |

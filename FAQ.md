# BlueSDK 常见问题 (FAQ)

---

## 连接 / Connection / Verbindung

### 扫描不到设备怎么办？

1. 确认设备已开机且蓝牙指示灯闪烁
2. 确认手机蓝牙已开启
3. Android 6~11 需要开启位置服务（系统限制）
4. Android 12+ 需要授予 BLUETOOTH_SCAN 权限
5. iOS 需要在 Info.plist 中声明 NSBluetoothAlwaysUsageDescription
6. 确认设备在手机 3 米范围内
7. 如果之前连接过其他手机，需对设备恢复出厂
8. 尝试重启手机蓝牙后再扫描

### 认证失败是什么原因？

认证失败常见原因：
1. 设备已被其他手机绑定 → 对设备恢复出厂，调用 clearBinding()
2. fixedAuthKey 错误 → 确认为4位十六进制或设为null自动计算
3. 固件不兼容 → queryDeviceInfo() 查看版本

### 连接后自动断开是怎么回事？

常见原因：
1. 认证失败后 SDK 自动断开
2. 设备电量不足
3. 距离过远（>3米）或有障碍物
4. 华为/小米省电策略杀后台（Android）
5. iOS 后台被系统回收

SDK 自动重连（最多5次，间隔2s/4s/8s）。

### 华为手机扫描不到设备？

Android 6~11 需要开启「位置服务」才能 BLE 扫描（系统限制）。
解决：扫描前检查位置服务，提示用户开启GPS。

### 小米手机后台断连？

MIUI「省电优化」会杀后台蓝牙。需要：
1.「自启动管理」允许 APP
2.「电量和性能」关闭省电优化
3. 锁定在最近任务列表

### 如何在后台保持连接？（iOS）

iOS 后台 BLE 连接需要：
1. 在 Info.plist 的 UIBackgroundModes 中添加 bluetooth-central
2. 使用 Core Bluetooth 的状态恢复机制

注意：即使配置了后台模式，系统仍可能在内存压力时终止连接。

### 设备同时只能连一台手机吗？

是的。LX-PD02 采用绑定机制，认证成功后设备会记住手机密钥。
- 同一时间只能有一台手机连接
- 如需换手机使用，需先对设备恢复出厂设置
- 恢复后旧手机调用 clearBinding() 清除本地密钥

### 如何判断设备是否在线？

SDK 提供 `connectionState` 属性实时查询：
- `AUTHENTICATED` = 在线且可操作
- `CONNECTING` / `CONNECTED` = 正在连接中
- `DISCONNECTED` = 离线

也可通过短时扫描（5秒）检测设备是否在蓝牙范围内。

---

## 闹钟 / Alarm

### 最多能设置几个闹钟？

LX-PD02 支持最多 7 个闹钟槽位（index 1~7）。
每个可独立设置时间和重复周期（WeekDays）。

### 批量设置闹钟会覆盖已有的吗？

是的。setAlarms() 按索引逐个设置，已有闹钟会被覆盖。
追加闹钟：先 queryAlarm() 找空闲槽位（isDeleted=true）。

### 闹钟时间设为 0:00 有效吗？

有效。0:00 表示午夜（凌晨 12 点整）。
- 有效范围：hour 0~23, minute 0~59
- 无效值（如 hour=24 或 minute=60）SDK 会自动校正为 23:59
- 闹钟还有启用/禁用开关（isEnabled），禁用后不触发

---

## 用药 / Medication

### 用药事件有哪几种状态？

MedicationStatus 有 4 种：
- TAKEN (0x01) — 按时取药
- TIMEOUT (0x02) — 超时取药
- MISSED (0x03) — 漏服
- EARLY (0x04) — 提前取药

### 设备断线后用药记录会丢失吗？

不会。设备本地缓存记录，重连后自动上报。
建议 APP 使用 SQLite 持久化存储。

---

## 音频 / Audio

### 铃声和静音是什么关系？

静音 = 设置铃声类型为 MUTE(0x00)。
- setSilence(true) = setSoundType(MUTE)
- setSilence(false) = setSoundType(TYPE_A)

---

## 设备 / Device

### 如何切换 12/24 小时制？

调用 setTimeFormat 即可切换：
- `sdk.setTimeFormat(TimeFormat.HOUR_12)` — 12 小时制
- `sdk.setTimeFormat(TimeFormat.HOUR_24)` — 24 小时制

切换后：
- SDK 内部 `currentTimeFormat` 属性自动更新
- 设备上报 `onTimeFormatChanged` 回调
- 界面应跟随此值显示时间（AM/PM 或 24H 格式）

### 恢复出厂设置后需要做什么？

1. 设备断开蓝牙
2. 设备清除所有闹钟和配对信息
3. APP 调用 clearBinding()
4. 重新扫描连接
注意：不可逆操作。

---

## SDK

### 多个指令可以连续调用吗？

可以。SDK 内部 CommandQueue 自动串行排队。
- 同时只有一条指令等待应答
- 间隔至少 200ms
- 超时 5 秒，重试最多 3 次

### SDK 初始化耗时多久？

initialize() < 100ms，仅内存初始化。
建议在 Application.onCreate()（Android）或 AppDelegate（iOS）中调用一次。

### 如何调试 BLE 通信问题？

1. 初始化时设置 `rawFrameLogEnabled = true` 开启帧日志
2. `setLogHandler { }` 自定义处理器
3. `exportLog()` 导出最近 1000 条

### SDK 使用了哪些第三方依赖？

**零依赖**。SDK 仅使用平台原生蓝牙框架（Android BluetoothGatt / iOS CoreBluetooth），不引入任何第三方库。

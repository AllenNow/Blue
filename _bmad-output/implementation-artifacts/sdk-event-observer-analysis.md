# SDK 事件监听机制分析报告

## 结论

✅ **任意地方都可以监听** — 任何实现了协议/接口的对象都可以注册为观察者  
✅ **支持任意多个监听者** — 多播机制，无数量限制  
✅ **双端实现合理** — 各自使用平台惯用技术，线程安全

---

## 架构概览

```
┌─────────────────────────────────────────────┐
│               BlueSDK 单例                   │
│                                             │
│  BLE 设备上报事件                            │
│       ↓                                     │
│  notifyObservers { ... }                    │
│       ↓                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ delegate │  │observer 1│  │observer 2│  │
│  │ (主回调) │  │(闹钟页面)│  │(记录页面)│  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘
```

---

## iOS 实现

### 技术方案：NSHashTable 弱引用 + Protocol 默认实现

```swift
// SDK 内部
private var observers = NSHashTable<AnyObject>.weakObjects()

public func addObserver(_ observer: BlueSDKDelegate) {
    observers.add(observer as AnyObject)
}

public func removeObserver(_ observer: BlueSDKDelegate) {
    observers.remove(observer as AnyObject)
}

private func notifyObservers(_ block: (BlueSDKDelegate) -> Void) {
    if let d = delegate { block(d) }
    for obj in observers.allObjects {
        if let obs = obj as? BlueSDKDelegate { block(obs) }
    }
}
```

### 关键特性

| 特性 | 说明 |
|------|------|
| 引用方式 | **弱引用**（`NSHashTable.weakObjects()`），观察者被释放后自动从列表移除 |
| 内存安全 | 无需手动 `removeObserver`，不会造成内存泄漏（但推荐主动移除以明确生命周期） |
| 线程派发 | 所有回调通过 `CallbackDispatcher.shared.dispatch` 切到**主线程** |
| 协议设计 | `BlueSDKDelegate` 纯 Swift 协议 + extension 默认空实现，观察者只需实现关心的方法 |
| 兼容性 | 保留 `delegate` 属性（单 delegate）向后兼容，同时支持 `addObserver` 多播 |

### 使用方式

```swift
// 任何 ViewController / Manager / Service 都可以监听
class AlarmManagerViewController: UIViewController, BlueSDKDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        BlueSDK.shared.addObserver(self)  // 注册
    }
    
    // 只实现关心的方法，其他方法有默认空实现
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo) {
        // 实时更新 UI
    }
}
```

### 合理性评估

| 维度 | 评价 |
|------|------|
| 平台惯例 | ✅ `NSHashTable.weakObjects()` 是 Apple 推荐的多播弱引用容器 |
| 内存管理 | ✅ 弱引用自动清理，不需要 `deinit` 中手动移除 |
| 性能 | ✅ `allObjects` 遍历 O(n)，对于 BLE SDK 场景（通常 <10 个观察者）完全足够 |
| 线程安全 | ⚠️ `NSHashTable` 本身非线程安全，当前在主线程操作可接受。如果未来多线程 add/remove 需要加锁 |

---

## Android 实现

### 技术方案：synchronized MutableList + Interface 默认实现

```kotlin
// SDK 内部
private val observers = mutableListOf<BlueSDKListener>()

fun addObserver(observer: BlueSDKListener) {
    synchronized(observers) { if (!observers.contains(observer)) observers.add(observer) }
}

fun removeObserver(observer: BlueSDKListener) {
    synchronized(observers) { observers.remove(observer) }
}

private fun notifyObservers(block: (BlueSDKListener) -> Unit) {
    listener?.let { block(it) }
    synchronized(observers) { observers.toList() }.forEach { block(it) }
}
```

### 关键特性

| 特性 | 说明 |
|------|------|
| 引用方式 | **强引用**（`MutableList`），必须在 `onDestroy` 中调用 `removeObserver` |
| 线程安全 | `synchronized` 保护列表操作；`toList()` 复制后遍历避免 ConcurrentModification |
| 线程派发 | 所有回调通过 `CallbackDispatcher.dispatch` 切到**主线程** |
| 接口设计 | `BlueSDKListener` interface + 默认空方法体，观察者只需 override 关心的方法 |
| 去重 | `contains` 检查防止重复注册 |
| 兼容性 | 保留 `listener` 属性（单 listener）向后兼容，同时支持 `addObserver` 多播 |

### 使用方式

```kotlin
class AlarmManagerActivity : AppCompatActivity() {
    private val alarmObserver = object : BlueSDKListener {
        override fun onAlarmUpdated(alarm: AlarmInfo) {
            runOnUiThread { /* 实时更新 UI */ }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sdk.addObserver(alarmObserver)  // 注册
    }
    
    override fun onDestroy() {
        super.onDestroy()
        sdk.removeObserver(alarmObserver)  // 必须移除，否则内存泄漏
    }
}
```

### 合理性评估

| 维度 | 评价 |
|------|------|
| 平台惯例 | ✅ Android 中 `synchronized + MutableList` 是标准多播模式（EventBus、LiveData 内部类似） |
| 内存管理 | ⚠️ 强引用，必须手动 `removeObserver`。如果忘记会导致 Activity 泄漏 |
| 性能 | ✅ `toList()` 复制开销极小（通常 <10 个元素） |
| 线程安全 | ✅ `synchronized` 保证 add/remove/iterate 互斥 |
| 改进空间 | 可考虑改用 `WeakReference` 包装或 `CopyOnWriteArrayList` 简化代码 |

---

## 双端对比

| 维度 | iOS | Android |
|------|-----|---------|
| 容器类型 | `NSHashTable<AnyObject>.weakObjects()` | `MutableList<BlueSDKListener>` |
| 引用方式 | 弱引用（自动回收） | 强引用（需手动移除） |
| 线程安全 | 依赖主线程操作 | `synchronized` 显式加锁 |
| 去重机制 | `NSHashTable` 自带（基于对象 identity） | `contains` 检查 |
| 是否需要 removeObserver | 推荐但非必须 | **必须**（否则内存泄漏） |
| 回调线程 | 主线程（CallbackDispatcher） | 主线程（CallbackDispatcher） |
| 方法可选性 | protocol extension 默认空实现 | interface 默认空方法体 |

---

## 当前已注册的观察者

| 观察者 | 监听事件 | 平台 |
|--------|---------|------|
| ViewController / MainActivity | 全部事件（主 delegate/listener） | 双端 |
| AlarmManagerViewController / Activity | `didUpdateAlarm` / `onAlarmUpdated` | 双端 |
| MedicationRecordsViewController / Activity | `didReceiveMedicationRecord` + `didReceiveMedicationResult` | 双端 |

---

## 第三方集成指引

集成方可以在 app 的任何位置添加观察者：

```swift
// iOS — 在 Service 层监听用药事件做数据上报
class MedicationSyncService: BlueSDKDelegate {
    init() {
        BlueSDK.shared.addObserver(self)
    }
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord) {
        // 上报到服务器
    }
}
```

```kotlin
// Android — 在 Service 层监听连接状态做后台保活
class BleKeepAliveService : Service(), BlueSDKListener {
    override fun onCreate() {
        super.onCreate()
        BlueSDK.getInstance(this).addObserver(this)
    }
    override fun onConnectionStateChanged(state: ConnectionState) {
        // 连接断开时触发重连
    }
    override fun onDestroy() {
        BlueSDK.getInstance(this).removeObserver(this)
        super.onDestroy()
    }
}
```

---

## 改进建议（可选）

| # | 建议 | 优先级 | 说明 |
|---|------|--------|------|
| 1 | Android 改用 `WeakReference` 包装 | 低 | 避免忘记 removeObserver 导致泄漏，但增加了 null 检查复杂度 |
| 2 | iOS 加 `os_unfair_lock` 保护 | 低 | 如果未来有后台线程 addObserver 的场景 |
| 3 | 增加 `observerCount` 属性 | 低 | 调试用，方便确认注册状态 |
| 4 | 支持按事件类型过滤注册 | 中 | 减少不必要的回调分发，但当前事件量极小，不急 |

---

## 总结

当前的多播 observer 机制：
- ✅ 任意对象、任意位置都可以注册监听
- ✅ 支持无限多个监听者
- ✅ 各平台使用惯用技术实现
- ✅ 主线程派发，UI 安全
- ✅ 向后兼容原有单 delegate/listener 模式
- ⚠️ Android 端需注意手动 removeObserver 防止内存泄漏

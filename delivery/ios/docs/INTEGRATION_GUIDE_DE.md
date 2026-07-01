# BlueSDK Integrationsanleitung

LX-PD02 Intelligente Pillendose Bluetooth-Kommunikations-SDK — iOS & Android Dual-Plattform-Integrationsdokument

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Systemanforderungen](#systemanforderungen)
- [Integrationsschritte](#integrationsschritte)
- [Berechtigungskonfiguration](#berechtigungskonfiguration)
- [Initialisierung](#initialisierung)
- [Scannen & Verbindung](#scannen--verbindung)
- [Authentifizierungsmechanismus](#authentifizierungsmechanismus)
- [API-Referenz](#api-referenz)
- [Ereignis-Callbacks](#ereignis-callbacks)
- [Fehlerbehandlung](#fehlerbehandlung)
- [Threading-Modell](#threading-modell)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Überblick

BlueSDK kapselt das proprietäre Bluetooth 5.0-Kommunikationsprotokoll des LX-PD02 vollständig. Integratoren müssen keine Low-Level-Rahmenstrukturen, CRC-Prüfungen, Schlüsselalgorithmen oder andere Details verstehen. Das SDK bietet eine einheitliche High-Level-API mit hochkonsistentem Schnittstellendesign auf beiden Plattformen (iOS/Android), was die plattformübergreifenden Wartungskosten reduziert.

**Kernfunktionen:**

| Funktion | Beschreibung |
|------|------|
| BLE-Scan & Verbindung | Automatische Wiederverbindung (exponentielles Backoff, bis zu 5 Versuche) |
| Schlüsselauthentifizierung | Automatisch berechnet oder fester Schlüssel, mit klaren Wiederherstellungsvorschlägen bei Auth-Fehler |
| Alarmverwaltung | 7-Slot CRUD, unterstützt wiederkehrende Zeitpläne |
| Medikationsereignisse | Echtzeit-Empfang von Klingeln/Timeout/Einnahme/Versäumnis-Ereignissen |
| Medikationsaufzeichnungen | Gerät meldet proaktiv vollständige Aufzeichnungen mit Millisekunden-Zeitstempeln |
| Audio-Systemeinstellungen | Lautstärke/Klingelton/Stumm/Dauer/12H-24H-Zeitformat |
| Geräteverwaltung | Geräteinfo-Abfrage/Zeitsynchronisation/Werksreset/Entkopplung |
| Protokollierungssystem | Gestufte Protokollierung, Schlüsselwert-Maskierung, Export-Unterstützung |

---

## Systemanforderungen

| Plattform | Mindestversion | Sprache | Bluetooth |
|------|---------|------|------|
| Android | API 21 (5.0+) | Kotlin 1.9+ | BLE 5.0+ |
| iOS | 13.0+ | Swift 5.7+ | BLE 5.0+ |

---

## Integrationsschritte

### Android

**Option A: Lokale AAR**

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

**Option B: Modulabhängigkeit (Entwicklungsphase)**

```kotlin
// settings.gradle.kts
include(":blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

### iOS

**CocoaPods**

```ruby
pod 'BlueSDK', :path => '../blue-sdk-ios/BlueSDK'
```

**SPM**

```swift
.package(path: "../blue-sdk-ios")
```

---

## Berechtigungskonfiguration

### Android — AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

### iOS — Info.plist

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接智能药盒设备</string>

<!-- 可选：后台接收用药事件 -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Initialisierung

### Android

```kotlin
// Application.onCreate() 中调用一次
val config = BlueSDKConfig(
    fixedAuthKey = null,           // 固定密钥（4位hex），null=自动计算
    logLevel = LogLevel.DEBUG,     // 生产环境用 LogLevel.NONE
    autoAuthEnabled = true,        // 连接成功后自动认证
    autoReconnect = true,          // 断线后自动重连
    maxReconnectAttempts = 5,      // 最大重连次数
    language = BlueSDKLanguage.SYSTEM,  // 多语言：SYSTEM/ZH/EN/DE
    customPhoneMac = null,         // 自定义手机标识（12位hex），null=自动生成
    rawFrameLogEnabled = false     // 是否输出 BLE 收发帧原始数据
)
BlueSDKManager.getInstance(this).initialize(config)
```

### iOS

```swift
// AppDelegate didFinishLaunching 中调用
let config = BlueSDKConfig(
    fixedAuthKey: nil,
    logLevel: .debug,
    autoAuthEnabled: true,
    autoReconnect: true,
    maxReconnectAttempts: 5,
    language: .system,             // 多语言：.system/.zh/.en/.de
    customPhoneMac: nil,
    rawFrameLogEnabled: false      // true 时输出 TX/RX 帧数据
)
BlueSDKManager.shared.initialize(config: config)
```

### Konfigurationsparameter

| Parameter | Typ | Standardwert | Beschreibung |
|------|------|--------|------|
| `fixedAuthKey` | String? | null | Fester Authentifizierungsschlüssel (4-stellig hex z.B. "05FA"), null für automatische Berechnung |
| `logLevel` | LogLevel | DEBUG | Protokollierungsebene: DEBUG/INFO/WARN/ERROR/NONE |
| `autoAuthEnabled` | Boolean | true | Ob nach erfolgreicher Verbindung automatisch authentifiziert werden soll |
| `autoReconnect` | Boolean | true | Ob nach unerwarteter Trennung automatisch wiederverbunden werden soll |
| `maxReconnectAttempts` | Int | 5 | Maximale Anzahl automatischer Wiederverbindungsversuche |
| `language` | BlueSDKLanguage | SYSTEM | Sprache der Fehlerbeschreibungen: SYSTEM/ZH/EN/DE |
| `customPhoneMac` | String? | null | Benutzerdefinierte Telefonkennung (12-stellig hex), wird für Schlüsselberechnung verwendet |
| `rawFrameLogEnabled` | Boolean | false | Ob rohe BLE-Frame-Hex-Daten ausgegeben werden sollen (zum Debuggen) |

---

## Scannen & Verbindung

### Android

```kotlin
val sdk = BlueSDKManager.getInstance(context)

sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            // event.device 包含 deviceId, deviceName, rssi
            sdk.connect(event.device)  // SDK 自动完成认证
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* error.message */ }
        is ScanEvent.Stopped -> { /* 超时或手动停止 */ }
    }
}
```

### iOS

```swift
BlueSDKManager.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDKManager.shared.connect(device)
        BlueSDKManager.shared.stopScan()
    case .error(let error):
        print(error.localizedDescription)
    case .stopped:
        break
    }
}
```

---

## Authentifizierungsmechanismus

Das SDK unterstützt zwei Authentifizierungsmodi:

| Modus | Konfiguration | Beschreibung |
|------|------|------|
| Automatische Authentifizierung | `fixedAuthKey = null` | SDK berechnet den Schlüssel automatisch aus Telefon-MAC + Geräte-MAC |
| Fester Schlüssel | `fixedAuthKey = "05FA"` | Verwendet einen voreingestellten 4-stelligen Hex-Schlüssel |

Nach erfolgreicher Verbindung **initiiert das SDK automatisch die Authentifizierung** — kein manueller Aufruf erforderlich. Authentifizierungsergebnisse werden über Callbacks geliefert:

```kotlin
// Android
override fun onAuthResult(success: Boolean, error: BlueError?) { }

// iOS
func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
```

---

## API-Referenz

Alle Geschäfts-APIs müssen nach dem `AUTHENTICATED`-Status aufgerufen werden; andernfalls wird ein `NotAuthenticated`-Fehler zurückgegeben.

### Lebenszyklus

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Initialisieren | `initialize(config)` | `initialize(config:)` | Einmal auf Application-Ebene aufrufen |
| Zerstören | `destroy()` | `destroy()` | BLE-Ressourcen freigeben |

### Verbindungsverwaltung

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Geräte scannen | `startScan(timeoutMs, callback)` | `startScan(timeout:callback:)` | Einheitlicher ScanEvent-Callback |
| Scan stoppen | `stopScan()` | `stopScan()` | |
| Gerät verbinden | `connect(device)` | `connect(device)` | Authentifiziert automatisch nach Verbindung |
| Trennen | `disconnect()` | `disconnect()` | Manuelles Trennen löst keine Wiederverbindung aus |
| Wiederverbindung abbrechen | `cancelReconnection()` | `cancelReconnection()` | |
| Gerät entkoppeln | `clearBinding(completion)` | `clearBinding(completion:)` | Sendet Entkopplungsbefehl + trennt |
| Mit Schlüssel authentifizieren | `authenticateWithKey(hi, lo, cb)` | `authenticateWithKey(keyHigh:keyLow:completion:)` | |
| Berechtigungen prüfen | `checkPermissions()` | `checkPermissions()` | Gibt PermissionStatus zurück |
| Verbindungsstatus | `connectionState` (Eigenschaft) | `connectionState` (Eigenschaft) | |
| Aktuelles Zeitformat | `currentTimeFormat` (Eigenschaft) | `currentTimeFormat` (Eigenschaft) | Folgt Geräteeinstellungen |
| Observer hinzufügen | `addObserver(observer)` | `addObserver(_:)` | Mehrere Seiten können gleichzeitig zuhören |
| Observer entfernen | `removeObserver(observer)` | `removeObserver(_:)` | |
| UUID-Direktverbindung | — | `connect(byIdentifier:completion:)` | iOS: Schnelle Wiederverbindung für gebundene Geräte |
| Sprache wechseln | `setLanguage(language)` | `setLanguage(_:)` | Fehlerbeschreibungssprache zur Laufzeit wechseln |
| Schlüsselanzeige | `currentAuthKeyDisplay` (Eigenschaft) | `currentAuthKeyDisplay` (Eigenschaft) | Aktuell verwendeter Authentifizierungsschlüssel |

### Geräteinformationen & Zeit

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Geräteinfo abfragen | `queryDeviceInfo(completion)` | `queryDeviceInfo(completion:)` | MAC + Firmware-Version |
| Zeitsynchronisation | `syncTime(completion)` | `syncTime(completion:)` | Sendet aktuelle Systemzeit |

### Alarmverwaltung (7 Slots)

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Alarm setzen | `setAlarm(index, hour, minute, days, cb)` | `setAlarm(index:hour:minute:days:completion:)` | Typsichere Version |
| Stapelweise setzen | `setAlarms(list, completion)` | `setAlarms(_:completion:)` | Seriell gesendet |
| Alarm abfragen | `queryAlarm(index, completion)` | `queryAlarm(index:completion:)` | Einzelnen Slot abfragen |
| Alarm löschen | `deleteAlarm(index, completion)` | `deleteAlarm(index:completion:)` | |
| Alle löschen | `clearAllAlarms(completion)` | `clearAllAlarms(completion:)` | |

**Parametereinschränkungen:**
- `index`: 1~7
- `hour`: 0~23
- `minute`: 0~59
- `days`: `WeekDays`-Enum (`.ALL` / `.WEEKDAYS` / `.WEEKEND` / benutzerdefinierte Kombination)

### Audio- & Systemeinstellungen

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Lautstärke setzen | `setVolume(level, cb)` | `setVolume(_:completion:)` | LOW / MEDIUM / HIGH |
| Klingelton setzen | `setSoundType(type, cb)` | `setSoundType(_:completion:)` | TYPE_A / TYPE_B |
| Stummschalten | `setSilence(enabled, cb)` | `setSilence(_:completion:)` | true=stumm |
| Erinnerungsdauer | `setAlertDuration(minutes, cb)` | `setAlertDuration(_:completion:)` | 1~5 Minuten |
| Zeitformat | `setTimeFormat(format, cb)` | `setTimeFormat(_:completion:)` | HOUR_12 / HOUR_24 |
| Werkseinstellungen | `restoreFactory(completion)` | `restoreFactory(completion:)` | Gerät startet neu und trennt |

### Medikationsereignisse

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Medikationsbenachrichtigung senden | `sendMedicationNotification(status, cb)` | `sendMedicationNotification(status:completion:)` | |

### Protokollierung

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Ebene setzen | `setLogLevel(level)` | `setLogLevel(_:)` | DEBUG/INFO/WARN/ERROR/NONE |
| Benutzerdefinierter Handler | `setLogHandler(handler)` | `setLogHandler(_:)` | Integration in Ihr eigenes Protokollierungssystem |
| Protokoll exportieren | `exportLog(maxLines)` | `exportLog(maxLines:)` | Letzte 1000 Einträge |
| Puffer leeren | `clearLogBuffer()` | `clearLogBuffer()` | |

---

## Ereignis-Callbacks

### Android — `BlueSDKListener` interface

```kotlin
interface BlueSDKListener {
    // 连接
    fun onConnectionStateChanged(state: ConnectionState) {}
    fun onAuthResult(success: Boolean, error: BlueError?) {}
    fun onReconnecting(attempt: Int, maxAttempts: Int) {}
    fun onReconnectFailed() {}
    fun onError(error: BlueError) {}

    // 设备
    fun onDeviceInfoReceived(info: DeviceInfo) {}
    fun onTimeSyncRequested() {}

    // 闹钟
    fun onAlarmUpdated(alarm: AlarmInfo) {}
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    // 用药
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}
    fun onMedicationRecordReported(record: MedicationRecord) {}
    fun onMedicationNotification(type: MedicationNotificationType) {}

    // 系统设置
    fun onSoundTypeChanged(type: SoundType) {}
    fun onAlertDurationChanged(minutes: Int) {}
    fun onTimeFormatChanged(format: TimeFormat) {}
    fun onLowBattery() {}
    fun onDeviceUnbound() {}
}
```

### iOS — `BlueSDKDelegate` protocol

```swift
protocol BlueSDKDelegate {
    // 连接
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    // 设备
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // 闹钟
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    // 用药
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: MedicationNotificationType)

    // 系统设置
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)
    func blueSDK(_ sdk: BlueSDK, didChangeAlertDuration minutes: Int)
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)
}
```

> Alle Callback-Methoden haben standardmäßige leere Implementierungen; überschreiben Sie nur die, die Sie benötigen.

---

## Fehlerbehandlung

Alle asynchronen Operationen liefern Ergebnisse über `Result`-Callbacks — **es werden keine Exceptions geworfen**.

### Fehlertypen

| Fehler | Code | Wiederholbar | Beschreibung |
|------|------|--------|------|
| `NotInitialized` | 1 | ❌ | initialize() wurde nicht aufgerufen |
| `NotAuthenticated` | 2 | ❌ | Schlüsselauthentifizierung nicht abgeschlossen |
| `AuthFailed` | 3 | ❌ | Schlüssel stimmt nicht überein, Werksreset erforderlich |
| `Timeout` | 4 | ✅ | Befehlstimeout (SDK hat intern bereits 3 Mal wiederholt) |
| `PermissionDenied` | 5 | ❌ | Bluetooth-Berechtigung nicht erteilt |
| `InvalidParameter` | 6 | ❌ | Parameter außerhalb des gültigen Bereichs |
| `ProtocolError` | 7 | ✅ | CRC-Prüfung fehlgeschlagen, mögliche Bluetooth-Interferenz |
| `BleError` | 8 | ✅ | System-Bluetooth-Ausnahme |
| `Disconnected` | 9 | ✅ | Gerät getrennt, SDK wird automatisch wiederverbinden |
| `DeviceNotFound` | 10 | ❌ | Gerät nicht gefunden (nur iOS) |

### Verwendung von `isRetryable`

```kotlin
// Android
result.onFailure { error ->
    val blueError = error as BlueError
    if (blueError.isRetryable) {
        // 可安全重试（如 timeout、protocolError）
    } else {
        // 需用户干预（如 authFailed、permissionDenied）
        showError(blueError.message, blueError.recoverySuggestion)
    }
}
```

```swift
// iOS
case .failure(let error):
    if error.isRetryable {
        // 可安全重试
    } else {
        showAlert(error.localizedDescription, suggestion: error.recoverySuggestion)
    }
```

---

## Threading-Modell

| Regel | Beschreibung |
|------|------|
| Callback-Thread | **Alle Ereignis-Callbacks werden auf dem Hauptthread ausgeliefert** — kein manuelles Wechseln erforderlich |
| API-Aufrufe | Alle öffentlichen Methoden sind threadsicher und können von jedem Thread aufgerufen werden |
| Befehlswarteschlange | Interne FIFO-serielle Warteschlange — nur ein Befehl wartet gleichzeitig auf eine Antwort |
| Befehlsintervall | 200ms |
| Befehls-Timeout | 5 Sekunden, automatische Wiederholung bis zu 3 Mal |

---

## Best Practices

### 1. Verwenden Sie das Observer-Muster anstelle eines einzelnen Listeners

```kotlin
// 多个页面可同时监听事件
sdk.addObserver(alarmManagerObserver)
sdk.addObserver(medicationObserver)

// 页面销毁时移除
sdk.removeObserver(alarmManagerObserver)
```

### 2. Senden Sie Befehle erst nach erfolgreicher Authentifizierung

```kotlin
override fun onConnectionStateChanged(state: ConnectionState) {
    if (state == ConnectionState.AUTHENTICATED) {
        // 此时可安全调用业务接口
        sdk.syncTime { }
    }
}
```

### 3. Behandlung von Medikationsereignissen

```kotlin
// onMedicationResult — 实时事件（无时间戳）
// onMedicationRecordReported — 完整记录（含设定时间 + 实际时间）
// 建议：用 onMedicationRecordReported 入库，用 onMedicationNotification 做 UI 提醒
```

### 4. Zeitformat folgt dem Gerät

```kotlin
// 读取当前时制
val is24Hour = sdk.currentTimeFormat == TimeFormat.HOUR_24

// 监听切换
override fun onTimeFormatChanged(format: TimeFormat) {
    // 刷新界面时间显示
}
```

### 5. Stapelweise Alarmeinstellung

```kotlin
val alarms = listOf(
    AlarmConfig(1, 8, 0, WeekDays.WEEKDAYS),
    AlarmConfig(2, 12, 30, WeekDays.ALL),
    AlarmConfig(3, 20, 0, WeekDays.WEEKEND)
)
sdk.setAlarms(alarms) { result ->
    // result: Result<List<AlarmInfo>>
}
```

---

## FAQ

### F: Gerät wird auf Huawei/Xiaomi-Telefonen nicht gefunden?

Android 6–11 erfordert, dass die **Standortdienste aktiviert** sind (Systembeschränkung). Android 12+ verwendet die `BLUETOOTH_SCAN`-Berechtigung mit konfiguriertem `neverForLocation`, sodass kein Standort erforderlich ist.

### F: Wird die Verbindung im Hintergrund getrennt?

Benutzerdefinierte ROMs wie MIUI/ColorOS können Bluetooth-Verbindungen im Hintergrund beenden. Empfehlungen:
1. Leiten Sie Benutzer an, die „Akkuoptimierung" zu deaktivieren
2. Fügen Sie die App zur Autostart-Whitelist hinzu
3. Für iOS konfigurieren Sie den `bluetooth-central` Hintergrundmodus

### F: Was tun bei fehlgeschlagener Authentifizierung?

1. Prüfen Sie, ob `fixedAuthKey` mit dem Gerät übereinstimmt
2. Gerät ist bereits mit einem anderen Telefon gekoppelt → Gerätetaste lange drücken für Werksreset
3. Nach dem Reset `clearBinding()` aufrufen, um alte lokale Schlüssel zu löschen

### F: Verursacht das aufeinanderfolgende Senden mehrerer Befehle Konflikte?

Nein. Die interne `CommandQueue` des SDK serialisiert Befehle automatisch:

```kotlin
sdk.setAlarm(1, 8, 0) { }      // 立即发送
sdk.setAlarm(2, 12, 30) { }    // 排队等待
sdk.setSoundType(TYPE_A) { }   // 继续排队
```

### F: Wie werden proaktiv vom Gerät gemeldete Daten empfangen?

Implementieren Sie die entsprechenden Callback-Methoden. Das Gerät meldet proaktiv in folgenden Szenarien:
- Nach erfolgreicher Authentifizierung: meldet alle Alarmkonfigurationen + aktuelle Audioeinstellungen
- Bei Alarmklingeln: `onMedicationNotification(.ringing)`
- Wenn der Benutzer Medikamente einnimmt: `onMedicationNotification(.taken)` + `onMedicationRecordReported`
- Timeout ohne Medikamenteneinnahme: `onMedicationNotification(.timeout)`
- Niedriger Akkustand: `onLowBattery()`

### F: Welche Drittanbieter-Abhängigkeiten verwendet das SDK?

**Keine Abhängigkeiten**. Das SDK verwendet ausschließlich plattformnative Bluetooth-Frameworks (Android BluetoothGatt / iOS CoreBluetooth) und führt keine Drittanbieter-Bibliotheken ein.

---

## Datenschutzerklärung

Dieses SDK **sammelt, speichert oder überträgt keine** Benutzerdaten:
- Medikationsaufzeichnungen werden über Callbacks an die App weitergegeben; das SDK speichert sie nicht
- Geräte-MAC-Adressen werden nur im Speicher für die Schlüsselberechnung verwendet
- Schlüsselwerte werden in Protokollen immer maskiert
- Keine Netzwerkanfragen enthalten

---

## Version

Aktuelle Version: 1.0.0

Beide Plattform-SDKs werden synchron veröffentlicht mit konsistenten API-Schnittstellen.

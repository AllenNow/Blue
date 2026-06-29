# BlueSDK Integrationsanleitung

LX-PD02 Intelligente Pillendose Bluetooth-Kommunikations-SDK — iOS & Android Plattformübergreifende Integrationsdokumentation

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
- [Event-Callbacks-Referenz](#event-callbacks-referenz)
- [Fehlerbehandlung](#fehlerbehandlung)
- [Threading-Modell](#threading-modell)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Überblick

BlueSDK kapselt das proprietäre Bluetooth-5.0-Kommunikationsprotokoll des LX-PD02 vollständig. Integratoren müssen weder die zugrunde liegende Frame-Struktur, CRC-Prüfung, Schlüsselalgorithmen noch andere Low-Level-Details verstehen. Das SDK bietet eine einheitliche High-Level-API mit einem auf beiden Plattformen (iOS/Android) hochgradig konsistenten Schnittstellendesign, wodurch der plattformübergreifende Wartungsaufwand reduziert wird.

**Kernfunktionen:**

| Funktion | Beschreibung |
|------|------|
| BLE-Scannen & Verbindung | Automatische Wiederverbindung (exponentielles Backoff, bis zu 5 Versuche) |
| Schlüsselauthentifizierung | Automatische Berechnung oder fester Schlüssel, klare Wiederherstellungsempfehlungen bei Authentifizierungsfehler |
| Alarmverwaltung | 7-Slot-CRUD, unterstützt wiederkehrende Zeitpläne |
| Medikamentenereignisse | Echtzeit-Empfang von Klingeln/Timeout/Einnahme/Versäumnis-Ereignissen |
| Medikamentenprotokolle | Gerät meldet proaktiv vollständige Datensätze mit Millisekunden-Zeitstempeln |
| Audio-Systemeinstellungen | Lautstärke/Klingelton/Stumm/Dauer/12H-24H-Zeitformat |
| Geräteverwaltung | Geräteinformationsabfrage/Zeitsynchronisation/Werksreset/Entkopplung |
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

**Option A: Lokales AAR**

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
<string>Bluetooth-Berechtigung wird benötigt, um eine Verbindung zum intelligenten Pillendosen-Gerät herzustellen</string>

<!-- Optional: Medikamentenereignisse im Hintergrund empfangen -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Initialisierung

### Android

```kotlin
// Einmalig in Application.onCreate() aufrufen
val config = BlueSDKConfig(
    fixedAuthKey = null,        // Fester Schlüssel (4-stellig hex), null = automatische Berechnung
    logLevel = LogLevel.DEBUG,  // In Produktion LogLevel.NONE verwenden
    autoAuthEnabled = true      // Nach Verbindung automatisch authentifizieren
)
BlueSDK.getInstance(this).initialize(config)
```

### iOS

```swift
// In AppDelegate didFinishLaunching aufrufen
let config = BlueSDKConfig(
    fixedAuthKey: nil,
    logLevel: .debug,
    autoAuthEnabled: true
)
BlueSDK.shared.initialize(config: config)
```

---

## Scannen & Verbindung

### Android

```kotlin
val sdk = BlueSDK.getInstance(context)

sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            // event.device enthält deviceId, deviceName, rssi
            sdk.connect(event.device)  // SDK schließt Authentifizierung automatisch ab
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* error.message */ }
        is ScanEvent.Stopped -> { /* Timeout oder manuell gestoppt */ }
    }
}
```

### iOS

```swift
BlueSDK.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
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
| Automatische Authentifizierung | `fixedAuthKey = null` | SDK berechnet den Schlüssel automatisch basierend auf Telefon-MAC + Geräte-MAC |
| Fester Schlüssel | `fixedAuthKey = "05FA"` | Verwendet einen voreingestellten 4-stelligen Hex-Schlüssel |

Nach einer erfolgreichen Verbindung **initiiert das SDK automatisch die Authentifizierung** — ein manueller Aufruf ist nicht erforderlich. Das Authentifizierungsergebnis wird über Callbacks übermittelt:

```kotlin
// Android
override fun onAuthResult(success: Boolean, error: BlueError?) { }

// iOS
func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?) { }
```

---

## API-Referenz

Alle Geschäfts-APIs müssen nach Erreichen des `AUTHENTICATED`-Status aufgerufen werden; andernfalls wird ein `NotAuthenticated`-Fehler zurückgegeben.

### Lebenszyklus

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Initialisieren | `initialize(config)` | `initialize(config:)` | Einmalig auf Application-Ebene aufrufen |
| Zerstören | `destroy()` | `destroy()` | BLE-Ressourcen freigeben |

### Verbindungsverwaltung

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Geräte scannen | `startScan(timeoutMs, callback)` | `startScan(timeout:callback:)` | Einheitlicher ScanEvent-Callback |
| Scan stoppen | `stopScan()` | `stopScan()` | |
| Gerät verbinden | `connect(device)` | `connect(device)` | Authentifiziert nach Verbindung automatisch |
| Trennen | `disconnect()` | `disconnect()` | Manuelles Trennen löst keine Wiederverbindung aus |
| Wiederverbindung abbrechen | `cancelReconnection()` | `cancelReconnection()` | |
| Gerät entkoppeln | `clearBinding(completion)` | `clearBinding(completion:)` | Sendet Entkopplungsbefehl + trennt |
| Mit Schlüssel authentifizieren | `authenticateWithKey(hi, lo, cb)` | `authenticateWithKey(keyHigh:keyLow:completion:)` | |
| Berechtigungen prüfen | `checkPermissions()` | `checkPermissions()` | Gibt PermissionStatus zurück |
| Verbindungsstatus | `connectionState` (Eigenschaft) | `connectionState` (Eigenschaft) | |
| Aktuelles Zeitformat | `currentTimeFormat` (Eigenschaft) | `currentTimeFormat` (Eigenschaft) | Folgt der Geräteeinstellung |

### Geräteinformationen & Zeit

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Geräteinformationen abfragen | `queryDeviceInfo(completion)` | `queryDeviceInfo(completion:)` | MAC + Firmware-Version |
| Zeitsynchronisation | `syncTime(completion)` | `syncTime(completion:)` | Sendet aktuelle Systemzeit an das Gerät |

### Alarmverwaltung (7 Slots)

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Alarm setzen | `setAlarm(index, hour, minute, days, cb)` | `setAlarm(index:hour:minute:days:completion:)` | Typsichere Version |
| Stapelweise setzen | `setAlarms(list, completion)` | `setAlarms(_:completion:)` | Serielles Senden |
| Alarm abfragen | `queryAlarm(index, completion)` | `queryAlarm(index:completion:)` | Einzelnen Slot abfragen |
| Alarm löschen | `deleteAlarm(index, completion)` | `deleteAlarm(index:completion:)` | |
| Alle löschen | `clearAllAlarms(completion)` | `clearAllAlarms(completion:)` | |

**Parameterbeschränkungen:**
- `index`: 1–7
- `hour`: 0–23
- `minute`: 0–59
- `days`: `WeekDays`-Enum (`.ALL` / `.WEEKDAYS` / `.WEEKEND` / benutzerdefinierte Kombination)

### Audio- & Systemeinstellungen

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Lautstärke setzen | `setVolume(level, cb)` | `setVolume(_:completion:)` | LOW / MEDIUM / HIGH |
| Klingelton setzen | `setSoundType(type, cb)` | `setSoundType(_:completion:)` | TYPE_A / TYPE_B |
| Stummschaltung | `setSilence(enabled, cb)` | `setSilence(_:completion:)` | true = stumm |
| Alarmdauer | `setAlertDuration(minutes, cb)` | `setAlertDuration(_:completion:)` | 1–5 Minuten |
| Zeitformat | `setTimeFormat(format, cb)` | `setTimeFormat(_:completion:)` | HOUR_12 / HOUR_24 |
| Werksreset | `restoreFactory(completion)` | `restoreFactory(completion:)` | Gerät startet neu und trennt sich |

### Medikamentenereignisse

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Medikamentenbenachrichtigung senden | `sendMedicationNotification(status, cb)` | `sendMedicationNotification(status:completion:)` | |

### Protokollierung

| API | Android | iOS | Beschreibung |
|------|---------|-----|------|
| Stufe setzen | `setLogLevel(level)` | `setLogLevel(_:)` | DEBUG/INFO/WARN/ERROR/NONE |
| Benutzerdefinierter Handler | `setLogHandler(handler)` | `setLogHandler(_:)` | In Ihr eigenes Protokollierungssystem integrieren |
| Protokoll exportieren | `exportLog(maxLines)` | `exportLog(maxLines:)` | Letzte 1000 Einträge |
| Puffer leeren | `clearLogBuffer()` | `clearLogBuffer()` | |

---

## Event-Callbacks-Referenz

### Android — `BlueSDKListener` Interface

```kotlin
interface BlueSDKListener {
    // Verbindung
    fun onConnectionStateChanged(state: ConnectionState) {}
    fun onAuthResult(success: Boolean, error: BlueError?) {}
    fun onReconnecting(attempt: Int, maxAttempts: Int) {}
    fun onReconnectFailed() {}
    fun onError(error: BlueError) {}

    // Gerät
    fun onDeviceInfoReceived(info: DeviceInfo) {}
    fun onTimeSyncRequested() {}

    // Alarm
    fun onAlarmUpdated(alarm: AlarmInfo) {}
    fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {}
    fun onAlarmTimeout(alarmIndex: Int, alarmInfo: AlarmInfo) {}

    // Medikation
    fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {}
    fun onMedicationRecordReported(record: MedicationRecord) {}
    fun onMedicationNotification(type: MedicationNotificationType) {}

    // Systemeinstellungen
    fun onSoundTypeChanged(type: SoundType) {}
    fun onAlertDurationChanged(minutes: Int) {}
    fun onTimeFormatChanged(format: TimeFormat) {}
    fun onLowBattery() {}
    fun onDeviceUnbound() {}
}
```

### iOS — `BlueSDKDelegate` Protokoll

```swift
protocol BlueSDKDelegate {
    // Verbindung
    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState)
    func blueSDK(_ sdk: BlueSDK, didAuthenticateWithSuccess success: Bool, error: BlueError?)
    func blueSDK(_ sdk: BlueSDK, didStartReconnecting attempt: Int, maxAttempts: Int)
    func blueSDKDidFailReconnection(_ sdk: BlueSDK)
    func blueSDK(_ sdk: BlueSDK, didEncounterError error: BlueError)

    // Gerät
    func blueSDK(_ sdk: BlueSDK, didReceiveDeviceInfo info: DeviceInfo)
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK)

    // Alarm
    func blueSDK(_ sdk: BlueSDK, didUpdateAlarm alarm: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo)
    func blueSDK(_ sdk: BlueSDK, didAlarmTimeout alarmIndex: Int, alarmInfo: AlarmInfo)

    // Medikation
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationRecord record: MedicationRecord)
    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationNotification type: MedicationNotificationType)

    // Systemeinstellungen
    func blueSDK(_ sdk: BlueSDK, didChangeSoundType type: SoundType)
    func blueSDK(_ sdk: BlueSDK, didChangeAlertDuration minutes: Int)
    func blueSDK(_ sdk: BlueSDK, didChangeTimeFormat format: TimeFormat)
    func blueSDKDidReportLowBattery(_ sdk: BlueSDK)
    func blueSDKDidReportDeviceUnbound(_ sdk: BlueSDK)
}
```

> Alle Callback-Methoden verfügen über standardmäßige leere Implementierungen; überschreiben Sie nur die, die Sie benötigen.

---

## Fehlerbehandlung

Alle asynchronen Operationen liefern Ergebnisse über `Result`-Callbacks — **es werden keine Exceptions geworfen**.

### Fehlertypen

| Fehler | Code | Wiederholbar | Beschreibung |
|------|------|--------|------|
| `NotInitialized` | 1 | ❌ | initialize() wurde nicht aufgerufen |
| `NotAuthenticated` | 2 | ❌ | Schlüsselauthentifizierung nicht abgeschlossen |
| `AuthFailed` | 3 | ❌ | Schlüssel stimmt nicht überein, Werksreset erforderlich |
| `Timeout` | 4 | ✅ | Befehl-Timeout (SDK hat intern bereits 3 Mal wiederholt) |
| `PermissionDenied` | 5 | ❌ | Bluetooth-Berechtigung nicht erteilt |
| `InvalidParameter` | 6 | ❌ | Parameter außerhalb des gültigen Bereichs |
| `ProtocolError` | 7 | ✅ | CRC-Prüfung fehlgeschlagen, mögliche Bluetooth-Interferenz |
| `BleError` | 8 | ✅ | System-Bluetooth-Ausnahme |
| `Disconnected` | 9 | ✅ | Gerät getrennt, SDK verbindet automatisch erneut |
| `DeviceNotFound` | 10 | ❌ | Gerät nicht gefunden (nur iOS) |

### Verwendung von `isRetryable`

```kotlin
// Android
result.onFailure { error ->
    val blueError = error as BlueError
    if (blueError.isRetryable) {
        // Sicherer Wiederholungsversuch (z.B. timeout, protocolError)
    } else {
        // Erfordert Benutzereingriff (z.B. authFailed, permissionDenied)
        showError(blueError.message, blueError.recoverySuggestion)
    }
}
```

```swift
// iOS
case .failure(let error):
    if error.isRetryable {
        // Sicherer Wiederholungsversuch
    } else {
        showAlert(error.localizedDescription, suggestion: error.recoverySuggestion)
    }
```

---

## Threading-Modell

| Regel | Beschreibung |
|------|------|
| Callback-Thread | **Alle Event-Callbacks werden auf dem Main-Thread ausgeliefert** — kein manuelles Wechseln erforderlich |
| API-Aufrufe | Alle öffentlichen Methoden sind thread-sicher und können von jedem Thread aufgerufen werden |
| Befehlswarteschlange | Interne serielle FIFO-Warteschlange — nur ein Befehl wartet gleichzeitig auf eine Antwort |
| Befehlsintervall | 200ms |
| Befehls-Timeout | 5 Sekunden, automatische Wiederholung bis zu 3 Mal |

---

## Best Practices

### 1. Verwenden Sie das Observer-Muster anstelle eines einzelnen Listeners

```kotlin
// Mehrere Bildschirme können gleichzeitig auf Ereignisse lauschen
sdk.addObserver(alarmManagerObserver)
sdk.addObserver(medicationObserver)

// Beim Zerstören des Bildschirms entfernen
sdk.removeObserver(alarmManagerObserver)
```

### 2. Befehle erst nach erfolgreicher Authentifizierung senden

```kotlin
override fun onConnectionStateChanged(state: ConnectionState) {
    if (state == ConnectionState.AUTHENTICATED) {
        // Jetzt können Geschäfts-APIs sicher aufgerufen werden
        sdk.syncTime { }
    }
}
```

### 3. Behandlung von Medikamentenereignissen

```kotlin
// onMedicationResult — Echtzeit-Ereignis (ohne Zeitstempel)
// onMedicationRecordReported — Vollständiger Datensatz (enthält geplante Zeit + tatsächliche Zeit)
// Empfehlung: onMedicationRecordReported für die Datenbankspeicherung verwenden,
//             onMedicationNotification für UI-Benachrichtigungen verwenden
```

### 4. Zeitformat folgt dem Gerät

```kotlin
// Aktuelles Zeitformat lesen
val is24Hour = sdk.currentTimeFormat == TimeFormat.HOUR_24

// Änderungen überwachen
override fun onTimeFormatChanged(format: TimeFormat) {
    // Zeitanzeige in der Benutzeroberfläche aktualisieren
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

Auf Android 6–11 müssen **Standortdienste aktiviert sein** (Systemeinschränkung). Ab Android 12 entfällt bei Verwendung der `BLUETOOTH_SCAN`-Berechtigung mit konfiguriertem `neverForLocation` die Standortanforderung.

### F: Wird die Verbindung im Hintergrund getrennt?

Benutzerdefinierte ROMs wie MIUI/ColorOS können Bluetooth-Verbindungen im Hintergrund beenden. Empfehlungen:
1. Benutzer anleiten, die „Akkuoptimierung" zu deaktivieren
2. Die App zur Autostart-Whitelist hinzufügen
3. Unter iOS den `bluetooth-central`-Hintergrundmodus konfigurieren

### F: Was tun bei fehlgeschlagener Authentifizierung?

1. Überprüfen Sie, ob `fixedAuthKey` mit dem Gerät übereinstimmt
2. Wenn das Gerät bereits mit einem anderen Telefon gekoppelt ist → Gerätetaste lang drücken für Werksreset
3. Nach dem Reset `clearBinding()` aufrufen, um den lokalen veralteten Schlüssel zu löschen

### F: Führt das aufeinanderfolgende Senden mehrerer Befehle zu Konflikten?

Nein. Die interne `CommandQueue` des SDK serialisiert Befehle automatisch:

```kotlin
sdk.setAlarm(1, 8, 0) { }      // Wird sofort gesendet
sdk.setAlarm(2, 12, 30) { }    // In Warteschlange
sdk.setSoundType(TYPE_A) { }   // In Warteschlange
```

### F: Wie empfange ich Daten, die das Gerät proaktiv meldet?

Implementieren Sie die entsprechenden Callback-Methoden. Das Gerät meldet proaktiv Daten in folgenden Szenarien:
- Nach erfolgreicher Authentifizierung: meldet alle Alarmkonfigurationen + aktuelle Audioeinstellungen
- Wenn ein Alarm klingelt: `onMedicationNotification(.ringing)`
- Wenn der Benutzer Medikamente einnimmt: `onMedicationNotification(.taken)` + `onMedicationRecordReported`
- Wenn Medikamente nicht vor dem Timeout eingenommen werden: `onMedicationNotification(.timeout)`
- Niedriger Akkustand: `onLowBattery()`

### F: Welche Drittanbieter-Abhängigkeiten verwendet das SDK?

**Keine Abhängigkeiten.** Das SDK verwendet ausschließlich die nativen Bluetooth-Frameworks der Plattform (Android BluetoothGatt / iOS CoreBluetooth) und führt keine Drittanbieter-Bibliotheken ein.

---

## Datenschutzerklärung

Dieses SDK **sammelt, speichert und überträgt keine** Benutzerdaten:
- Medikamentenprotokolle werden über Callbacks an die App übergeben; das SDK speichert sie nicht
- Geräte-MAC-Adressen werden nur im Arbeitsspeicher für die Schlüsselberechnung verwendet
- Schlüsselwerte sind in Protokollen stets maskiert
- Es sind keine Netzwerkanfragen enthalten

---

## Version

Aktuelle Version: 1.0.0

Beide Plattform-SDKs werden synchron veröffentlicht und verfügen über konsistente API-Schnittstellen.

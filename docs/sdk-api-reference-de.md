# BlueSDK API-Referenz (Deutsch)

## Übersicht

BlueSDK ist ein BLE-SDK für die LX-PD02 Smart-Pillendose. Es bietet eine einfache API für Verbindung, Authentifizierung, Alarmverwaltung und Medikamentenüberwachung.

---

## Schnellstart

```swift
// iOS
let config = BlueSDKConfig(language: .de)
BlueSDK.shared.initialize(config: config)
BlueSDK.shared.delegate = self

// Scannen und verbinden
BlueSDK.shared.startScan(timeout: 10) { event in
    switch event {
    case .deviceFound(let device):
        BlueSDK.shared.connect(device)
    case .error(let error):
        print(error.recoverySuggestion)
    case .stopped:
        break
    }
}
```

```kotlin
// Android
val config = BlueSDKConfig(language = BlueSDKLanguage.DE)
sdk.initialize(config)
sdk.listener = this

// Scannen und verbinden
sdk.startScan(timeoutMs = 10000) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> sdk.connect(event.device)
        is ScanEvent.Error -> Log.e("SDK", event.error.recoverySuggestion)
        is ScanEvent.Stopped -> {}
    }
}
```

---

## Ereignis-Callbacks

Alle Callbacks werden im Haupt-Thread ausgelöst. Mehrere Observer werden unterstützt.

| # | Ereignis | Android | iOS |
|---|----------|---------|-----|
| 1 | Verbindungsstatus geändert | `onConnectionStateChanged(state)` | `blueSDK(_:didChangeConnectionState:)` |
| 2 | Authentifizierungsergebnis | `onAuthResult(success, error)` | `blueSDK(_:didAuthenticateWithSuccess:error:)` |
| 3 | Geräteinformationen | `onDeviceInfoReceived(info)` | `blueSDK(_:didReceiveDeviceInfo:)` |
| 4 | Zeitsynchronisierung angefordert | `onTimeSyncRequested()` | `blueSDKDidRequestTimeSync(_:)` |
| 5 | Alarmkonfiguration geändert | `onAlarmUpdated(alarm)` | `blueSDK(_:didUpdateAlarm:)` |
| 6 | Alarm klingelt | `onAlarmRinging(index, alarmInfo)` | `blueSDK(_:didAlarmRinging:alarmInfo:)` |
| 7 | Alarm-Timeout | `onAlarmTimeout(index, alarmInfo)` | `blueSDK(_:didAlarmTimeout:alarmInfo:)` |
| 8 | Medikamentenergebnis (Echtzeit) | `onMedicationResult(index, status)` | `blueSDK(_:didReceiveMedicationResult:status:)` |
| 9 | Medikamentenaufzeichnung (vollständig) | `onMedicationRecordReported(record)` | `blueSDK(_:didReceiveMedicationRecord:)` |
| 10 | Klingelton geändert | `onSoundTypeChanged(type)` | `blueSDK(_:didChangeSoundType:)` |
| 11 | Zeitformat geändert | `onTimeFormatChanged(format)` | `blueSDK(_:didChangeTimeFormat:)` |
| 12 | Niedriger Akku | `onLowBattery()` | `blueSDKDidReportLowBattery(_:)` |
| 13 | Medikamentenbenachrichtigung | `onMedicationNotification(type)` | `blueSDK(_:didReceiveMedicationNotification:)` |
| 14 | Verbindungsfehler | `onError(error)` | `blueSDK(_:didEncounterError:)` |
| 15 | Neuverbindung läuft | `onReconnecting(attempt, max)` | `blueSDK(_:didStartReconnecting:maxAttempts:)` |
| 16 | Neuverbindung fehlgeschlagen | `onReconnectFailed()` | `blueSDKDidFailReconnection(_:)` |

---

## Datenstrukturen

### ConnectionState (Verbindungsstatus)

| Wert | Bedeutung |
|------|-----------|
| `DISCONNECTED` | Getrennt |
| `CONNECTING` | Verbinden |
| `CONNECTED` | Verbunden (nicht authentifiziert) |
| `AUTHENTICATED` | Authentifiziert (bereit für Befehle) |
| `RECONNECTING` | Automatische Neuverbindung |

### MedicationStatus (Medikamentenstatus)

| Protokollwert | Enum | Bedeutung |
|---------------|------|-----------|
| 0x01 | `TAKEN` / `.taken` | Pünktlich eingenommen |
| 0x02 | `TIMEOUT` / `.timeout` | Verspätet eingenommen |
| 0x03 | `MISSED` / `.missed` | Vergessen |
| 0x04 | `EARLY` / `.early` | Vorzeitig eingenommen |

### MedicationNotification (Medikamentenbenachrichtigung)

| type | Bedeutung | App-Aktion |
|------|-----------|------------|
| 1 | Alarm klingelt, warten auf Entnahme | Popup "Bitte Medikamente nehmen" |
| 2 | Timeout, nicht rechtzeitig entnommen | Lokale Push-Benachrichtigung |
| 3 | Benutzer hat Medikamente entnommen | Ermutigungs-Popup |

### AlarmInfo (Alarminformation)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `index` | Int | Alarm-Slot (1~7) |
| `hour` | Int | Stunde (0~23) |
| `minute` | Int | Minute (0~59) |
| `weekMask` | Int | Wochentag-Bitmaske |
| `runState` | RunState | idle / ringing / ended |

### MedicationRecord (Medikamentenaufzeichnung)

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `timestamp` | Int64/Long | Ereigniszeit (Unix ms) |
| `alarmIndex` | Int | Zugehöriger Alarm (1~7) |
| `alarmHour` | Int | Eingestellte Stunde |
| `alarmMinute` | Int | Eingestellte Minute |
| `status` | MedicationStatus | Ergebnis |

### BlueError (Fehlertypen)

| Code | Fehler | Beschreibung | Wiederherstellungsvorschlag |
|------|--------|--------------|----------------------------|
| 1 | NotInitialized | SDK nicht initialisiert | `initialize()` aufrufen |
| 2 | NotAuthenticated | Nicht authentifiziert | Automatische Auth. abwarten |
| 3 | AuthFailed | Authentifizierung fehlgeschlagen | Schlüssel oder Werksreset prüfen |
| 4 | Timeout | Befehl-Timeout | Reichweite und Akku prüfen |
| 5 | PermissionDenied | Berechtigung verweigert | Bluetooth-Berechtigung erteilen |
| 6 | InvalidParameter | Ungültiger Parameter | Parameterbereiche prüfen |
| 7 | ProtocolError | Protokollfehler | Trennen und erneut versuchen |
| 8 | BleError | BLE-Systemfehler | Bluetooth neu starten |
| 9 | Disconnected | Gerät getrennt | Erneut verbinden |

---

## Öffentliche API-Methoden

### Lebenszyklus

| Methode | Beschreibung |
|---------|--------------|
| `initialize(config)` | SDK initialisieren |
| `destroy()` | Ressourcen freigeben |

### Verbindungsverwaltung

| Methode | Beschreibung |
|---------|--------------|
| `startScan(timeout, callback)` | Gerät scannen |
| `stopScan()` | Scan stoppen |
| `connect(device)` | Mit Gerät verbinden |
| `disconnect()` | Verbindung trennen |
| `cancelReconnection()` | Auto-Neuverbindung abbrechen |

### Authentifizierung

| Methode | Beschreibung |
|---------|--------------|
| `authenticateWithKey(keyHigh, keyLow)` | Manuelle Schlüssel-Auth. (erweitert) |
| `clearBinding(completion)` | Gerät entkoppeln (sendet 0xA1) |

### Alarmverwaltung

| Methode | Beschreibung |
|---------|--------------|
| `setAlarm(index, hour, minute, days)` | Alarm setzen |
| `deleteAlarm(index)` | Alarm löschen |
| `clearAllAlarms()` | Alle Alarme löschen |
| `setAlarms(alarms)` | Mehrere Alarme setzen |

### Audio & System

| Methode | Beschreibung |
|---------|--------------|
| `setVolume(level)` | Lautstärke einstellen |
| `setSoundType(type)` | Klingelton einstellen |
| `setSilence(enabled)` | Stumm-Modus |
| `setAlertDuration(minutes)` | Klingeldauer (1~5 Min) |
| `setTimeFormat(format)` | Zeitformat (12H/24H) |
| `restoreFactory()` | Werkseinstellungen |

### Konfiguration

```kotlin
// Android
BlueSDKConfig(
    fixedAuthKey = "05FA",      // 4-Zeichen-Hex (optional)
    customPhoneMac = "A1B2C3D4E5F6", // 12-Zeichen-Hex (optional)
    language = BlueSDKLanguage.DE,
    autoAuthEnabled = true,
    autoReconnect = true,
    maxReconnectAttempts = 5
)
```

```swift
// iOS
BlueSDKConfig(
    fixedAuthKey: "05FA",
    customPhoneMac: "A1B2C3D4E5F6",
    language: .de,
    autoAuthEnabled: true,
    autoReconnect: true,
    maxReconnectAttempts: 5
)
```

### Observer registrieren

```kotlin
// Android — Observer hinzufügen (starke Referenz, muss entfernt werden)
sdk.addObserver(observer)
sdk.removeObserver(observer) // in onDestroy()
```

```swift
// iOS — Observer hinzufügen (schwache Referenz, automatische Bereinigung)
BlueSDK.shared.addObserver(self)
BlueSDK.shared.removeObserver(self) // optional
```

---

## WeekDays (Wochentage)

```kotlin
// Android
setOf(WeekDay.MONDAY, WeekDay.WEDNESDAY, WeekDay.FRIDAY)
WeekDay.WEEKDAYS  // Mo-Fr
WeekDay.ALL       // Jeden Tag
```

```swift
// iOS
[.monday, .wednesday, .friday]
.weekdays  // Mo-Fr
.all       // Jeden Tag
```

---

## Hinweise für die Integration

1. **Authentifizierung** erfolgt automatisch nach der Verbindung — kein manueller Aufruf nötig
2. **fixedAuthKey** Format: genau 4 Hex-Zeichen (z.B. "05FA")
3. **customPhoneMac** Format: genau 12 Hex-Zeichen (z.B. "A1B2C3D4E5F6")
4. **Klingeldauer**: nur ganzzahlige Werte 1~5 Minuten
5. **Werksreset** löscht NICHT den lokalen Schlüssel — nur `clearBinding()` tut dies
6. **Medikamentenaufzeichnungen**: Nur `onMedicationRecordReported` enthält vollständige Zeitinformationen

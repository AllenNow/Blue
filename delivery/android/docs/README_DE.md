# BlueSDK Android

LX-PD02 Intelligente Pillendose Bluetooth-Kommunikations-SDK (Android Native Kotlin)

## Systemanforderungen

- Android 5.0+ (API 21+)
- Kotlin 1.9+
- Bluetooth 5.0+ Hardware

## Integration

### Lokales AAR (Empfohlen)

Platzieren Sie `blue-sdk-release.aar` im Verzeichnis `app/libs/` und fügen Sie folgendes in `build.gradle.kts` hinzu:

```kotlin
dependencies {
    implementation(files("libs/blue-sdk-release.aar"))
}
```

### Lokale Modulabhängigkeit (Entwicklungsphase)

```kotlin
// settings.gradle.kts
include(":blue-sdk")

// app/build.gradle.kts
dependencies {
    implementation(project(":blue-sdk"))
}
```

## Schnellstart

### 1. Berechtigungskonfiguration

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

### 2. SDK initialisieren

```kotlin
// Einmal in Application.onCreate() aufrufen
val config = BlueSDKConfig(
    fixedAuthKey = null,        // Fester Schlüssel, null für automatische Berechnung
    logLevel = LogLevel.DEBUG,  // Log-Level
    autoAuthEnabled = true      // Automatische Authentifizierung nach Verbindung
)
BlueSDK.getInstance(this).initialize(config)
```

### 3. Gerät scannen und verbinden

```kotlin
val sdk = BlueSDK.getInstance(context)
sdk.listener = myListener

// Scannen (stoppt automatisch nach 10 Sekunden)
sdk.startScan(timeoutMs = 10000L) { event ->
    when (event) {
        is ScanEvent.DeviceFound -> {
            sdk.connect(event.device)  // SDK führt nach Verbindung automatisch die Schlüsselauthentifizierung durch
            sdk.stopScan()
        }
        is ScanEvent.Error -> { /* Fehler behandeln */ }
        is ScanEvent.Stopped -> { /* Scan-Zeitüberschreitung */ }
    }
}
```

### 4. Ereignis-Callbacks überwachen

```kotlin
sdk.listener = object : BlueSDKListener {
    override fun onConnectionStateChanged(state: ConnectionState) {
        // DISCONNECTED → CONNECTING → CONNECTED → AUTHENTICATED
    }
    override fun onAuthResult(success: Boolean, error: BlueError?) {
        if (success) { /* Geschäftsbefehle können jetzt gesendet werden */ }
    }
    override fun onAlarmRinging(alarmIndex: Int, alarmInfo: AlarmInfo) {
        // Gerätealarm klingelt
    }
    override fun onMedicationResult(alarmIndex: Int, status: MedicationStatus) {
        // Medikationsergebnis (pünktlich / Zeitüberschreitung / verpasst / vorzeitig)
    }
}
```

### 5. Geschäftsbefehle senden

```kotlin
// Alle Geschäftsbefehle müssen nach dem AUTHENTICATED-Status aufgerufen werden

// Alarm setzen (typsicher)
sdk.setAlarm(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS) { result ->
    result.fold(
        onSuccess = { alarmInfo -> /* Erfolgreich */ },
        onFailure = { error -> /* Fehler behandeln */ }
    )
}

// Alarme stapelweise setzen
sdk.setAlarms(listOf(
    AlarmConfig(index = 1, hour = 8, minute = 0, days = WeekDays.WEEKDAYS),
    AlarmConfig(index = 2, hour = 12, minute = 30, days = WeekDays.ALL),
    AlarmConfig(index = 3, hour = 20, minute = 0, days = WeekDays.WEEKEND)
)) { result -> }

// Audio-Einstellungen
sdk.setSoundType(SoundType.TYPE_A) { }
sdk.setVolume(VolumeLevel.MEDIUM) { }
sdk.setTimeFormat(TimeFormat.HOUR_24) { }
sdk.setSilence(true) { }
sdk.setAlertDuration(5) { }  // 5 Minuten

// Gerätesteuerung
sdk.syncTime { }
sdk.queryDeviceInfo { result -> }
sdk.restoreFactory { }
```

## Architekturübersicht

```
┌─────────────────────────────────────────────────────┐
│                  Integrator-App                       │
├─────────────────────────────────────────────────────┤
│  BlueSDK (Öffentlicher API-Einstiegspunkt)           │
│  ├── BlueSDKConfig        Konfiguration             │
│  ├── BlueSDKListener      Ereignis-Callbacks        │
│  └── BlueError            Fehlertypen               │
├─────────────────────────────────────────────────────┤
│  Manager-Schicht (Geschäftslogik)                    │
│  ├── AuthManager          Schlüsselauthentifizierung│
│  ├── AlarmManager         Alarmverwaltung (7 Slots) │
│  ├── MedicationManager    Medikationsereignisse     │
│  ├── AudioManager         Audio-/Systemeinstellungen│
│  ├── DeviceManager        Geräteinfo/Zeitsync       │
│  ├── ConnectionManager    Verbindungszustandsautomat│
│  └── PermissionManager    Berechtigungsprüfung      │
├─────────────────────────────────────────────────────┤
│  Interne Schicht (Infrastruktur)                     │
│  ├── CommandQueue         FIFO-Serielle Befehlsqueue│
│  ├── CallbackDispatcher   Hauptthread-Dispatching   │
│  ├── BlueLogger           Gestuftes Logging+Redakt. │
│  ├── KeystoreHelper       phoneMac-Persistierung    │
│  └── LogFormatter         Log-Formatierung          │
├─────────────────────────────────────────────────────┤
│  Transport-Schicht (Protokollkommunikation)          │
│  ├── BLEScanner           Gerätescan                │
│  ├── BLEConnector         GATT-Verbindung/Lesen&Schr│
│  ├── FrameBuilder         Frame-Aufbau (55 AA…CRC8) │
│  ├── FrameParser          Frame-Parsing + CRC-Prüf. │
│  ├── StreamFrameParser    Paket-Reassemblierung     │
│  ├── CRC8Calculator       Prüfsummenalgorithmus     │
│  ├── CommandCode          CMD-Befehlskonstanten     │
│  ├── DPIDConstants        DPID-Funktionsbyte-Konst. │
│  └── FrameConstants       Frame-Format-Konstanten   │
└─────────────────────────────────────────────────────┘
                        ↕ BLE
┌─────────────────────────────────────────────────────┐
│         LX-PD02 Intelligente Pillendose Hardware     │
└─────────────────────────────────────────────────────┘
```

## Verbindungszustandsautomat

```
                    connect()
 DISCONNECTED ──────────────────→ CONNECTING
      ↑                                │
      │ disconnect()                   │ GATT-Verbindung erfolgreich
      │ Neuverbindung fehlgeschlagen   ↓
      │ (5 Versuche)
      ←──────────────────────── CONNECTED
      ↑                                │
      │                                │ Automatische Schlüsselauthentifizierung
      │   Unerwartete Trennung         ↓
 RECONNECTING ←──────────────── AUTHENTICATED
      │                                │
      │  2s/4s/8s exponentielles       │ disconnect()
      │  Backoff                       │
      └────────→ CONNECTING ←──────────┘ (kein Reconnect ausgelöst)
```

**Zustandsbeschreibungen:**
- `DISCONNECTED` — Ausgangszustand, `connect()` kann aufgerufen werden
- `CONNECTING` — GATT-Verbindung wird aufgebaut (15 Sekunden Timeout)
- `CONNECTED` — GATT bereit, SDK startet automatisch die Authentifizierung
- `AUTHENTICATED` — Authentifizierung bestanden, alle Geschäftsbefehle können ausgeführt werden
- `RECONNECTING` — Automatische Neuverbindung nach unerwartetem Verbindungsabbruch (max. 5 Versuche)

## Threading-Modell

- **Alle `BlueSDKListener`-Callbacks werden auf dem Hauptthread ausgeliefert** — Integratoren müssen nicht manuell den Thread wechseln
- **`completion`-Callbacks von API-Methoden können auf dem BLE-Thread ausgelöst werden** — verwenden Sie `runOnUiThread` für UI-Operationen
- Interne BLE-Operationen laufen auf dem System-Bluetooth-Thread
- `CommandQueue` stellt sicher, dass zu jedem Zeitpunkt nur ein Befehl auf eine Antwort wartet (FIFO-seriell)
- 200 ms Intervall zwischen Befehlen, 5 Sekunden Timeout mit automatischer Wiederholung, maximal 3 Versuche
- Das SDK selbst ist threadsicher; alle öffentlichen Methoden können von jedem Thread aufgerufen werden

## Öffentliche API-Referenz

### Lebenszyklus

| Methode | Beschreibung |
|---------|--------------|
| `initialize(config)` | SDK initialisieren (einmal in Application aufrufen) |
| `destroy()` | Alle BLE-Ressourcen freigeben |

### Verbindungsverwaltung

| Methode | Beschreibung |
|---------|--------------|
| `startScan(timeoutMs, callback)` | BLE-Geräte scannen (einheitlicher ScanEvent-Callback) |
| `stopScan()` | Scan stoppen |
| `connect(device)` | Mit Gerät verbinden (automatische Authentifizierung) |
| `disconnect()` | Manuell trennen (löst keine Neuverbindung aus) |
| `cancelReconnection()` | Automatische Neuverbindung abbrechen |
| `clearBinding()` | Lokalen Bindungsschlüssel löschen |
| `authenticateWithKey(high, low)` | Mit angegebenem Schlüssel authentifizieren |
| `checkPermissions()` | Bluetooth-Berechtigungsstatus abfragen |
| `connectionState` | Aktueller Verbindungsstatus (Eigenschaft) |

### Geräteinformationen

| Methode | Beschreibung | Voraussetzung |
|---------|--------------|---------------|
| `queryDeviceInfo(completion)` | MAC + Firmware-Version abfragen | Initialisiert |
| `syncTime(completion)` | Systemzeit an Gerät senden | Authentifiziert |

### Alarmverwaltung

| Methode | Beschreibung | Voraussetzung |
|---------|--------------|---------------|
| `setAlarm(index, hour, minute, days, completion)` | Alarm setzen (1–7) | Authentifiziert |
| `setAlarms(list, completion)` | Alarme stapelweise setzen | Authentifiziert |
| `deleteAlarm(index, completion)` | Alarm löschen | Authentifiziert |
| `clearAllAlarms(completion)` | Alle Alarme löschen | Authentifiziert |

### Audio & System

| Methode | Beschreibung | Voraussetzung |
|---------|--------------|---------------|
| `setVolume(level, completion)` | Lautstärke (LOW/MEDIUM/HIGH) | Authentifiziert |
| `setSoundType(type, completion)` | Klingelton (TYPE_A/B/C/MUTE) | Authentifiziert |
| `setSilence(enabled, completion)` | Stummschaltung ein/aus | Authentifiziert |
| `setAlertDuration(minutes, completion)` | Erinnerungsdauer | Authentifiziert |
| `setTimeFormat(format, completion)` | Zeitformat (HOUR_12/HOUR_24) | Authentifiziert |
| `restoreFactory(completion)` | Werkseinstellungen wiederherstellen | Authentifiziert |

### Medikationsereignisse

| Methode | Beschreibung | Voraussetzung |
|---------|--------------|---------------|
| `sendMedicationNotification(status, completion)` | Medikationsergebnis-Benachrichtigung senden | Authentifiziert |

### Protokollierung

| Methode | Beschreibung |
|---------|--------------|
| `setLogLevel(level)` | Log-Level festlegen |
| `setLogHandler(handler)` | Benutzerdefinierter Log-Handler |
| `exportLog(maxLines)` | Aktuelle Logs exportieren (max. 1000 Einträge) |
| `clearLogBuffer()` | Log-Puffer leeren |

## Fehlerbehandlung

Alle asynchronen Operationen liefern Ergebnisse über `Result<T>`-Callbacks zurück; es werden keine Exceptions geworfen.

```kotlin
sdk.setAlarm(1, 8, 0) { result ->
    result.fold(
        onSuccess = { info -> /* Erfolgreich */ },
        onFailure = { error ->
            val blueError = error as BlueError
            Log.e("SDK", "${blueError.message} | Vorschlag: ${blueError.recoverySuggestion}")
        }
    )
}
```

### Fehlertypen

| Fehler | Code | Beschreibung | Wiederherstellungsvorschlag |
|--------|------|--------------|----------------------------|
| `NotInitialized` | 1 | SDK nicht initialisiert | Rufen Sie zuerst `initialize()` auf |
| `NotAuthenticated` | 2 | Authentifizierung nicht abgeschlossen | Warten Sie auf die automatische Authentifizierung oder prüfen Sie die Schlüsselkonfiguration |
| `AuthFailed` | 3 | Schlüssel stimmt nicht überein | Prüfen Sie fixedAuthKey oder setzen Sie das Gerät auf Werkseinstellungen zurück |
| `Timeout` | 4 | Befehlszeitüberschreitung (5s × 3 Versuche) | Stellen Sie sicher, dass das Gerät innerhalb von 3 Metern ist und ausreichend Akku hat |
| `PermissionDenied` | 5 | Bluetooth-Berechtigung nicht erteilt | Android 12+ erfordert BLUETOOTH_SCAN + CONNECT |
| `InvalidParameter` | 6 | Ungültiger Parameter | Prüfen Sie Alarmindex 1–7, Stunde 0–23, Minute 0–59 |
| `ProtocolError` | 7 | Frame-CRC-Prüfung fehlgeschlagen | Mögliche Bluetooth-Interferenz; trennen und neu verbinden |
| `BleError` | 8 | System-Bluetooth-Fehler | Stellen Sie sicher, dass Bluetooth aktiviert ist; versuchen Sie Bluetooth neu zu starten |
| `Disconnected` | 9 | Verbindung verloren | SDK verbindet sich automatisch neu, oder rufen Sie manuell connect() auf |

## Häufig gestellte Fragen (FAQ)

### Huawei-Telefone finden das Gerät beim Scannen nicht

Android 6–11 erfordert, dass die **Standortdienste aktiviert** sind, um BLE-Scans durchzuführen (dies ist eine Systemeinschränkung, kein SDK-Problem). Fordern Sie den Benutzer vor dem Scannen auf, GPS zu aktivieren.

### Xiaomi-Telefone trennen die Verbindung im Hintergrund

MIUIs „Energiesparmodus" kann Bluetooth-Hintergrundverbindungen beenden. Lösungen:
1. Erlauben Sie die App unter „Autostart-Verwaltung"
2. Deaktivieren Sie den „Energiesparmodus" für die App unter „Akku & Leistung"
3. Sperren Sie die App in der Liste der letzten Aufgaben

### Fehlerbehebung bei Authentifizierungsproblemen

1. Prüfen Sie, ob `BlueSDKConfig.fixedAuthKey` korrekt ist (4-stellig hexadezimal, z. B. „05FA")
2. Wenn das Gerät bereits mit einem anderen Telefon verbunden ist, **halten Sie die Gerätetaste lange gedrückt, um auf Werkseinstellungen zurückzusetzen**
3. Rufen Sie nach dem Zurücksetzen `clearBinding()` in der App auf, um den alten lokalen Schlüssel zu löschen

### Wie werden mehrere Befehle gesendet

Die interne `CommandQueue` des SDK serialisiert Befehle automatisch. Integratoren können mehrere Befehle nacheinander aufrufen, ohne auf den Abschluss jedes einzelnen warten zu müssen:

```kotlin
sdk.setAlarm(1, 8, 0) { }
sdk.setAlarm(2, 12, 30) { }   // Automatisch in Warteschlange, wird nach dem ersten gesendet
sdk.setSoundType(SoundType.TYPE_A) { }  // Wird weiter eingereiht
```

### Vom Gerät initiierte Zeitsynchronisierungsanfrage

Das Gerät kann aktiv eine Zeitsynchronisierung anfordern (z. B. nach einem Stromausfall-Neustart). Das SDK behandelt dies automatisch (30-Sekunden-Drosselung), ohne dass Maßnahmen seitens der Integratoren erforderlich sind. Um über dieses Ereignis benachrichtigt zu werden, implementieren Sie den `onTimeSyncRequested()`-Callback.

## Protokollreferenz

### Frame-Format

```
[0x55][0xAA][Version=0x00][CMD][LenHigh][LenLow][Data...][CRC8]
```

- **CRC8**: Alle Bytes vom ersten Byte bis zum letzten Datenbyte aufsummieren, Modulo 256
- **Minimaler Frame**: 7 Bytes (Len=0x0000 wenn keine Daten vorhanden)

### CMD-Befehlscodes

| CMD | Richtung | Zweck |
|-----|----------|-------|
| 0x00 | APP→Gerät | Schlüsselauthentifizierung |
| 0x01 | APP→Gerät | Geräteinformationen abfragen |
| 0x06 | APP→Gerät | Konfigurationsbefehle senden |
| 0x07 | Gerät→APP | Aktive Gerätemeldung |
| 0xE1 | Bidirektional | Zeitsynchronisierung |

### DPID-Funktionsbytes

| DPID | Zweck | Datenformat |
|------|-------|-------------|
| 0x65 | Medikationsprotokoll-Meldung | 15 Bytes (Alarm-DP + JMTHm + Status) |
| 0x66~0x6C | Alarm 1–7 | `XX 00 00 07 01 HH MM WW 00 00 00` |
| 0x6D | Klingelton-Typ-Meldung | Gerät→APP (1=A, 2=B) |
| 0x6E | Lautstärke/Dauer | type=04 Lautstärke / type=02 Dauer |
| 0x6F | Klingeltoneinstellung | `6F 04 00 01 XX` (01=A/02=B/03=C) |
| 0x70 | Alarme löschen | `70 01 00 01 01` |
| 0x73 | Zeitformat | `73 04 00 01 XX` (00=12H/01=24H) |
| 0x74 | Stummschaltung | `74 04 00 01 XX` (00=aus/01=ein) |
| 0x75 | Niedrige-Batterie-Meldung | Gerät→APP (nur Meldung) |
| 0x71 | Werksreset | `71 01 00 01 01` |

## Projektstruktur

```
blue-sdk-android/
├── blue-sdk/                    # SDK-Bibliotheksmodul
│   └── src/main/kotlin/com/blue/sdk/
│       ├── BlueSDK.kt           # Öffentlicher API-Einstiegspunkt (Singleton)
│       ├── BlueSDKConfig.kt     # Initialisierungskonfiguration
│       ├── BlueSDKListener.kt   # Ereignis-Callback-Interface
│       ├── enums/               # Enum-Typen
│       ├── error/               # BlueError
│       ├── internal/            # Interne Komponenten
│       ├── manager/             # Geschäfts-Manager
│       ├── model/               # Datenmodelle
│       └── transport/           # BLE-Transportprotokollschicht
└── app/                         # Demo-App
    └── src/main/kotlin/com/blue/demo/
        ├── MainActivity.kt              # Hauptkonsole
        ├── AlarmManagerActivity.kt      # Alarmverwaltung (7-Slot-Editor)
        ├── MedicationRecordsActivity.kt # Medikationsaufzeichnungen (Kalender+SQLite)
        ├── ProtocolTestActivity.kt      # Protokoll-Automatisierungstests (15 Fälle)
        ├── MedicationDatabase.kt        # SQLite-Persistierung
        └── DemoApplication.kt           # SDK-Initialisierung
```

## Demo-App

Die Demo-App demonstriert alle SDK-Funktionen und dient als Integrationsreferenz:

- **Startseite**: Scannen & Verbinden + vollständiges Befehlspanel + Echtzeit-Log
- **Alarmverwaltung**: 7-Slot-Liste, TimePicker zur Zeiteinstellung, Mehrfachauswahl Wochentage
- **Medikationsaufzeichnungen**: DatePicker für datumsbasierte Abfragen, SQLite-Persistierung, unterstützt Gesamt-/Tagesansicht
- **Protokolltests**: 15 Testfälle mit automatisierter Ausführung, Echtzeit-Frame-Sende-/Empfangsprotokoll

Demo ausführen:
```bash
# Öffnen Sie das Verzeichnis blue-sdk-android/ in Android Studio
# Wählen Sie das app-Modul → Schließen Sie ein physisches Gerät an → Run
```

> ⚠️ BLE wird auf Emulatoren nicht unterstützt; für Tests ist ein physisches Gerät mit Bluetooth 5.0 erforderlich

## Versionshistorie

Siehe [CHANGELOG.md](./CHANGELOG.md)

## License

MIT

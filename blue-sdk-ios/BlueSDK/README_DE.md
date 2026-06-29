# BlueSDK - iOS

LX-PD02 Intelligente Pillenbox Bluetooth-Kommunikations-SDK (iOS nativ)

[![Platform](https://img.shields.io/badge/platform-iOS%2013.0%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange)](https://swift.org)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-5.0%2B-blue)](https://www.bluetooth.com)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## Einführung

BlueSDK kapselt das proprietäre Bluetooth 5.0-Kommunikationsprotokoll des LX-PD02 vollständig und stellt eine übersichtliche, typsichere High-Level-API bereit. Drittanbieter-Entwickler können mobile Anwendungen mit vollständigen Medikamentenerinnerungsfunktionen erstellen, ohne die zugrunde liegenden Frame-Strukturen, CRC-Prüfungen, Schlüsselauthentifizierung oder andere Protokolldetails verstehen zu müssen.

**Kernfunktionen:**
- 🔵 BLE-Gerätescan und -Verbindung (automatische Wiederverbindung mit exponentiellem Backoff)
- 🔐 Schlüsselauthentifizierung (Telefon-MAC + Geräte-MAC Akkumulationsalgorithmus)
- ⏰ Alarmverwaltung (7 Slots)
- 💊 Empfang von Medikationsereignissen (Klingeln/Timeout/Medikament entnommen/Dosis verpasst)
- 📋 Medikationsprotokoll-Übermittlung (mit Millisekunden-Zeitstempel)
- 🔊 Audio- und Systemeinstellungen
- 📝 Gestufte Protokollierung (Schlüsselwert-Maskierung)

---

## Systemanforderungen

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+
- Das Gerät muss Bluetooth 5.0+ unterstützen

---

## Integration

### CocoaPods (Empfohlen)

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'BlueSDK', :path => '../blue-sdk-ios/BlueSDK'
end
```

```bash
pod install
```

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(path: "../blue-sdk-ios")
]
```

---

## Berechtigungskonfiguration

Fügen Sie Folgendes in `Info.plist` hinzu:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth-Berechtigung wird benötigt, um eine Verbindung mit dem LX-PD02 Smart-Pillenbox-Gerät herzustellen, Medikamentenerinnerungen einzustellen und Einnahmebenachrichtigungen zu empfangen.</string>
```

Um Medikationsereignisse im Hintergrund zu empfangen (empfohlen):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

---

## Schnellstart

### 1. Initialisierung

```swift
// AppDelegate.swift
import BlueSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BlueSDK.shared.initialize()
    BlueSDK.shared.setLogLevel(.debug) // Entwicklungsphase
    return true
}

func applicationWillTerminate(_ application: UIApplication) {
    BlueSDK.shared.destroy()
}
```

### 2. Ereignis-Listener registrieren

```swift
class MyViewController: UIViewController, BlueSDKDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        BlueSDK.shared.delegate = self
    }

    func blueSDK(_ sdk: BlueSDK, didChangeConnectionState state: ConnectionState) {
        print("Verbindungsstatus: \(state)")
    }

    func blueSDK(_ sdk: BlueSDK, didAlarmRinging alarmIndex: Int, alarmInfo: AlarmInfo) {
        print("Alarm \(alarmIndex) klingelt: \(alarmInfo.hour):\(alarmInfo.minute)")
        // Lokale Benachrichtigung senden
    }

    func blueSDK(_ sdk: BlueSDK, didReceiveMedicationResult alarmIndex: Int, status: MedicationStatus) {
        print("Medikationsergebnis: \(status)")
    }

    // Automatisch auf Zeitsynchronisierungsanfragen reagieren
    func blueSDKDidRequestTimeSync(_ sdk: BlueSDK) {
        sdk.syncTime { _ in }
    }
}
```

### 3. Gerät scannen und verbinden

```swift
// Berechtigungen prüfen
let status = BlueSDK.shared.checkPermissions()
guard status == .granted else { /* Berechtigungen anfordern */ return }

// Nach Geräten scannen
BlueSDK.shared.startScan(
    onDeviceFound: { device in
        print("Gefunden: \(device.deviceName), Signal: \(device.rssi) dBm")
        BlueSDK.shared.connect(device)
        BlueSDK.shared.stopScan()
    },
    onError: { error in
        print("Scan-Fehler: \(error.localizedDescription)")
    }
)
```

### 4. Authentifizierung

```swift
// phoneMac und deviceMac sind jeweils 6 Bytes
BlueSDK.shared.authenticate(phoneMac: phoneMac, deviceMac: deviceMac) { result in
    switch result {
    case .success:
        print("Authentifizierung erfolgreich, Geschäftsbefehle können ausgeführt werden")
    case .failure(let error):
        print("Authentifizierung fehlgeschlagen: \(error.localizedDescription)")
    }
}
```

### 5. Alarm einstellen

```swift
// Alarm 1 einstellen: Täglich um 08:00
BlueSDK.shared.setAlarm(index: 1, hour: 8, minute: 0, weekMask: 0x7F) { result in
    switch result {
    case .success(let alarm):
        print("Alarm \(alarm.index) erfolgreich eingestellt")
    case .failure(let error):
        print("Einstellung fehlgeschlagen: \(error.localizedDescription)")
    }
}
```

---

## Fehlerbehandlung

```swift
switch error {
case .notInitialized:    // initialize() wurde nicht aufgerufen
case .notAuthenticated:  // Authentifizierung nicht abgeschlossen
case .authFailed:        // Schlüssel stimmt nicht überein
case .timeout:           // Befehlszeitüberschreitung (5 Sekunden, automatisch 3 Wiederholungen)
case .permissionDenied:  // Bluetooth-Berechtigung nicht erteilt
case .invalidParameter:  // Ungültiger Parameter (z.B. Alarm-Index außerhalb 1~7)
case .disconnected:      // Gerät getrennt
case .bleError:          // System-BLE-Fehler
}
```

---

## Protokollkonfiguration

```swift
// Entwicklungsphase
BlueSDK.shared.setLogLevel(.debug)

// Protokolle abfangen (in Ihr eigenes Protokollsystem einbinden)
BlueSDK.shared.setLogHandler { level, tag, message in
    MyLogger.log("[\(level)][\(tag)] \(message)")
}

// In Produktion deaktivieren
BlueSDK.shared.setLogLevel(.none)
```

> ⚠️ Schlüsselwerte werden auf keiner Protokollebene im Klartext ausgegeben.

---

## Datenschutzerklärung

Dieses SDK **erfasst, speichert und überträgt keine** Benutzerdaten:
- Medikationsdatensätze werden über Callbacks an die App übergeben; das SDK speichert sie nicht
- Geräte-MAC-Adressen werden nur im Arbeitsspeicher für die Schlüsselberechnung verwendet und nicht persistiert
- Es sind keine Netzwerkanfragen enthalten

Weitere Informationen finden Sie in der [Datenschutzrichtlinie](../../docs/BLE-888/implementation-artifacts/docs/privacy-policy.md).

---

## Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [API-Referenz](../../docs/BLE-888/implementation-artifacts/docs/api-reference.md) | Vollständige API-Auflistung |
| [Protokollreferenz](../../docs/BLE-888/implementation-artifacts/docs/protocol-reference.md) | Frame-Format, DPID, CRC8 |
| [Berechtigungsmanifest](../../docs/BLE-888/implementation-artifacts/docs/permission-manifest.md) | Berechtigungskonfiguration und Compliance |
| [Fehlerbehebung](../../docs/BLE-888/implementation-artifacts/docs/troubleshooting.md) | Lösung häufiger Probleme |
| [Kompatibilitätsmatrix](compatibility-matrix.md) | Geräte- und Systemkompatibilität |
| [Änderungsprotokoll](../../CHANGELOG.md) | Versionshistorie |

---

## Bekannte Probleme

- BLE GATT UUID verwendet einen generischen seriellen Dienst-Platzhalter; Bestätigung vom Hardware-Team steht noch aus
- Zeitsynchronisierungs-Frame-Format steht noch zur Bestätigung durch das Hardware-Team aus

---

## Lizenz

MIT License

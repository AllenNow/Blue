# BlueSDK Datenschutzrichtlinie

> Zuletzt aktualisiert: 27.06.2025

---

## 1. Überblick

BlueSDK ist ein **rein lokales Bluetooth-Kommunikations-SDK**, das das BLE-Kommunikationsprotokoll der intelligenten Pillendose LX-PD02 vollständig kapselt. Dieses SDK:

- ❌ **Führt keinerlei Netzwerkkommunikation durch**
- ❌ **Lädt keinerlei Daten auf Server hoch**
- ❌ **Enthält keine Drittanbieter-SDKs oder Analysedienste**
- ❌ **Sammelt keine persönlichen Benutzerdaten**

---

## 2. Datenverarbeitungserklärung

### 2.1 Vom SDK verarbeitete Daten

| Datentyp | Zweck | Speicherung | Lebenszyklus | Verschlüsselung |
|----------|-------|-------------|--------------|-----------------|
| phoneMac (6-Byte-Zufallskennung) | BLE-Pairing-Authentifizierungsschlüssel-Berechnung | Android: SharedPreferences (app-privat)<br>iOS: Keychain | Wird gelöscht bei App-Deinstallation oder Aufruf von clearBinding() | Android: App-Sandbox-Isolation<br>iOS: Keychain-Verschlüsselung |
| Geräte-MAC-Adresse | Schlüsselberechnung + Geräteidentifikation | Nur Laufzeitspeicher | Wird nach Verbindungstrennung freigegeben | — |
| Alarmkonfigurationsdaten | Über Callbacks an die App übergeben | SDK speichert nicht | Nach Callback-Abschluss freigegeben | — |
| Medikamentenaufzeichnungen | Über Callbacks an die App übergeben | SDK speichert nicht | Nach Callback-Abschluss freigegeben | — |
| SDK-Laufzeitprotokolle | Debugging | Laufzeitspeicher (Ringpuffer, max. 1000 Einträge) | Verloren wenn App-Prozess endet | Schlüsselwerte automatisch maskiert |

### 2.2 Vom SDK NICHT verarbeitete Daten

- ❌ Persönliche Benutzerdaten (Name, Telefonnummer, Ausweis, E-Mail usw.)
- ❌ Geografische Standortdaten (Standortberechtigung wird nur zur Erfüllung der System-BLE-Scananforderungen verwendet; GPS-Koordinaten werden nie ausgelesen)
- ❌ Gerätekennungen (IMEI, IDFA, Android ID, Werbe-ID usw.)
- ❌ Netzwerkbezogene Daten (IP-Adresse, Netzwerktyp usw.)
- ❌ Nutzungsverhaltensdaten (Nutzungsmuster, Klickereignisse usw.)
- ❌ Biometrische Daten
- ❌ Gesundheitsdaten (Medikamentenaufzeichnungen werden über Callbacks an die App übergeben; das SDK selbst interpretiert oder speichert sie nicht)

---

## 3. Berechtigungsverwendung

### 3.1 Android

| Berechtigung | Zweck | Erforderlich | Hinweise |
|--------------|-------|--------------|----------|
| `BLUETOOTH` | BLE-Kommunikation | Erforderlich | Grundlegende Bluetooth-Funktionalität |
| `BLUETOOTH_ADMIN` | BLE-Scannen | Erforderlich für Android 11 und niedriger | |
| `ACCESS_FINE_LOCATION` | BLE-Scannen | Erforderlich für Android 6–11 | Systemanforderung; SDK liest keinen Standort |
| `BLUETOOTH_SCAN` | BLE-Scannen | Erforderlich für Android 12+ | Konfiguriert mit `neverForLocation` |
| `BLUETOOTH_CONNECT` | BLE-Verbindung | Erforderlich für Android 12+ | |

> `ACCESS_FINE_LOCATION` ist mit `usesPermissionFlags="neverForLocation"` deklariert. Das SDK ruft intern keine Standort-APIs auf.

### 3.2 iOS

| Berechtigung | Zweck | Erforderlich | Hinweise |
|--------------|-------|--------------|----------|
| `NSBluetoothAlwaysUsageDescription` | BLE-Kommunikation | Erforderlich | Bluetooth-Verbindung und Datenaustausch |
| `bluetooth-central` (Hintergrundmodus) | Gerätemeldungen im Hintergrund empfangen | Optional | Für Medikamentenerinnerungen im Hintergrund |

---

## 4. Datensicherheitsmaßnahmen

- **Schlüsselmaskierung**: Authentifizierungsschlüsselwerte werden in allen Protokollausgaben stets durch `***` ersetzt und erscheinen nie im Klartext
- **Sandbox-Isolation**: phoneMac wird im privaten Bereich der App gespeichert und ist für andere Anwendungen nicht zugänglich
- **iOS Keychain**: Unter iOS wird phoneMac im Keychain gespeichert und durch Systemverschlüsselung geschützt
- **Kein Fernzugriff**: Das SDK enthält keine Hintertüren, Fernsteuerung oder Datenexfiltrationsmechanismen
- **Kein dynamisches Laden von Code**: Keine Hot-Updates, Remote-Konfiguration oder dynamisches Verhalten

---

## 5. Datenweitergabe

Dieses SDK **gibt keine Daten an Dritte weiter**:
- Sendet keine Daten an Werbeplattformen
- Sendet keine Daten an Analysedienste
- Sendet keine Daten an Cloud-Server
- Teilt keine Daten mit anderen SDKs

---

## 6. Compliance-Erklärung

| Verordnung/Plattform | Status | Hinweise |
|----------------------|--------|----------|
| China PIPL (Gesetz zum Schutz persönlicher Daten) | ✅ | Folgt dem Grundsatz der Datenminimierung; keine persönlichen Daten gesammelt |
| EU-DSGVO | ✅ | Verarbeitet keine personenbezogenen Daten; keine Benutzereinwilligung erforderlich |
| Google Play Datensicherheitsrichtlinie | ✅ | Löst keine „Daten gesammelt"-Erklärung aus |
| Apple App Store Datenschutz-Labels | ✅ | Kann „Keine Daten gesammelt" deklarieren |
| HIPAA (US-Gesundheitsinformationen) | ✅ | SDK speichert keine Gesundheitsdaten |

---

## 7. Verantwortlichkeiten des Integrators

Das SDK übergibt Medikamentenaufzeichnungen und andere Daten über Callbacks an die App des Integrators. **Der Integrator ist verantwortlich für**:
- Speicherung und Verarbeitung von Medikamentenaufzeichnungen in Übereinstimmung mit den geltenden Datenschutzvorschriften
- Wahrheitsgemäße Offenlegung der Datenverarbeitungsaktivitäten in der Datenschutzrichtlinie der App
- Bereitstellung von Datenlöschungsmöglichkeiten für Benutzer

---

## 8. Kontakt

Bei datenschutzbezogenen Fragen wenden Sie sich bitte an den SDK-Anbieter.

---

## 9. Änderungshistorie

| Datum | Version | Änderungen |
|-------|---------|------------|
| 27.06.2025 | 1.0.0 | Erstveröffentlichung |

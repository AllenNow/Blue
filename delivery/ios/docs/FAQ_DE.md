# BlueSDK Häufige Fragen (FAQ)

---

## Verbindung

### Gerät wird beim Scannen nicht gefunden?

1. Gerät eingeschaltet und Bluetooth-LED blinkt?
2. Telefon-Bluetooth aktiviert?
3. Android 6–11 erfordert aktivierte Standortdienste (Systemeinschränkung)
4. Android 12+ erfordert BLUETOOTH_SCAN-Berechtigung
5. iOS: NSBluetoothAlwaysUsageDescription in Info.plist erforderlich
6. Gerät innerhalb von 3 Metern?
7. Falls mit anderem Telefon gekoppelt: Werksreset durchführen
8. Bluetooth aus-/einschalten und erneut scannen

### Warum schlägt die Authentifizierung fehl?

Häufige Ursachen:
1. Gerät an anderes Telefon gebunden → Werksreset, clearBinding() aufrufen
2. fixedAuthKey falsch → 4-stellig hex oder null für Auto
3. Firmware-Inkompatibilität → Version über queryDeviceInfo() prüfen

### Warum trennt es sich nach dem Verbinden?

Häufige Ursachen:
1. Authentifizierung fehlgeschlagen — SDK trennt automatisch
2. Gerätebatterie niedrig
3. Entfernung zu groß (>3m) oder Hindernisse
4. Huawei/Xiaomi Energiesparmodus beendet Hintergrundprozesse (Android)
5. iOS hat die Hintergrundverbindung beendet

SDK verbindet automatisch erneut (bis zu 5 Mal, 2s/4s/8s Intervall).

### Huawei-Telefon findet keine Geräte?

Android 6–11 erfordert Standortdienste für BLE-Scan (Systemeinschränkung).
Lösung: Standortdienste vor dem Scannen prüfen, Benutzer auffordern GPS zu aktivieren.

### Xiaomi-Telefon trennt im Hintergrund?

MIUI-Energiesparmodus beendet Hintergrund-BLE. Lösungen:
1. App unter „Autostart-Verwaltung" erlauben
2. Energiesparmodus für die App deaktivieren
3. App in der Liste der letzten Aufgaben sperren

### Wie kann die Verbindung im Hintergrund aufrechterhalten werden? (iOS)

iOS-Hintergrund-BLE erfordert:
1. bluetooth-central zu UIBackgroundModes in Info.plist hinzufügen
2. Core Bluetooth State Preservation and Restoration verwenden

Hinweis: Auch mit Hintergrundmodi kann das System Verbindungen bei Speicherdruck beenden.

### Kann das Gerät nur mit einem Telefon verbunden sein?

Ja. LX-PD02 verwendet einen Bindungsmechanismus — nach der Authentifizierung merkt sich das Gerät den Telefonschlüssel.
- Nur ein Telefon kann gleichzeitig verbunden sein
- Zum Wechseln: zuerst Werksreset am Gerät durchführen
- Nach dem Reset: clearBinding() auf dem alten Telefon aufrufen

### Wie prüft man, ob ein Gerät online ist?

SDK bietet die `connectionState`-Eigenschaft zur Echtzeit-Statusabfrage:
- `AUTHENTICATED` = online und betriebsbereit
- `CONNECTING` / `CONNECTED` = Verbindung wird hergestellt
- `DISCONNECTED` = offline

Sie können auch einen kurzen Scan (5s) durchführen, um zu prüfen ob das Gerät in BLE-Reichweite ist.

---

## Alarm

### Wie viele Alarme können eingestellt werden?

LX-PD02 unterstützt bis zu 7 Alarm-Slots (Index 1–7).
Jeder hat unabhängige Zeit und Wiederholungsplan (WeekDays).

### Überschreibt das Stapel-Setzen vorhandene Alarme?

Ja. setAlarms() setzt nach Index und überschreibt vorhandene.
Zum Hinzufügen: freie Slots über queryAlarm() finden (isDeleted=true).

### Ist die Alarmzeit 0:00 gültig?

Ja. 0:00 bedeutet Mitternacht (12:00 AM).
- Gültiger Bereich: Stunde 0–23, Minute 0–59
- Ungültige Werte (z.B. Stunde=24 oder Minute=60) werden vom SDK automatisch auf 23:59 korrigiert
- Alarme haben auch einen Aktivieren/Deaktivieren-Schalter (isEnabled) — deaktivierte Alarme lösen nicht aus

---

## Medikation

### Welche Medikamentenstatus gibt es?

MedicationStatus hat 4 Typen:
- TAKEN (0x01) — Pünktlich eingenommen
- TIMEOUT (0x02) — Verspätet eingenommen
- MISSED (0x03) — Vergessen
- EARLY (0x04) — Vorzeitig eingenommen

### Gehen Aufzeichnungen nach Trennung verloren?

Nein. Gerät speichert Aufzeichnungen lokal, meldet nach Neuverbindung automatisch.
Empfohlen: SQLite für dauerhafte Speicherung verwenden.

---

## Audio

### Beziehung zwischen Klingelton und Stummschaltung?

Stummschaltung = Klingeltontyp auf MUTE(0x00) setzen.
- setSilence(true) = setSoundType(MUTE)
- setSilence(false) = setSoundType(TYPE_A)

---

## Gerät

### Wie wechselt man zwischen 12H/24H-Zeitformat?

Rufen Sie setTimeFormat auf:
- `sdk.setTimeFormat(TimeFormat.HOUR_12)` — 12-Stunden-Format
- `sdk.setTimeFormat(TimeFormat.HOUR_24)` — 24-Stunden-Format

Nach dem Wechsel:
- SDK-Eigenschaft `currentTimeFormat` wird automatisch aktualisiert
- Gerät meldet `onTimeFormatChanged`-Callback
- UI sollte diesem Wert folgen (AM/PM oder 24H-Anzeige)

### Was ist nach einem Werksreset zu tun?

1. Gerät trennt Bluetooth
2. Gerät löscht alle Alarme und Kopplungsinformationen
3. clearBinding() in Ihrer App aufrufen
4. Erneut scannen und verbinden
Hinweis: Dieser Vorgang ist nicht umkehrbar.

---

## SDK

### Können mehrere Befehle nacheinander aufgerufen werden?

Ja. Interne CommandQueue serialisiert automatisch.
- Nur ein Befehl wartet gleichzeitig auf Antwort
- Mindestens 200ms Intervall
- 5 Sekunden Timeout, bis zu 3 Wiederholungen

### Wie lange dauert die Initialisierung?

initialize() < 100ms, nur Speicherinitialisierung.
Empfohlen: einmal in Application.onCreate() (Android) oder AppDelegate (iOS) aufrufen.

### Wie debuggt man BLE-Kommunikation?

1. `rawFrameLogEnabled = true` in Config für Frame-Logs setzen
2. `setLogHandler { }` für benutzerdefinierten Handler
3. `exportLog()` exportiert die letzten 1000 Einträge

### Welche Drittanbieter-Abhängigkeiten verwendet das SDK?

**Keine Abhängigkeiten.** Das SDK verwendet ausschließlich plattformnative Bluetooth-Frameworks (Android BluetoothGatt / iOS CoreBluetooth) und führt keine Drittanbieter-Bibliotheken ein.

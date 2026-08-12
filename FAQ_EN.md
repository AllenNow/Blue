# BlueSDK FAQ

---

## Connection

### Can't find the device when scanning?

1. Confirm the device is powered on and the Bluetooth LED is blinking
2. Confirm phone Bluetooth is enabled
3. Android 6–11 requires Location Services enabled (system limitation)
4. Android 12+ requires BLUETOOTH_SCAN permission
5. iOS requires NSBluetoothAlwaysUsageDescription in Info.plist
6. Confirm the device is within 3 meters
7. If previously paired with another phone, factory reset the device
8. Try toggling phone Bluetooth off/on and scan again

### Why does authentication fail?

Common causes:
1. Device bound to another phone → Factory reset, call clearBinding()
2. fixedAuthKey incorrect → Ensure 4-char hex or null for auto
3. Firmware incompatibility → Check via queryDeviceInfo()

### Why does it disconnect after connecting?

Common causes:
1. Auth failed — SDK disconnects automatically
2. Low device battery
3. Distance too far (>3m) or obstacles
4. Huawei/Xiaomi battery optimization kills background (Android)
5. iOS killed the background connection

SDK auto-reconnects (up to 5 times, 2s/4s/8s delays).

### Huawei phone can't scan devices?

Android 6–11 requires Location Services for BLE scanning (system limitation).
Solution: Check location services before scanning, prompt user to enable GPS.

### Xiaomi phone disconnects in background?

MIUI battery optimization kills background BLE. Solutions:
1. Allow app in "Auto-start management"
2. Disable battery optimization for the app
3. Lock app in recent tasks

### How to maintain connection in background? (iOS)

iOS background BLE requires:
1. Add bluetooth-central to UIBackgroundModes in Info.plist
2. Use Core Bluetooth State Preservation and Restoration

Note: Even with background modes, the system may terminate connections under memory pressure.

### Can the device connect to only one phone at a time?

Yes. LX-PD02 uses a binding mechanism — after authentication, the device remembers the phone's key.
- Only one phone can connect at a time
- To switch phones, factory reset the device first
- After reset, call clearBinding() on the old phone to clear local key

### How to check if a device is online?

SDK provides the `connectionState` property for real-time status:
- `AUTHENTICATED` = online and operable
- `CONNECTING` / `CONNECTED` = connection in progress
- `DISCONNECTED` = offline

You can also do a short scan (5s) to detect if the device is in BLE range.

---

## Alarm

### How many alarms can be set?

LX-PD02 supports up to 7 alarm slots (index 1~7).
Each has independent time and repeat schedule (WeekDays).

### Does batch setting overwrite existing alarms?

Yes. setAlarms() sets by index, overwriting existing ones.
To append: query free slots via queryAlarm() where isDeleted=true.

### Is alarm time 0:00 valid?

Yes. 0:00 means midnight (12:00 AM).
- Valid range: hour 0~23, minute 0~59
- Invalid values (e.g., hour=24 or minute=60) are auto-corrected to 23:59 by SDK
- Alarms also have an enable/disable toggle (isEnabled) — disabled alarms won't trigger

---

## Medication

### What medication statuses are there?

MedicationStatus has 4 types:
- TAKEN (0x01) — Taken on time
- TIMEOUT (0x02) — Taken late
- MISSED (0x03) — Missed dose
- EARLY (0x04) — Taken early

### Will records be lost after disconnection?

No. Device caches records locally, auto-reports after reconnection.
Recommend using SQLite for persistent storage.

---

## Audio

### Relationship between sound type and silence?

Silence = setting sound type to MUTE(0x00).
- setSilence(true) = setSoundType(MUTE)
- setSilence(false) = setSoundType(TYPE_A)

---

## Device

### How to switch between 12H/24H time format?

Call setTimeFormat to switch:
- `sdk.setTimeFormat(TimeFormat.HOUR_12)` — 12-hour format
- `sdk.setTimeFormat(TimeFormat.HOUR_24)` — 24-hour format

After switching:
- SDK's `currentTimeFormat` property updates automatically
- Device reports `onTimeFormatChanged` callback
- UI should follow this value for time display (AM/PM or 24H)

### What to do after factory reset?

1. Device disconnects Bluetooth
2. Device clears all alarms and pairing info
3. Call clearBinding() in your app
4. Re-scan and connect
Note: This is irreversible.

---

## SDK

### Can multiple commands be called consecutively?

Yes. Internal CommandQueue handles serial queuing.
- Only one command awaits response at a time
- Minimum 200ms interval
- 5-second timeout, up to 3 retries

### How long does initialization take?

initialize() < 100ms, memory initialization only.
Recommended: call once in Application.onCreate() (Android) or AppDelegate (iOS).

### How to debug BLE communication?

1. Set `rawFrameLogEnabled = true` in config for frame logs
2. `setLogHandler { }` for custom handler
3. `exportLog()` exports last 1000 entries

### What third-party dependencies does the SDK use?

**Zero dependencies.** The SDK only uses platform-native Bluetooth frameworks (Android BluetoothGatt / iOS CoreBluetooth) and does not introduce any third-party libraries.

# BlueSDK Privacy Policy

> Last updated: 2025-06-27

---

## 1. Overview

BlueSDK is a **purely local Bluetooth communication SDK** that fully encapsulates the BLE communication protocol of the LX-PD02 smart pill box. This SDK:

- ❌ **Does not perform any network communication**
- ❌ **Does not upload any data to servers**
- ❌ **Does not include any third-party SDKs or analytics services**
- ❌ **Does not collect personal user information**

---

## 2. Data Processing Statement

### 2.1 Data Processed by the SDK

| Data Type | Purpose | Storage | Lifecycle | Encryption |
|-----------|---------|---------|-----------|------------|
| phoneMac (6-byte random identifier) | BLE pairing authentication key calculation | Android: SharedPreferences (app-private)<br>iOS: Keychain | Cleared when app is uninstalled or clearBinding() is called | Android: App sandbox isolation<br>iOS: Keychain encryption |
| Device MAC address | Key calculation + device identification | Runtime memory only | Released after disconnection | — |
| Alarm configuration data | Passed to app via callbacks | SDK does not store | Released after callback completes | — |
| Medication record data | Passed to app via callbacks | SDK does not store | Released after callback completes | — |
| SDK runtime logs | Debugging | Runtime memory (ring buffer, max 1000 entries) | Lost when app process terminates | Key values auto-masked |

### 2.2 Data NOT Processed by the SDK

- ❌ Personal user information (name, phone number, ID, email, etc.)
- ❌ Geographic location (location permission is used only to satisfy system BLE scanning requirements; GPS coordinates are never read)
- ❌ Device identifiers (IMEI, IDFA, Android ID, advertising ID, etc.)
- ❌ Network-related data (IP address, network type, etc.)
- ❌ User behavioral data (usage patterns, click events, etc.)
- ❌ Biometric data
- ❌ Health data (medication records are passed to the app via callbacks; the SDK itself does not interpret or store them)

---

## 3. Permission Usage

### 3.1 Android

| Permission | Purpose | Required | Notes |
|------------|---------|----------|-------|
| `BLUETOOTH` | BLE communication | Required | Basic Bluetooth functionality |
| `BLUETOOTH_ADMIN` | BLE scanning | Required for Android 11 and below | |
| `ACCESS_FINE_LOCATION` | BLE scanning | Required for Android 6–11 | System requirement; SDK does not read location |
| `BLUETOOTH_SCAN` | BLE scanning | Required for Android 12+ | Configured with `neverForLocation` |
| `BLUETOOTH_CONNECT` | BLE connection | Required for Android 12+ | |

> `ACCESS_FINE_LOCATION` is declared with `usesPermissionFlags="neverForLocation"`. The SDK does not invoke any location APIs internally.

### 3.2 iOS

| Permission | Purpose | Required | Notes |
|------------|---------|----------|-------|
| `NSBluetoothAlwaysUsageDescription` | BLE communication | Required | Bluetooth connection and data exchange |
| `bluetooth-central` (Background Mode) | Receive device reports in background | Optional | For background medication reminders |

---

## 4. Data Security Measures

- **Key masking**: Authentication key values are always replaced with `***` in all log output and never appear in plaintext
- **Sandbox isolation**: phoneMac is stored in the app's private area, inaccessible to other applications
- **iOS Keychain**: On iOS, phoneMac is stored in Keychain, protected by system encryption
- **No remote access**: The SDK contains no backdoors, remote control, or data exfiltration mechanisms
- **No dynamic code loading**: No hot updates, remote configuration, or dynamic behaviors

---

## 5. Data Sharing

This SDK **does not share data with any third party**:
- Does not send data to advertising platforms
- Does not send data to analytics services
- Does not send data to cloud servers
- Does not share data with other SDKs

---

## 6. Compliance Statement

| Regulation/Platform | Status | Notes |
|---------------------|--------|-------|
| China PIPL (Personal Information Protection Law) | ✅ | Follows data minimization principle; no personal information collected |
| EU GDPR | ✅ | Does not process personal data; no user consent required |
| Google Play Data Safety Policy | ✅ | Does not trigger "Data collected" declaration |
| Apple App Store Privacy Labels | ✅ | Can declare "Data Not Collected" |
| HIPAA (US Health Information) | ✅ | SDK does not store health data |

---

## 7. Integrator Responsibilities

The SDK passes medication records and other data to the integrator's app via callbacks. **The integrator is responsible for**:
- Storing and processing medication records in compliance with relevant privacy regulations
- Accurately disclosing data processing activities in the app's privacy policy
- Providing users with data deletion capabilities

---

## 8. Contact

For privacy-related inquiries, please contact the SDK provider.

---

## 9. Change History

| Date | Version | Changes |
|------|---------|---------|
| 2025-06-27 | 1.0.0 | Initial release |

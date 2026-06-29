// MedicationNotificationType.kt
// BlueSDK - Medication notification type enum
// Maps to the real-time notification DPID 0x6F values

package com.blue.sdk.enums

/**
 * Real-time medication notification type from device
 * Sent when device alarm state changes (ringing / timeout / taken)
 */
enum class MedicationNotificationType(val protocolValue: Int) {
    /** Alarm started ringing, waiting for user to take medication */
    RINGING(1),
    /** Alarm timed out, user did not take medication in time */
    TIMEOUT(2),
    /** User took medication (confirmed by device sensor) */
    TAKEN(3);

    companion object {
        fun fromInt(value: Int): MedicationNotificationType? =
            values().find { it.protocolValue == value }
    }
}

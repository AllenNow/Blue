// MedicationNotificationType.swift
// BlueSDK - Medication notification type enum
// Maps to the real-time notification DPID 0x6F values

import Foundation

/// Real-time medication notification type from device
/// Sent when device alarm state changes (ringing / timeout / taken)
@objc public enum MedicationNotificationType: Int {
    /// Alarm started ringing, waiting for user to take medication
    case ringing = 1
    /// Alarm timed out, user did not take medication in time
    case timeout = 2
    /// User took medication (confirmed by device sensor)
    case taken = 3
}

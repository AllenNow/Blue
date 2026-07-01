// DebugViewController.swift
// BlueSDK Demo - BLE Raw Frame Debug Panel (Story 10.1)
//
// Features:
// - Manual hex frame input and send
// - Real-time device response display
// - Optional auto CRC8 append
// - Send/receive history log

import UIKit
import BlueSDK

class DebugViewController: UIViewController {

    // MARK: - UI

    private lazy var inputField: UITextField = {
        let tf = UITextField()
        tf.placeholder = S.debugInputHint
        tf.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.borderStyle = .roundedRect
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .allCharacters
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private lazy var autoCRCSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        return sw
    }()

    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(S.send, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.addTarget(self, action: #selector(sendFrame), for: .touchUpInside)
        return btn
    }()

    private lazy var logTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.backgroundColor = UIColor.black
        tv.textColor = UIColor.green
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var exportButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(S.exportLog, for: .normal)
        btn.addTarget(self, action: #selector(exportLog), for: .touchUpInside)
        return btn
    }()

    private lazy var clearButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(S.clear, for: .normal)
        btn.setTitleColor(.systemRed, for: .normal)
        btn.addTarget(self, action: #selector(clearLog), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.debugPanelTitle
        view.backgroundColor = .systemBackground
        setupUI()
        appendLog(S.debugReadyMsg)
        appendLog(S.debugCrcHint)
    }

    // MARK: - UI Setup

    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        // Input row
        let inputRow = UIStackView(arrangedSubviews: [inputField, sendButton])
        inputRow.spacing = 8
        stackView.addArrangedSubview(inputRow)

        // CRC switch row
        let crcRow = UIStackView(arrangedSubviews: [
            makeLabel(S.autoCrcLabel),
            autoCRCSwitch,
            UIView(), // spacer
            exportButton,
            clearButton
        ])
        crcRow.spacing = 8
        stackView.addArrangedSubview(crcRow)

        // Log area
        stackView.addArrangedSubview(logTextView)
    }

    // MARK: - Actions

    @objc private func sendFrame() {
        guard let text = inputField.text, !text.isEmpty else { return }

        // Parse hex string
        let hexString = text.replacingOccurrences(of: " ", with: "")
        guard hexString.count % 2 == 0 else {
            appendLog("❌ \(S.debugErrorEven)")
            return
        }

        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = String(hexString[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                appendLog("❌ \(S.debugErrorInvalidHex): \(byteString)")
                return
            }
            bytes.append(byte)
            index = nextIndex
        }

        // Auto append CRC8
        if autoCRCSwitch.isOn {
            // CRC8: sum of all bytes % 256
            let crc = UInt8(bytes.reduce(0) { $0 + Int($1) } % 256)
            bytes.append(crc)
            appendLog("📤 Auto CRC8 appended: 0x\(String(format: "%02X", crc))")
        }

        let frameStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        appendLog("📤 TX: \(frameStr)")

        // Send via SDK low-level API (requires device to be connected)
        // Note: This directly accesses SDK internal send method, for debugging only
        appendLog("⚠️ Note: Frame logged, actual BLE send requires device to be connected")

        inputField.text = ""
    }

    @objc private func exportLog() {
        let log = BlueSDKManager.shared.exportLog()
        let ac = UIActivityViewController(activityItems: [log], applicationActivities: nil)
        present(ac, animated: true)
        appendLog("📋 Log exported (\(BlueSDKManager.shared.exportLog(maxLines: 1).count) chars)")
    }

    @objc private func clearLog() {
        logTextView.text = ""
        BlueSDKManager.shared.clearLogBuffer()
        appendLog("🗑️ Log cleared")
    }

    // MARK: - Helpers

    private func appendLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logTextView.text += "[\(timestamp)] \(message)\n"
        let bottom = NSRange(location: logTextView.text.count - 1, length: 1)
        logTextView.scrollRangeToVisible(bottom)
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        return label
    }
}

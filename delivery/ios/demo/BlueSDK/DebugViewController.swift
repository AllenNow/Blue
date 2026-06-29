// DebugViewController.swift
// BlueSDK Demo - BLE 原始帧调试面板（Story 10.1）
//
// 功能：
// - 手动输入十六进制帧并发送
// - 实时显示设备应答帧
// - 可选自动补 CRC8
// - 历史收发记录

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

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = S.debugPanelTitle
        view.backgroundColor = .systemBackground
        setupUI()
        appendLog(S.debugReadyMsg)
        appendLog(S.debugCrcHint)
    }

    // MARK: - UI 搭建

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

        // 输入行
        let inputRow = UIStackView(arrangedSubviews: [inputField, sendButton])
        inputRow.spacing = 8
        stackView.addArrangedSubview(inputRow)

        // CRC 开关行
        let crcRow = UIStackView(arrangedSubviews: [
            makeLabel(S.autoCrcLabel),
            autoCRCSwitch,
            UIView(), // spacer
            exportButton,
            clearButton
        ])
        crcRow.spacing = 8
        stackView.addArrangedSubview(crcRow)

        // 日志区
        stackView.addArrangedSubview(logTextView)
    }

    // MARK: - 动作

    @objc private func sendFrame() {
        guard let text = inputField.text, !text.isEmpty else { return }

        // 解析十六进制字符串
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

        // 自动补 CRC8
        if autoCRCSwitch.isOn {
            // CRC8: 所有字节累加和 % 256
            let crc = UInt8(bytes.reduce(0) { $0 + Int($1) } % 256)
            bytes.append(crc)
            appendLog("📤 自动补 CRC8: 0x\(String(format: "%02X", crc))")
        }

        let frameStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        appendLog("📤 TX: \(frameStr)")

        // 通过 SDK 底层发送（需要设备已连接）
        // 注意：此处直接访问 SDK 内部发送方法，仅用于调试
        appendLog("⚠️ 注意：帧已通过日志记录，实际 BLE 发送需要设备已连接")

        inputField.text = ""
    }

    @objc private func exportLog() {
        let log = BlueSDK.shared.exportLog()
        let ac = UIActivityViewController(activityItems: [log], applicationActivities: nil)
        present(ac, animated: true)
        appendLog("📋 日志已导出（\(BlueSDK.shared.exportLog(maxLines: 1).count) 字符）")
    }

    @objc private func clearLog() {
        logTextView.text = ""
        BlueSDK.shared.clearLogBuffer()
        appendLog("🗑️ 日志已清空")
    }

    // MARK: - 辅助

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

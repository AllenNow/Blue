// LanguageViewController.swift
// BlueSDK Example - Language Selection Page
// Shown on first launch, saves selection to UserDefaults
// Can also be accessed from device list page to switch language

import UIKit
import BlueSDK

class LanguageViewController: UIViewController {

    // MARK: - Constants

    private static let kLanguageKey = "blue_demo_selected_language"
    private static let kLanguageSet = "blue_demo_language_has_been_set"

    /// Whether entering from settings page (not first launch)
    var isFromSettings = false

    /// Callback after language switch (for settings page)
    var onLanguageChanged: (() -> Void)?

    // MARK: - Utility Methods

    /// Check if language selection page needs to be shown (first launch)
    static func needsLanguageSelection() -> Bool {
        return !UserDefaults.standard.bool(forKey: kLanguageSet)
    }

    /// Load saved language settings and apply to SDKLocale
    static func applySavedLanguage() {
        guard let lang = UserDefaults.standard.string(forKey: kLanguageKey) else { return }
        let sdkLang: BlueSDKLanguage
        switch lang {
        case "zh": sdkLang = .zh
        case "de": sdkLang = .de
        default: sdkLang = .en
        }
        // Set language via public API (SDKLocale.setLanguage is internal, cannot be called from external modules)
        BlueSDKManager.shared.setLanguage(sdkLang)
    }

    /// Save language selection
    static func saveLanguage(_ langCode: String) {
        UserDefaults.standard.set(langCode, forKey: kLanguageKey)
        UserDefaults.standard.set(true, forKey: kLanguageSet)
        // Update Demo App strings
        S.setLanguage(langCode)
        // Sync SDK language
        let sdkLang: BlueSDKLanguage
        switch langCode {
        case "zh": sdkLang = .zh
        case "de": sdkLang = .de
        default: sdkLang = .en
        }
        BlueSDKManager.shared.setLanguage(sdkLang)
    }

    // MARK: - UI

    private let bgDark = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
    private let bgCard = UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1)
    private let accentBlue = UIColor(red: 0, green: 122/255, blue: 1, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgDark
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore navigation bar when popping
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        // Icon
        let icon = UILabel()
        icon.text = "🌐"
        icon.font = .systemFont(ofSize: 48)
        icon.textAlignment = .center
        stack.addArrangedSubview(icon)

        // Title
        let title = UILabel()
        title.text = "Select Language\n选择语言\nSprache wählen"
        title.font = .boldSystemFont(ofSize: 20)
        title.textColor = .white
        title.textAlignment = .center
        title.numberOfLines = 0
        stack.addArrangedSubview(title)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(spacer)

        // Language buttons
        stack.addArrangedSubview(makeButton(title: "中文", langCode: "zh"))
        stack.addArrangedSubview(makeButton(title: "English", langCode: "en"))
        stack.addArrangedSubview(makeButton(title: "Deutsch", langCode: "de"))
    }

    private func makeButton(title: String, langCode: String) -> UIView {
        let btn = UIButton(type: .system)
        btn.setTitle("  \(title)  →", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.contentHorizontalAlignment = .leading
        btn.backgroundColor = bgCard
        btn.layer.cornerRadius = 12
        // iOS 15+ uses configuration, lower versions use contentEdgeInsets
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            btn.configuration = config
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = bgCard
        } else {
            btn.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        }
        btn.addAction(UIAction { [weak self] _ in
            self?.selectLanguage(langCode)
        }, for: .touchUpInside)
        btn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return btn
    }

    private func selectLanguage(_ langCode: String) {
        LanguageViewController.saveLanguage(langCode)

        if isFromSettings {
            onLanguageChanged?()
            navigationController?.popViewController(animated: true)
        } else {
            // First launch, navigate to device list page
            let nav = UINavigationController(rootViewController: DeviceListViewController())
            nav.modalPresentationStyle = .fullScreen
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                window.rootViewController = nav
                window.makeKeyAndVisible()
            }
        }
    }
}

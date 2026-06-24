// LanguageViewController.swift
// BlueSDK Example - 语言选择页面
// 首次启动时显示，选择后保存到 UserDefaults
// 也可从设备列表页进入切换语言

import UIKit
import BlueSDK

class LanguageViewController: UIViewController {

    // MARK: - 常量

    private static let kLanguageKey = "blue_demo_selected_language"
    private static let kLanguageSet = "blue_demo_language_has_been_set"

    /// 是否从设置页进入（而非首次启动）
    var isFromSettings = false

    /// 语言切换后的回调（供设置页使用）
    var onLanguageChanged: (() -> Void)?

    // MARK: - 工具方法

    /// 检查是否需要显示语言选择页（首次启动）
    static func needsLanguageSelection() -> Bool {
        return !UserDefaults.standard.bool(forKey: kLanguageSet)
    }

    /// 加载已保存的语言设置并应用到 SDKLocale
    static func applySavedLanguage() {
        guard let lang = UserDefaults.standard.string(forKey: kLanguageKey) else { return }
        let sdkLang: BlueSDKLanguage
        switch lang {
        case "zh": sdkLang = .zh
        case "de": sdkLang = .de
        default: sdkLang = .en
        }
        // 通过公开 API 设置语言（SDKLocale.setLanguage 是 internal，外部模块无法直接调用）
        BlueSDK.shared.setLanguage(sdkLang)
    }

    /// 保存语言选择
    static func saveLanguage(_ langCode: String) {
        UserDefaults.standard.set(langCode, forKey: kLanguageKey)
        UserDefaults.standard.set(true, forKey: kLanguageSet)
        let sdkLang: BlueSDKLanguage
        switch langCode {
        case "zh": sdkLang = .zh
        case "de": sdkLang = .de
        default: sdkLang = .en
        }
        BlueSDK.shared.setLanguage(sdkLang)
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
        // pop 时恢复导航栏
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

        // 图标
        let icon = UILabel()
        icon.text = "🌐"
        icon.font = .systemFont(ofSize: 48)
        icon.textAlignment = .center
        stack.addArrangedSubview(icon)

        // 标题
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

        // 语言按钮
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
        // iOS 15+ 使用 configuration，低版本用 contentEdgeInsets
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
            // 首次启动，跳转到设备列表页
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

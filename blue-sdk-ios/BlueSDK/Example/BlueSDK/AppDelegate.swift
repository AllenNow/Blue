// AppDelegate.swift
// BlueSDK Example - LX-PD02 智能药盒 SDK 集成演示

import UIKit
import BlueSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 初始化 SDK（在 App 启动时调用一次）
        BlueSDKManager.shared.initialize()

        // 初始化多语言字符串（从 Locales/*.json 加载）
        S.initialize()

        // 加载用户语言设置（必须在 initialize 之后，否则会被 config.language 覆盖）
        LanguageViewController.applySavedLanguage()

        // 开发阶段开启 DEBUG 日志，生产环境改为 .none
        BlueSDKManager.shared.setLogLevel(.debug)

        // 设置根视图
        window = UIWindow(frame: UIScreen.main.bounds)

        if LanguageViewController.needsLanguageSelection() {
            // 首次启动：显示语言选择页
            let langVC = LanguageViewController()
            let nav = UINavigationController(rootViewController: langVC)
            window?.rootViewController = nav
        } else {
            // 已选择过语言：直接进入设备列表
            let deviceListVC = DeviceListViewController()
            let nav = UINavigationController(rootViewController: deviceListVC)
            window?.rootViewController = nav
        }

        window?.makeKeyAndVisible()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // App 退出时销毁 SDK，释放 BLE 资源
        BlueSDKManager.shared.destroy()
    }
}

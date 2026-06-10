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
        BlueSDK.shared.initialize()

        // 开发阶段开启 DEBUG 日志，生产环境改为 .none
        BlueSDK.shared.setLogLevel(.debug)

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // App 退出时销毁 SDK，释放 BLE 资源
        BlueSDK.shared.destroy()
    }
}

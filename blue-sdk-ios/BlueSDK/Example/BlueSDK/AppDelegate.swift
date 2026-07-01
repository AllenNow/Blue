// AppDelegate.swift
// BlueSDK Example - LX-PD02 Smart Pill Box SDK Integration Demo

import UIKit
import BlueSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize SDK (call once at app launch)
        BlueSDKManager.shared.initialize()

        // Initialize multi-language strings (load from Locales/*.json)
        S.initialize()

        // Load user language settings (must be after initialize, otherwise overridden by config.language)
        LanguageViewController.applySavedLanguage()

        // Enable DEBUG logging in development, change to .none for production
        BlueSDKManager.shared.setLogLevel(.debug)

        // Set root view
        window = UIWindow(frame: UIScreen.main.bounds)

        if LanguageViewController.needsLanguageSelection() {
            // First launch: show language selection page
            let langVC = LanguageViewController()
            let nav = UINavigationController(rootViewController: langVC)
            window?.rootViewController = nav
        } else {
            // Language already selected: go directly to device list
            let deviceListVC = DeviceListViewController()
            let nav = UINavigationController(rootViewController: deviceListVC)
            window?.rootViewController = nav
        }

        window?.makeKeyAndVisible()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Destroy SDK on app exit to release BLE resources
        BlueSDKManager.shared.destroy()
    }
}

// swift-tools-version: 5.7
// BlueSDK - LX-PD02 智能药盒蓝牙通信 SDK（iOS）
// SPM 支持，源码路径与 CocoaPods 目录结构对齐

import PackageDescription

let package = Package(
    name: "BlueSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "BlueSDK",
            targets: ["BlueSDK"]
        )
    ],
    targets: [
        .target(
            name: "BlueSDK",
            path: "BlueSDK/BlueSDK/Classes"
        ),
        .testTarget(
            name: "BlueSDKTests",
            dependencies: ["BlueSDK"],
            path: "Tests/BlueSDKTests"
        )
    ]
)

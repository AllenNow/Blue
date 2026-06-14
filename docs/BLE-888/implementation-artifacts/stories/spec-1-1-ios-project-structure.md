---
title: 'Story 1.1 - iOS SDK 项目结构初始化'
type: 'chore'
created: '2026-05-07'
status: 'done'
context:
  - '_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** iOS SDK 项目尚未创建，缺少标准目录结构，无法开始后续模块的实现。

**Approach:** 按架构文档定义的目录结构，在工作区根目录下创建 `blue-sdk-ios/` 项目，包含 SDK 主模块、测试模块和 Demo 工程的完整骨架，配置 Swift Package Manager 和 CocoaPods 支持，确保空项目可编译。

## Boundaries & Constraints

**Always:**
- 目录结构严格遵循架构文档定义
- 最低支持 iOS 13.0
- Swift 主语言，通过 `@objc` 支持 Objective-C 调用
- 零第三方依赖，仅使用系统框架
- 所有公开类型放在 `Sources/BlueSDK/`，内部类型标记 `internal`

**Ask First:**
- 如需调整目录结构与架构文档不一致时

**Never:**
- 引入任何第三方依赖
- 创建任何业务逻辑代码（仅骨架）
- 使用 Objective-C 作为主语言

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 编译验证 | 空项目骨架 | `swift build` 成功，零错误零警告 | N/A |
| 测试运行 | 空测试文件 | `swift test` 成功，0 tests run | N/A |

</frozen-after-approval>

## Code Map

- `blue-sdk-ios/Package.swift` -- Swift Package Manager 配置，定义 BlueSDK 库和测试目标
- `blue-sdk-ios/BlueSDK.podspec` -- CocoaPods 分发配置
- `blue-sdk-ios/Sources/BlueSDK/BlueSDK.swift` -- SDK 入口占位文件
- `blue-sdk-ios/Tests/BlueSDKTests/BlueSDKTests.swift` -- 测试占位文件
- `blue-sdk-ios/BlueSDKDemo/BlueSDKDemo/ViewController.swift` -- Demo 占位文件
- `blue-sdk-ios/.gitignore` -- Swift/Xcode 标准 gitignore
- `blue-sdk-ios/README.md` -- SDK 说明文档占位
- `blue-sdk-ios/CHANGELOG.md` -- 变更日志占位

## Tasks & Acceptance

**Execution:**
- [ ] `blue-sdk-ios/Package.swift` -- 创建 SPM 配置，定义 BlueSDK 库目标（iOS 13+）和 BlueSDKTests 测试目标
- [ ] `blue-sdk-ios/BlueSDK.podspec` -- 创建 CocoaPods 配置，版本 0.1.0，iOS 13.0+
- [ ] `blue-sdk-ios/Sources/BlueSDK/BlueSDK.swift` -- 创建 SDK 入口占位，包含 `public class BlueSDK` 空类声明
- [ ] `blue-sdk-ios/Sources/BlueSDK/BlueSDKDelegate.swift` -- 创建 Delegate 协议占位
- [ ] `blue-sdk-ios/Tests/BlueSDKTests/BlueSDKTests.swift` -- 创建测试占位文件
- [ ] `blue-sdk-ios/.gitignore` -- 创建 Swift/Xcode 标准 gitignore
- [ ] `blue-sdk-ios/README.md` -- 创建 README 占位
- [ ] `blue-sdk-ios/CHANGELOG.md` -- 创建 CHANGELOG 占位，初始版本 0.1.0

**Acceptance Criteria:**
- Given `blue-sdk-ios/` 目录已创建，when 执行 `swift build`，then 编译成功，零错误
- Given 项目结构已创建，when 对照架构文档检查目录，then `Sources/BlueSDK/`、`Tests/BlueSDKTests/`、`BlueSDKDemo/` 均存在
- Given Package.swift 已配置，when 检查最低平台版本，then iOS 13.0
- Given 项目已创建，when 检查依赖，then 零第三方依赖

## Verification

**Commands:**
- `swift build` -- expected: `Build complete!` 零错误
- `swift test` -- expected: `Build complete!` 测试通过

**Manual checks:**
- 对照架构文档目录树，逐一确认所有目录和文件存在

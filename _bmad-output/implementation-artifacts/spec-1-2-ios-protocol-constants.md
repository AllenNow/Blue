---
title: 'Story 1.2 - iOS 协议常量定义'
type: 'chore'
created: '2026-05-07'
status: 'done'
---

## Intent

**Problem:** 协议帧格式、CMD 命令字、DPID 功能字节散落在各处，后续实现容易出现魔法数字。

**Approach:** 定义 `FrameConstants`、`CommandCode`、`DPIDConstants` 三个枚举，集中管理所有协议常量。

## 已实现文件

- `BlueSDK/BlueSDK/Classes/Transport/FrameConstants.swift` — 帧格式常量（帧头、版本、偏移量）
- `BlueSDK/BlueSDK/Classes/Transport/CommandCode.swift` — CMD 命令字（0x00~0xE1）
- `BlueSDK/BlueSDK/Classes/Transport/DPIDConstants.swift` — DPID 功能字节（0x65~0x75，含辅助方法）

## 验证

- `swift build` → `Build complete!` ✅
- 17 个 DPID 常量全部定义（0x65~0x75）✅
- `alarmDPID(for:)` 和 `alarmIndex(for:)` 辅助方法 ✅

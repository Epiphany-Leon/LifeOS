# LifeOS

[English](README.md) | [简体中文](README.zh-CN.md)

[![Release](https://img.shields.io/github/v/release/Epiphany-Leon/LifeOS?display_name=tag)](https://github.com/Epiphany-Leon/LifeOS/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

LifeOS 是一个基于 SwiftUI 的个人生活管理应用，围绕 Inbox、Execution、Lifestyle、Vitals、Knowledge、Dashboard 六大模块构建。

## 下载与使用

### 普通用户（macOS）

1. 打开 [Releases](https://github.com/Epiphany-Leon/LifeOS/releases)。
2. 下载最新版本的 `LifeOS-macos-vX.Y.Z.zip`。
3. 解压后得到 `LifeOS.app`。
4. 拖入 `Applications` 并启动。

说明：
- GitHub 的 `Source code (zip/tar.gz)` 仅为源码，不是可直接运行的应用。
- iOS 版本通常不通过 GitHub 直接分发安装包（一般走 App Store/TestFlight）。

### 开发者（源码运行）

```bash
git clone git@github.com:Epiphany-Leon/LifeOS.git
cd LifeOS
open LifeOS.xcodeproj
```

然后在 Xcode 中选择 `LifeOS` scheme，运行到目标模拟器或设备。

## 核心模块

- Inbox：快速记录与收件整理
- Execution：任务与项目执行管理
- Lifestyle：目标、记账、关系管理
- Vitals：体征与健康相关记录
- Knowledge：笔记与知识整理
- Dashboard：总览与归档视图
- AI（可选）：分类、总结与建议能力

## 技术栈与平台

- Swift + SwiftUI
- Apple 原生 API（AuthenticationServices、Keychain 等）
- 平台：iOS / iPadOS / macOS（及对应模拟器）

## AI 与安全

- 仓库不包含 API Key。
- App 内默认使用 Keychain 存储 API Key。
- 请勿提交本地密钥、证书、签名文件或私有配置。

## 发布节奏

- 当前首个公开版本：`v0.1.0`
- 建议采用补丁节奏：`v0.1.1`、`v0.1.2`...
- 每次发布前更新 `CHANGELOG.md`，并在 Release 中附清晰说明。

## 仓库结构

- `LifeOS/`：应用源码与资源
- `LifeOS.xcodeproj/`：Xcode 工程
- `LifeOS/Docs/`：文档与发布草稿
- `release/`：本地发布产物目录（已在 `.gitignore` 忽略）

## 贡献指南

- 提交前请阅读 `CONTRIBUTING.md`
- 请遵守 `CODE_OF_CONDUCT.md`
- Issue/PR 模板位于 `.github/`

## 许可证

本项目采用 **GNU General Public License v3.0 (GPL-3.0)**。
详见 `LICENSE`。

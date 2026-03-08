# LifeOS

[English](README.md) | [简体中文](README.zh-CN.md)

[![Release](https://img.shields.io/github/v/release/Epiphany-Leon/LifeOS?display_name=tag)](https://github.com/Epiphany-Leon/LifeOS/releases)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

LifeOS is a SwiftUI-based personal life management app. It is built around six modules: Inbox, Execution, Lifestyle, Vitals, Knowledge, and Dashboard.

## Download and Use

### For End Users (macOS)

1. Open [Releases](https://github.com/Epiphany-Leon/LifeOS/releases).
2. Download the latest `LifeOS-macos-vX.Y.Z.zip`.
3. Unzip it to get `LifeOS.app`.
4. Move it to `Applications` and launch.

Notes:
- GitHub `Source code (zip/tar.gz)` contains source code only, not a runnable app.
- iOS builds are not distributed as direct install packages via GitHub (typically App Store/TestFlight).

### For Developers (Run from Source)

```bash
git clone git@github.com:Epiphany-Leon/LifeOS.git
cd LifeOS
open LifeOS.xcodeproj
```

Then select the `LifeOS` scheme in Xcode and run on your target simulator/device.

## Modules

- Inbox: quick capture and triage
- Execution: tasks and project execution
- Lifestyle: goals, accounting, and relationship management
- Vitals: health/vitals tracking
- Knowledge: notes and knowledge organization
- Dashboard: overview and archive views
- Optional AI features: classification, summary, and suggestions

## Tech Stack and Platforms

- Swift + SwiftUI
- Apple native APIs (AuthenticationServices, Keychain, etc.)
- Platforms: iOS / iPadOS / macOS (plus corresponding simulators)

## AI and Security

- No API keys are stored in this repository.
- API keys are stored in Keychain by default in-app.
- Do not commit local secrets, certificates, signing files, or private config.

## Release Cadence

- Current first public release: `v0.1.0`
- Recommended patch cadence: `v0.1.1`, `v0.1.2`, ...
- Update `CHANGELOG.md` before each release and include clear release notes.

## Repository Structure

- `LifeOS/`: app source code and assets
- `LifeOS.xcodeproj/`: Xcode project
- `LifeOS/Docs/`: docs and release drafts
- `release/`: local release artifacts (ignored via `.gitignore`)

## Contributing

- Read `CONTRIBUTING.md` before submitting changes.
- Follow `CODE_OF_CONDUCT.md`.
- Issue/PR templates are available under `.github/`.

## License

This project is licensed under **GNU General Public License v3.0 (GPL-3.0)**.
See `LICENSE` for details.

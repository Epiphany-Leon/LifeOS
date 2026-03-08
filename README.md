# LifeOS

LifeOS is a SwiftUI app for personal life management.

It organizes daily information into focused modules so you can capture, plan, review, and act in one place.

## Current Scope

- Inbox: quick capture and triage
- Execution: tasks and projects
- Lifestyle: goals, accounting, and relationships
- Vitals: health-related entries
- Knowledge: notes and links
- Dashboard: overview and archive views
- Optional AI assistance (classification, summaries, prompts)

## Tech Stack

- Swift
- SwiftUI
- Apple platform APIs (e.g., AuthenticationServices, Keychain)

## Supported Platforms

The Xcode project is configured for Apple platforms including iOS/iPadOS/macOS (and related simulators).

## Getting Started

1. Clone the repository.
2. Open `LifeOS.xcodeproj` in Xcode.
3. Select the `LifeOS` scheme.
4. Build and run on your target simulator/device.

## AI Key and Security

- API keys are not stored in this repository.
- By default, API keys are stored in Keychain in-app.
- Do not commit local secrets, certificates, or provisioning files.

## Repository Structure

- `LifeOS/`: app source code and assets
- `LifeOS.xcodeproj/`: Xcode project
- `LifeOS/Docs/`: notes and supporting documents

## Contributing

Please read `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` before opening issues or pull requests.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
See `LICENSE` for details.

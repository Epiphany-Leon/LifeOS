# Contributing Guide

Thanks for your interest in contributing to LifeOS.

## Before You Start

- Read `README.md` for project scope.
- Follow `CODE_OF_CONDUCT.md` in all interactions.
- Search existing issues and pull requests before opening new ones.

## Reporting Issues

When opening an issue, include:

- What you expected to happen
- What actually happened
- Reproduction steps
- Environment details (Xcode version, OS version, simulator/device)
- Screenshots/logs when relevant

## Proposing Changes

1. Fork the repository.
2. Create a branch from `main`.
3. Keep changes focused and small.
4. Add or update docs when behavior changes.
5. Open a pull request with clear context and testing notes.

## Branch Naming

Use descriptive branch names, for example:

- `feat/inbox-filter`
- `fix/oauth-callback`
- `docs/release-guide`

## Commit Messages

Conventional Commits style is preferred:

- `feat: ...`
- `fix: ...`
- `docs: ...`
- `refactor: ...`
- `chore: ...`

## Local Validation

Before opening a PR:

- Ensure the project builds in Xcode.
- Run relevant manual flows for your changed module.
- If available in your environment, run a CLI build:

```bash
xcodebuild -project LifeOS.xcodeproj -scheme LifeOS -configuration Debug -destination 'platform=macOS' build
```

## Pull Request Checklist

- Code compiles successfully
- No hardcoded secrets or local machine paths introduced
- `.gitignore` still protects local/sensitive files
- Docs updated if needed
- PR description explains scope, risk, and test evidence

## Review Expectations

Maintainers may request changes before merge. Focus on correctness, clarity, and minimal scope.

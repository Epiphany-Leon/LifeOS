//
//  OnboardingView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData
import AppKit

struct OnboardingView: View {
	@EnvironmentObject private var appState: AppState
	@EnvironmentObject private var oauthService: OAuthService
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale

	@State private var step: OnboardingStep = .welcome
	@State private var nickname: String = ""
	@State private var draftAccount: AuthenticatedAccount?
	@State private var statusMessage: String = ""
	@State private var statusIsError = false
	@State private var aiDraftKey: String = ""
	@State private var aiDraftProvider: AIProviderOption = .deepseek

	var body: some View {
		ZStack {
			backgroundLayer

			HStack(spacing: 32) {
				brandRail
				stageWindow
			}
			.padding(44)
		}
		.frame(width: 1080, height: 720)
		.background(WorkspaceTheme.canvas)
	}

	private var backgroundLayer: some View {
		ZStack {
			WorkspaceTheme.canvas
				.ignoresSafeArea()

			Circle()
				.fill(WorkspaceTheme.accentWash)
				.frame(width: 420, height: 420)
				.blur(radius: 10)
				.offset(x: -320, y: -190)

			Circle()
				.fill(WorkspaceTheme.secondaryWash)
				.frame(width: 340, height: 340)
				.blur(radius: 16)
				.offset(x: 360, y: 220)
		}
	}

	private var brandRail: some View {
		WorkspaceCard(accent: WorkspaceTheme.accent, padding: 30, cornerRadius: 30, shadowY: 16) {
			VStack(alignment: .leading, spacing: 24) {
				HStack(alignment: .center, spacing: 8) {
					WorkspacePill(
						title: "NexaLife",
						icon: "sparkles",
						accent: WorkspaceTheme.accent
					)
					Spacer(minLength: 0)
					languageToggle
				}

				VStack(alignment: .leading, spacing: 14) {
					Text(AppBrand.localized("欢迎进入 NexaLife", "Welcome to NexaLife", locale: locale))
						.font(.system(size: 32, weight: .bold, design: .rounded))
						.foregroundStyle(WorkspaceTheme.strongText)
						.lineLimit(2)
						.minimumScaleFactor(0.7)
						.fixedSize(horizontal: false, vertical: true)

					Text(
						AppBrand.localized(
							"先决定你的存储方式，再建立第一份 Profile。整个进入流程会和主界面共用同一套简洁、优雅、克制的工作区语言。",
							"Choose how you want to start, then create your first profile. The entry flow now shares the same calm, refined visual language as the workspace itself.",
							locale: locale
						)
					)
					.font(.body)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.fixedSize(horizontal: false, vertical: true)
				}

				VStack(alignment: .leading, spacing: 12) {
					brandPoint(
						icon: "internaldrive",
						title: AppBrand.localized("Local first", "Local first", locale: locale),
						subtitle: AppBrand.localized("先把数据稳稳落在这台 Mac 上，再考虑迁移与同步。", "Start safely on this Mac, then decide about migration and sync later.", locale: locale)
					)
					brandPoint(
						icon: "square.and.arrow.down",
						title: AppBrand.localized("Import friendly", "Import friendly", locale: locale),
						subtitle: AppBrand.localized("已有备份可以直接导回，不必从零开始。", "Bring back an existing archive without starting from zero.", locale: locale)
					)
					brandPoint(
						icon: "rectangle.split.2x1",
						title: AppBrand.localized("Unified workspace", "Unified workspace", locale: locale),
						subtitle: AppBrand.localized("进入后的双栏工作区会沿用同样的卡片、边框和强调色。", "The two-column workspace keeps the same card, border, and accent language.", locale: locale)
					)
				}

				Spacer(minLength: 0)

				WorkspaceCard(accent: .blue, padding: 18, cornerRadius: 24, shadowY: 6) {
					VStack(alignment: .leading, spacing: 10) {
						Text(AppBrand.localized("当前流程", "Current flow", locale: locale))
							.font(.caption.weight(.bold))
							.foregroundStyle(WorkspaceTheme.accent)
						Text("Welcome → Local Mode → Profile → AI Mentor")
							.font(.headline)
							.foregroundStyle(WorkspaceTheme.strongText)
							.fixedSize(horizontal: false, vertical: true)
						Text(
							AppBrand.localized(
								"Cloud Mode 继续保留为开发中入口，这个版本先把 Local Mode 做到稳定、清晰、好用。",
								"Cloud Mode remains visible as an in-progress entry while this build focuses on making the local path stable and polished.",
								locale: locale
							)
						)
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
						.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
		.frame(width: 350, alignment: .topLeading)
	}

	private var stageWindow: some View {
		WorkspaceCard(accent: WorkspaceTheme.accent, padding: 32, cornerRadius: 32, shadowY: 18) {
			VStack(alignment: .leading, spacing: 28) {
				stageHeader

				switch step {
				case .welcome:
					welcomeStage
				case .localMode:
					localModeStage
				case .createNickname:
					profileStage
				case .aiSetup:
					aiSetupStage
				case .aiKeyEntry:
					aiKeyEntryStage
				case .done:
					EmptyView()
				}

				if !statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					statusBanner
				}
			}
		}
		.frame(width: 654, alignment: .topLeading)
	}

	private var languageToggle: some View {
		Menu {
			ForEach(AppLanguagePreference.allCases) { preference in
				Button {
					appState.selectedLanguagePreference = preference
				} label: {
					HStack {
						Text(languageLabel(for: preference))
						if appState.selectedLanguagePreference == preference {
							Image(systemName: "checkmark")
						}
					}
				}
			}
		} label: {
			HStack(spacing: 4) {
				Image(systemName: "globe")
					.font(.system(size: 11, weight: .semibold))
				Text(languageShortLabel)
					.font(.caption.weight(.semibold))
			}
			.padding(.horizontal, 9)
			.padding(.vertical, 5)
			.background(WorkspaceTheme.elevatedSurface)
			.clipShape(Capsule())
			.overlay(
				Capsule().stroke(WorkspaceTheme.border, lineWidth: 1)
			)
			.foregroundStyle(WorkspaceTheme.strongText)
		}
		.menuStyle(.borderlessButton)
		.menuIndicator(.hidden)
		.fixedSize()
		.help(AppBrand.localized("切换界面语言", "Switch interface language", locale: locale))
	}

	private var languageShortLabel: String {
		switch appState.selectedLanguagePreference {
		case .system:            return AppBrand.localized("自动", "Auto", locale: locale)
		case .simplifiedChinese: return "中"
		case .english:           return "EN"
		}
	}

	private func languageLabel(for preference: AppLanguagePreference) -> String {
		switch preference {
		case .system:
			return AppBrand.localized("跟随系统", "Follow System", locale: locale)
		case .simplifiedChinese:
			return AppBrand.localized("简体中文", "简体中文 (Simplified Chinese)", locale: locale)
		case .english:
			return AppBrand.localized("English (英文)", "English", locale: locale)
		}
	}

	private var stageHeader: some View {
		HStack(spacing: 10) {
			stageStepCapsule(
				index: 1,
				title: AppBrand.localized("选择模式", "Choose mode", locale: locale),
				isActive: step == .welcome || step == .localMode
			)
			stageStepCapsule(
				index: 2,
				title: AppBrand.localized("建立资料", "Create profile", locale: locale),
				isActive: step == .createNickname
			)
			stageStepCapsule(
				index: 3,
				title: AppBrand.localized("AI Mentor", "AI Mentor", locale: locale),
				isActive: step == .aiSetup || step == .aiKeyEntry
			)
			Spacer(minLength: 0)
		}
	}

	private var welcomeStage: some View {
		VStack(alignment: .center, spacing: 26) {
			Spacer(minLength: 6)

			WorkspaceSectionTitle(
				eyebrow: "Welcome",
				title: AppBrand.localized("选择你的起点", "Choose your starting point", locale: locale),
				subtitle: AppBrand.localized("先进入 Local Mode。Cloud Mode 保留入口，但当前版本仍处于开发中。", "Start with Local Mode. Cloud Mode stays visible here, but it is still in development in this build.", locale: locale),
				accent: WorkspaceTheme.accent
			)
			.frame(maxWidth: 440)

			VStack(spacing: 14) {
				stageActionCard(
					title: "Local Mode",
					subtitle: AppBrand.localized("在本机建立第一份 Profile，立刻开始使用。", "Create your first profile on this Mac and start right away.", locale: locale),
					icon: "internaldrive",
					accent: WorkspaceTheme.accent
				) {
					statusMessage = ""
					statusIsError = false
					step = .localMode
				}

				stageActionCard(
					title: "Cloud Mode",
					subtitle: AppBrand.localized("仍在开发中，后续版本再开放。", "Still in development for a later build.", locale: locale),
					icon: "cloud",
					accent: .orange
				) {
					statusMessage = AppBrand.localized("Cloud Mode 正在开发中，当前请先使用 Local Mode。", "Cloud Mode is still in development. Please use Local Mode for now.", locale: locale)
					statusIsError = false
				}
			}
			.frame(maxWidth: 420)

			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, alignment: .center)
	}

	private var localModeStage: some View {
		VStack(alignment: .leading, spacing: 22) {
			stageBackLink {
				statusMessage = ""
				statusIsError = false
				step = .welcome
			}

			WorkspaceSectionTitle(
				eyebrow: "Local Mode",
				title: AppBrand.localized("创建新的本机资料，或导入旧档案", "Create a new local profile, or import an existing archive", locale: locale),
				subtitle: AppBrand.localized("如果你是第一次使用，就创建一份新的 Profile；如果你已有 JSON 备份，就直接导回。", "Create a fresh profile if this is your first time, or restore directly from your JSON archive if you already have one.", locale: locale),
				accent: .green
			)

			VStack(spacing: 14) {
				stageActionCard(
					title: AppBrand.localized("创建本机 Profile", "Create local profile", locale: locale),
					subtitle: AppBrand.localized("创建本机档案，并在下一步确认昵称。", "Start a local profile and confirm your display name next.", locale: locale),
					icon: "person.crop.circle.badge.plus",
					accent: WorkspaceTheme.accent
				) {
					startLocalAccount()
				}

				stageActionCard(
					title: AppBrand.localized("导入 Profile", "Import profile", locale: locale),
					subtitle: AppBrand.localized("导入旧版本导出的 JSON 数据包。", "Restore an exported JSON archive from a previous build.", locale: locale),
					icon: "square.and.arrow.down",
					accent: .green
				) {
					importLocalArchive()
				}
			}

			Spacer(minLength: 0)
		}
	}

	private var profileStage: some View {
		VStack(alignment: .leading, spacing: 20) {
			stageBackLink {
				step = .localMode
			}

			WorkspaceSectionTitle(
				eyebrow: AppBrand.localized("Profile", "Profile", locale: locale),
				title: AppBrand.localized("确认你的显示名称", "Confirm your display name", locale: locale),
				subtitle: AppBrand.localized("昵称会出现在 Dashboard 问候语、侧边栏和后续引导层中，之后仍可修改。", "Your profile name appears in the dashboard greeting, sidebar, and guidance layer. You can still change it later.", locale: locale),
				accent: WorkspaceTheme.accent
			)

			WorkspaceCard(accent: .teal, padding: 20, cornerRadius: 24, shadowY: 6) {
				VStack(alignment: .leading, spacing: 14) {
					profileFactRow(
						title: AppBrand.localized("Profile 类型", "Profile type", locale: locale),
						value: draftAccount?.provider.label(for: locale) ?? AccountProviderOption.localOnly.label(for: locale)
					)
					profileFactRow(
						title: "Profile ID",
						value: draftAccount?.identifier ?? AppBrand.localized("未生成", "Not generated yet", locale: locale),
						monospaced: true
					)
					if let email = draftAccount?.email, !email.isEmpty {
						profileFactRow(
							title: AppBrand.localized("邮箱", "Email", locale: locale),
							value: email
						)
					}
				}
			}

			VStack(alignment: .leading, spacing: 10) {
				Text(AppBrand.localized("昵称", "Profile Name", locale: locale))
					.font(.headline)
					.foregroundStyle(WorkspaceTheme.strongText)

				TextField(AppBrand.localized("例如：Lihong", "For example: Lihong", locale: locale), text: $nickname)
					.textFieldStyle(.plain)
					.padding(.horizontal, 16)
					.padding(.vertical, 14)
					.background(
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.fill(WorkspaceTheme.elevatedSurface)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 18, style: .continuous)
							.stroke(WorkspaceTheme.border, lineWidth: 1)
					)
			}

			HStack(spacing: 12) {
				secondaryTextAction(AppBrand.localized("返回", "Back", locale: locale)) {
					step = .localMode
				}

				Spacer(minLength: 0)

				primaryTextAction(
					AppBrand.localized("开始使用 \(AppBrand.displayName(for: locale))", "Start Using \(AppBrand.displayName(for: locale))", locale: locale),
					isDisabled: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
				) {
					completeAccountSetup()
				}
			}

			Spacer(minLength: 0)
		}
	}

	private var statusBanner: some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "info.circle.fill")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(statusIsError ? .orange : WorkspaceTheme.accent)
				.padding(.top, 2)

			Text(statusMessage)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 16)
		.padding(.vertical, 14)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(statusIsError ? Color.orange.opacity(0.08) : WorkspaceTheme.accentTint)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(statusIsError ? Color.orange.opacity(0.18) : WorkspaceTheme.accent.opacity(0.12), lineWidth: 1)
		)
	}

	private func brandPoint(icon: String, title: String, subtitle: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			WorkspaceIconBadge(icon: icon, accent: WorkspaceTheme.accent, size: 38)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(WorkspaceTheme.strongText)
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private func stageStepCapsule(index: Int, title: String, isActive: Bool) -> some View {
		HStack(spacing: 8) {
			Text("\(index)")
				.font(.caption.weight(.bold))
				.frame(width: 22, height: 22)
				.background(isActive ? Color.white.opacity(0.22) : WorkspaceTheme.accentTint)
				.clipShape(Circle())
			Text(title)
				.font(.subheadline.weight(.semibold))
		}
		.foregroundStyle(isActive ? Color.white : Color.primary)
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(isActive ? WorkspaceTheme.accent : WorkspaceTheme.surface)
		.clipShape(Capsule())
	}

	private func stageActionCard(
		title: String,
		subtitle: String,
		icon: String,
		accent: Color,
		action: @escaping () -> Void
	) -> some View {
		HStack(spacing: 14) {
			WorkspaceIconBadge(icon: icon, accent: accent, size: 52)

			VStack(alignment: .leading, spacing: 5) {
				Text(title)
					.font(.system(size: 20, weight: .semibold))
					.foregroundStyle(WorkspaceTheme.strongText)
				Text(subtitle)
					.font(.subheadline)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.fixedSize(horizontal: false, vertical: true)
			}

			Spacer(minLength: 0)

			Image(systemName: "arrow.right")
				.font(.system(size: 14, weight: .bold))
				.foregroundStyle(accent)
		}
		.padding(18)
		.background(
			RoundedRectangle(cornerRadius: 22, style: .continuous)
				.fill(WorkspaceTheme.elevatedSurface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 22, style: .continuous)
				.stroke(accent.opacity(0.12), lineWidth: 1)
		)
		.contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
		.onTapGesture(perform: action)
	}

	private func stageBackLink(_ action: @escaping () -> Void) -> some View {
		HStack(spacing: 8) {
			Image(systemName: "arrow.left")
			Text(AppBrand.localized("返回", "Back", locale: locale))
		}
		.font(.subheadline.weight(.semibold))
		.foregroundStyle(WorkspaceTheme.mutedText)
		.contentShape(Rectangle())
		.onTapGesture(perform: action)
	}

	private func profileFactRow(title: String, value: String, monospaced: Bool = false) -> some View {
		HStack(alignment: .firstTextBaseline, spacing: 12) {
			Text(title)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Spacer(minLength: 0)
			Text(value)
				.font(monospaced ? .system(.body, design: .monospaced) : .body)
				.lineLimit(1)
				.truncationMode(.middle)
		}
	}

	private func primaryTextAction(_ title: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
		Text(title)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(isDisabled ? Color.secondary : Color.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 11)
			.background(
				Capsule()
					.fill(isDisabled ? Color.secondary.opacity(0.14) : WorkspaceTheme.accent)
			)
			.contentShape(Capsule())
			.opacity(isDisabled ? 0.72 : 1)
			.onTapGesture {
				guard !isDisabled else { return }
				action()
			}
	}

	private func secondaryTextAction(_ title: String, action: @escaping () -> Void) -> some View {
		Text(title)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(WorkspaceTheme.strongText)
			.padding(.horizontal, 16)
			.padding(.vertical, 11)
			.background(WorkspaceTheme.elevatedSurface)
			.clipShape(Capsule())
			.contentShape(Capsule())
			.onTapGesture(perform: action)
	}

	private func startLocalAccount() {
		let displayName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		draftAccount = AuthenticatedAccount(
			provider: .localOnly,
			identifier: UUID().uuidString,
			email: "",
			displayName: displayName
		)
		statusMessage = ""
		statusIsError = false
		step = .createNickname
	}

	private func completeAccountSetup() {
		let finalName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		let account = draftAccount ?? AuthenticatedAccount(
			provider: .localOnly,
			identifier: UUID().uuidString,
			email: "",
			displayName: finalName
		)
		let finalizedAccount = AuthenticatedAccount(
			provider: account.provider,
			identifier: account.identifier,
			email: account.email,
			displayName: finalName
		)

		appState.applyAccount(
			provider: finalizedAccount.provider,
			email: finalizedAccount.email,
			identifier: finalizedAccount.identifier
		)
		oauthService.updateStoredProfile(finalizedAccount)
		appState.userName = finalName
		step = .aiSetup
	}

	private func finishOnboarding() {
		let finalName = nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			? appState.userName
			: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		appState.completeOnboarding(name: finalName)
		step = .done
	}

	private var aiSetupStage: some View {
		VStack(alignment: .leading, spacing: 24) {
			WorkspaceSectionTitle(
				eyebrow: "AI Mentor",
				title: AppBrand.localized("是否启用 AI 助手？", "Enable the AI assistant?", locale: locale),
				subtitle: AppBrand.localized(
					"配置 AI API Key 后即可在仪表盘和侧边栏与 AI Mentor 对话。可以在之后的设置中单独配置。",
					"With an AI API key configured you can chat with the mentor from the dashboard and sidebar. You can configure this later in Settings.",
					locale: locale
				),
				accent: WorkspaceTheme.accent
			)

			VStack(spacing: 14) {
				stageActionCard(
					title: AppBrand.localized("现在配置 AI", "Configure AI now", locale: locale),
					subtitle: AppBrand.localized(
						"在下一步填入 API Key 与模型，立刻可用。",
						"Enter your API key and model in the next step — ready to use immediately.",
						locale: locale
					),
					icon: "sparkles",
					accent: WorkspaceTheme.accent
				) {
					statusMessage = ""
					statusIsError = false
					aiDraftKey = AICredentialStore.readAPIKey()
					aiDraftProvider = appState.selectedAIProvider
					step = .aiKeyEntry
				}

				stageActionCard(
					title: AppBrand.localized("跳过 Skip", "Skip for now", locale: locale),
					subtitle: AppBrand.localized(
						"先不启用，可以在设置中随时开启。",
						"Skip for now — you can turn it on anytime in Settings.",
						locale: locale
					),
					icon: "arrow.right.circle",
					accent: WorkspaceTheme.mutedText
				) {
					finishOnboarding()
				}
			}

			Text(AppBrand.localized(
				"提示：AI Mentor 的所有功能都可以在主界面中关闭。这一选择不会影响其他模块的使用。",
				"Note: every AI Mentor capability can be turned off later. This choice doesn't affect other modules.",
				locale: locale
			))
			.font(.caption)
			.foregroundStyle(WorkspaceTheme.mutedText)
			.fixedSize(horizontal: false, vertical: true)
		}
	}

	private var aiKeyEntryStage: some View {
		VStack(alignment: .leading, spacing: 22) {
			WorkspaceSectionTitle(
				eyebrow: "AI Mentor",
				title: AppBrand.localized("填入 AI API Key", "Add your AI API key", locale: locale),
				subtitle: AppBrand.localized(
					"Key 会保存在系统钥匙串中，可随时在设置中修改或清除。",
					"Your key is stored in the system Keychain — you can edit or clear it anytime in Settings.",
					locale: locale
				),
				accent: WorkspaceTheme.accent
			)

			VStack(alignment: .leading, spacing: 8) {
				Text(AppBrand.localized("AI 提供方", "AI provider", locale: locale))
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(WorkspaceTheme.mutedText)
				Picker("", selection: $aiDraftProvider) {
					ForEach(AIProviderOption.allCases) { option in
						Text(providerLabel(option)).tag(option)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}

			VStack(alignment: .leading, spacing: 8) {
				Text(AppBrand.localized("API Key", "API Key", locale: locale))
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(WorkspaceTheme.mutedText)
				SecureField("sk-...", text: $aiDraftKey)
					.textFieldStyle(.roundedBorder)
			}

			HStack(spacing: 10) {
				Button {
					step = .aiSetup
					statusMessage = ""
					statusIsError = false
				} label: {
					Label(
						AppBrand.localized("返回", "Back", locale: locale),
						systemImage: "chevron.left"
					)
					.padding(.horizontal, 6)
				}
				.buttonStyle(.bordered)

				Spacer()

				Button {
					finishOnboarding()
				} label: {
					Text(AppBrand.localized("先跳过", "Skip", locale: locale))
						.padding(.horizontal, 6)
				}
				.buttonStyle(.bordered)

				Button {
					saveAIKeyAndFinish()
				} label: {
					Label(
						AppBrand.localized("保存并进入", "Save & continue", locale: locale),
						systemImage: "checkmark"
					)
					.padding(.horizontal, 6)
				}
				.buttonStyle(.borderedProminent)
				.disabled(aiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}
		}
	}

	private func saveAIKeyAndFinish() {
		let trimmed = aiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			statusMessage = AppBrand.localized("请填入有效的 API Key。", "Please enter a valid API key.", locale: locale)
			statusIsError = true
			return
		}
		AICredentialStore.saveAPIKey(trimmed)
		appState.selectedAIProvider = aiDraftProvider
		statusMessage = ""
		statusIsError = false
		finishOnboarding()
	}

	private func providerLabel(_ option: AIProviderOption) -> String {
		switch option {
		case .deepseek: return "DeepSeek"
		case .qwen:     return AppBrand.localized("通义千问 Qwen", "Qwen", locale: locale)
		}
	}

	private func importLocalArchive() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.message = AppBrand.localized(
			"选择导出的 \(AppBrand.displayName(for: locale)) JSON 数据包或包含它的文件夹",
			"Choose an exported \(AppBrand.displayName(for: locale)) JSON archive or a folder that contains one",
			locale: locale
		)
		guard panel.runModal() == .OK, let source = panel.url else { return }

		do {
			let archive = try AppDataArchiveService.loadSnapshot(from: source)
			try AppDataArchiveService.replaceLocalData(
				with: archive,
				modelContext: modelContext,
				appState: appState
			)
			draftAccount = AuthenticatedAccount(
				provider: appState.selectedAccountProvider,
				identifier: appState.accountIdentifier,
				email: appState.accountEmail,
				displayName: appState.userName
			)
			nickname = appState.userName
			statusMessage = AppBrand.localized("已导入本地数据。", "Local data imported.", locale: locale)
			statusIsError = false
			if appState.hasCompletedOnboarding {
				step = .done
			} else {
				step = .createNickname
			}
		} catch {
			statusMessage = error.localizedDescription
			statusIsError = true
		}
	}
}

//
//  PreferencesView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
	@EnvironmentObject private var appState: AppState
	@EnvironmentObject private var oauthService: OAuthService
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale

	@State private var apiKeyInput: String = ""
	@State private var savedApiKey: String = ""
	@State private var draftProfileName: String = ""
	@State private var showTokenValue = false
	@State private var copiedToken = false
	@State private var savedProfile = false
	@State private var savedToken = false
	@State private var aiTestInProgress = false
	@State private var aiTestMessage: String = ""
	@State private var aiTestSucceeded = false
	@State private var dataStatusMessage: String = ""
	@State private var dataStatusSuccess = true
	@State private var rebirthStatusMessage: String = ""
	@State private var rebirthStatusSuccess = true
	@State private var showClearContentConfirmation = false
	@State private var showDeleteAccountConfirmation = false
	@State private var privacyStatusMessage: String = ""
	@State private var privacyStatusSuccess = true
	@State private var syncStatusMessage: String = ""
	@State private var syncStatusSuccess = true
	@State private var showRestartPrompt = false
	@State private var showModelPicker = false

	private let deepSeekModels = ["deepseek-chat", "deepseek-reasoner"]
	private let qwenModels = ["qwen-turbo", "qwen-plus", "qwen-max"]

	private var tokenDisplayText: String {
		guard !savedApiKey.isEmpty else { return String(localized: "preferences.token.not_saved") }
		if showTokenValue { return savedApiKey }
		return String(repeating: "*", count: max(8, min(savedApiKey.count, 24)))
	}

	var body: some View {
		TabView {
			profileTab
				.tabItem { Label(profileTabTitle, systemImage: "person.crop.circle") }

			generalTab
				.tabItem { Label("preferences.tab.general", systemImage: "gearshape") }

			aiTab
				.tabItem { Label("preferences.tab.ai", systemImage: "sparkles") }

			dataTab
				.tabItem { Label("preferences.tab.data", systemImage: "externaldrive") }

			shortcutsTab
				.tabItem { Label("preferences.tab.shortcuts", systemImage: "keyboard") }

			privacyTab
				.tabItem { Label("preferences.tab.privacy", systemImage: "lock.shield") }
		}
		.frame(width: 860, height: 620)
		.onAppear {
			appState.apiTokenStorageMode = AICredentialStore.mode.rawValue
			let key = AICredentialStore.readAPIKey()
			savedApiKey = key
			apiKeyInput = key
			draftProfileName = appState.userName
		}
		.sheet(isPresented: $showModelPicker) {
			AIModelPickerSheet(
				isPresented: $showModelPicker,
				initialSelection: .builtIn(appState.selectedAIProvider, model: aiModelBinding.wrappedValue)
			) { selection in
				if let option = selection.builtInOption {
					appState.selectedAIProvider = option
					if option == .qwen {
						appState.aiModelQwen = selection.model
					} else {
						appState.aiModelDeepSeek = selection.model
					}
				}
				// Custom providers persist on the picker side; selection stored in
				// future work when AIService learns to dispatch arbitrary endpoints.
			}
			.environment(\.locale, locale)
		}
		.alert(
			AppBrand.localized("AI Key 已保存", "AI key saved", locale: locale),
			isPresented: $showRestartPrompt
		) {
			Button(AppBrand.localized("退出并重启", "Quit & Reopen", locale: locale), role: .destructive) {
				Self.relaunchApp()
			}
			Button(AppBrand.localized("稍后再说", "Later", locale: locale), role: .cancel) {}
		} message: {
			Text(AppBrand.localized(
				"建议立即退出并重启 NexaLife，让 AI Mentor 立刻使用新的 API Key。",
				"It is recommended to quit and reopen NexaLife so the AI Mentor picks up the new API key right away.",
				locale: locale
			))
		}
		.onChange(of: appState.userName) { _, newValue in
			draftProfileName = newValue
		}
	}

	private var profileTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text(verbatim: profileSectionTitle)) {
				PreferenceRow(title: Text(verbatim: profileNameTitle)) {
					HStack(spacing: 10) {
						TextField(profileNamePlaceholder, text: $draftProfileName)
							.textFieldStyle(.roundedBorder)
							.frame(width: 280)
						Button(saveProfileButtonTitle) {
							saveProfileName()
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.small)
						if savedProfile {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(.green)
						}
					}
				}

				PreferenceRow(title: Text(verbatim: profileTypeTitle)) {
					Text(appState.selectedAccountProvider.label(for: locale))
						.foregroundStyle(.secondary)
						.frame(width: 360, alignment: .leading)
				}

				PreferenceRow(title: Text(verbatim: profileIdentifierTitle)) {
					ProfileIdentifierView(
						identifier: appState.accountIdentifier,
						emptyLabel: missingProfileIdentifierText,
						hoverLabel: revealIdentifierHint,
						copyLabel: copyIdentifierHint,
						copiedLabel: copiedHint,
						onCopy: copyProfileIdentifier
					)
					.frame(width: 360, alignment: .leading)
				}

				if let profileContactDescription {
					PreferenceRow(title: Text(verbatim: profileContactTitle)) {
						Text(profileContactDescription)
							.foregroundStyle(.secondary)
							.textSelection(.enabled)
							.frame(width: 360, alignment: .leading)
					}
				}

				PreferenceActionRow {
					Text(profileFootnote)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				PreferenceActionRow {
					HStack(spacing: 10) {
						if appState.accountIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
							Button(createLocalProfileButtonTitle) {
								createLocalProfile()
							}
							.buttonStyle(.borderedProminent)
						}

						Button(deleteProfileButtonTitle, role: .destructive) {
							showDeleteAccountConfirmation = true
						}
						.buttonStyle(.bordered)
					}
				}
			}
		}
		.confirmationDialog(
			deleteProfileConfirmationTitle,
			isPresented: $showDeleteAccountConfirmation,
			titleVisibility: .visible
		) {
			Button(deleteProfileButtonTitle, role: .destructive) {
				deleteAccountForFreshStart()
			}
			Button(role: .cancel) {}
		} message: {
			Text(deleteProfileConfirmationMessage)
		}
	}

	private var generalTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text("preferences.section.localization")) {
				PreferenceRow(title: Text("preferences.localization.language")) {
					Picker("", selection: $appState.appLanguagePreference) {
						ForEach(AppLanguagePreference.allCases) { item in
							Text(item.preferenceLabel(for: locale)).tag(item.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}

				PreferenceRow(title: Text("preferences.localization.appearance")) {
					Picker("", selection: $appState.appAppearanceMode) {
						ForEach(AppAppearanceMode.allCases) { item in
							Text(item.preferenceLabel(for: locale)).tag(item.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}
			}

			PreferenceSectionCard(title: Text("preferences.section.startup")) {
				PreferenceRow(title: Text("preferences.startup.module")) {
					Picker("", selection: $appState.startupModule) {
						ForEach(AppModule.allCases) { module in
							Text(module.preferenceLabel(for: locale)).tag(module.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}
			}
		}
	}

	private var aiTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text("preferences.ai.section.provider")) {
				PreferenceRow(title: Text("preferences.ai.model")) {
					HStack(spacing: 10) {
						VStack(alignment: .trailing, spacing: 2) {
							Text(appState.selectedAIProvider.preferenceLabel(for: locale))
								.font(.subheadline.weight(.semibold))
								.foregroundStyle(WorkspaceTheme.strongText)
							Text(aiModelBinding.wrappedValue)
								.font(.caption)
								.foregroundStyle(WorkspaceTheme.mutedText)
								.monospaced()
						}
						Button {
							showModelPicker = true
						} label: {
							Label(
								AppBrand.localized("更换", "Change", locale: locale),
								systemImage: "arrow.triangle.2.circlepath"
							)
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
					}
				}

				PreferenceRow(title: Text("preferences.ai.timeout")) {
					HStack(spacing: 10) {
						Slider(value: $appState.aiTimeoutSeconds, in: 5...120, step: 1)
							.frame(width: 220)
						Text("\(Int(appState.aiTimeoutSeconds))s")
							.monospacedDigit()
							.frame(width: 44, alignment: .trailing)
					}
				}

				PreferenceActionRow {
					HStack(spacing: 10) {
						Button("preferences.ai.test") {
							Task {
								await runAITest()
							}
						}
						.buttonStyle(.bordered)
						.disabled(aiTestInProgress)

						if aiTestInProgress {
							ProgressView()
								.controlSize(.small)
						}

						if !aiTestMessage.isEmpty {
							Text(aiTestMessage)
								.font(.subheadline)
								.foregroundStyle(aiTestSucceeded ? .green : .secondary)
						}
					}
				}
			}

			PreferenceSectionCard(title: Text("preferences.token.section")) {
				PreferenceRow(title: Text("preferences.token.saved")) {
					HStack(spacing: 8) {
						if showTokenValue && !savedApiKey.isEmpty {
							Button(savedApiKey) {
								copyTokenToPasteboard()
							}
							.buttonStyle(.plain)
							.help(String(localized: "preferences.token.copy_hint"))
							.textSelection(.enabled)
							.lineLimit(1)
							.truncationMode(.middle)
						} else {
							Text(tokenDisplayText)
								.foregroundStyle(savedApiKey.isEmpty ? .secondary : .primary)
						}
						Button {
							showTokenValue.toggle()
						} label: {
							Image(systemName: showTokenValue ? "eye.slash" : "eye")
						}
						.buttonStyle(.plain)
						if copiedToken {
							Text("preferences.token.copied")
								.font(.caption)
								.foregroundStyle(.green)
						}
					}
				}

				PreferenceRow(title: Text("preferences.token.update")) {
					SecureField("sk-...", text: $apiKeyInput)
						.textFieldStyle(.roundedBorder)
						.frame(width: 280)
				}

				PreferenceRow(title: Text("preferences.token.storage_location")) {
					Text(tokenStorageLocationDescription)
						.foregroundStyle(.secondary)
						.truncationMode(.middle)
						.frame(width: 360, alignment: .leading)
				}

				PreferenceActionRow {
					HStack(spacing: 10) {
						Button("preferences.token.save") {
							saveAPIKey()
						}
						.buttonStyle(.borderedProminent)
						.disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

						if savedToken {
							Label("preferences.common.saved", systemImage: "checkmark.circle.fill")
								.font(.subheadline)
								.foregroundStyle(.green)
						}
					}
				}
			}
		}
	}

	private var dataTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text(verbatim: syncSectionTitle)) {
				PreferenceRow(title: Text(verbatim: profileTabTitle)) {
					Text(profileSummaryLabel)
						.foregroundStyle(.secondary)
						.frame(width: 360, alignment: .leading)
				}

				PreferenceRow(title: Text(verbatim: syncModeTitle)) {
					Picker("", selection: $appState.syncMode) {
						ForEach(DataSyncMode.allCases) { mode in
							Text(mode.label(for: locale)).tag(mode.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
					.onChange(of: appState.syncMode) { _, _ in
						syncStatusMessage = ""
						syncStatusSuccess = true
					}
				}

				PreferenceRow(title: Text(verbatim: lastSyncTitle)) {
					Text(lastSyncDescription)
						.foregroundStyle(.secondary)
						.frame(width: 360, alignment: .leading)
				}

				if appState.selectedSyncMode == .folder {
					PreferenceRow(title: Text(verbatim: externalFolderTitle)) {
						Text(appState.syncDirectory?.path ?? missingSyncFolderText)
							.foregroundStyle(.secondary)
							.truncationMode(.middle)
							.frame(width: 360, alignment: .leading)
					}

					PreferenceActionRow {
						HStack(spacing: 10) {
							Button(selectExternalFolderButtonTitle) {
								selectSyncFolder()
							}
							.buttonStyle(.bordered)

							Button(syncToFolderButtonTitle) {
								performSelectedSync()
							}
							.buttonStyle(.borderedProminent)
							.disabled(appState.syncDirectory == nil)
						}
					}
				}

				if appState.selectedSyncMode == .iCloud {
					PreferenceRow(title: Text(verbatim: iCloudStatusTitle)) {
						Text(iCloudStatusDescription)
							.foregroundStyle(iCloudSyncAvailable ? Color.secondary : Color.orange)
							.fixedSize(horizontal: false, vertical: true)
							.frame(width: 360, alignment: .leading)
					}
				}

				PreferenceActionRow {
					Text(syncModeFootnote)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				if !syncStatusMessage.isEmpty {
					PreferenceActionRow {
						Text(syncStatusMessage)
							.font(.subheadline)
							.foregroundStyle(syncStatusSuccess ? .green : .orange)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}

			PreferenceSectionCard(title: Text(verbatim: localDataSectionTitle)) {
				PreferenceRow(title: Text(verbatim: storageModeTitle)) {
					Text(appManagedStorageTitle)
						.foregroundStyle(.secondary)
						.frame(width: 360, alignment: .leading)
				}

				PreferenceRow(title: Text(verbatim: localPathTitle)) {
					Text(appManagedDataDirectory().path)
						.foregroundStyle(.secondary)
						.truncationMode(.middle)
						.frame(width: 360, alignment: .leading)
				}

				PreferenceActionRow {
					Text(appManagedStorageFootnote)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}

			PreferenceSectionCard(title: Text("preferences.data.section.backup")) {
				PreferenceRow(title: Text("preferences.data.backup_frequency")) {
					Picker("", selection: $appState.backupFrequency) {
						ForEach(BackupFrequency.allCases) { item in
							Text(item.preferenceLabel(for: locale)).tag(item.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}

				PreferenceActionRow {
					HStack(spacing: 10) {
						Button("preferences.data.export") {
							exportDataFolder()
						}
						.buttonStyle(.bordered)

						Button("preferences.data.import") {
							importDataFolder()
						}
						.buttonStyle(.bordered)
					}
				}
			}

			PreferenceSectionCard(title: Text("preferences.data.section.integrity")) {
				PreferenceActionRow {
					HStack(spacing: 10) {
						Button("preferences.data.validate") {
							validateDataDirectory()
						}
						.buttonStyle(.bordered)

						Button("preferences.data.repair") {
							repairDataDirectory()
						}
						.buttonStyle(.bordered)
					}
				}

				if !dataStatusMessage.isEmpty {
					PreferenceActionRow {
						Text(dataStatusMessage)
							.font(.subheadline)
							.foregroundStyle(dataStatusSuccess ? .green : .orange)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}

			PreferenceSectionCard(title: Text("preferences.data.section.fresh_start")) {
				PreferenceActionRow {
					Text("preferences.data.fresh_start.tagline")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				PreferenceActionRow {
					HStack(spacing: 10) {
						Button("preferences.data.fresh_start.clear_content", role: .destructive) {
							showClearContentConfirmation = true
						}
						.buttonStyle(.bordered)
					}
				}

				if !rebirthStatusMessage.isEmpty {
					PreferenceActionRow {
						Text(rebirthStatusMessage)
							.font(.subheadline)
							.foregroundStyle(rebirthStatusSuccess ? .green : .orange)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
		.confirmationDialog(
			String(localized: "preferences.data.fresh_start.clear_content.confirm.title"),
			isPresented: $showClearContentConfirmation,
			titleVisibility: .visible
		) {
			Button("preferences.data.fresh_start.clear_content", role: .destructive) {
				clearContentForFreshStart()
			}
			Button(role: .cancel) {}
		} message: {
			Text("preferences.data.fresh_start.clear_content.confirm.message")
		}
	}

	private var shortcutsTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text("preferences.shortcuts.section")) {
				PreferenceRow(title: Text("preferences.shortcuts.quick_capture")) {
					Picker("", selection: $appState.quickCaptureShortcut) {
						ForEach(ShortcutPreset.allCases) { preset in
							Text(preset.preferenceLabel(for: locale)).tag(preset.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}

				PreferenceRow(title: Text("preferences.shortcuts.global_search")) {
					Picker("", selection: $appState.globalSearchShortcut) {
						ForEach(ShortcutPreset.allCases) { preset in
							Text(preset.preferenceLabel(for: locale)).tag(preset.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}

				PreferenceActionRow {
					Text("preferences.shortcuts.hint")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var privacyTab: some View {
		preferencePane {
			PreferenceSectionCard(title: Text("preferences.privacy.section")) {
				PreferenceRow(title: Text("preferences.privacy.log_level")) {
					Picker("", selection: $appState.logLevel) {
						ForEach(LogLevel.allCases) { item in
							Text(item.preferenceLabel(for: locale)).tag(item.rawValue)
						}
					}
					.labelsHidden()
					.frame(width: 280)
				}

				PreferenceActionRow {
					Toggle("preferences.privacy.crash_reports", isOn: $appState.crashReportEnabled)
				}

				PreferenceActionRow {
					Button("preferences.privacy.clear_cache") {
						clearCaches()
					}
					.buttonStyle(.bordered)
				}

				if !privacyStatusMessage.isEmpty {
					PreferenceActionRow {
						Text(privacyStatusMessage)
							.font(.subheadline)
							.foregroundStyle(privacyStatusSuccess ? .green : .orange)
					}
				}
			}
		}
	}

	private func preferencePane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				content()
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 20)
			.frame(maxWidth: 760, alignment: .leading)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.background(Color(nsColor: .windowBackgroundColor))
	}

	private var aiModelBinding: Binding<String> {
		Binding(
			get: {
				appState.selectedAIProvider == .qwen ? appState.aiModelQwen : appState.aiModelDeepSeek
			},
			set: { newValue in
				if appState.selectedAIProvider == .qwen {
					appState.aiModelQwen = newValue
				} else {
					appState.aiModelDeepSeek = newValue
				}
			}
		)
	}

	private var activeModelOptions: [String] {
		appState.selectedAIProvider == .qwen ? qwenModels : deepSeekModels
	}

	private var tokenStorageLocationDescription: String {
		AICredentialStore.localFileURL().path
	}

	private var profileTabTitle: String {
		AppBrand.localized("Profile", "Profile", locale: locale)
	}

	private var profileSectionTitle: String {
		AppBrand.localized("当前 Profile", "Current Profile", locale: locale)
	}

	private var profileNameTitle: String {
		AppBrand.localized("Profile 名称", "Profile Name", locale: locale)
	}

	private var profileNamePlaceholder: String {
		AppBrand.localized("输入 Profile 名称", "Enter a profile name", locale: locale)
	}

	private var saveProfileButtonTitle: String {
		AppBrand.localized("保存", "Save", locale: locale)
	}

	private var profileTypeTitle: String {
		AppBrand.localized("Profile 类型", "Profile Type", locale: locale)
	}

	private var profileIdentifierTitle: String {
		"Profile ID"
	}

	private var missingProfileIdentifierText: String {
		AppBrand.localized("将在首次创建 Profile 后生成", "Generated after you create a profile", locale: locale)
	}

	private var revealIdentifierHint: String {
		AppBrand.localized("悬停查看完整 ID", "Hover to reveal the full ID", locale: locale)
	}

	private var copyIdentifierHint: String {
		AppBrand.localized("单击复制 Profile ID", "Click to copy the Profile ID", locale: locale)
	}

	private var copiedHint: String {
		AppBrand.localized("已复制", "Copied", locale: locale)
	}

	private var profileContactTitle: String {
		AppBrand.localized("联系邮箱", "Contact Email", locale: locale)
	}

	private var profileFootnote: String {
		AppBrand.localized(
			"Profile 记录当前设备身份、导出归属与同步偏好，不代表开发者托管的云端身份。",
			"The profile defines this device identity, archive ownership, and sync preference. It does not represent a developer-hosted cloud account.",
			locale: locale
		)
	}

	private var createLocalProfileButtonTitle: String {
		AppBrand.localized("创建本机 Profile", "Create Local Profile", locale: locale)
	}

	private var deleteProfileButtonTitle: String {
		AppBrand.localized("删除 Profile", "Delete Profile", locale: locale)
	}

	private var deleteProfileConfirmationTitle: String {
		AppBrand.localized("确认删除当前 Profile？", "Delete this profile?", locale: locale)
	}

	private var deleteProfileConfirmationMessage: String {
		AppBrand.localized(
			"这会移除当前 Profile 标识、本地内容与偏好设置，并回到首次启动流程。",
			"This removes the current profile identity, local content, and preferences, then returns the app to onboarding.",
			locale: locale
		)
	}

	private var syncSectionTitle: String {
		AppBrand.localized("同步", "Sync", locale: locale)
	}

	private var syncModeTitle: String {
		AppBrand.localized("同步模式", "Sync Mode", locale: locale)
	}

	private var lastSyncTitle: String {
		AppBrand.localized("最近同步", "Last Sync", locale: locale)
	}

	private var externalFolderTitle: String {
		AppBrand.localized("外部目录", "External Folder", locale: locale)
	}

	private var missingSyncFolderText: String {
		AppBrand.localized("尚未选择外部同步目录", "No external sync folder selected yet", locale: locale)
	}

	private var selectExternalFolderButtonTitle: String {
		AppBrand.localized("选择外部目录", "Choose External Folder", locale: locale)
	}

	private var syncToFolderButtonTitle: String {
		AppBrand.localized("同步到外部目录", "Sync to External Folder", locale: locale)
	}

	private var iCloudStatusTitle: String {
		AppBrand.localized("iCloud 状态", "iCloud Status", locale: locale)
	}

	private var localDataSectionTitle: String {
		AppBrand.localized("本地数据", "Local Data", locale: locale)
	}

	private var storageModeTitle: String {
		AppBrand.localized("主存储", "Primary Storage", locale: locale)
	}

	private var appManagedStorageTitle: String {
		AppBrand.localized("App 内部存储", "App Internal Storage", locale: locale)
	}

	private var localPathTitle: String {
		AppBrand.localized("本地路径", "Local Path", locale: locale)
	}

	private var appManagedStorageFootnote: String {
		AppBrand.localized(
			"\(AppBrand.displayName(for: locale)) 默认把活动数据保存在 App 内部容器中；外部目录只用于同步或导出，不再作为主数据库。",
			"\(AppBrand.displayName(for: locale)) keeps active data inside the app container by default. External folders are only used for sync targets and exports, not as the live database.",
			locale: locale
		)
	}

	private var profileSummaryLabel: String {
		let provider = appState.selectedAccountProvider.label(for: locale)
		let email = appState.accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
		return email.isEmpty ? provider : "\(provider) · \(email)"
	}

	private var profileContactDescription: String? {
		let email = appState.accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
		return email.isEmpty ? nil : email
	}

	private var iCloudSyncAvailable: Bool {
		appState.selectedAccountProvider == .appleID
	}

	private var iCloudStatusDescription: String {
		if iCloudSyncAvailable {
			return AppBrand.localized(
				"当前 Profile 可作为 Apple 私有云同步入口；接入 CloudKit 后，数据将直接进入用户自己的 iCloud 私有容器，不经过开发者数据库。",
				"This profile can serve as your Apple private-cloud sync identity. Once CloudKit is connected, data will go straight into the user's private iCloud container instead of a developer database.",
				locale: locale
			)
		}
		return AppBrand.localized(
			"iCloud 同步仅适用于 Apple Profile。若要使用该模式，请先创建或切换到 Apple Profile。",
			"iCloud sync is only available for Apple profiles. Create or switch to an Apple profile before using this mode.",
			locale: locale
		)
	}

	private var syncModeFootnote: String {
		switch appState.selectedSyncMode {
		case .off:
			return AppBrand.localized(
				"当前仅保留 App 内部本地存储。你仍可随时导出或导入便携快照。",
				"Data stays in local app storage for now. You can still export or import portable snapshots at any time.",
				locale: locale
			)
		case .iCloud:
			return AppBrand.localized(
				"iCloud 模式面向 Apple Profile，不会把数据默认托管到开发者数据库。",
				"iCloud mode is designed for Apple profiles and does not send data into a developer-hosted database by default.",
				locale: locale
			)
		case .folder:
			return AppBrand.localized(
				"外部目录模式适合坚果云、NAS、iCloud Drive 或其他用户自管目录；同步策略仍采用最新快照覆盖旧快照。",
				"External-folder mode fits Nutstore, NAS, iCloud Drive, or other user-managed storage. Sync still works by replacing the older snapshot with the newest one.",
				locale: locale
			)
		}
	}

	private var lastSyncDescription: String {
		guard let lastSyncAt = appState.lastSyncAt else {
			return AppBrand.localized("尚未同步", "Not synced yet", locale: locale)
		}
		return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
	}

	private func saveProfileName() {
		let trimmed = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		appState.userName = trimmed
		withAnimation { savedProfile = true }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
			withAnimation { savedProfile = false }
		}
	}

	private func createLocalProfile() {
		let name = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
		let finalName = name.isEmpty
			? AppBrand.localized("本机 Profile", "Local Profile", locale: locale)
			: name
		appState.applyAccount(
			provider: .localOnly,
			email: "",
			identifier: UUID().uuidString
		)
		appState.userName = finalName
	}

	private func copyProfileIdentifier() {
		let identifier = appState.accountIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !identifier.isEmpty else { return }
		let board = NSPasteboard.general
		board.clearContents()
		board.setString(identifier, forType: .string)
	}

	private func saveAPIKey() {
		let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		let previousKey = savedApiKey
		AICredentialStore.saveAPIKey(trimmed)
		savedApiKey = AICredentialStore.readAPIKey()
		withAnimation { savedToken = true }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
			withAnimation { savedToken = false }
		}
		if savedApiKey != previousKey {
			showRestartPrompt = true
		}
	}

	private static func relaunchApp() {
		let bundleURL = Bundle.main.bundleURL
		let task = Process()
		task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
		task.arguments = ["-n", bundleURL.path]
		do {
			try task.run()
		} catch {
			AppLogger.warning("Relaunch failed: \(error.localizedDescription)", category: "app")
		}
		NSApp.terminate(nil)
	}

	@MainActor
	private func runAITest() async {
		aiTestInProgress = true
		aiTestMessage = ""
		let service = AIService()
		// Reasoning models (e.g. deepseek-v4-pro in thinking mode) burn tokens
		// on internal reasoning before emitting any visible content. Give the
		// test plenty of headroom so a thinking model can still produce output.
		let result = await service.callAPIDetailed(
			prompt: "请用一句话回复：连接成功",
			maxTokens: 512
		)
		aiTestInProgress = false
		switch result {
		case .success(let text):
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if trimmed.isEmpty {
				// HTTP 200 with empty content still means the network/key/model
				// path is healthy — flag success but warn the user.
				aiTestMessage = AppBrand.localized(
					"连接成功，但模型返回空内容（可能正在思考耗光 max_tokens）。",
					"Connected, but the model returned empty content (likely a thinking model exhausting max_tokens).",
					locale: locale
				)
			} else {
				aiTestMessage = AppBrand.localized(
					"连接成功：\(String(trimmed.prefix(40)))",
					"Connected: \(String(trimmed.prefix(40)))",
					locale: locale
				)
			}
			aiTestSucceeded = true
		case .failure(let error):
			aiTestMessage = error.errorDescription ?? String(localized: "preferences.ai.test.failure")
			aiTestSucceeded = false
		}
	}

	private func copyTokenToPasteboard() {
		guard !savedApiKey.isEmpty else { return }
		let board = NSPasteboard.general
		board.clearContents()
		board.setString(savedApiKey, forType: .string)
		withAnimation { copiedToken = true }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
			withAnimation { copiedToken = false }
		}
	}

	private func appManagedDataDirectory() -> URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		return AppBrand.migratedDirectory(
			in: appSupport,
			preferredPath: Bundle.main.bundleIdentifier ?? AppBrand.bundleIdentifier,
			legacyPath: AppBrand.legacyBundleIdentifier
		)
	}

	private func exportDataFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let destinationRoot = panel.url else { return }

		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd-HHmmss"
		let fileName = "NexaLife-backup-\(formatter.string(from: .now)).json"

		do {
			let archive = try AppDataArchiveService.captureSnapshot(
				modelContext: modelContext,
				appState: appState
			)
			let destination = try AppDataArchiveService.writeSnapshot(
				archive,
				toDirectory: destinationRoot,
				fileName: fileName
			)
			dataStatusMessage = String(localized: "preferences.data.export.success") + destination.path
			dataStatusSuccess = true
		} catch {
			dataStatusMessage = String(localized: "preferences.data.export.failure") + error.localizedDescription
			dataStatusSuccess = false
		}
	}

	private func importDataFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let source = panel.url else { return }

		do {
			let incoming = try AppDataArchiveService.loadSnapshot(from: source)
			let rollback = try AppDataArchiveService.captureSnapshot(
				modelContext: modelContext,
				appState: appState
			)
			do {
				try AppDataArchiveService.replaceLocalData(
					with: incoming,
					modelContext: modelContext,
					appState: appState
				)
			} catch {
				try? AppDataArchiveService.replaceLocalData(
					with: rollback,
					modelContext: modelContext,
					appState: appState
				)
				dataStatusMessage = String(localized: "preferences.data.import.failure.rolled_back") + error.localizedDescription
				dataStatusSuccess = false
				return
			}

			dataStatusMessage = String(localized: "preferences.data.import.success")
			dataStatusSuccess = true
		} catch {
			dataStatusMessage = String(localized: "preferences.data.import.failure") + error.localizedDescription
			dataStatusSuccess = false
		}
	}

	private func selectSyncFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.message = AppBrand.localized(
			"选择一个可被多端访问的同步目录",
			"Choose a sync folder that can be accessed from multiple devices",
			locale: locale
		)
		guard panel.runModal() == .OK, let url = panel.url else { return }
		appState.syncDirectory = url
		appState.selectedSyncMode = .folder
	}

	private func performSelectedSync() {
		switch appState.selectedSyncMode {
		case .off:
			syncStatusMessage = AppBrand.localized(
				"当前模式为本机存储，无需执行外部同步。",
				"Sync is disabled in local-only mode.",
				locale: locale
			)
			syncStatusSuccess = true
		case .iCloud:
			syncStatusMessage = iCloudStatusDescription
			syncStatusSuccess = iCloudSyncAvailable
		case .folder:
			performFolderSync()
		}
	}

	private func performFolderSync() {
		guard let directory = appState.syncDirectory else {
			syncStatusMessage = AppBrand.localized(
				"请先选择外部同步目录。",
				"Choose an external sync folder first.",
				locale: locale
			)
			syncStatusSuccess = false
			return
		}

		do {
			let result = try AppDataArchiveService.performFolderSync(
				at: directory,
				modelContext: modelContext,
				appState: appState
			)
			appState.lastSyncAt = .now
			switch result {
			case .pushed(let url):
				syncStatusMessage = AppBrand.localized(
					"已将当前快照推送到 \(url.path)",
					"Current snapshot pushed to \(url.path)",
					locale: locale
				)
			case .pulled(let url):
				syncStatusMessage = AppBrand.localized(
					"已从 \(url.path) 拉取较新的快照",
					"Pulled a newer snapshot from \(url.path)",
					locale: locale
				)
			case .noChanges:
				syncStatusMessage = AppBrand.localized(
					"当前 Profile 与外部目录之间没有新的差异",
					"No new differences were found between the current profile and the external folder.",
					locale: locale
				)
			}
			syncStatusSuccess = true
		} catch {
			syncStatusMessage = AppBrand.localized(
				"同步失败：\(error.localizedDescription)",
				"Sync failed: \(error.localizedDescription)",
				locale: locale
			)
			syncStatusSuccess = false
		}
	}

	private func validateDataDirectory() {
		let directory = appManagedDataDirectory()
		let fm = FileManager.default
		var warnings: [String] = []

		var isDirectory: ObjCBool = false
		if !fm.fileExists(atPath: directory.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
			warnings.append(String(localized: "preferences.data.validation.missing_directory"))
		}
		if !fm.isReadableFile(atPath: directory.path) {
			warnings.append(String(localized: "preferences.data.validation.not_readable"))
		}
		if !fm.isWritableFile(atPath: directory.path) {
			warnings.append(String(localized: "preferences.data.validation.not_writable"))
		}
		if !appState.avatarImagePath.isEmpty && !fm.fileExists(atPath: appState.avatarImagePath) {
			warnings.append(String(localized: "preferences.data.validation.avatar_missing"))
		}

		if warnings.isEmpty {
			dataStatusMessage = String(localized: "preferences.data.validation.ok")
			dataStatusSuccess = true
		} else {
			dataStatusMessage = warnings.joined(separator: "\n")
			dataStatusSuccess = false
		}
	}

	private func repairDataDirectory() {
		let directory = appManagedDataDirectory()
		let fm = FileManager.default
		var actions: [String] = []

		do {
			try fm.createDirectory(at: directory, withIntermediateDirectories: true)
			actions.append(String(localized: "preferences.data.repair.directory_created"))
		} catch {
			dataStatusMessage = String(localized: "preferences.data.repair.failure") + error.localizedDescription
			dataStatusSuccess = false
			return
		}

		if !appState.avatarImagePath.isEmpty && !fm.fileExists(atPath: appState.avatarImagePath) {
			appState.avatarImagePath = ""
			actions.append(String(localized: "preferences.data.repair.avatar_reset"))
		}

		if appState.aiTimeoutSeconds < 5 || appState.aiTimeoutSeconds > 120 {
			appState.aiTimeoutSeconds = 30
			actions.append(String(localized: "preferences.data.repair.timeout_reset"))
		}

		if actions.isEmpty {
			dataStatusMessage = String(localized: "preferences.data.repair.noop")
		} else {
			dataStatusMessage = actions.joined(separator: "\n")
		}
		dataStatusSuccess = true
	}

	private func clearCaches() {
		URLCache.shared.removeAllCachedResponses()
		let fm = FileManager.default
		let temp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
		do {
			let tempItems = try fm.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)
			for item in tempItems where
				item.lastPathComponent.hasPrefix(AppBrand.englishName) ||
				item.lastPathComponent.hasPrefix(AppBrand.legacyEnglishName) {
				try? fm.removeItem(at: item)
			}
			privacyStatusMessage = String(localized: "preferences.privacy.clear_cache.success")
			privacyStatusSuccess = true
		} catch {
			privacyStatusMessage = String(localized: "preferences.privacy.clear_cache.failure") + error.localizedDescription
			privacyStatusSuccess = false
		}
	}

	private func clearContentForFreshStart() {
		rebirthStatusMessage = ""
		do {
			try AppDataArchiveService.clearAllModelData(modelContext: modelContext)
			rebirthStatusMessage = String(localized: "preferences.data.fresh_start.clear_success")
				+ "\n"
				+ AppBrand.localized("已保留你的 Profile 与偏好设置。", "Your profile and preferences were kept.", locale: locale)
			rebirthStatusSuccess = true
		} catch {
			rebirthStatusMessage = String(localized: "preferences.data.fresh_start.partial_failure")
				+ error.localizedDescription
			rebirthStatusSuccess = false
		}
	}

	private func deleteAccountForFreshStart() {
		rebirthStatusMessage = ""
		do {
			NotificationCenter.default.post(name: .nexaLifeResetSelections, object: nil)
			try AppDataArchiveService.clearAllModelData(modelContext: modelContext)
			if !appState.avatarImagePath.isEmpty {
				try? FileManager.default.removeItem(at: URL(fileURLWithPath: appState.avatarImagePath))
			}
			AICredentialStore.clearAPIKey()
			oauthService.resetSession()
			savedApiKey = ""
			apiKeyInput = ""
			showTokenValue = false
			copiedToken = false

			rebirthStatusMessage = AppBrand.localized(
				"Profile 已删除，本地内容已清理。",
				"Profile deleted and local content cleared.",
				locale: locale
			)
				+ "\n"
				+ AppBrand.localized(
					"本地 Profile 信息和内容都已清理。",
					"Local profile information and content have both been removed.",
					locale: locale
				)
			rebirthStatusSuccess = true
			DispatchQueue.main.async {
				appState.resetAccountForFreshStart()
			}
		} catch {
			rebirthStatusMessage = String(localized: "preferences.data.fresh_start.partial_failure")
				+ error.localizedDescription
			rebirthStatusSuccess = false
		}
	}
}

private struct PreferenceSectionCard<Content: View>: View {
	private let title: Text
	@ViewBuilder var content: () -> Content

	init(title: Text, @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.content = content
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			title
				.font(.headline)

			VStack(alignment: .leading, spacing: 10) {
				content()
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}

private struct PreferenceRow<Control: View>: View {
	private let title: Text
	@ViewBuilder var control: () -> Control

	init(title: Text, @ViewBuilder control: @escaping () -> Control) {
		self.title = title
		self.control = control
	}

	var body: some View {
		HStack(alignment: .center, spacing: 16) {
			title
				.foregroundStyle(.secondary)
				.frame(width: 200, alignment: .trailing)
			control()
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct PreferenceActionRow<Content: View>: View {
	@ViewBuilder var content: () -> Content

	var body: some View {
		HStack(alignment: .center, spacing: 16) {
			Color.clear
				.frame(width: 200, height: 1)
			content()
				.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct ProfileIdentifierView: View {
	let identifier: String
	let emptyLabel: String
	let hoverLabel: String
	let copyLabel: String
	let copiedLabel: String
	let onCopy: () -> Void

	@State private var isHovering = false
	@State private var isCopied = false

	private var trimmedIdentifier: String {
		identifier.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private var maskedIdentifier: String {
		guard !trimmedIdentifier.isEmpty else { return emptyLabel }
		let segments = trimmedIdentifier.split(separator: "-")
		guard let suffix = segments.last else { return "••••••••" }
		return "••••••••-••••-••••-••••-\(suffix)"
	}

	var body: some View {
		if trimmedIdentifier.isEmpty {
			Text(emptyLabel)
				.foregroundStyle(.secondary)
		} else {
			VStack(alignment: .leading, spacing: 4) {
				Button {
					onCopy()
					withAnimation { isCopied = true }
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
						withAnimation { isCopied = false }
					}
				} label: {
					Text(isHovering ? trimmedIdentifier : maskedIdentifier)
						.font(.system(.body, design: .monospaced))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.buttonStyle(.plain)
				.help(copyLabel)
				.onHover { hovering in
					isHovering = hovering
				}

				Text(isCopied ? copiedLabel : hoverLabel)
					.font(.caption)
					.foregroundStyle(isCopied ? .green : .secondary)
			}
		}
	}
}

private extension AppLanguagePreference {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .system:
			return AppBrand.localized("跟随系统", "Follow System", locale: locale)
		case .simplifiedChinese:
			return AppBrand.localized("简体中文", "Simplified Chinese", locale: locale)
		case .english:
			return AppBrand.localized("英文", "English", locale: locale)
		}
	}
}

private extension AppAppearanceMode {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .system:
			return AppBrand.localized("跟随系统", "Follow System", locale: locale)
		case .light:
			return AppBrand.localized("浅色", "Light", locale: locale)
		case .dark:
			return AppBrand.localized("深色", "Dark", locale: locale)
		}
	}
}

private extension AIProviderOption {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .deepseek:
			return "DeepSeek"
		case .qwen:
			return AppBrand.localized("通义千问 Qwen", "Qwen", locale: locale)
		}
	}
}

private extension APITokenStorageMode {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .keychain:
			return AppBrand.localized("系统钥匙串", "Keychain", locale: locale)
		case .localFile:
			return AppBrand.localized("本地文件", "Local File", locale: locale)
		}
	}
}

private extension BackupFrequency {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .off:
			return AppBrand.localized("关闭", "Off", locale: locale)
		case .daily:
			return AppBrand.localized("每天", "Daily", locale: locale)
		case .weekly:
			return AppBrand.localized("每周", "Weekly", locale: locale)
		}
	}
}

private extension LogLevel {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .error:
			return AppBrand.localized("错误", "Error", locale: locale)
		case .warning:
			return AppBrand.localized("警告", "Warning", locale: locale)
		case .info:
			return AppBrand.localized("信息", "Info", locale: locale)
		case .debug:
			return "Debug"
		}
	}
}

private extension ShortcutPreset {
	func preferenceLabel(for locale: Locale) -> String {
		switch self {
		case .commandShiftN:
			return "Command + Shift + N"
		case .commandN:
			return "Command + N"
		case .commandK:
			return "Command + K"
		case .commandShiftSpace:
			return "Command + Shift + Space"
		case .commandF:
			return "Command + F"
		}
	}
}

//
//  AppState.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//
//  AppState.swift — NexaLife 全局状态中枢

import SwiftUI
import Combine

enum AppModule: String, CaseIterable, Identifiable {
	case dashboard  = "Dashboard"
	case inbox      = "Inbox"
	case execution  = "Execution"
	case lifestyle  = "Lifestyle"
	case knowledge  = "Knowledge"
	case vitals     = "Vitals"
	case trash      = "Trash"

	var id: String { rawValue }

	var icon: String {
		switch self {
		case .dashboard:  return "rectangle.grid.2x2.fill"
		case .inbox:      return "tray.and.arrow.down"
		case .execution:  return "target"
		case .lifestyle:  return "cup.and.saucer"
		case .knowledge:  return "book"
		case .vitals:     return "sparkles"
		case .trash:      return "trash"
		}
	}

	func label(for locale: Locale) -> String {
		switch self {
		case .dashboard:
			return AppBrand.localized("仪表盘", "Dashboard", locale: locale)
		case .inbox:
			return AppBrand.localized("收件箱", "Inbox", locale: locale)
		case .execution:
			return AppBrand.localized("执行", "Execution", locale: locale)
		case .lifestyle:
			return AppBrand.localized("生活", "Lifestyle", locale: locale)
		case .knowledge:
			return AppBrand.localized("知识", "Knowledge", locale: locale)
		case .vitals:
			return AppBrand.localized("觉知", "Vitals", locale: locale)
		case .trash:
			return AppBrand.localized("回收站", "Trash", locale: locale)
		}
	}

	var label: String {
		label(for: .autoupdatingCurrent)
	}

	func preferenceLabel(for locale: Locale) -> String {
		label(for: locale)
	}

	var preferenceLabel: String {
		preferenceLabel(for: .autoupdatingCurrent)
	}
}

enum OnboardingStep {
	case welcome
	case localMode
	case createNickname
	case aiSetup
	case aiKeyEntry
	case done
}

enum AppLanguagePreference: String, CaseIterable, Identifiable {
	case system
	case simplifiedChinese = "zh-Hans"
	case english = "en"

	var id: String { rawValue }

	var locale: Locale {
		switch self {
		case .system:
			return .autoupdatingCurrent
		case .simplifiedChinese:
			return Locale(identifier: "zh-Hans")
		case .english:
			return Locale(identifier: "en")
		}
	}
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
	case system
	case light
	case dark

	var id: String { rawValue }

	var colorScheme: ColorScheme? {
		switch self {
		case .system:
			return nil
		case .light:
			return .light
		case .dark:
			return .dark
		}
	}
}

enum AIProviderOption: String, CaseIterable, Identifiable {
	case deepseek
	case qwen

	var id: String { rawValue }
}

enum BackupFrequency: String, CaseIterable, Identifiable {
	case off
	case daily
	case weekly

	var id: String { rawValue }
}

enum AccountProviderOption: String, CaseIterable, Identifiable, Codable {
	case appleID
	case email
	case localOnly

	var id: String { rawValue }

	var label: String {
		label(for: .autoupdatingCurrent)
	}

	func label(for locale: Locale) -> String {
		switch self {
		case .appleID:
			return "Apple Profile"
		case .email:
			return AppBrand.localized("邮箱 Profile", "Email Profile", locale: locale)
		case .localOnly:
			return AppBrand.localized("本机 Profile", "Local Profile", locale: locale)
		}
	}
}

enum DataSyncMode: String, CaseIterable, Identifiable, Codable {
	case off
	case iCloud
	case folder

	var id: String { rawValue }

	var label: String {
		label(for: .autoupdatingCurrent)
	}

	func label(for locale: Locale) -> String {
		switch self {
		case .off:
			return AppBrand.localized("本机", "Local", locale: locale)
		case .iCloud:
			return "iCloud"
		case .folder:
			return AppBrand.localized("外部目录", "External Folder", locale: locale)
		}
	}
}

enum ProfileGuidanceMode: String, CaseIterable, Identifiable, Codable {
	case selfDirected
	case exploratory

	var id: String { rawValue }

	func title(for locale: Locale) -> String {
		switch self {
		case .selfDirected:
			return AppBrand.localized("我有清晰规划", "I already know my direction", locale: locale)
		case .exploratory:
			return AppBrand.localized("我还在探索方向", "I am still exploring", locale: locale)
		}
	}

	func subtitle(for locale: Locale) -> String {
		switch self {
		case .selfDirected:
			return AppBrand.localized("系统以执行追踪、进度拆解和复盘为主。", "The system will focus on execution tracking, goal breakdowns, and reviews.", locale: locale)
		case .exploratory:
			return AppBrand.localized("系统会更主动识别模式，并给出阶段性引导。", "The system will more actively identify patterns and guide your next stage.", locale: locale)
		}
	}
}

enum LogLevel: String, CaseIterable, Identifiable {
	case error
	case warning
	case info
	case debug

	var id: String { rawValue }
}

enum ShortcutPreset: String, CaseIterable, Identifiable {
	case commandShiftN
	case commandN
	case commandK
	case commandShiftSpace
	case commandF

	var id: String { rawValue }

	var keyEquivalent: KeyEquivalent {
		switch self {
		case .commandShiftN:
			return "n"
		case .commandN:
			return "n"
		case .commandK:
			return "k"
		case .commandShiftSpace:
			return " "
		case .commandF:
			return "f"
		}
	}

	var modifiers: EventModifiers {
		switch self {
		case .commandShiftN:
			return [.command, .shift]
		case .commandN, .commandK, .commandF:
			return .command
		case .commandShiftSpace:
			return [.command, .shift]
		}
	}
}

@MainActor
class AppState: ObservableObject {
	private enum Keys {
		static let hasCompletedOnboarding = "hasCompletedOnboarding"
		static let userName = "userName"
		static let avatarImagePath = "avatarImagePath"
		static let accountProvider = "accountProvider"
		static let accountEmail = "accountEmail"
		static let accountIdentifier = "accountIdentifier"
		static let apiTokenStorageMode = "apiTokenStorageMode"
		static let globalCurrency = "globalCurrency"
		static let monthlyBudget = "monthlyBudget"
		static let profileGuidanceMode = "profileGuidanceMode"
		static let storageDirectory = "storageDirectory"
		static let syncMode = "syncMode"
		static let syncDirectory = "syncDirectory"
		static let lastSyncAt = "lastSyncAt"
		static let appLanguage = "appLanguagePreference"
		static let appearanceMode = "appAppearanceMode"
		static let startupModule = "startupModule"
		static let aiProvider = "aiProvider"
		static let aiModelDeepSeek = "aiModelDeepSeek"
		static let aiModelQwen = "aiModelQwen"
		static let aiTimeoutSeconds = "aiTimeoutSeconds"
		static let backupFrequency = "backupFrequency"
		static let lastAutoBackupAt = "lastAutoBackupAt"
		static let quickCaptureShortcut = "quickCaptureShortcut"
		static let globalSearchShortcut = "globalSearchShortcut"
		static let logLevel = "logLevel"
		static let crashReportEnabled = "crashReportEnabled"
	}

	// MARK: - Onboarding
	@Published var hasCompletedOnboarding: Bool {
		didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
	}

	// MARK: - User
	@Published var userName: String {
		didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
	}
	@Published var avatarImagePath: String {
		didSet { UserDefaults.standard.set(avatarImagePath, forKey: Keys.avatarImagePath) }
	}
	@Published var accountProvider: String {
		didSet { UserDefaults.standard.set(accountProvider, forKey: Keys.accountProvider) }
	}
	@Published var accountEmail: String {
		didSet { UserDefaults.standard.set(accountEmail, forKey: Keys.accountEmail) }
	}
	@Published var accountIdentifier: String {
		didSet { UserDefaults.standard.set(accountIdentifier, forKey: Keys.accountIdentifier) }
	}
	@Published var apiTokenStorageMode: String {
		didSet { UserDefaults.standard.set(apiTokenStorageMode, forKey: Keys.apiTokenStorageMode) }
	}
	@Published var globalCurrency: String {
		didSet { UserDefaults.standard.set(globalCurrency, forKey: Keys.globalCurrency) }
	}
	@Published var monthlyBudget: Double {
		didSet { UserDefaults.standard.set(monthlyBudget, forKey: Keys.monthlyBudget) }
	}
	@Published var profileGuidanceMode: String {
		didSet { UserDefaults.standard.set(profileGuidanceMode, forKey: Keys.profileGuidanceMode) }
	}

	// MARK: - Preferences
	@Published var appLanguagePreference: String {
		didSet { UserDefaults.standard.set(appLanguagePreference, forKey: Keys.appLanguage) }
	}
	@Published var appAppearanceMode: String {
		didSet { UserDefaults.standard.set(appAppearanceMode, forKey: Keys.appearanceMode) }
	}
	@Published var startupModule: String {
		didSet { UserDefaults.standard.set(startupModule, forKey: Keys.startupModule) }
	}
	@Published var aiProvider: String {
		didSet { UserDefaults.standard.set(aiProvider, forKey: Keys.aiProvider) }
	}
	@Published var aiModelDeepSeek: String {
		didSet { UserDefaults.standard.set(aiModelDeepSeek, forKey: Keys.aiModelDeepSeek) }
	}
	@Published var aiModelQwen: String {
		didSet { UserDefaults.standard.set(aiModelQwen, forKey: Keys.aiModelQwen) }
	}
	@Published var aiTimeoutSeconds: Double {
		didSet { UserDefaults.standard.set(aiTimeoutSeconds, forKey: Keys.aiTimeoutSeconds) }
	}
	@Published var backupFrequency: String {
		didSet { UserDefaults.standard.set(backupFrequency, forKey: Keys.backupFrequency) }
	}
	@Published var quickCaptureShortcut: String {
		didSet { UserDefaults.standard.set(quickCaptureShortcut, forKey: Keys.quickCaptureShortcut) }
	}
	@Published var globalSearchShortcut: String {
		didSet { UserDefaults.standard.set(globalSearchShortcut, forKey: Keys.globalSearchShortcut) }
	}
	@Published var logLevel: String {
		didSet { UserDefaults.standard.set(logLevel, forKey: Keys.logLevel) }
	}
	@Published var crashReportEnabled: Bool {
		didSet { UserDefaults.standard.set(crashReportEnabled, forKey: Keys.crashReportEnabled) }
	}

	// MARK: - Auth
	@Published var authToken: String?

	// MARK: - Navigation
	@Published var selectedModule: AppModule

	// MARK: - Storage
	@Published var storageDirectory: URL? {
		didSet {
			if let url = storageDirectory {
				UserDefaults.standard.set(url.path, forKey: Keys.storageDirectory)
			} else {
				UserDefaults.standard.removeObject(forKey: Keys.storageDirectory)
			}
		}
	}
	@Published var syncMode: String {
		didSet { UserDefaults.standard.set(syncMode, forKey: Keys.syncMode) }
	}
	@Published var syncDirectory: URL? {
		didSet {
			if let url = syncDirectory {
				UserDefaults.standard.set(url.path, forKey: Keys.syncDirectory)
			} else {
				UserDefaults.standard.removeObject(forKey: Keys.syncDirectory)
			}
		}
	}
	@Published var lastSyncAt: Date? {
		didSet {
			if let lastSyncAt {
				UserDefaults.standard.set(lastSyncAt, forKey: Keys.lastSyncAt)
			} else {
				UserDefaults.standard.removeObject(forKey: Keys.lastSyncAt)
			}
		}
	}

	init() {
		Self.clearLegacyWindowStateIfNeeded()
		AICredentialStore.bootstrapSecurityDefaults()

		self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
		self.userName = UserDefaults.standard.string(forKey: Keys.userName) ?? ""
		self.avatarImagePath = UserDefaults.standard.string(forKey: Keys.avatarImagePath) ?? ""
		self.accountProvider = UserDefaults.standard.string(forKey: Keys.accountProvider)
			?? AccountProviderOption.localOnly.rawValue
		self.accountEmail = UserDefaults.standard.string(forKey: Keys.accountEmail) ?? ""
		self.accountIdentifier = UserDefaults.standard.string(forKey: Keys.accountIdentifier) ?? ""
		self.apiTokenStorageMode = APITokenStorageMode.localFile.rawValue
		self.globalCurrency = UserDefaults.standard.string(forKey: Keys.globalCurrency)
			?? CurrencyCode.CNY.rawValue
		let defaultBudget = UserDefaults.standard.double(forKey: Keys.monthlyBudget)
		self.monthlyBudget = defaultBudget > 0 ? defaultBudget : 0
		self.profileGuidanceMode = UserDefaults.standard.string(forKey: Keys.profileGuidanceMode)
			?? ProfileGuidanceMode.exploratory.rawValue
		self.appLanguagePreference = UserDefaults.standard.string(forKey: Keys.appLanguage)
			?? AppLanguagePreference.system.rawValue
		self.appAppearanceMode = UserDefaults.standard.string(forKey: Keys.appearanceMode)
			?? AppAppearanceMode.system.rawValue
			let startupModuleRaw = UserDefaults.standard.string(forKey: Keys.startupModule)
				?? AppModule.dashboard.rawValue
			self.startupModule = startupModuleRaw
		self.aiProvider = UserDefaults.standard.string(forKey: Keys.aiProvider)
			?? AIProviderOption.deepseek.rawValue
		self.aiModelDeepSeek = UserDefaults.standard.string(forKey: Keys.aiModelDeepSeek)
			?? "deepseek-chat"
		self.aiModelQwen = UserDefaults.standard.string(forKey: Keys.aiModelQwen)
			?? "qwen-turbo"
		let timeout = UserDefaults.standard.double(forKey: Keys.aiTimeoutSeconds)
		self.aiTimeoutSeconds = timeout > 0 ? timeout : 30
		self.backupFrequency = UserDefaults.standard.string(forKey: Keys.backupFrequency)
			?? BackupFrequency.off.rawValue
		self.quickCaptureShortcut = UserDefaults.standard.string(forKey: Keys.quickCaptureShortcut)
			?? ShortcutPreset.commandShiftN.rawValue
		self.globalSearchShortcut = UserDefaults.standard.string(forKey: Keys.globalSearchShortcut)
			?? ShortcutPreset.commandK.rawValue
		self.logLevel = UserDefaults.standard.string(forKey: Keys.logLevel)
			?? LogLevel.info.rawValue
		if UserDefaults.standard.object(forKey: Keys.crashReportEnabled) == nil {
			self.crashReportEnabled = true
		} else {
			self.crashReportEnabled = UserDefaults.standard.bool(forKey: Keys.crashReportEnabled)
		}
		self.syncMode = UserDefaults.standard.string(forKey: Keys.syncMode)
			?? DataSyncMode.off.rawValue
		self.lastSyncAt = UserDefaults.standard.object(forKey: Keys.lastSyncAt) as? Date

		let bootModule = AppModule(rawValue: startupModuleRaw) ?? .dashboard
		self.selectedModule = bootModule
		self.storageDirectory = nil
		self.syncDirectory = nil

		if let path = UserDefaults.standard.string(forKey: Keys.storageDirectory) {
			self.storageDirectory = URL(fileURLWithPath: path)
		}
		if let path = UserDefaults.standard.string(forKey: Keys.syncDirectory) {
			self.syncDirectory = URL(fileURLWithPath: path)
		}
	}

	private static func clearLegacyWindowStateIfNeeded() {
		let defaults = UserDefaults.standard
		for key in defaults.dictionaryRepresentation().keys
		where key.hasPrefix("NSWindow Frame SwiftUI.") ||
			key.hasPrefix("NSSplitView Subview Frames SwiftUI.") {
			defaults.removeObject(forKey: key)
		}
	}

	func completeOnboarding(name: String) {
		self.userName = name
		self.hasCompletedOnboarding = true
	}

	func applyAccount(
		provider: AccountProviderOption,
		email: String,
		identifier: String
	) {
		accountProvider = provider.rawValue
		accountEmail = email
		accountIdentifier = identifier
		authToken = identifier.isEmpty ? nil : identifier
	}

	func resetAccountForFreshStart() {
		hasCompletedOnboarding = false
		userName = ""
		avatarImagePath = ""
		accountProvider = AccountProviderOption.localOnly.rawValue
		accountEmail = ""
		accountIdentifier = ""
		authToken = nil

		apiTokenStorageMode = APITokenStorageMode.localFile.rawValue
		globalCurrency = CurrencyCode.CNY.rawValue
		monthlyBudget = 0
		profileGuidanceMode = ProfileGuidanceMode.exploratory.rawValue

		appLanguagePreference = AppLanguagePreference.system.rawValue
		appAppearanceMode = AppAppearanceMode.system.rawValue
		startupModule = AppModule.dashboard.rawValue
		aiProvider = AIProviderOption.deepseek.rawValue
		aiModelDeepSeek = "deepseek-chat"
		aiModelQwen = "qwen-turbo"
		aiTimeoutSeconds = 30
		backupFrequency = BackupFrequency.off.rawValue
		quickCaptureShortcut = ShortcutPreset.commandShiftN.rawValue
		globalSearchShortcut = ShortcutPreset.commandK.rawValue
		logLevel = LogLevel.info.rawValue
		crashReportEnabled = true

		selectedModule = .dashboard

		storageDirectory = nil
		syncMode = DataSyncMode.off.rawValue
		syncDirectory = nil
		lastSyncAt = nil
		UserDefaults.standard.removeObject(forKey: Keys.lastAutoBackupAt)
	}

	var selectedCurrencyCode: CurrencyCode {
		get { CurrencyCode(rawValue: globalCurrency) ?? .CNY }
		set { globalCurrency = newValue.rawValue }
	}

	var selectedLanguagePreference: AppLanguagePreference {
		get { AppLanguagePreference(rawValue: appLanguagePreference) ?? .system }
		set { appLanguagePreference = newValue.rawValue }
	}

	var currentLocale: Locale {
		selectedLanguagePreference.locale
	}

	var selectedAppearanceMode: AppAppearanceMode {
		get { AppAppearanceMode(rawValue: appAppearanceMode) ?? .system }
		set { appAppearanceMode = newValue.rawValue }
	}

	var selectedStartupModule: AppModule {
		get { AppModule(rawValue: startupModule) ?? .dashboard }
		set { startupModule = newValue.rawValue }
	}

	var selectedAIProvider: AIProviderOption {
		get { AIProviderOption(rawValue: aiProvider) ?? .deepseek }
		set { aiProvider = newValue.rawValue }
	}

	var selectedBackupFrequency: BackupFrequency {
		get { BackupFrequency(rawValue: backupFrequency) ?? .off }
		set { backupFrequency = newValue.rawValue }
	}

	var selectedQuickCaptureShortcut: ShortcutPreset {
		get { ShortcutPreset(rawValue: quickCaptureShortcut) ?? .commandShiftN }
		set { quickCaptureShortcut = newValue.rawValue }
	}

	var selectedGlobalSearchShortcut: ShortcutPreset {
		get { ShortcutPreset(rawValue: globalSearchShortcut) ?? .commandK }
		set { globalSearchShortcut = newValue.rawValue }
	}

	var selectedLogLevel: LogLevel {
		get { LogLevel(rawValue: logLevel) ?? .info }
		set { logLevel = newValue.rawValue }
	}

	var selectedAPITokenStorageMode: APITokenStorageMode {
		get { .localFile }
		set { apiTokenStorageMode = newValue.rawValue }
	}

	var selectedAccountProvider: AccountProviderOption {
		get { AccountProviderOption(rawValue: accountProvider) ?? .localOnly }
		set { accountProvider = newValue.rawValue }
	}

	var selectedProfileGuidanceMode: ProfileGuidanceMode {
		get { ProfileGuidanceMode(rawValue: profileGuidanceMode) ?? .exploratory }
		set { profileGuidanceMode = newValue.rawValue }
	}

	var selectedSyncMode: DataSyncMode {
		get { DataSyncMode(rawValue: syncMode) ?? .off }
		set { syncMode = newValue.rawValue }
	}

	func updateModule(_ module: AppModule) {
		guard selectedModule != module else { return }
		selectedModule = module
	}

	func runAutoBackupIfNeeded() {
		let frequency = selectedBackupFrequency
		guard frequency != .off else { return }

		let now = Date()
		let last = UserDefaults.standard.object(forKey: Keys.lastAutoBackupAt) as? Date
		guard shouldRunAutoBackup(last: last, now: now, frequency: frequency) else { return }
		NotificationCenter.default.post(name: .nexaLifePerformAutoBackup, object: now)
	}

	func markAutoBackupCompleted(at date: Date = .now) {
		UserDefaults.standard.set(date, forKey: Keys.lastAutoBackupAt)
	}

	private func shouldRunAutoBackup(last: Date?, now: Date, frequency: BackupFrequency) -> Bool {
		guard let last else { return true }
		switch frequency {
		case .off:
			return false
		case .daily:
			return !Calendar.current.isDate(last, inSameDayAs: now)
		case .weekly:
			let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
			return days >= 7
		}
	}
}

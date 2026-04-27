//
//  NexaLifeApp.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-24.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct NexaLifeApp: App {
	@StateObject private var appState     = AppState()
	@StateObject private var oauthService = OAuthService()

	private static let appSchema = Schema([
		InboxItem.self,
		TaskItem.self,
		ExecutionProject.self,
		Note.self,
		Transaction.self,
		Goal.self,
		GoalMilestone.self,
		GoalProgressEntry.self,
		DailyReviewEntry.self,
		VitalsEntry.self,
		Connection.self,
		DashboardSnapshot.self
	])

	init() {
		Self.registerCompatibilityTransformers()
	}

	var sharedModelContainer: ModelContainer = Self.makeSharedModelContainer()

	private static func registerCompatibilityTransformers() {
		let name = RichTextCompatibilityTransformer.registrationName
		if ValueTransformer(forName: name) == nil {
			ValueTransformer.setValueTransformer(
				RichTextCompatibilityTransformer(),
				forName: name
			)
		}
	}

	private static func makeSharedModelContainer() -> ModelContainer {
		registerCompatibilityTransformers()

		if isRunningForPreview {
			return makeInMemoryModelContainer()
		}

		do {
			return try ModelContainer(
				for: appSchema,
				configurations: [ModelConfiguration(schema: appSchema, isStoredInMemoryOnly: false)]
			)
		} catch {
			AppLogger.error("Failed to open persistent SwiftData store: \(error.localizedDescription)", category: "swiftdata")
		}

		do {
			try quarantinePersistentStoreFiles()
			return try ModelContainer(
				for: appSchema,
				configurations: [ModelConfiguration(schema: appSchema, isStoredInMemoryOnly: false)]
			)
		} catch {
			AppLogger.error("Failed to rebuild persistent SwiftData store after quarantine: \(error.localizedDescription)", category: "swiftdata")
			return makeInMemoryModelContainer()
		}
	}

	private static var isRunningForPreview: Bool {
		ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}

	private static func makeInMemoryModelContainer() -> ModelContainer {
		do {
			return try ModelContainer(
				for: appSchema,
				configurations: [ModelConfiguration(schema: appSchema, isStoredInMemoryOnly: true)]
			)
		} catch {
			fatalError("Unable to create in-memory SwiftData container: \(error.localizedDescription)")
		}
	}

	private static func quarantinePersistentStoreFiles() throws {
		let fileManager = FileManager.default
		let storeDirectory = try defaultStoreDirectory(using: fileManager)
		let storeBaseName = "default.store"
		let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
		let quarantineDirectory = storeDirectory
			.appendingPathComponent("CorruptedStores", isDirectory: true)
			.appendingPathComponent(timestamp, isDirectory: true)

		try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)

		let storeNames = [
			storeBaseName,
			"\(storeBaseName)-shm",
			"\(storeBaseName)-wal"
		]

		for name in storeNames {
			let sourceURL = storeDirectory.appendingPathComponent(name)
			guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

			let destinationURL = quarantineDirectory.appendingPathComponent(name)
			try? fileManager.removeItem(at: destinationURL)
			try fileManager.moveItem(at: sourceURL, to: destinationURL)
			AppLogger.warning("Quarantined SwiftData store file: \(name)", category: "swiftdata")
		}
	}

	private static func defaultStoreDirectory(using fileManager: FileManager) throws -> URL {
		if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
			return appSupport
		}

		throw CocoaError(.fileNoSuchFile)
	}

	var body: some Scene {
		WindowGroup {
			Group {
				if !appState.hasCompletedOnboarding {
					OnboardingView()
				} else {
					ContentView()
				}
			}
			.environmentObject(appState)
			.environmentObject(oauthService)
			.environment(\.locale, appState.currentLocale)
			.preferredColorScheme(appState.selectedAppearanceMode.colorScheme)
			.task {
				DailyReviewReminderScheduler.configureIfNeeded()
			}
		}
		.defaultSize(width: 1280, height: 800)
		.modelContainer(sharedModelContainer)
		.commands {
			AboutCommands(locale: appState.currentLocale)

			CommandMenu("settings.commands.quick_actions") {
				Button("settings.commands.quick_capture") {
					NotificationCenter.default.post(name: .nexaLifeShowQuickInput, object: nil)
				}
				.keyboardShortcut(
					appState.selectedQuickCaptureShortcut.keyEquivalent,
					modifiers: appState.selectedQuickCaptureShortcut.modifiers
				)

				Button("settings.commands.global_search") {
					NotificationCenter.default.post(name: .nexaLifeShowGlobalSearch, object: nil)
				}
				.keyboardShortcut(
					appState.selectedGlobalSearchShortcut.keyEquivalent,
					modifiers: appState.selectedGlobalSearchShortcut.modifiers
				)
			}
		}

		Settings {
			PreferencesView()
				.environmentObject(appState)
				.environmentObject(oauthService)
				.environment(\.locale, appState.currentLocale)
				.preferredColorScheme(appState.selectedAppearanceMode.colorScheme)
				.modelContainer(sharedModelContainer)
		}

		Window(AppBrand.aboutTitle(for: appState.currentLocale), id: "about-nexalife") {
			AboutNexaLifeView()
				.padding(24)
				.frame(width: 520)
				.environment(\.locale, appState.currentLocale)
				.preferredColorScheme(appState.selectedAppearanceMode.colorScheme)
		}
		.windowResizability(.contentSize)
	}
}

private final class RichTextCompatibilityTransformer: NSSecureUnarchiveFromDataTransformer {
	static let registrationName = NSValueTransformerName("NSAttributedStringTransformer")

	override class var allowedTopLevelClasses: [AnyClass] {
		super.allowedTopLevelClasses + [
			NSAttributedString.self,
			NSMutableAttributedString.self,
			NSColor.self,
			NSFont.self,
			NSTextAttachment.self,
			NSURL.self,
			NSString.self,
			NSNumber.self,
			NSArray.self,
			NSDictionary.self,
			NSData.self
		]
	}
}

private struct AboutCommands: Commands {
	@Environment(\.openWindow) private var openWindow
	let locale: Locale

	var body: some Commands {
		CommandGroup(replacing: .appInfo) {
			Button(AppBrand.aboutTitle(for: locale)) {
				openWindow(id: "about-nexalife")
			}
		}
	}
}

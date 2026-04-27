//
//  ContentView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-24.
//
//  Top-level shell. The window frame, module router, navigation state,
//  and per-module hosts live in ModuleWorkspaceRouter.swift.
//

import SwiftUI
import SwiftData
import Combine
import AppKit

struct ContentView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.modelContext) private var modelContext
	@Environment(\.openSettings) private var openSettings

	@State private var isShowingQuickInput = false
	@State private var isShowingGlobalSearch = false
	@State private var isShowingAIChat = false

	@StateObject private var workspaceNavigation = WorkspaceNavigationState()

	var body: some View {
		rootLayout
			.sheet(isPresented: $isShowingQuickInput) {
				QuickInputSheet(isPresented: $isShowingQuickInput)
			}
			.sheet(isPresented: $isShowingGlobalSearch) {
				GlobalSearchSheet()
					.environmentObject(appState)
			}
			.sheet(isPresented: $isShowingAIChat) {
				AIChatSheet(isPresented: $isShowingAIChat)
					.environmentObject(appState)
					.environment(\.locale, appState.currentLocale)
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeShowQuickInput)) { _ in
				isShowingQuickInput = true
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeShowGlobalSearch)) { _ in
				isShowingGlobalSearch = true
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeShowAIChat)) { _ in
				isShowingAIChat = true
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeOpenAISettings)) { _ in
				openSettings()
				NSApp.activate(ignoringOtherApps: true)
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifePerformAutoBackup)) { note in
				performAutoBackup(at: note.object as? Date ?? .now)
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeResetSelections)) { _ in
				workspaceNavigation.resetAllSelections()
			}
			.task {
				appState.runAutoBackupIfNeeded()
			}
	}

	// MARK: - Layout

	private var rootLayout: some View {
		WorkspaceWindowFrame {
			sidebarSurface
		} workspace: {
			workspaceSurface
		}
		.background(Color.white)
		.transaction { transaction in
			transaction.animation = nil
		}
	}

	private var sidebarSurface: some View {
		SidebarView()
			.frame(width: 240)
			.padding(.vertical, 10)
			.background(Color.white)
	}

	private var workspaceSurface: some View {
		ModuleWorkspaceRouter(
			selectedModule: appState.selectedModule,
			navigation: workspaceNavigation
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(Color.white)
	}

	// MARK: - Auto backup

	private func performAutoBackup(at date: Date) {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd-HHmmss"
		let fileName = "\(AppBrand.autoBackupPrefix)\(formatter.string(from: date)).json"
		let backupRoot = resolvedWorkspaceDirectory().appendingPathComponent("Backups", isDirectory: true)
		do {
			let archive = try AppDataArchiveService.captureSnapshot(
				modelContext: modelContext,
				appState: appState
			)
			_ = try AppDataArchiveService.writeSnapshot(
				archive,
				toDirectory: backupRoot,
				fileName: fileName
			)
			appState.markAutoBackupCompleted(at: date)
		} catch {
			AppLogger.warning("Auto backup failed: \(error.localizedDescription)", category: "data")
		}
	}

	private func resolvedWorkspaceDirectory() -> URL {
		let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		return AppBrand.migratedDirectory(
			in: documents,
			preferredPath: AppBrand.workspaceFolderName,
			legacyPath: AppBrand.legacyWorkspaceFolderName
		)
	}
}

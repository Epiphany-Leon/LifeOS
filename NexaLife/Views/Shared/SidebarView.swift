//
//  SidebarView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import AppKit

struct SidebarView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.locale) private var locale
	@State private var isShowingAccountDetail = false

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			accountButton
			quickCaptureAction

			VStack(alignment: .leading, spacing: 8) {
				moduleButton(AppModule.dashboard)
			}

			sidebarSection(
				title: AppBrand.localized("主控室", "Core", locale: locale),
				modules: [AppModule.inbox]
			)

			sidebarSection(
				title: AppBrand.localized("四大象限", "Four Quadrants", locale: locale),
				modules: [AppModule.execution, AppModule.lifestyle, AppModule.knowledge, AppModule.vitals]
			)

			sidebarSection(
				title: AppBrand.localized("归档区", "Archive", locale: locale),
				modules: [AppModule.trash]
			)

			Spacer(minLength: 0)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.padding(.horizontal, 16)
		.padding(.vertical, 18)
		.background(WorkspaceTheme.surface)
		.overlay(alignment: .bottomLeading) {
			aiFloatingButton
				.padding(.leading, 16)
				.padding(.bottom, 16)
		}
		.sheet(isPresented: $isShowingAccountDetail) {
			AccountDetailView()
				.environmentObject(appState)
				.environment(\.locale, appState.currentLocale)
				.preferredColorScheme(appState.selectedAppearanceMode.colorScheme)
		}
	}

	private var aiFloatingButton: some View {
		Button {
			NotificationCenter.default.post(name: .nexaLifeShowAIChat, object: nil)
		} label: {
			ZStack {
				Circle()
					.fill(LinearGradient(
						colors: [WorkspaceTheme.accent, .pink.opacity(0.85)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					))
					.frame(width: 32, height: 32)
					.shadow(color: WorkspaceTheme.accent.opacity(0.3), radius: 5, x: 0, y: 3)
				Image(systemName: "sparkles")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(.white)
			}
		}
		.buttonStyle(.plain)
		.help(AppBrand.localized("呼出 AI Mentor", "Open AI Mentor", locale: locale))
	}


	private var accountButton: some View {
		WorkspaceCard(accent: WorkspaceTheme.accent, padding: 14, cornerRadius: 22, shadowY: 10) {
			HStack(spacing: 12) {
				AvatarThumbnail(path: appState.avatarImagePath, fallbackText: accountInitials)

				VStack(alignment: .leading, spacing: 3) {
					Text(appState.userName.isEmpty ? AppBrand.localized("未命名 Profile", "Unnamed Profile", locale: locale) : appState.userName)
						.font(.headline)
						.foregroundStyle(WorkspaceTheme.strongText)
					Text(AppBrand.localized("账号、偏好与资料", "Account, preferences, and profile", locale: locale))
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
				}

				Spacer()

				Image(systemName: "chevron.right")
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(WorkspaceTheme.mutedText)
			}
			.contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
			.onTapGesture {
				isShowingAccountDetail = true
			}
		}
	}

	private var quickCaptureAction: some View {
		WorkspaceCard(accent: .blue, padding: 12, cornerRadius: 20, shadowY: 8) {
			HStack(spacing: 10) {
				WorkspaceIconBadge(icon: "square.and.pencil", accent: .blue, size: 34)
				VStack(alignment: .leading, spacing: 2) {
					Text(AppBrand.localized("快速捕捉", "Quick Capture", locale: locale))
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					Text(AppBrand.localized("把想法先接住，再决定去哪里", "Capture first, decide the destination later", locale: locale))
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
				}
				Spacer()
			}
			.contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			.onTapGesture {
				NotificationCenter.default.post(name: .nexaLifeShowQuickInput, object: nil)
			}
		}
	}

	private var accountInitials: String {
		let trimmed = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "ME" : String(trimmed.prefix(2)).uppercased()
	}

	private func sidebarSection(title: String, modules: [AppModule]) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.caption.weight(.semibold))
				.foregroundStyle(WorkspaceTheme.mutedText)
				.padding(.horizontal, 6)

			ForEach(modules) { module in
				moduleButton(module)
			}
		}
	}

	private func moduleButton(_ module: AppModule) -> some View {
		let isSelected = appState.selectedModule == module
		let accent = moduleAccent(for: module)

		return Button {
			appState.updateModule(module)
		} label: {
			HStack(spacing: 10) {
				moduleIconView(module, isSelected: isSelected)
				Text(module.label(for: locale))
					.font(.system(size: 14, weight: isSelected ? .semibold : .medium))
				Spacer()
				if isSelected {
					Circle()
						.fill(Color.white.opacity(0.9))
						.frame(width: 6, height: 6)
				}
			}
		}
		.foregroundStyle(isSelected ? Color.white : WorkspaceTheme.strongText)
		.padding(.horizontal, 12)
		.padding(.vertical, 11)
		.background(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.fill(isSelected ? accent : WorkspaceTheme.elevatedSurface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(isSelected ? accent.opacity(0.24) : WorkspaceTheme.border, lineWidth: 1)
		)
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.buttonStyle(.plain)
	}

	private func moduleAccent(for module: AppModule) -> Color {
		WorkspaceTheme.moduleAccent(for: module)
	}

	private func moduleIconView(_ module: AppModule, isSelected: Bool) -> some View {
		let accent = moduleAccent(for: module)
		return ZStack {
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(isSelected ? Color.white.opacity(0.18) : WorkspaceTheme.elevatedSurface)
				.frame(width: 28, height: 28)
			Image(systemName: module.icon)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(isSelected ? Color.white : accent)
		}
	}
}

private struct AvatarThumbnail: View {
	var path: String
	var fallbackText: String

	var body: some View {
		if let image = AvatarImageLoader.load(from: path) {
			Image(nsImage: image)
				.resizable()
				.scaledToFill()
				.frame(width: 32, height: 32)
				.clipShape(Circle())
		} else {
			ZStack {
				Circle()
					.fill(Color.secondary.opacity(0.12))
					.frame(width: 32, height: 32)
				Text(fallbackText)
					.font(.system(size: 11, weight: .bold))
					.foregroundStyle(.secondary)
			}
		}
	}
}

enum AvatarImageLoader {
	static func load(from path: String) -> NSImage? {
		let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedPath.isEmpty else { return nil }

		let fileURL = URL(fileURLWithPath: trimmedPath)
		guard FileManager.default.fileExists(atPath: fileURL.path),
			  let data = try? Data(contentsOf: fileURL),
			  !data.isEmpty,
			  let bitmap = NSBitmapImageRep(data: data) else {
			return nil
		}

		let size = NSSize(
			width: max(1, bitmap.size.width),
			height: max(1, bitmap.size.height)
		)
		let image = NSImage(size: size)
		image.addRepresentation(bitmap)
		return image
	}
}

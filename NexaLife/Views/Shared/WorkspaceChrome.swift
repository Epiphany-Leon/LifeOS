//
//  WorkspaceChrome.swift
//  NexaLife
//
//  Created by Codex on 2026-04-14.
//

import SwiftUI

struct WorkspaceCard<Content: View>: View {
	let accent: Color
	let padding: CGFloat
	let cornerRadius: CGFloat
	let shadowY: CGFloat
	let content: Content

	init(
		accent: Color = WorkspaceTheme.accent,
		padding: CGFloat = 22,
		cornerRadius: CGFloat = 24,
		shadowY: CGFloat = 14,
		@ViewBuilder content: () -> Content
	) {
		self.accent = accent
		self.padding = padding
		self.cornerRadius = cornerRadius
		self.shadowY = shadowY
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			content
		}
		.padding(padding)
		.background(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.fill(WorkspaceTheme.surface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.stroke(accent.opacity(0.10), lineWidth: 1)
		)
		.shadow(color: WorkspaceTheme.shadow, radius: 24, x: 0, y: shadowY)
	}
}

struct WorkspaceSectionTitle: View {
	let eyebrow: String
	let title: String
	let subtitle: String
	let accent: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(eyebrow)
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(accent)
				.textCase(.uppercase)
			Text(title)
				.font(.system(size: 28, weight: .bold, design: .rounded))
				.foregroundStyle(WorkspaceTheme.strongText)
			Text(subtitle)
				.font(.subheadline)
				.foregroundStyle(WorkspaceTheme.mutedText)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}

struct WorkspaceMetricTile: View {
	let title: String
	let value: String
	let subtitle: String
	let icon: String
	let accent: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(spacing: 10) {
				ZStack {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(accent.opacity(0.12))
						.frame(width: 38, height: 38)
					Image(systemName: icon)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(accent)
				}
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					Text(subtitle)
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
						.lineLimit(1)
				}
			}

			Text(value)
				.font(.system(size: 28, weight: .bold, design: .rounded))
				.foregroundStyle(WorkspaceTheme.strongText)
				.lineLimit(1)
				.minimumScaleFactor(0.72)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(18)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(WorkspaceTheme.elevatedSurface)
		)
		.overlayBorder(accent: accent)   // FIX: 加上 leading dot，否则被解读为 self.overlayBorder() 当 sibling，造成无限递归
	}
}

struct WorkspacePanelHeader: View {
	let title: String
	let subtitle: String
	let accent: Color
	let icon: String?
	let value: String?

	init(
		title: String,
		subtitle: String,
		accent: Color,
		icon: String? = nil,
		value: String? = nil
	) {
		self.title = title
		self.subtitle = subtitle
		self.accent = accent
		self.icon = icon
		self.value = value
	}

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			if let icon {
				WorkspaceIconBadge(icon: icon, accent: accent, size: 36)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.headline)
					.foregroundStyle(WorkspaceTheme.strongText)
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
			}

			Spacer(minLength: 0)

			if let value {
				WorkspacePill(title: value, accent: accent)
			}
		}
	}
}

struct WorkspaceSelectableCard<Content: View>: View {
	let accent: Color
	let isSelected: Bool
	let cornerRadius: CGFloat
	let padding: CGFloat
	let content: Content

	init(
		accent: Color,
		isSelected: Bool = false,
		cornerRadius: CGFloat = 20,
		padding: CGFloat = 16,
		@ViewBuilder content: () -> Content
	) {
		self.accent = accent
		self.isSelected = isSelected
		self.cornerRadius = cornerRadius
		self.padding = padding
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			content
		}
		.padding(padding)
		.background(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.fill(isSelected ? accent.opacity(0.10) : WorkspaceTheme.elevatedSurface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.stroke(isSelected ? accent.opacity(0.24) : WorkspaceTheme.border, lineWidth: 1)
		)
		.shadow(color: WorkspaceTheme.shadow.opacity(isSelected ? 1 : 0.65), radius: 14, x: 0, y: 6)
	}
}

struct WorkspacePill: View {
	let title: String
	let icon: String?
	let accent: Color
	let isFilled: Bool

	init(title: String, icon: String? = nil, accent: Color, isFilled: Bool = false) {
		self.title = title
		self.icon = icon
		self.accent = accent
		self.isFilled = isFilled
	}

	var body: some View {
		HStack(spacing: 7) {
			if let icon {
				Image(systemName: icon)
					.font(.system(size: 11, weight: .semibold))
			}
			Text(title)
				.font(.caption.weight(.semibold))
		}
		.foregroundStyle(isFilled ? Color.white : accent)
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(
			Capsule()
				.fill(isFilled ? accent : accent.opacity(0.10))
		)
	}
}

struct WorkspaceActionButton: View {
	let title: String
	let icon: String?
	let accent: Color
	let isPrimary: Bool
	let action: () -> Void

	var body: some View {
		HStack(spacing: 8) {
			if let icon {
				Image(systemName: icon)
					.font(.system(size: 12, weight: .semibold))
			}
			Text(title)
				.font(.subheadline.weight(.semibold))
		}
		.foregroundStyle(isPrimary ? Color.white : accent)
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(
			Capsule()
				.fill(isPrimary ? accent : accent.opacity(0.10))
		)
		.contentShape(Capsule())
		.onTapGesture(perform: action)
	}
}

struct WorkspaceInlineStat: View {
	let title: String
	let value: String
	let accent: Color

	var body: some View {
		HStack(spacing: 6) {
			Text(title)
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
			Text(value)
				.font(.caption.weight(.bold))
				.foregroundStyle(accent)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(accent.opacity(0.10))
		.clipShape(Capsule())
	}
}

struct WorkspaceIconBadge: View {
	let icon: String
	let accent: Color
	let size: CGFloat

	init(icon: String, accent: Color, size: CGFloat = 40) {
		self.icon = icon
		self.accent = accent
		self.size = size
	}

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
				.fill(accent.opacity(0.10))
				.frame(width: size, height: size)
			Image(systemName: icon)
				.font(.system(size: size * 0.36, weight: .semibold))
				.foregroundStyle(accent)
		}
	}
}

// MARK: - Module Workspace Layout

/// Shared outer frame for all non-Dashboard module workspaces.
/// Provides a consistent module-identity strip at the top, followed by
/// the module's own content (toolbar + list/board/etc.).
struct ModuleWorkspaceLayout<Content: View, Trailing: View>: View {
	let module: AppModule
	let content: Content
	let trailing: Trailing
	@Environment(\.locale) private var locale

	init(
		module: AppModule,
		@ViewBuilder content: () -> Content,
		@ViewBuilder trailing: () -> Trailing
	) {
		self.module = module
		self.content = content()
		self.trailing = trailing()
	}

	private var accent: Color { WorkspaceTheme.moduleAccent(for: module) }

	var body: some View {
		VStack(spacing: 0) {
			moduleStrip
			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)
			content
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(WorkspaceTheme.surface)
	}

	private var moduleStrip: some View {
		HStack(spacing: 10) {
			WorkspaceIconBadge(icon: module.icon, accent: accent, size: 26)
			Text(module.label(for: locale))
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(WorkspaceTheme.strongText)
			Spacer()
			trailing
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 10)
		.background(WorkspaceTheme.surface)
	}
}

extension ModuleWorkspaceLayout where Trailing == EmptyView {
	init(module: AppModule, @ViewBuilder content: () -> Content) {
		self.init(module: module, content: content, trailing: { EmptyView() })
	}
}

private extension View {
	func overlayBorder(accent: Color) -> some View {
		overlay(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.stroke(accent.opacity(0.10), lineWidth: 1)
		)
	}
}

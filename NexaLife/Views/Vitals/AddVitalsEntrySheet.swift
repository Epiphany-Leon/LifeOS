//
//  AddVitalsEntrySheet.swift
//  NexaLife
//
//  v0.2.0 — 严格按 WorkspaceTheme / WorkspaceCard 设计语言
//

import SwiftUI
import SwiftData

struct AddVitalsEntrySheet: View {
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale

	var defaultType: VitalsEntryType

	@State private var content: String = ""
	@State private var selectedType: VitalsEntryType = .motivation
	@State private var moodScore: Int = 3
	@State private var coreCategory: String = "未分类"

	init(isPresented: Binding<Bool>, defaultType: VitalsEntryType) {
		self._isPresented = isPresented
		self.defaultType = defaultType
		self._selectedType = State(initialValue: defaultType)
	}

	var typeColor: Color {
		switch selectedType {
		case .coreCode:   return .purple
		case .reflection: return .blue
		case .emotion:    return .pink
		case .treehol:    return .green
		case .motivation: return .orange
		}
	}

	var body: some View {
		AnyView(rootContent)
			.background(WorkspaceTheme.surface)
			.frame(width: 540, height: 540)
	}

	private var rootContent: some View {
		VStack(spacing: 0) {
			topBar
			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)

			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					typeCard

					if selectedType == .coreCode {
						coreCategoryCard
					}

					contentCard

					if selectedType == .motivation || selectedType == .emotion {
						ratingCard
					}

					if selectedType == .coreCode || selectedType == .treehol {
						protectedHint
					}
				}
				.padding(.horizontal, 22)
				.padding(.vertical, 20)
			}
		}
	}

	// MARK: - Top Bar

	private var topBar: some View {
		HStack(spacing: 12) {
			WorkspaceIconBadge(icon: "sparkles", accent: typeColor, size: 30)
			Text(AppBrand.localized("新增觉知记录", "New Vitals Entry", locale: locale))
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(WorkspaceTheme.strongText)
			Spacer()
			Button(AppBrand.localized("取消", "Cancel", locale: locale)) {
				isPresented = false
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.keyboardShortcut(.cancelAction)

			WorkspaceActionButton(
				title: AppBrand.localized("保存记录", "Save", locale: locale),
				icon: "checkmark",
				accent: typeColor,
				isPrimary: true
			) {
				if !content.isEmpty { saveEntry() }
			}
			.opacity(content.isEmpty ? 0.45 : 1)
			.allowsHitTesting(!content.isEmpty)
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 11)
		.background(WorkspaceTheme.surface)
	}

	// MARK: - Type

	private var typeCard: some View {
		WorkspaceCard(accent: typeColor, padding: 16, cornerRadius: 18, shadowY: 4) {
			VStack(alignment: .leading, spacing: 10) {
				WorkspacePanelHeader(
					title: AppBrand.localized("类型", "Type", locale: locale),
					subtitle: typeHint,
					accent: typeColor,
					icon: typeIcon
				)
				Picker("", selection: $selectedType) {
					ForEach(VitalsEntryType.allCases, id: \.self) { type in
						Text(type.rawValue).tag(type)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}
		}
	}

	// MARK: - Content

	private var contentCard: some View {
		WorkspaceCard(accent: typeColor, padding: 16, cornerRadius: 18, shadowY: 4) {
			VStack(alignment: .leading, spacing: 8) {
				WorkspacePanelHeader(
					title: AppBrand.localized("内容", "Content", locale: locale),
					subtitle: AppBrand.localized("写下当下的想法，可随时编辑", "Write what's on your mind — editable anytime", locale: locale),
					accent: typeColor,
					icon: "doc.text"
				)
				ZStack(alignment: .topLeading) {
					TextEditor(text: $content)
						.font(.system(size: 14))
						.scrollContentBackground(.hidden)
						.frame(minHeight: 140)
						.padding(12)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(WorkspaceTheme.elevatedSurface)
						)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(typeColor.opacity(0.20), lineWidth: 1)
						)
					if content.isEmpty {
						Text(placeholder)
							.font(.system(size: 13))
							.foregroundStyle(WorkspaceTheme.mutedText)
							.padding(16)
							.allowsHitTesting(false)
					}
				}
			}
		}
	}

	// MARK: - Core Category

	private var coreCategoryCard: some View {
		WorkspaceCard(accent: .purple, padding: 14, cornerRadius: 18, shadowY: 3) {
			VStack(alignment: .leading, spacing: 8) {
				HStack(spacing: 6) {
					Image(systemName: "square.grid.2x2")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.purple)
					Text(AppBrand.localized("守则分类", "Principle Category", locale: locale))
						.font(.system(size: 12, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.mutedText)
				}
				TextField(
					AppBrand.localized("如：决策原则、沟通原则、健康原则", "e.g. Decision · Communication · Health", locale: locale),
					text: $coreCategory
				)
				.textFieldStyle(.roundedBorder)
			}
		}
	}

	// MARK: - Rating

	private var ratingCard: some View {
		WorkspaceCard(accent: typeColor, padding: 14, cornerRadius: 18, shadowY: 3) {
			HStack(spacing: 12) {
				Text(selectedType == .emotion
					 ? AppBrand.localized("情绪强度", "Emotion intensity", locale: locale)
					 : AppBrand.localized("能量评分", "Energy score", locale: locale))
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(WorkspaceTheme.mutedText)
				Spacer()
				HStack(spacing: 4) {
					ForEach(1...5, id: \.self) { i in
						Button {
							moodScore = i
						} label: {
							Image(systemName: i <= moodScore ? "star.fill" : "star")
								.font(.system(size: 16))
								.foregroundStyle(i <= moodScore ? typeColor : WorkspaceTheme.mutedText.opacity(0.4))
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	// MARK: - Protected Hint

	private var protectedHint: some View {
		HStack(spacing: 8) {
			Image(systemName: "lock.shield.fill")
				.font(.system(size: 13))
				.foregroundStyle(typeColor)
			Text(selectedType == .coreCode
				 ? AppBrand.localized("核心守则将被保护，删除需要身份验证", "Core principle is protected; deletion requires authentication", locale: locale)
				 : AppBrand.localized("树洞记录受保护，删除需要身份验证", "Treehole entry is protected; deletion requires authentication", locale: locale))
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
			Spacer()
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 9)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(typeColor.opacity(0.08))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.stroke(typeColor.opacity(0.18), lineWidth: 1)
		)
	}

	// MARK: - Type metadata

	private var typeIcon: String {
		switch selectedType {
		case .coreCode:   return "shield.lefthalf.filled"
		case .reflection: return "book.closed"
		case .emotion:    return "heart.text.square"
		case .treehol:    return "tree"
		case .motivation: return "bolt.heart"
		}
	}

	private var typeHint: String {
		switch selectedType {
		case .coreCode:
			return AppBrand.localized(
				"记录核心价值观与行为准则，AI 可辅助提炼",
				"Capture core values & principles · AI helps refine",
				locale: locale
			)
		case .reflection:
			return AppBrand.localized(
				"每日复盘 / 阶段记录 / 看见的模式",
				"Daily review · phase notes · spotted patterns",
				locale: locale
			)
		case .emotion:
			return AppBrand.localized(
				"记录情绪波动与触发点",
				"Track emotion shifts & triggers",
				locale: locale
			)
		case .treehol:
			return AppBrand.localized(
				"安全的情绪出口，沉淀不删除",
				"A safe outlet — saved, never deleted",
				locale: locale
			)
		case .motivation:
			return AppBrand.localized(
				"捕捉让你兴奋的想法与灵感",
				"Capture sparks of motivation & ideas",
				locale: locale
			)
		}
	}

	private var placeholder: String {
		switch selectedType {
		case .coreCode:   return AppBrand.localized("写下你的核心守则…", "Write your core principle…", locale: locale)
		case .reflection: return AppBrand.localized("今天发生了什么、看见了什么模式、明天推进什么…", "What happened today, patterns noticed, next move…", locale: locale)
		case .emotion:    return AppBrand.localized("此刻最明显的情绪是什么？触发它的是什么？", "What emotion is loudest now? What triggered it?", locale: locale)
		case .treehol:    return AppBrand.localized("想到什么写什么…", "Whatever comes to mind…", locale: locale)
		case .motivation: return AppBrand.localized("是什么让你感到兴奋或有动力？", "What's exciting or energizing you?", locale: locale)
		}
	}

	private func saveEntry() {
		let isProtected = selectedType == .coreCode || selectedType == .treehol
		let entry = VitalsEntry(
			content: content,
			type: selectedType,
			category: selectedType == .coreCode ? normalizedCoreCategory : "",
			isProtected: isProtected,
			moodScore: selectedType == .motivation || selectedType == .emotion ? moodScore : 0
		)
		modelContext.insert(entry)
		isPresented = false
	}

	private var normalizedCoreCategory: String {
		let trimmed = coreCategory.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}
}

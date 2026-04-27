//
//  VitalsDetailView.swift
//  NexaLife
//
//  v0.2.0 — 严格按 WorkspaceTheme / WorkspaceCard 设计语言
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct VitalsDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale
	@Query(sort: \VitalsEntry.timestamp, order: .reverse) private var allEntries: [VitalsEntry]
	@Binding var selectedEntry: VitalsEntry?
	@Bindable var entry: VitalsEntry
	@StateObject private var aiService = AIService()

	@State private var aiGuidance: String = ""
	@State private var isLoadingAI = false
	@State private var draftContent: String = ""
	@State private var isEditingContent = false

	var typeColor: Color {
		switch entry.type {
		case .coreCode:   return .purple
		case .reflection: return .blue
		case .emotion:    return .pink
		case .treehol:    return .green
		case .motivation: return .orange
		}
	}

	private var accent: Color { typeColor }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 22) {
				headerCard

				if entry.type == .coreCode {
					coreCategoryCard
				}

				if entry.type == .motivation || entry.type == .emotion {
					ratingCard
				}

				contentCard

				if entry.type == .coreCode || entry.type == .reflection || entry.type == .emotion {
					aiCard
				}

				if entry.type != .coreCode {
					archiveCard
				}

				deleteCard
			}
			.padding(.horizontal, 28)
			.padding(.vertical, 24)
		}
		.background(WorkspaceTheme.surface)
		.onAppear {
			normalizeEntryCategoryIfNeeded()
			draftContent = entry.content
			isEditingContent = false
		}
		.onChange(of: entry.id) { _, _ in
			draftContent = entry.content
			isEditingContent = false
		}
	}

	// MARK: - Header

	private var headerCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 8) {
			HStack(alignment: .top, spacing: 14) {
				WorkspaceIconBadge(icon: typeIcon, accent: accent, size: 38)
				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: 8) {
						Text(entry.type.rawValue)
							.font(.system(size: 17, weight: .bold, design: .rounded))
							.foregroundStyle(WorkspaceTheme.strongText)
						if entry.isProtected {
							WorkspacePill(title: AppBrand.localized("受保护", "Protected", locale: locale), icon: "lock.fill", accent: .gray)
						}
					}
					Text(AppDateFormatter.ymd(entry.timestamp))
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
				}
				Spacer()
				Menu {
					ForEach(VitalsEntryType.allCases, id: \.self) { type in
						Button {
							createEntry(type: type)
						} label: {
							Label(type.rawValue, systemImage: typeIcon(for: type))
						}
					}
				} label: {
					HStack(spacing: 6) {
						Image(systemName: "plus")
							.font(.system(size: 11, weight: .semibold))
						Text(AppBrand.localized("新建", "New", locale: locale))
							.font(.caption.weight(.semibold))
					}
					.foregroundStyle(Color.white)
					.padding(.horizontal, 12)
					.padding(.vertical, 7)
					.background(Capsule().fill(accent))
				}
				.menuStyle(.borderlessButton)
				.menuIndicator(.hidden)
				.fixedSize()
			}
		}
	}

	// MARK: - Rating

	private var ratingCard: some View {
		WorkspaceCard(accent: accent, padding: 16, cornerRadius: 18, shadowY: 4) {
			HStack(spacing: 12) {
				Text(entry.type == .emotion
					 ? AppBrand.localized("情绪强度", "Emotion intensity", locale: locale)
					 : AppBrand.localized("能量评分", "Energy score", locale: locale))
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(WorkspaceTheme.mutedText)
				Spacer()
				HStack(spacing: 4) {
					ForEach(1...5, id: \.self) { i in
						Button {
							entry.moodScore = i
						} label: {
							Image(systemName: i <= entry.moodScore ? "star.fill" : "star")
								.font(.system(size: 16))
								.foregroundStyle(i <= entry.moodScore ? accent : WorkspaceTheme.mutedText.opacity(0.4))
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	// MARK: - Content

	private var contentCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					WorkspacePanelHeader(
						title: AppBrand.localized("正文内容", "Content", locale: locale),
						subtitle: isEditingContent
							? AppBrand.localized("编辑模式 · 完成后点保存", "Editing · save when done", locale: locale)
							: AppBrand.localized("点击修改进入编辑", "Tap edit to modify", locale: locale),
						accent: accent,
						icon: "doc.text"
					)
					Spacer()
					if isEditingContent {
						Button(AppBrand.localized("取消", "Cancel", locale: locale)) {
							draftContent = entry.content
							isEditingContent = false
						}
						.buttonStyle(.bordered)
						.controlSize(.small)

						Button(AppBrand.localized("保存", "Save", locale: locale)) {
							entry.content = draftContent
							isEditingContent = false
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.small)
					} else {
						WorkspaceActionButton(
							title: AppBrand.localized("修改", "Edit", locale: locale),
							icon: "pencil",
							accent: accent,
							isPrimary: false
						) {
							draftContent = entry.content
							isEditingContent = true
						}
					}
				}

				if isEditingContent {
					TextEditor(text: $draftContent)
						.font(.system(size: 14))
						.scrollContentBackground(.hidden)
						.frame(minHeight: 180)
						.padding(12)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(WorkspaceTheme.elevatedSurface)
						)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(accent.opacity(0.20), lineWidth: 1)
						)
				} else {
					Text(entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
						 ? AppBrand.localized("暂无内容", "No content yet", locale: locale)
						 : entry.content)
						.font(.system(size: 14))
						.foregroundStyle(WorkspaceTheme.strongText)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(14)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(accent.opacity(0.05))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(WorkspaceTheme.border, lineWidth: 1)
						)
				}
			}
		}
	}

	// MARK: - Core Category

	private var coreCategoryCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 4) {
			VStack(alignment: .leading, spacing: 12) {
				WorkspacePanelHeader(
					title: AppBrand.localized("守则分类", "Principle Category", locale: locale),
					subtitle: AppBrand.localized("如：决策原则 / 沟通原则 / 关系原则", "e.g. Decision · Communication · Relationships", locale: locale),
					accent: accent,
					icon: "square.grid.2x2"
				)

				TextField(
					AppBrand.localized("输入分类", "Type a category", locale: locale),
					text: $entry.category
				)
				.textFieldStyle(.roundedBorder)
				.onSubmit { normalizeEntryCategoryIfNeeded() }

				if !coreCategoryOptions.isEmpty {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 6) {
							ForEach(coreCategoryOptions, id: \.self) { option in
								let isActive = option == normalizedCoreCategory(entry.category)
								Button {
									entry.category = option
								} label: {
									Text(option)
										.font(.caption.weight(.semibold))
										.foregroundStyle(isActive ? Color.white : accent)
										.padding(.horizontal, 10)
										.padding(.vertical, 5)
										.background(Capsule().fill(isActive ? accent : accent.opacity(0.10)))
								}
								.buttonStyle(.plain)
							}
						}
					}
				}
			}
		}
	}

	// MARK: - AI

	private var aiCard: some View {
		WorkspaceCard(accent: .purple, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					WorkspacePanelHeader(
						title: AppBrand.localized("AI 辅助整理", "AI Assistance", locale: locale),
						subtitle: AppBrand.localized("提取要点、生成结构化建议", "Extract key points and structured advice", locale: locale),
						accent: .purple,
						icon: "sparkles"
					)
					Button {
						loadAIGuidance()
					} label: {
						HStack(spacing: 6) {
							if isLoadingAI {
								ProgressView().scaleEffect(0.6)
								Text(AppBrand.localized("生成中…", "Generating…", locale: locale))
									.font(.caption.weight(.semibold))
							} else {
								Image(systemName: "wand.and.stars")
									.font(.system(size: 11, weight: .semibold))
								Text(AppBrand.localized("获取建议", "Generate", locale: locale))
									.font(.caption.weight(.semibold))
							}
						}
						.foregroundStyle(Color.white)
						.padding(.horizontal, 12)
						.padding(.vertical, 7)
						.background(Capsule().fill(Color.purple))
					}
					.buttonStyle(.plain)
					.disabled(isLoadingAI)
				}

				if !aiGuidance.isEmpty {
					Text(aiGuidance)
						.font(.system(size: 13))
						.foregroundStyle(WorkspaceTheme.strongText)
						.padding(14)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(Color.purple.opacity(0.06))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(Color.purple.opacity(0.18), lineWidth: 1)
						)
				}
			}
		}
	}

	// MARK: - Archive

	private var archiveCard: some View {
		WorkspaceCard(accent: accent, padding: 16, cornerRadius: 18, shadowY: 4) {
			HStack(spacing: 10) {
				WorkspaceActionButton(
					title: entry.isArchived
						? AppBrand.localized("已存档", "Archived", locale: locale)
						: AppBrand.localized("存入 Knowledge", "Save to Knowledge", locale: locale),
					icon: "book",
					accent: WorkspaceTheme.moduleAccent(for: .knowledge),
					isPrimary: false
				) { archiveEntry(to: "Knowledge") }

				WorkspaceActionButton(
					title: AppBrand.localized("存入 Vitals Review", "Save to Vitals Review", locale: locale),
					icon: "sparkles",
					accent: .purple,
					isPrimary: false
				) { archiveEntry(to: "Vitals") }

				Spacer()
			}
			.opacity(entry.isArchived ? 0.55 : 1)
			.allowsHitTesting(!entry.isArchived)
		}
	}

	// MARK: - Delete

	private var deleteCard: some View {
		HStack {
			Spacer()
			WorkspaceActionButton(
				title: AppBrand.localized("删除记录", "Delete entry", locale: locale),
				icon: "trash",
				accent: .red,
				isPrimary: false
			) { attemptDeleteCurrentEntry() }
		}
	}

	private var coreCategoryOptions: [String] {
		Set(allEntries.filter { $0.type == .coreCode }.map { normalizedCoreCategory($0.category) }).sorted()
	}

	private var typeIcon: String {
		typeIcon(for: entry.type)
	}

	private func typeIcon(for type: VitalsEntryType) -> String {
		switch type {
		case .coreCode:   return "shield.lefthalf.filled"
		case .reflection: return "book.closed"
		case .emotion:    return "heart.text.square"
		case .treehol:    return "tree"
		case .motivation: return "bolt.heart"
		}
	}

	private func createEntry(type: VitalsEntryType) {
		let isProtected = type == .coreCode || type == .treehol
		let newEntry = VitalsEntry(
			content: "",
			type: type,
			category: type == .coreCode ? "未分类" : "",
			isProtected: isProtected,
			moodScore: type == .motivation || type == .emotion ? 3 : 0
		)
		modelContext.insert(newEntry)
		selectedEntry = newEntry
	}

	private func normalizeEntryCategoryIfNeeded() {
		guard entry.type == .coreCode else { return }
		entry.category = normalizedCoreCategory(entry.category)
	}

	private func normalizedCoreCategory(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}

	private func attemptDeleteCurrentEntry() {
		if entry.isProtected {
			authenticateAndDelete(entry: entry)
		} else {
			deleteEntry(entry)
		}
	}

	private func deleteEntry(_ target: VitalsEntry) {
		selectedEntry = nil
		modelContext.delete(target)
	}

	private func authenticateAndDelete(entry: VitalsEntry) {
		let context = LAContext()
		var error: NSError?
		guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
		context.evaluatePolicy(
			.deviceOwnerAuthentication,
			localizedReason: "需要验证身份才能删除「\(entry.type.rawValue)」记录"
		) { success, _ in
			DispatchQueue.main.async {
				if success {
					deleteEntry(entry)
				}
			}
		}
	}

	private func loadAIGuidance() {
		isLoadingAI = true
		Task {
			let guidance = await aiService.generateReport(
				entries: [entry.content],
				type: "\(entry.type.rawValue)整理"
			)
			await MainActor.run {
				aiGuidance = guidance
				isLoadingAI = false
			}
		}
	}

	private func archiveEntry(to destination: String) {
		let note = Note(
			title: "【Vitals 存档】\(entry.type.rawValue)",
			subtitle: AppDateFormatter.ymd(entry.timestamp),
			content: entry.content,
			topic: destination == "Vitals" ? "Vitals Review" : "Vitals"
		)
		modelContext.insert(note)
		entry.isArchived = true
	}
}

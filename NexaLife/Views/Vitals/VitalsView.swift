//
//  VitalsView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//
//  v0.2.0 layout: 1:2 two-column workspace.
//   - Left column: 核心守则 (top) + 树洞 quick-add (bottom)
//   - Right column: 复盘记录 / 动力·灵感 (tabbed)
//

import SwiftUI
import SwiftData

// MARK: - Helpers

private enum VitalsEntryFactory {
	static func make(_ type: VitalsEntryType) -> VitalsEntry {
		let isProtected = (type == .coreCode || type == .treehol)
		return VitalsEntry(content: "", type: type, category: "", isProtected: isProtected, moodScore: 0)
	}
}

private func vitalsPreviewText(_ entry: VitalsEntry) -> String {
	let trimmed = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
	return trimmed.isEmpty ? "（空白记录）" : trimmed
}

// MARK: - VitalsView

struct VitalsView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \VitalsEntry.timestamp, order: .reverse) private var entries: [VitalsEntry]

	@Binding var selectedEntry: VitalsEntry?
	@State private var treeholeDraft: String = ""

	private var coreEntries: [VitalsEntry] { entries.filter { $0.type == .coreCode } }
	private var reflectionEntries: [VitalsEntry] { entries.filter { $0.type == .reflection } }
	private var motivationEntries: [VitalsEntry] { entries.filter { $0.type == .motivation } }
	private var emotionAndTreeholeEntries: [VitalsEntry] {
		entries.filter { $0.type == .emotion || $0.type == .treehol }
	}

	var body: some View {
		GeometryReader { proxy in
			let spacing: CGFloat = 16
			let horizontalPadding: CGFloat = 32
			let usable = max(0, proxy.size.width - horizontalPadding - spacing)
			let leftWidth = usable / 3
			let rightWidth = usable - leftWidth

			ScrollView {
				HStack(alignment: .top, spacing: spacing) {
					VStack(alignment: .leading, spacing: 16) {
						CoreGuidelinesPanel(
							entries: coreEntries,
							selectedEntry: selectedEntry,
							onSelect: { selectedEntry = $0 },
							onCreate: { createEntry(.coreCode) },
							onDelete: deleteEntry
						)

						TreeholeQuickAddCard(
							entries: emotionAndTreeholeEntries,
							draft: $treeholeDraft,
							onSelect: { selectedEntry = $0 },
							onSubmit: addTreeholeFromDraft,
							onDelete: deleteEntry
						)
					}
					.frame(width: leftWidth)

					ReflectionMotivationPanel(
						reflectionEntries: reflectionEntries,
						motivationEntries: motivationEntries,
						selectedEntry: selectedEntry,
						onSelect: { selectedEntry = $0 },
						onCreateReflection: { createEntry(.reflection) },
						onCreateMotivation: { createEntry(.motivation) },
						onDelete: deleteEntry
					)
					.frame(width: rightWidth)
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 18)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.onChange(of: entries.map(\.id)) { _, ids in
			if let selected = selectedEntry, !ids.contains(selected.id) {
				selectedEntry = nil
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .nexaLifeVitalsCreateEntry)) { _ in
			createEntry(.reflection)
		}
	}

	// MARK: - Mutations

	private func createEntry(_ type: VitalsEntryType) {
		let entry = VitalsEntryFactory.make(type)
		modelContext.insert(entry)
		try? modelContext.save()
		selectedEntry = entry
	}

	private func deleteEntry(_ entry: VitalsEntry) {
		if selectedEntry?.id == entry.id {
			selectedEntry = nil
		}
		modelContext.delete(entry)
		try? modelContext.save()
	}

	private func addTreeholeFromDraft() {
		let trimmed = treeholeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		let entry = VitalsEntry(
			content: trimmed,
			type: .treehol,
			category: "",
			isProtected: true,
			moodScore: 0
		)
		modelContext.insert(entry)
		try? modelContext.save()
		treeholeDraft = ""
	}
}

// MARK: - CoreGuidelinesPanel

private struct CoreGuidelinesPanel: View {
	let entries: [VitalsEntry]
	let selectedEntry: VitalsEntry?
	let onSelect: (VitalsEntry) -> Void
	let onCreate: () -> Void
	let onDelete: (VitalsEntry) -> Void

	private let accent: Color = .purple

	private var grouped: [(category: String, items: [VitalsEntry])] {
		let dict = Dictionary(grouping: entries) { entry -> String in
			let trimmed = entry.category.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? "未分类" : trimmed
		}
		return dict.keys.sorted().map { key in
			(key, (dict[key] ?? []).sorted(by: { $0.timestamp > $1.timestamp }))
		}
	}

	var body: some View {
		WorkspaceCard(accent: accent, padding: 20, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				VitalsPanelHeader(
					title: "核心守则",
					icon: "shield.lefthalf.filled",
					accent: accent,
					createHint: "添加核心守则",
					onCreate: onCreate
				)

				VitalsCountLine(count: entries.count, accent: accent)

				if entries.isEmpty {
					VitalsEmptyHint(text: "还没有核心守则")
				} else {
					VStack(alignment: .leading, spacing: 14) {
						ForEach(grouped, id: \.category) { group in
							VStack(alignment: .leading, spacing: 6) {
								Text(group.category)
									.font(.caption.weight(.semibold))
									.foregroundStyle(accent.opacity(0.85))

								ForEach(group.items) { entry in
									VitalsEntryRow(
										entry: entry,
										isSelected: selectedEntry?.id == entry.id,
										accent: accent,
										showsTimestamp: false,
										onSelect: { onSelect(entry) },
										onDelete: { onDelete(entry) }
									)
								}
							}
						}
					}
				}
			}
		}
	}
}

// MARK: - ReflectionMotivationPanel

private enum ReflectionMotivationTab: String, CaseIterable {
	case reflection = "复盘记录"
	case motivation = "动力 / 灵感"

	var icon: String {
		switch self {
		case .reflection: return "book.closed"
		case .motivation: return "bolt.heart"
		}
	}

	var accent: Color {
		switch self {
		case .reflection: return .blue
		case .motivation: return .orange
		}
	}
}

private struct ReflectionMotivationPanel: View {
	let reflectionEntries: [VitalsEntry]
	let motivationEntries: [VitalsEntry]
	let selectedEntry: VitalsEntry?
	let onSelect: (VitalsEntry) -> Void
	let onCreateReflection: () -> Void
	let onCreateMotivation: () -> Void
	let onDelete: (VitalsEntry) -> Void

	@State private var activeTab: ReflectionMotivationTab = .reflection

	private var activeEntries: [VitalsEntry] {
		switch activeTab {
		case .reflection: return reflectionEntries
		case .motivation: return motivationEntries
		}
	}

	private func handleCreate() {
		switch activeTab {
		case .reflection: onCreateReflection()
		case .motivation: onCreateMotivation()
		}
	}

	var body: some View {
		WorkspaceCard(accent: activeTab.accent, padding: 20, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				VitalsPanelHeader(
					title: activeTab.rawValue,
					icon: activeTab.icon,
					accent: activeTab.accent,
					createHint: "添加 \(activeTab.rawValue)",
					onCreate: handleCreate
				)

				HStack(spacing: 6) {
					ForEach(ReflectionMotivationTab.allCases, id: \.self) { tab in
						let isActive = tab == activeTab
						Button { activeTab = tab } label: {
							Text(tab.rawValue)
								.font(.system(size: 12, weight: isActive ? .semibold : .medium))
								.foregroundStyle(isActive ? Color.white : WorkspaceTheme.strongText)
								.padding(.horizontal, 10)
								.padding(.vertical, 5)
								.background(isActive ? tab.accent : WorkspaceTheme.elevatedSurface)
								.clipShape(Capsule())
						}
						.buttonStyle(.plain)
					}

					Spacer(minLength: 0)

					VitalsCountLine(count: activeEntries.count, accent: activeTab.accent, inline: true)
				}

				if activeEntries.isEmpty {
					VitalsEmptyHint(text: "现在有什么想法")
				} else {
					VStack(alignment: .leading, spacing: 6) {
						ForEach(activeEntries.prefix(8)) { entry in
							VitalsEntryRow(
								entry: entry,
								isSelected: selectedEntry?.id == entry.id,
								accent: activeTab.accent,
								showsTimestamp: true,
								onSelect: { onSelect(entry) },
								onDelete: { onDelete(entry) }
							)
						}
					}
				}
			}
		}
	}
}

// MARK: - TreeholeQuickAddCard

private struct TreeholeQuickAddCard: View {
	let entries: [VitalsEntry]
	@Binding var draft: String
	let onSelect: (VitalsEntry) -> Void
	let onSubmit: () -> Void
	let onDelete: (VitalsEntry) -> Void

	private let accent: Color = .pink

	private var recent: [VitalsEntry] { Array(entries.prefix(3)) }

	private var canSubmit: Bool {
		!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		WorkspaceCard(accent: accent, padding: 20, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(spacing: 10) {
					WorkspaceIconBadge(icon: "leaf", accent: accent, size: 26)
					Text("树洞")
						.font(.system(size: 15, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					Spacer(minLength: 0)
				}

				VitalsCountLine(count: entries.count, accent: accent)

				if recent.isEmpty {
					VitalsEmptyHint(text: "还没有树洞独白")
				} else {
					VStack(alignment: .leading, spacing: 8) {
						ForEach(recent) { entry in
							Button { onSelect(entry) } label: {
								HStack(alignment: .top, spacing: 8) {
									Image(systemName: "quote.opening")
										.font(.system(size: 11, weight: .semibold))
										.foregroundStyle(accent.opacity(0.7))
										.padding(.top, 3)
									VStack(alignment: .leading, spacing: 2) {
										Text(vitalsPreviewText(entry))
											.font(.system(size: 13))
											.foregroundStyle(WorkspaceTheme.strongText)
											.lineLimit(2)
											.multilineTextAlignment(.leading)
										Text(AppDateFormatter.ymd(entry.timestamp))
											.font(.caption2)
											.foregroundStyle(.tertiary)
									}
									Spacer(minLength: 0)
								}
							}
							.buttonStyle(.plain)
							.contextMenu {
								Button("编辑") { onSelect(entry) }
								Button("删除", role: .destructive) { onDelete(entry) }
							}
						}
					}
				}

				HStack(spacing: 8) {
					TextField("写下此刻的想法…", text: $draft, axis: .vertical)
						.textFieldStyle(.plain)
						.lineLimit(1...3)
						.padding(.horizontal, 12)
						.padding(.vertical, 10)
						.background(WorkspaceTheme.elevatedSurface)
						.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
						.overlay(
							RoundedRectangle(cornerRadius: 12, style: .continuous)
								.stroke(WorkspaceTheme.border, lineWidth: 1)
						)
						.onSubmit(onSubmit)

					Button(action: onSubmit) {
						Image(systemName: "arrow.up.circle.fill")
							.font(.system(size: 22, weight: .semibold))
							.foregroundStyle(canSubmit ? accent : Color.gray.opacity(0.4))
					}
					.buttonStyle(.plain)
					.disabled(!canSubmit)
				}
			}
		}
	}
}

// MARK: - Reusable subviews

private struct VitalsPanelHeader: View {
	let title: String
	let icon: String
	let accent: Color
	let createHint: String
	let onCreate: () -> Void

	var body: some View {
		HStack(spacing: 10) {
			WorkspaceIconBadge(icon: icon, accent: accent, size: 26)
			Text(title)
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(WorkspaceTheme.strongText)
			Spacer(minLength: 0)
			Button(action: onCreate) {
				Image(systemName: "plus.circle.fill")
					.font(.system(size: 20, weight: .semibold))
					.foregroundStyle(accent)
			}
			.buttonStyle(.plain)
			.help(createHint)
		}
	}
}

private struct VitalsCountLine: View {
	let count: Int
	let accent: Color
	var inline: Bool = false

	var body: some View {
		HStack(spacing: 6) {
			Text("\(count)")
				.font(.system(size: inline ? 18 : 22, weight: .bold, design: .rounded))
				.foregroundStyle(accent)
			Text("条")
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
		}
	}
}

private struct VitalsEmptyHint: View {
	let text: String
	var body: some View {
		Text(text)
			.font(.caption)
			.foregroundStyle(WorkspaceTheme.mutedText)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.vertical, 6)
	}
}

private struct VitalsEntryRow: View {
	let entry: VitalsEntry
	let isSelected: Bool
	let accent: Color
	let showsTimestamp: Bool
	let onSelect: () -> Void
	let onDelete: () -> Void

	var body: some View {
		Button(action: onSelect) {
			HStack(alignment: .top, spacing: 6) {
				Circle()
					.fill(accent.opacity(0.6))
					.frame(width: 5, height: 5)
					.padding(.top, 6)
				VStack(alignment: .leading, spacing: 2) {
					Text(vitalsPreviewText(entry))
						.font(.system(size: 12.5))
						.foregroundStyle(WorkspaceTheme.strongText)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
					if showsTimestamp {
						Text(AppDateFormatter.ymd(entry.timestamp))
							.font(.caption2)
							.foregroundStyle(.tertiary)
					}
				}
				Spacer(minLength: 0)
			}
			.padding(.vertical, 3)
			.padding(.horizontal, 6)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(isSelected ? accent.opacity(0.12) : Color.clear)
			)
		}
		.buttonStyle(.plain)
		.contextMenu {
			Button("编辑", action: onSelect)
			Button("删除", role: .destructive, action: onDelete)
		}
	}
}

//
//  VitalsView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct VitalsView: View {
	@Query(sort: \VitalsEntry.timestamp, order: .reverse) private var entries: [VitalsEntry]

	@Binding var selectedEntry: VitalsEntry?
	@State private var selectedType: VitalsEntryType? = nil   // nil = 全部

	private let calendar = Calendar.current

	private var filteredEntries: [VitalsEntry] {
		guard let type = selectedType else { return entries }
		return entries.filter { $0.type == type }
	}

	private var coreEntries: [VitalsEntry] {
		entries.filter { $0.type == .coreCode }
	}

	private var coreCategoryCount: Int {
		Set(coreEntries.map { coreCategoryLabel($0.category) }).count
	}

	private var updatedThisWeekCount: Int {
		guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
		return entries.filter { $0.timestamp >= weekStart }.count
	}

	private var archivedCount: Int {
		entries.filter(\.isArchived).count
	}

	private var groupedCoreEntries: [(String, [VitalsEntry])] {
		let grouped = Dictionary(
			grouping: filteredEntries.filter { $0.type == .coreCode },
			by: { coreCategoryLabel($0.category) }
		)
		return grouped.keys.sorted().map { category in
			(category, (grouped[category] ?? []).sorted(by: { $0.timestamp > $1.timestamp }))
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			header

			Divider()

			typeFilterBar

			Divider()

			List(selection: $selectedEntry) {
				if filteredEntries.isEmpty {
					ContentUnavailableView(
						"还没有记录",
						systemImage: "sparkles",
						description: Text("在右侧 Detail 栏新建并编辑记录")
					)
				} else if selectedType == .coreCode {
					ForEach(groupedCoreEntries, id: \.0) { category, items in
						Section(header: CoreCategorySectionHeader(category: category, count: items.count)) {
							ForEach(items) { entry in
								VitalsRowView(entry: entry)
									.tag(entry)
									.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
							}
						}
					}
				} else {
					ForEach(filteredEntries) { entry in
						VitalsRowView(entry: entry)
							.tag(entry)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
					}
				}
			}
		}
		.navigationTitle("觉知 Vitals")
		.navigationSplitViewColumnWidth(min: ColumnWidth.min, ideal: ColumnWidth.ideal, max: ColumnWidth.max)
		.onChange(of: entries.map(\.id)) { _, ids in
			if let selected = selectedEntry, !ids.contains(selected.id) {
				selectedEntry = nil
			}
		}
	}

	private var header: some View {
		LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
			VitalsMetricCard(
				title: "记录总数",
				value: "\(entries.count)",
				subtitle: "觉知沉淀规模",
				color: .blue
			)
			VitalsMetricCard(
				title: "核心守则",
				value: "\(coreEntries.count)",
				subtitle: "分类 \(coreCategoryCount)",
				color: .purple
			)
			VitalsMetricCard(
				title: "本周更新",
				value: "\(updatedThisWeekCount)",
				subtitle: "最近活跃度",
				color: .teal
			)
			VitalsMetricCard(
				title: "动力/灵感",
				value: "\(entries.filter { $0.type == .motivation }.count)",
				subtitle: "已存档 \(archivedCount)",
				color: .orange
			)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(Color(nsColor: .windowBackgroundColor))
	}

	private var typeFilterBar: some View {
		HStack(spacing: 0) {
			TypeFilterButton(label: "全部", isSelected: selectedType == nil) {
				selectedType = nil
			}
			ForEach(VitalsEntryType.allCases, id: \.self) { type in
				TypeFilterButton(label: type.rawValue, isSelected: selectedType == type) {
					selectedType = type
				}
			}
			Spacer()
		}
		.padding(.vertical, 6)
	}

	private func coreCategoryLabel(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}
}

private struct VitalsMetricCard: View {
	var title: String
	var value: String
	var subtitle: String
	var color: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
			Text(value)
				.font(.system(size: 20, weight: .bold))
				.foregroundStyle(color)
				.lineLimit(1)
				.minimumScaleFactor(0.75)
			Text(subtitle)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(color.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}

private struct CoreCategorySectionHeader: View {
	var category: String
	var count: Int

	var body: some View {
		HStack(spacing: 8) {
			Text(category)
				.font(.caption)
			Text("\(count)")
				.font(.caption2)
				.padding(.horizontal, 6)
				.padding(.vertical, 1)
				.background(Color.secondary.opacity(0.15))
				.clipShape(Capsule())
		}
		.foregroundStyle(.secondary)
	}
}

// MARK: - 类型筛选按钮
struct TypeFilterButton: View {
	var label: String
	var isSelected: Bool
	var action: () -> Void

	var body: some View {
		Button(action: action) {
			Text(label)
				.font(.subheadline)
				.padding(.horizontal, 12)
				.padding(.vertical, 5)
				.background(isSelected ? Color.accentColor : Color.clear)
				.foregroundStyle(isSelected ? .white : .primary)
				.clipShape(Capsule())
		}
		.buttonStyle(.plain)
		.padding(.leading, 8)
	}
}

// MARK: - 条目行
struct VitalsRowView: View {
	var entry: VitalsEntry

	var typeColor: Color {
		switch entry.type {
		case .coreCode:   return .purple
		case .treehol:    return .green
		case .motivation: return .orange
		}
	}

	var typeIcon: String {
		switch entry.type {
		case .coreCode:   return "shield.lefthalf.filled"
		case .treehol:    return "tree"
		case .motivation: return "bolt.heart"
		}
	}

	private var coreCategoryLabel: String {
		let trimmed = entry.category.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 6) {
				Label(entry.type.rawValue, systemImage: typeIcon)
					.font(.caption2)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(typeColor.opacity(0.12))
					.foregroundStyle(typeColor)
					.clipShape(Capsule())

				if entry.type == .coreCode {
					Text(coreCategoryLabel)
						.font(.caption2)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.purple.opacity(0.12))
						.foregroundStyle(.purple)
						.clipShape(Capsule())
				}

				if entry.isProtected {
					Image(systemName: "lock.fill")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}

				if entry.isArchived {
					Image(systemName: "archivebox.fill")
						.font(.caption2)
						.foregroundStyle(.blue)
				}

				Spacer()

				if entry.type == .motivation && entry.moodScore > 0 {
					HStack(spacing: 1) {
						ForEach(1...5, id: \.self) { i in
							Image(systemName: i <= entry.moodScore ? "star.fill" : "star")
								.font(.caption2)
								.foregroundStyle(i <= entry.moodScore ? Color.orange : Color.secondary)
						}
					}
				}
			}

			Text(entry.content)
				.font(.body)
				.lineLimit(3)

			Text(AppDateFormatter.ymd(entry.timestamp))
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

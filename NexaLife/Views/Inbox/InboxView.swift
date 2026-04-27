//
//  InboxView.swift
//  NexaLife
//
//  v0.2.0 — Header trailing 已移到 ModuleWorkspaceLayout；顶部 tag 统计改成卡片式。
//

import SwiftUI
import SwiftData

struct InboxView: View {
	@Query(sort: \InboxItem.timestamp, order: .reverse) private var items: [InboxItem]
	@Environment(\.locale) private var locale

	@Binding var selectedItem: InboxItem?

	var unprocessedItems: [InboxItem] { items.filter { !$0.isProcessed } }
	private var processedCount: Int { items.count - unprocessedItems.count }
	private var accent: Color { WorkspaceTheme.moduleAccent(for: .inbox) }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				statsCards

				Rectangle()
					.fill(WorkspaceTheme.divider)
					.frame(height: 1)
					.padding(.vertical, 4)

				if unprocessedItems.isEmpty {
					ContentUnavailableView(
						AppBrand.localized("收件箱是空的", "Inbox is empty", locale: locale),
						systemImage: "tray",
						description: Text(AppBrand.localized("用 ⌘⇧N 捕捉你的第一个闪念", "Press ⌘⇧N to capture your first flash idea", locale: locale))
					)
					.frame(maxWidth: .infinity)
					.padding(.top, 32)
				} else {
					Text(AppBrand.localized("未处理 (\(unprocessedItems.count))", "Unprocessed (\(unprocessedItems.count))", locale: locale))
						.font(.system(size: 12, weight: .bold))
						.foregroundStyle(WorkspaceTheme.mutedText)
						.textCase(.uppercase)
						.tracking(0.6)

					LazyVStack(spacing: 8) {
						ForEach(unprocessedItems) { item in
							InboxRowView(item: item)
								.padding(.horizontal, 12)
								.padding(.vertical, 10)
								.frame(maxWidth: .infinity, alignment: .leading)
								.background(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.fill(isSelected(item) ? accent.opacity(0.10) : WorkspaceTheme.elevatedSurface)
								)
								.overlay(
									RoundedRectangle(cornerRadius: 14, style: .continuous)
										.stroke(isSelected(item) ? accent.opacity(0.30) : WorkspaceTheme.border, lineWidth: 1)
								)
								.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
								.onTapGesture {
									selectedItem = item
								}
						}
					}
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 18)
		}
	}

	// 顶部卡片化统计（替代原来的 tag 行）
	private var statsCards: some View {
		LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
			WorkspaceMetricTile(
				title: AppBrand.localized("未处理", "Unprocessed", locale: locale),
				value: "\(unprocessedItems.count)",
				subtitle: AppBrand.localized("等待你判断去向", "Waiting to be routed", locale: locale),
				icon: "tray",
				accent: .orange
			)
			WorkspaceMetricTile(
				title: AppBrand.localized("已处理", "Processed", locale: locale),
				value: "\(processedCount)",
				subtitle: AppBrand.localized("已归类的条目", "Already classified", locale: locale),
				icon: "checkmark.circle",
				accent: .green
			)
			WorkspaceMetricTile(
				title: AppBrand.localized("总收集", "Total Captured", locale: locale),
				value: "\(items.count)",
				subtitle: AppBrand.localized("收件箱累计闪念", "Cumulative flash ideas", locale: locale),
				icon: "sparkles",
				accent: accent
			)
		}
	}

	private func isSelected(_ item: InboxItem) -> Bool {
		selectedItem?.id == item.id
	}
}

struct InboxRowView: View {
	var item: InboxItem

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Text(item.content)
				.lineLimit(2)
				.font(.system(size: 15, weight: .medium))
				.foregroundStyle(WorkspaceTheme.strongText)

			HStack(spacing: 6) {
				Text(item.timestamp, style: .date)
					.font(.system(size: 12))
					.foregroundStyle(WorkspaceTheme.mutedText)

				if let module = item.suggestedModule {
					Text("·").foregroundStyle(.secondary)
					Label(module, systemImage: "sparkles")
						.font(.system(size: 12))
						.foregroundStyle(.purple)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 5)
	}
}

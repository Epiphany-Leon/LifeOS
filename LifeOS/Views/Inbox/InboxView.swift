//
//  InboxView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct InboxView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \InboxItem.timestamp, order: .reverse) private var items: [InboxItem]

	@Binding var selectedItem: InboxItem?

	var unprocessedItems: [InboxItem] { items.filter { !$0.isProcessed } }

	var body: some View {
		List(selection: $selectedItem) {
			if unprocessedItems.isEmpty {
				ContentUnavailableView(
					"收件箱是空的",
					systemImage: "tray",
					description: Text("用 ⌘⇧N 捕捉你的第一个闪念")
				)
			}

			if !unprocessedItems.isEmpty {
				Section("未处理 (\(unprocessedItems.count))") {
					ForEach(unprocessedItems) { item in
						InboxRowView(item: item)
							.tag(item)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
							.contextMenu {
								Button(role: .destructive) {
									if selectedItem == item { selectedItem = nil }
									modelContext.delete(item)
								} label: {
									Label("删除", systemImage: "trash")
								}
							}
					}
				}
			}
		}
		.navigationTitle("收件箱 Inbox")
		.navigationSplitViewColumnWidth(
			min:   ColumnWidth.min,
			ideal: ColumnWidth.ideal,
			max:   ColumnWidth.max
		)
		.onDeleteCommand {
			if let item = selectedItem {
				selectedItem = nil
				modelContext.delete(item)
			}
		}
	}
}

struct InboxRowView: View {
	var item: InboxItem

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Text(item.content)
				.lineLimit(2)
				.font(.system(size: 15, weight: .medium))

			HStack(spacing: 6) {
				Text(item.timestamp, style: .date)
					.font(.system(size: 12))
					.foregroundStyle(.secondary)

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

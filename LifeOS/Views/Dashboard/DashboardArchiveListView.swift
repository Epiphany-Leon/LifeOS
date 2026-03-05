//
//  DashboardArchiveListView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//
//  DashboardArchiveListView.swift

import SwiftUI
import SwiftData

struct DashboardArchiveListView: View {
	@EnvironmentObject private var appState: AppState
	@Query(sort: \DashboardSnapshot.monthKey, order: .reverse)
	private var snapshots: [DashboardSnapshot]

	@Binding var selectedSnapshot: DashboardSnapshot?

	var body: some View {
		List(selection: $selectedSnapshot) {
			// ✅ 当月实时 置顶，直接作为第一行
			Section {
				HStack(spacing: 12) {
					ZStack {
						RoundedRectangle(cornerRadius: 8)
							.fill(Color.accentColor.opacity(0.12))
							.frame(width: 36, height: 36)
						Image(systemName: "gauge.with.needle")
							.foregroundStyle(Color.accentColor)
							.font(.system(size: 15))
					}
					VStack(alignment: .leading, spacing: 2) {
						Text("当月实时")
							.font(.system(size: 15, weight: .semibold))
						Text(currentMonthKey)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}
				.padding(.vertical, 2)
				.tag(nil as DashboardSnapshot?)   // ✅ nil = 当月实时
				.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
			}

			// ✅ 有存档时才显示存档 Section
			if !snapshots.isEmpty {
				Section("存档") {
					ForEach(snapshots) { snap in
						SnapshotRowView(snap: snap)
							.tag(snap as DashboardSnapshot?)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
					}
				}
			}
		}
		.navigationTitle("Dashboard")
		.navigationSplitViewColumnWidth(
			min:   ColumnWidth.min,
			ideal: ColumnWidth.ideal,
			max:   ColumnWidth.max
		)
		.onAppear {
			// ✅ 默认选中当月实时
			if selectedSnapshot == nil { selectedSnapshot = nil }
		}
	}

	var currentMonthKey: String {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM"
		return f.string(from: Date())
	}
}

// MARK: - 存档行
struct SnapshotRowView: View {
	@EnvironmentObject private var appState: AppState
	var snap: DashboardSnapshot

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				RoundedRectangle(cornerRadius: 8)
					.fill(Color.gray.opacity(0.1))
					.frame(width: 36, height: 36)
				Text(String(snap.monthKey.suffix(2)))
					.font(.system(size: 13, weight: .bold))
					.foregroundStyle(.secondary)
			}
			VStack(alignment: .leading, spacing: 3) {
				Text(snap.monthKey)
					.font(.system(size: 15, weight: .semibold))
				HStack(spacing: 8) {
					Label("\(snap.doneTasks)", systemImage: "checkmark.circle")
						.font(.caption).foregroundStyle(.green)
					Label("\(snap.totalNotes)", systemImage: "book")
						.font(.caption).foregroundStyle(.blue)
					Label(
						"\(appState.selectedCurrencyCode.symbol)\(String(format: "%.0f", abs(snap.monthlyExpense)))",
						systemImage: "yensign.circle"
					)
					.font(.caption)
					.foregroundStyle(.orange)
				}
			}
			Spacer()
			Text(snap.createdAt, style: .date)
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 2)
	}
}

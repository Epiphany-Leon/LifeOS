//
//  DashboardArchiveListView.swift
//  NexaLife
//
//  v0.2.0 — Archives 模块（沿用 WorkspaceTheme 设计语言）
//

import SwiftUI
import SwiftData

struct DashboardArchiveListView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.locale) private var locale
	@Query(sort: \DashboardSnapshot.monthKey, order: .reverse)
	private var snapshots: [DashboardSnapshot]

	@Binding var selectedSnapshot: DashboardSnapshot?

	private var accent: Color { WorkspaceTheme.accent }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				header
				liveCard
				if !snapshots.isEmpty {
					archivedSection
				} else {
					emptyHint
				}
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 22)
		}
		.background(WorkspaceTheme.surface)
		.onAppear {
			if selectedSnapshot == nil { selectedSnapshot = nil }
		}
	}

	private var header: some View {
		WorkspaceSectionTitle(
			eyebrow: AppBrand.localized("仪表盘", "Dashboard", locale: locale),
			title: AppBrand.localized("月度存档", "Monthly Archives", locale: locale),
			subtitle: AppBrand.localized(
				"按月查看历史快照，回顾每个月的执行、知识、生活、觉知。",
				"Review monthly snapshots — Execution, Knowledge, Lifestyle, Vitals at a glance.",
				locale: locale
			),
			accent: accent
		)
	}

	private var liveCard: some View {
		Button {
			selectedSnapshot = nil
		} label: {
			WorkspaceSelectableCard(accent: accent, isSelected: selectedSnapshot == nil) {
				HStack(spacing: 14) {
					WorkspaceIconBadge(icon: AppModule.dashboard.icon, accent: accent, size: 38)
					VStack(alignment: .leading, spacing: 4) {
						Text(AppBrand.localized("当月实时", "Current Month · Live", locale: locale))
							.font(.system(size: 15, weight: .semibold))
							.foregroundStyle(WorkspaceTheme.strongText)
						Text(currentMonthKey)
							.font(.caption)
							.foregroundStyle(WorkspaceTheme.mutedText)
					}
					Spacer()
					WorkspacePill(title: "Live", accent: accent, isFilled: selectedSnapshot == nil)
				}
			}
		}
		.buttonStyle(.plain)
	}

	private var archivedSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 8) {
				Text(AppBrand.localized("存档", "Archived", locale: locale))
					.font(.system(size: 12, weight: .bold))
					.foregroundStyle(accent)
					.textCase(.uppercase)
					.tracking(0.6)
				Text("· \(snapshots.count)")
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
				Spacer()
			}

			LazyVStack(spacing: 10) {
				ForEach(snapshots) { snap in
					Button {
						selectedSnapshot = snap
					} label: {
						SnapshotRowView(snap: snap, isSelected: selectedSnapshot?.id == snap.id, locale: locale)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}

	private var emptyHint: some View {
		WorkspaceCard(accent: accent, padding: 22, cornerRadius: 22, shadowY: 4) {
			HStack(spacing: 14) {
				WorkspaceIconBadge(icon: "archivebox", accent: accent, size: 40)
				VStack(alignment: .leading, spacing: 4) {
					Text(AppBrand.localized("还没有月度存档", "No monthly snapshots yet", locale: locale))
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					Text(AppBrand.localized(
						"在 Dashboard 点击「存档本月」即可生成第一份。",
						"Click \u{201C}Archive month\u{201D} on the Dashboard to create your first.",
						locale: locale
					))
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
				}
				Spacer()
			}
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
	let snap: DashboardSnapshot
	let isSelected: Bool
	let locale: Locale

	private var accent: Color { WorkspaceTheme.accent }

	var body: some View {
		WorkspaceSelectableCard(accent: accent, isSelected: isSelected, cornerRadius: 18, padding: 14) {
			HStack(spacing: 14) {
				ZStack {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(accent.opacity(0.12))
						.frame(width: 40, height: 40)
					Text(String(snap.monthKey.suffix(2)))
						.font(.system(size: 14, weight: .bold, design: .rounded))
						.foregroundStyle(accent)
				}

				VStack(alignment: .leading, spacing: 6) {
					Text(snap.monthKey)
						.font(.system(size: 14, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					HStack(spacing: 6) {
						WorkspaceInlineStat(title: AppBrand.localized("已完成", "Done", locale: locale), value: "\(snap.doneTasks)", accent: WorkspaceTheme.moduleAccent(for: .execution))
						WorkspaceInlineStat(title: AppBrand.localized("笔记", "Notes", locale: locale), value: "\(snap.totalNotes)", accent: WorkspaceTheme.moduleAccent(for: .knowledge))
						WorkspaceInlineStat(
							title: AppBrand.localized("支出", "Spent", locale: locale),
							value: "\(appState.selectedCurrencyCode.symbol)\(String(format: "%.0f", abs(snap.monthlyExpense)))",
							accent: WorkspaceTheme.moduleAccent(for: .lifestyle)
						)
					}
				}

				Spacer()

				Text(snap.createdAt, style: .date)
					.font(.caption2)
					.foregroundStyle(WorkspaceTheme.mutedText)
			}
		}
	}
}

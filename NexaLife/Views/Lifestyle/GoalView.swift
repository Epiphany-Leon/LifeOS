//
//  GoalView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct GoalView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \Goal.startDate, order: .reverse) private var goals: [Goal]
	@Query(sort: \GoalMilestone.createdAt, order: .reverse) private var milestones: [GoalMilestone]
	@Query(sort: \GoalProgressEntry.recordedAt, order: .reverse) private var progressEntries: [GoalProgressEntry]

	@Binding var selectedGoal: Goal?
	@State private var showCompleted = false

	private let calendar = Calendar.current

	private var activeGoals: [Goal] { goals.filter { !$0.isCompleted } }
	private var completedGoals: [Goal] { goals.filter { $0.isCompleted } }

	private var milestoneStatsByGoal: [UUID: (completed: Int, total: Int)] {
		Dictionary(grouping: milestones, by: \.goalID).mapValues { grouped in
			(grouped.filter(\.isCompleted).count, grouped.count)
		}
	}

	private var overdueGoalsCount: Int {
		let startOfToday = calendar.startOfDay(for: Date())
		return activeGoals.filter { goal in
			guard let due = goal.dueDate else { return false }
			return due < startOfToday
		}.count
	}

	private var thisWeekCheckInCount: Int {
		guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
		return progressEntries.filter { $0.recordedAt >= startOfWeek }.count
	}

	private var averageProgress: Double {
		guard !activeGoals.isEmpty else { return 0 }
		return activeGoals.map(\.progress).reduce(0, +) / Double(activeGoals.count)
	}

	private var structuredTrackingCount: Int {
		goals.filter {
			!$0.measurement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
			!$0.nextActionHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}.count
	}

	private var milestoneCompletionRatioText: String {
		let total = milestones.count
		guard total > 0 else { return "0/0" }
		let completed = milestones.filter(\.isCompleted).count
		return "\(completed)/\(total)"
	}

	private var completedGoalCount: Int {
		completedGoals.count
	}

	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					LazyVGrid(
						columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 14)],
						alignment: .leading,
						spacing: 14
					) {
						WorkspaceMetricTile(
							title: "结构化跟踪",
							value: "\(structuredTrackingCount)",
							subtitle: "带有衡量方式或下一步提示的目标",
							icon: "checklist",
							accent: .blue
						)
						WorkspaceMetricTile(
							title: "完成目标",
							value: "\(completedGoalCount)",
							subtitle: "已进入完成状态的目标",
							icon: "checkmark.seal",
							accent: .green
						)
						WorkspaceMetricTile(
							title: "平均进度",
							value: String(format: "%.0f%%", averageProgress * 100),
							subtitle: "当前所有进行中目标的平均推进度",
							icon: "chart.line.uptrend.xyaxis",
							accent: .orange
						)
					}

					goalWorkspacePanels
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 18)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .nexaLifeLifestyleCreateGoal)) { _ in
			createGoal()
		}
	}

	private func createGoal() {
		let goal = Goal(title: "新目标")
		modelContext.insert(goal)
		selectedGoal = goal
	}

	private func isSelected(_ goal: Goal) -> Bool {
		selectedGoal?.id == goal.id
	}

	@ViewBuilder
	private var goalWorkspacePanels: some View {
		if goals.isEmpty {
			WorkspaceCard(accent: .blue, padding: 24, cornerRadius: 24, shadowY: 8) {
				ContentUnavailableView(
					"还没有目标",
					systemImage: "flag.checkered",
					description: Text("点击右上角新建目标后继续编辑")
				)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 28)
			}
		}

		if !activeGoals.isEmpty {
			WorkspaceCard(accent: .blue, padding: 20, cornerRadius: 24, shadowY: 8) {
				VStack(alignment: .leading, spacing: 14) {
					WorkspacePanelHeader(
						title: "Goals In Motion",
						subtitle: "当前推进中的目标",
						accent: .blue,
						icon: "flag.checkered",
						value: "\(activeGoals.count)"
					)

					LazyVGrid(
						columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 12)],
						alignment: .leading,
						spacing: 12
					) {
						ForEach(activeGoals) { goal in
							let stats = milestoneStatsByGoal[goal.id] ?? (0, 0)
							WorkspaceSelectableCard(accent: .blue, isSelected: isSelected(goal), cornerRadius: 18, padding: 14) {
								GoalRowView(
									goal: goal,
									milestoneCompleted: stats.completed,
									milestoneTotal: stats.total
								)
							}
							.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
							.onTapGesture {
								selectedGoal = goal
							}
						}
					}
				}
			}
		}

		if !completedGoals.isEmpty {
			WorkspaceCard(accent: .green, padding: 20, cornerRadius: 24, shadowY: 8) {
				VStack(alignment: .leading, spacing: 14) {
					HStack(alignment: .center) {
						WorkspacePanelHeader(
							title: "Completed",
							subtitle: "已经结束的目标归档",
							accent: .green,
							icon: "checkmark.seal",
							value: "\(completedGoals.count)"
						)
						Spacer(minLength: 0)
						WorkspaceActionButton(
							title: showCompleted ? "收起" : "展开",
							icon: showCompleted ? "chevron.up" : "chevron.down",
							accent: .green,
							isPrimary: false
						) {
							showCompleted.toggle()
						}
					}

					if showCompleted {
						LazyVGrid(
							columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 12)],
							alignment: .leading,
							spacing: 12
						) {
							ForEach(completedGoals) { goal in
								let stats = milestoneStatsByGoal[goal.id] ?? (0, 0)
								WorkspaceSelectableCard(accent: .green, isSelected: isSelected(goal), cornerRadius: 18, padding: 14) {
									GoalRowView(
										goal: goal,
										milestoneCompleted: stats.completed,
										milestoneTotal: stats.total
									)
								}
								.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
								.onTapGesture {
									selectedGoal = goal
								}
							}
						}
					}
				}
			}
		}
	}
}

// MARK: - 目标行
struct GoalRowView: View {
	var goal: Goal
	var milestoneCompleted: Int = 0
	var milestoneTotal: Int = 0

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text(goal.title)
					.font(.headline)
					.strikethrough(goal.isCompleted)
					.foregroundStyle(goal.isCompleted ? WorkspaceTheme.mutedText : WorkspaceTheme.strongText)
				Spacer()
				GoalRowStatusBadge(goal: goal)
			}
			GoalRowMetaBadges(goal: goal, milestoneCompleted: milestoneCompleted, milestoneTotal: milestoneTotal)
			GoalRowOptionalNotes(goal: goal)
			ProgressView(value: goal.progress, total: 1.0)
				.tint(goal.isCompleted ? .green : .blue)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

// Extracted to break the deep _ConditionalContent type chain
private struct GoalRowStatusBadge: View {
	let goal: Goal

	private var daysRemaining: Int? {
		guard let due = goal.dueDate, !goal.isCompleted else { return nil }
		return Calendar.current.dateComponents([.day], from: Date(), to: due).day
	}

	@ViewBuilder var body: some View {
		if goal.isCompleted {
			Label("已完成", systemImage: "checkmark.seal.fill")
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.green)
		} else if let days = daysRemaining {
			Text(days >= 0 ? "\(days)天后" : "已逾期")
				.font(.caption2.weight(.semibold))
				.padding(.horizontal, 7)
				.padding(.vertical, 3)
				.background((days >= 0 ? Color.secondary : Color.red).opacity(0.12))
				.foregroundStyle(days >= 0 ? Color.secondary : Color.red)
				.clipShape(Capsule())
		}
	}
}

private struct GoalRowMetaBadges: View {
	let goal: Goal
	let milestoneCompleted: Int
	let milestoneTotal: Int

	var body: some View {
		HStack(spacing: 8) {
			Text(goal.template.rawValue)
				.font(.caption2)
				.foregroundStyle(.blue)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(Color.blue.opacity(0.12))
				.clipShape(Capsule())
			Text(goal.trackingFrequency.rawValue)
				.font(.caption2)
				.foregroundStyle(.indigo)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(Color.indigo.opacity(0.12))
				.clipShape(Capsule())
			if milestoneTotal > 0 {
				Label(
					"小目标 \(milestoneCompleted)/\(milestoneTotal)",
					systemImage: "checklist"
				)
				.font(.caption2)
				.foregroundStyle(.secondary)
			}
			Text(String(format: "%.0f%%", goal.progress * 100))
				.font(.caption2)
				.foregroundStyle(.secondary)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(Color.secondary.opacity(0.12))
				.clipShape(Capsule())
		}
	}
}

private struct GoalRowOptionalNotes: View {
	let goal: Goal

	@ViewBuilder var body: some View {
		if !goal.targetDescription.isEmpty {
			Text(goal.targetDescription)
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
				.lineLimit(2)
		}
		if !goal.nextActionHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			Text("下一步：\(goal.nextActionHint)")
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
				.lineLimit(2)
		}
	}
}

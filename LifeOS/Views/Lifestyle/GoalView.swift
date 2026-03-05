//
//  GoalView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct GoalView: View {
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

	private var milestoneCompletionRatioText: String {
		let total = milestones.count
		guard total > 0 else { return "0/0" }
		let completed = milestones.filter(\.isCompleted).count
		return "\(completed)/\(total)"
	}

	var body: some View {
		VStack(spacing: 0) {
			header

			Divider()

			List(selection: $selectedGoal) {
				if goals.isEmpty {
					ContentUnavailableView(
						"还没有目标",
						systemImage: "flag.checkered",
						description: Text("点击右上角新建目标后，在右侧详情编辑")
					)
				}

				if !activeGoals.isEmpty {
					Section("进行中") {
						ForEach(activeGoals) { goal in
							let stats = milestoneStatsByGoal[goal.id] ?? (0, 0)
							GoalRowView(
								goal: goal,
								milestoneCompleted: stats.completed,
								milestoneTotal: stats.total
							)
							.tag(goal)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
						}
					}
				}

				if !completedGoals.isEmpty {
					Section {
						if showCompleted {
							ForEach(completedGoals) { goal in
								let stats = milestoneStatsByGoal[goal.id] ?? (0, 0)
								GoalRowView(
									goal: goal,
									milestoneCompleted: stats.completed,
									milestoneTotal: stats.total
								)
								.tag(goal)
								.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
							}
						}
					} header: {
						Button {
							withAnimation { showCompleted.toggle() }
						} label: {
							HStack {
								Text("已完成 (\(completedGoals.count))")
								Spacer()
								Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
									.font(.caption)
							}
							.foregroundStyle(.secondary)
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	private var header: some View {
		LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
			GoalMetricMiniCard(
				title: "进行中",
				value: "\(activeGoals.count)",
				subtitle: "总目标 \(goals.count)",
				color: .blue
			)
			GoalMetricMiniCard(
				title: "逾期",
				value: "\(overdueGoalsCount)",
				subtitle: "需优先处理",
				color: overdueGoalsCount > 0 ? .red : .secondary
			)
			GoalMetricMiniCard(
				title: "本周打卡",
				value: "\(thisWeekCheckInCount)",
				subtitle: "进度更新次数",
				color: .teal
			)
			GoalMetricMiniCard(
				title: "小目标完成",
				value: milestoneCompletionRatioText,
				subtitle: "已完成/总数",
				color: .green
			)
			GoalMetricMiniCard(
				title: "平均进度",
				value: String(format: "%.0f%%", averageProgress * 100),
				subtitle: "进行中目标",
				color: .orange
			)
			GoalMetricMiniCard(
				title: "已完成",
				value: "\(completedGoals.count)",
				subtitle: "阶段成果",
				color: .green
			)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(Color(nsColor: .windowBackgroundColor))
	}
}

private struct GoalMetricMiniCard: View {
	let title: String
	let value: String
	let subtitle: String
	let color: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(value)
				.font(.system(size: 20, weight: .bold))
				.foregroundStyle(color)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			Text(subtitle)
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(color.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}

// MARK: - 目标行
struct GoalRowView: View {
	var goal: Goal
	var milestoneCompleted: Int = 0
	var milestoneTotal: Int = 0

	private var daysRemaining: Int? {
		guard let due = goal.dueDate, !goal.isCompleted else { return nil }
		return Calendar.current.dateComponents([.day], from: Date(), to: due).day
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text(goal.title)
					.font(.headline)
					.strikethrough(goal.isCompleted)
					.foregroundStyle(goal.isCompleted ? Color.secondary : Color.primary)
				Spacer()
				if goal.isCompleted {
					Image(systemName: "checkmark.seal.fill")
						.foregroundStyle(.green)
				} else if let days = daysRemaining {
					Text(days >= 0 ? "\(days)天后" : "已逾期")
						.font(.caption)
						.foregroundStyle(days >= 0 ? Color.secondary : Color.red)
				}
			}

			HStack(spacing: 8) {
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

			if !goal.targetDescription.isEmpty {
				Text(goal.targetDescription)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			ProgressView(value: goal.progress, total: 1.0)
				.tint(goal.isCompleted ? .green : .blue)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

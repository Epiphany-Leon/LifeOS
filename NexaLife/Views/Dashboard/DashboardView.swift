//
//  DashboardView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//
//  DashboardView.swift

import SwiftUI
import SwiftData
struct DashboardView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.modelContext) private var modelContext
	@StateObject private var aiService = AIService()

	@Query private var tasks:        [TaskItem]
	@Query private var inboxItems:   [InboxItem]
	@Query private var notes:        [Note]
	@Query private var transactions: [Transaction]
	@Query private var goals:        [Goal]
	@Query private var connections:  [Connection]
	@Query private var vitals:       [VitalsEntry]
	@Query(sort: \GoalProgressEntry.recordedAt, order: .reverse)
	private var goalProgressEntries: [GoalProgressEntry]
	@Query(sort: \DailyReviewEntry.day, order: .reverse)
	private var dailyReviews: [DailyReviewEntry]
	@Query(sort: \DashboardSnapshot.monthKey, order: .reverse)
	private var snapshots: [DashboardSnapshot]

	@Binding var externalSnapshot: DashboardSnapshot?
	@State private var mentorSummary: ProfileGuidanceSummary?
	@State private var isRefreshingMentor = false
	@State private var activeDailyReview: DailyReviewEntry?
	@State private var mentorRefreshTask: Task<Void, Never>?
	private let calendar = Calendar.current
	private var displayCurrency: CurrencyCode { appState.selectedCurrencyCode }

	// MARK: - 当月 Key
	var currentMonthKey: String {
		monthKey(for: Date())
	}

	// MARK: - 实时统计
	var activeExecutionTasks: [TaskItem] { tasks.filter { $0.archivedMonthKey == nil } }
	var pendingTasks:     Int { activeExecutionTasks.filter { $0.status == .todo }.count }
	var inProgressTasks:  Int { activeExecutionTasks.filter { $0.status == .inProgress }.count }
	var doneTasks:        Int { activeExecutionTasks.filter { $0.status == .done }.count }
	var totalNotes:       Int { notes.count }
	var unprocessedInbox: Int { inboxItems.filter { !$0.isProcessed }.count }
	var activeGoals:      Int { goals.filter { !$0.isCompleted }.count }
	var totalConnections: Int { connections.count }
	var highPriorityConnections: Int {
		connections.filter { min(5, max(1, $0.importanceLevel)) >= 4 }.count
	}
	var followUpConnections: Int {
		let threshold = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
		return connections.filter { connection in
			guard let date = connection.lastContactDate else { return true }
			return date < threshold
		}.count
	}
	var totalExecutionCount: Int { pendingTasks + inProgressTasks + doneTasks }
	var completedTodayCount: Int {
		activeExecutionTasks.filter {
			guard let completedAt = $0.completedAt else { return false }
			return calendar.isDateInToday(completedAt)
		}.count
	}
	var recentDailyReview: DailyReviewEntry? { dailyReviews.first }
	var todayReview: DailyReviewEntry? {
		dailyReviews.first { calendar.isDateInToday($0.day) }
	}
	var mentorRefreshSignature: String {
		let progressMarker: String
		if let recordedAt = goalProgressEntries.first?.recordedAt {
			progressMarker = recordedAt.ISO8601Format()
		} else {
			progressMarker = "no-progress"
		}

		let reviewMarker: String
		if let updatedAt = dailyReviews.first?.updatedAt {
			reviewMarker = updatedAt.ISO8601Format()
		} else {
			reviewMarker = "no-review"
		}

		return "\(inboxItems.count)|\(tasks.count)|\(notes.count)|\(goals.count)|\(vitals.count)|\(connections.count)|\(dailyReviews.count)|\(progressMarker)|\(reviewMarker)"
	}

	var knowledgeTopicTags: [String] {
		let topics = notes.flatMap { note in
			let tags = KnowledgeTagCodec.parse(note.topic)
			return tags.isEmpty ? ["未分类"] : tags
		}
		return normalizedTagList(topics, fallback: "未分类")
	}

	var coreCodeTags: [String] {
		let entries = vitals
			.filter { $0.type == .coreCode }
			.map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		return normalizedTagList(entries, fallback: "暂无核心守则")
	}

	var monthlyExpense: Double {
		monthlyExpense(for: Date())
	}
	var monthlyIncome: Double {
		monthlyIncome(for: Date())
	}

	var lifestyleTags: [String] {
		[
			"\(CurrencyService.format(monthlyIncome, currency: displayCurrency, showSign: true)) 收入",
			"\(activeGoals) 目标",
			"\(totalConnections) 人脉",
			"高优先 \(highPriorityConnections)",
			"待跟进 \(followUpConnections)"
		]
	}

	var systemAlerts: [String] {
		var a: [String] = []
		if unprocessedInbox > 5 { a.append("收件箱有 \(unprocessedInbox) 条未处理") }
		let overdue = activeExecutionTasks.filter { $0.dueDate != nil && $0.dueDate! < Date() && !$0.isDone }.count
		if overdue > 0 { a.append("\(overdue) 个任务已逾期") }
		return a
	}

	var overdueTaskCount: Int {
		activeExecutionTasks.filter { task in
			guard let dueDate = task.dueDate else { return false }
			return dueDate < Date() && !task.isDone
		}.count
	}

	var dashboardDisplayName: String {
		let trimmed = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty
			? AppBrand.localized("朋友", "there", locale: appState.currentLocale)
			: trimmed
	}

	// ✅ 图表数据：String x 轴，避免 Date+unit API 问题
	struct ExpenseBar: Identifiable {
		let id:     Int
		let label:  String
		let amount: Double
	}

	var last7DaysExpenses: [ExpenseBar] {
		let formatter = DateFormatter()
		formatter.dateFormat = "M/d"
		return (0..<7).reversed().enumerated().compactMap { idx, daysAgo -> ExpenseBar? in
			guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
			let total = transactions
				.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.amount < 0 }
				.reduce(0) { partial, tx in
					partial + abs(amountInDisplayCurrency(tx))
				}
			return ExpenseBar(id: idx, label: formatter.string(from: date), amount: total)
		}
	}

	var maxExpenseAmount: Double {
		last7DaysExpenses.map(\.amount).max() ?? 0
	}

	// MARK: - 问候
	var greeting: String {
		switch Calendar.current.component(.hour, from: Date()) {
		case 0..<6:   return "凌晨好"
		case 6..<12:  return "早上好"
		case 12..<14: return "中午好"
		case 14..<18: return "下午好"
		default:      return "晚上好"
		}
	}

	var todayString: String {
		let f = DateFormatter()
		f.locale = Locale(identifier: "zh_CN")
		f.dateFormat = "yyyy年M月d日 EEEE"
		return f.string(from: Date())
	}

	// MARK: - Body
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 28) {
				if let snap = externalSnapshot {
					archivedSnapshotView(snap)
				} else {
					currentDashboardView
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(44)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.onAppear {
			removeLegacyEmptySnapshotsIfNeeded()
			runAutomaticMonthlyArchiveIfNeeded()
			ensureInitialMentorSummary()
		}
		.onDisappear {
			mentorRefreshTask?.cancel()
			mentorRefreshTask = nil
		}
		.sheet(item: $activeDailyReview) { review in
			DailyReviewEditorSheet(review: review)
		}
		.onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
			removeLegacyEmptySnapshotsIfNeeded()
			runAutomaticMonthlyArchiveIfNeeded()
		}
	}

	// MARK: - 当月实时视图
	private var currentDashboardView: some View {
		VStack(alignment: .leading, spacing: 28) {
			dashboardHeroCard

			HStack(alignment: .top, spacing: 18) {
				VStack(alignment: .leading, spacing: 18) {
					LazyVGrid(
						columns: [GridItem(.adaptive(minimum: 240, maximum: 400), spacing: 16)],
						alignment: .leading,
						spacing: 16
					) {
						moduleTagCard(
							title: "Execution",
							value: "\(pendingTasks + inProgressTasks)",
							icon: AppModule.execution.icon,
							color: WorkspaceTheme.moduleAccent(for: .execution),
							tags: [
								"待办 \(pendingTasks)",
								"推进中 \(inProgressTasks)",
								"已完成 \(doneTasks)",
								"今日完成 \(completedTodayCount)"
							]
						)

						moduleTagCard(
							title: "Knowledge",
							value: "\(totalNotes)",
							icon: AppModule.knowledge.icon,
							color: WorkspaceTheme.moduleAccent(for: .knowledge),
							tags: Array(knowledgeTopicTags.prefix(4))
						)

						moduleTagCard(
							title: "Lifestyle",
							value: CurrencyService.format(abs(monthlyExpense), currency: displayCurrency, showSign: false),
							icon: AppModule.lifestyle.icon,
							color: WorkspaceTheme.moduleAccent(for: .lifestyle),
							tags: [
								"收入 \(CurrencyService.format(monthlyIncome, currency: displayCurrency, showSign: false))",
								"目标 \(activeGoals)",
								"待跟进 \(followUpConnections)",
								"高优先 \(highPriorityConnections)"
							]
						)

						moduleTagCard(
							title: "Vitals",
							value: "\(vitals.count)",
							icon: AppModule.vitals.icon,
							color: WorkspaceTheme.moduleAccent(for: .vitals),
							tags: Array(coreCodeTags.prefix(4))
						)
					}

					dashboardStatusStrip

					HStack(alignment: .top, spacing: 16) {
						expenseTrendSection
						dashboardPulsePanel
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				VStack(alignment: .leading, spacing: 16) {
					dailyReviewSection
					mentorSection
				}
				.frame(minWidth: 280, maxWidth: 520)
			}
		}
	}

	// MARK: - 存档月份视图
	@ViewBuilder
	private func archivedSnapshotView(_ snap: DashboardSnapshot) -> some View {
		VStack(alignment: .leading, spacing: 28) {
			cardSurface(accent: .indigo, padding: 26) {
				HStack(alignment: .top, spacing: 18) {
					VStack(alignment: .leading, spacing: 8) {
						Text("\(snap.monthKey) 月度存档")
							.font(.system(size: 30, weight: .bold))
						Text("存档于 " + AppDateFormatter.ymd(snap.createdAt))
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}

					Spacer(minLength: 24)

					dashboardActionChip(
						title: "返回当月",
						accent: .indigo
					) {
						externalSnapshot = nil
					}
				}
			}

			LazyVGrid(
				columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)],
				alignment: .leading,
				spacing: 16
			) {
				moduleTagCard(
					title: "Execution",
					value: "\(snap.pendingTasks + snap.doneTasks)",
					icon: AppModule.execution.icon,
					color: .orange,
					tags: [
						"待办 \(snap.pendingTasks)",
						"已完成 \(snap.doneTasks)"
					]
				)

				moduleTagCard(
					title: "Knowledge",
					value: "\(snap.totalNotes)",
					icon: AppModule.knowledge.icon,
					color: .teal,
					tags: ["月度知识沉淀", "归档已冻结"]
				)

				moduleTagCard(
					title: "Lifestyle",
					value: CurrencyService.format(abs(snap.monthlyExpense), currency: displayCurrency, showSign: false),
					icon: AppModule.lifestyle.icon,
					color: .green,
					tags: [
						"收入 \(CurrencyService.format(snap.monthlyIncome, currency: displayCurrency, showSign: false))",
						"目标 \(snap.activeGoals)"
					]
				)

				moduleTagCard(
					title: "Vitals",
					value: "\(snap.vitalsCount)",
					icon: AppModule.vitals.icon,
					color: .pink,
					tags: ["觉知记录", "历史存档"]
				)
			}

			if !snap.summary.isEmpty {
				cardSurface(accent: .secondary, padding: 24) {
					VStack(alignment: .leading, spacing: 12) {
						Text("月度总结")
							.font(.title3.bold())
						Text(snap.summary)
							.font(.body)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
	}

	// MARK: - 存档操作
	private func archiveCurrentMonth() {
		let now = Date()
		archiveMonthIfNeeded(monthDate: now, archiveDoneTasks: true, includeLegacyDoneFallback: false)
	}

	private func runAutomaticMonthlyArchiveIfNeeded() {
		guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart(for: Date())) else {
			return
		}
		archiveMonthIfNeeded(monthDate: previousMonth, archiveDoneTasks: true, includeLegacyDoneFallback: true)
	}

	private func removeLegacyEmptySnapshotsIfNeeded() {
		for snapshot in snapshots where isEmptySnapshot(snapshot) {
			modelContext.delete(snapshot)
		}
	}

	private func archiveMonthIfNeeded(
		monthDate: Date,
		archiveDoneTasks: Bool,
		includeLegacyDoneFallback: Bool
	) {
		let targetMonthKey = monthKey(for: monthDate)
		guard !snapshots.contains(where: { $0.monthKey == targetMonthKey }) else { return }
		guard let monthRange = calendar.dateInterval(of: .month, for: monthDate) else { return }
		let monthEnd = monthRange.end

		let pendingCount = activeExecutionTasks.filter { task in
			task.status != .done && task.createdAt < monthEnd
		}.count

		let doneToArchive = activeExecutionTasks.filter { task in
			guard task.status == .done else { return false }
			if let completedAt = task.completedAt {
				return calendar.isDate(completedAt, equalTo: monthDate, toGranularity: .month)
			}
			if includeLegacyDoneFallback {
				return task.createdAt < monthEnd
			}
			return calendar.isDate(task.createdAt, equalTo: monthDate, toGranularity: .month)
		}

		let notesCount = notes.filter { $0.createdAt < monthEnd }.count
		let income = monthlyIncome(for: monthDate)
		let expense = monthlyExpense(for: monthDate)
		let activeGoalsCount = goals.filter { $0.startDate < monthEnd && !$0.isCompleted }.count
		let vitalsCount = vitals.filter { $0.timestamp < monthEnd }.count

		let hasMeaningfulContent =
			pendingCount > 0 ||
			!doneToArchive.isEmpty ||
			notesCount > 0 ||
			income != 0 ||
			expense != 0 ||
			activeGoalsCount > 0 ||
			vitalsCount > 0
		guard hasMeaningfulContent else { return }

		let snap = DashboardSnapshot(
			monthKey: targetMonthKey,
			pendingTasks: pendingCount,
			doneTasks: doneToArchive.count,
			totalNotes: notesCount,
			monthlyIncome: income,
			monthlyExpense: expense,
			activeGoals: activeGoalsCount,
			vitalsCount: vitalsCount
		)
		modelContext.insert(snap)

		if archiveDoneTasks {
			for task in doneToArchive {
				task.archivedMonthKey = targetMonthKey
			}
		}
	}

	private func monthlyExpense(for monthDate: Date) -> Double {
		transactions
			.filter {
				calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) && $0.amount < 0
			}
			.reduce(0) { partial, tx in
				partial + amountInDisplayCurrency(tx)
			}
	}

	private func monthlyIncome(for monthDate: Date) -> Double {
		transactions
			.filter {
				calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) && $0.amount > 0
			}
			.reduce(0) { partial, tx in
				partial + amountInDisplayCurrency(tx)
			}
	}

	private func amountInDisplayCurrency(_ tx: Transaction) -> Double {
		let source = CurrencyCode(rawValue: tx.currencyCode) ?? .CNY
		return CurrencyService.convert(tx.amount, from: source, to: displayCurrency)
	}

	private func monthStart(for date: Date) -> Date {
		calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
	}

	private func monthKey(for date: Date) -> String {
		let formatter = DateFormatter()
		formatter.calendar = calendar
		formatter.dateFormat = "yyyy-MM"
		return formatter.string(from: date)
	}

	private func normalizedTagList(_ values: [String], fallback: String) -> [String] {
		var seen: Set<String> = []
		var tags: [String] = []
		for value in values {
			let normalized = value
				.replacingOccurrences(of: "\n", with: " ")
				.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !normalized.isEmpty else { continue }
			let display = normalized.count > 14 ? String(normalized.prefix(14)) + "…" : normalized
			guard !seen.contains(display) else { continue }
			seen.insert(display)
			tags.append(display)
		}
		if tags.isEmpty { return [fallback] }
		return Array(tags.prefix(6))
	}

	private func isEmptySnapshot(_ snapshot: DashboardSnapshot) -> Bool {
		let hasSummary = !snapshot.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		return
			snapshot.pendingTasks == 0 &&
			snapshot.doneTasks == 0 &&
			snapshot.totalNotes == 0 &&
			snapshot.monthlyIncome == 0 &&
			snapshot.monthlyExpense == 0 &&
			snapshot.activeGoals == 0 &&
			snapshot.vitalsCount == 0 &&
			!hasSummary
	}

	private func moduleTagCard(
		title: String,
		value: String,
		icon: String,
		color: Color,
		tags: [String]
	) -> some View {
		cardSurface(accent: color, padding: 22) {
			VStack(alignment: .leading, spacing: 18) {
				HStack(alignment: .center, spacing: 12) {
					WorkspaceIconBadge(icon: icon, accent: color, size: 40)

					VStack(alignment: .leading, spacing: 2) {
						Text(title)
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(WorkspaceTheme.strongText)
						Text("本月实时")
							.font(.caption)
							.foregroundStyle(WorkspaceTheme.mutedText)
					}

					Spacer(minLength: 0)
				}

				Text(value)
					.font(.system(size: 30, weight: .bold, design: .rounded))
					.foregroundStyle(WorkspaceTheme.strongText)

				if !tags.isEmpty {
					FlexibleTagWrap(tags: tags, color: color)
				}
			}
		}
	}

	private var dashboardHeroCard: some View {
		cardSurface(accent: WorkspaceTheme.accent, padding: 28) {
			VStack(alignment: .leading, spacing: 22) {
				HStack(alignment: .top, spacing: 20) {
					VStack(alignment: .leading, spacing: 10) {
						Text("\(greeting)，\(dashboardDisplayName)")
							.font(.system(size: 40, weight: .bold, design: .rounded))
							.foregroundStyle(WorkspaceTheme.strongText)
						Text(todayString)
							.font(.title3)
							.foregroundStyle(WorkspaceTheme.mutedText)
						Text(mentorSummary?.headline ?? "系统会持续把你的输入压缩成更清楚的方向感。")
							.font(.body)
							.foregroundStyle(WorkspaceTheme.mutedText)
							.lineLimit(3)
					}

					Spacer(minLength: 24)

					VStack(alignment: .trailing, spacing: 10) {
						dashboardActionChip(
							title: "存档本月",
							accent: WorkspaceTheme.accent
						) {
							archiveCurrentMonth()
						}

						HStack(spacing: 8) {
							compactMetricPill(
								icon: "tray.and.arrow.down",
								title: "待处理",
								value: "\(unprocessedInbox)",
								accent: .blue
							)
							compactMetricPill(
								icon: "checkmark.circle",
								title: "今日完成",
								value: "\(completedTodayCount)",
								accent: .green
							)
						}
					}
				}

				HStack(alignment: .center, spacing: 12) {
					snapshotPill(
						title: "当月实时",
						subtitle: currentMonthKey,
						detail: "Live",
						isSelected: externalSnapshot == nil,
						accent: WorkspaceTheme.accent
					) {
						externalSnapshot = nil
					}

					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 10) {
							ForEach(Array(snapshots.prefix(6))) { snapshot in
								snapshotPill(
									title: snapshot.monthKey,
									subtitle: "月度归档",
									detail: "\(snapshot.pendingTasks) 待办 / \(snapshot.doneTasks) 完成",
									isSelected: externalSnapshot?.id == snapshot.id,
									accent: WorkspaceTheme.accent
								) {
									externalSnapshot = snapshot
								}
							}
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
		}
	}

	private var dashboardStatusStrip: some View {
		cardSurface(accent: .blue, padding: 20) {
			VStack(alignment: .leading, spacing: 14) {
				HStack {
					Text("Inbox 状态与当前焦点")
						.font(.headline)
						.foregroundStyle(WorkspaceTheme.strongText)
					Spacer()
					WorkspacePill(title: "Quick Capture", icon: "square.and.pencil", accent: .blue)
				}

				HStack(spacing: 10) {
					WorkspaceInlineStat(title: "未处理", value: "\(unprocessedInbox)", accent: .blue)
					WorkspaceInlineStat(title: "逾期待办", value: "\(overdueTaskCount)", accent: .orange)
					WorkspaceInlineStat(title: "活跃目标", value: "\(activeGoals)", accent: .green)
					WorkspaceInlineStat(title: "高优先人脉", value: "\(highPriorityConnections)", accent: .pink)
				}

				Text(
					systemAlerts.first
					?? "你的当月驾驶舱维持在单一画布里，模块卡片用来给出最核心的状态变化。"
				)
				.font(.subheadline)
				.foregroundStyle(WorkspaceTheme.mutedText)
			}
		}
	}

	private var dashboardPulsePanel: some View {
		cardSurface(accent: .blue, padding: 24) {
			VStack(alignment: .leading, spacing: 16) {
				Text("系统脉冲")
					.font(.title3.bold())
					.foregroundStyle(WorkspaceTheme.strongText)

				LazyVGrid(
					columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
					alignment: .leading,
					spacing: 12
				) {
					pulseRow(
						icon: "tray.full",
						title: "收件箱待处理",
						value: "\(unprocessedInbox)",
						accent: .blue
					)
					pulseRow(
						icon: "target",
						title: "逾期待办",
						value: "\(overdueTaskCount)",
						accent: .orange
					)
					pulseRow(
						icon: "flag.2.crossed",
						title: "活跃目标",
						value: "\(activeGoals)",
						accent: .green
					)
					pulseRow(
						icon: "person.2",
						title: "待跟进人脉",
						value: "\(followUpConnections)",
						accent: .pink
					)
				}

				if !systemAlerts.isEmpty {
					Rectangle()
						.fill(WorkspaceTheme.divider)
						.frame(height: 1)

					VStack(alignment: .leading, spacing: 10) {
						ForEach(systemAlerts, id: \.self) { alert in
							HStack(alignment: .top, spacing: 10) {
								Image(systemName: "exclamationmark.circle.fill")
									.font(.system(size: 12, weight: .semibold))
									.foregroundStyle(.orange)
									.padding(.top, 2)
								Text(alert)
									.font(.subheadline)
									.foregroundStyle(.secondary)
									.fixedSize(horizontal: false, vertical: true)
							}
						}
					}
				}
			}
		}
	}

	private func cardSurface<Content: View>(
		accent: Color,
		padding: CGFloat = 20,
		@ViewBuilder content: () -> Content
	) -> some View {
		WorkspaceCard(accent: accent, padding: padding, cornerRadius: 24, shadowY: 10) {
			content()
		}
	}

	private func compactMetricPill(icon: String, title: String, value: String, accent: Color) -> some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(accent)
			Text(title)
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
			Text(value)
				.font(.caption.weight(.semibold))
				.foregroundStyle(WorkspaceTheme.strongText)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(WorkspaceTheme.elevatedSurface)
		.overlay(
			Capsule()
				.stroke(accent.opacity(0.18), lineWidth: 1)
		)
		.clipShape(Capsule())
	}

	private func snapshotPill(
		title: String,
		subtitle: String,
		detail: String,
		isSelected: Bool,
		accent: Color,
		action: @escaping () -> Void
	) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(isSelected ? Color.white : WorkspaceTheme.strongText)
			Text(subtitle)
				.font(.caption)
				.foregroundStyle(isSelected ? Color.white.opacity(0.82) : WorkspaceTheme.mutedText)
			Text(detail)
				.font(.caption2.weight(.medium))
				.foregroundStyle(isSelected ? Color.white.opacity(0.76) : WorkspaceTheme.mutedText)
		}
		.frame(width: isSelected ? 176 : 166, alignment: .leading)
		.frame(minHeight: 88, alignment: .leading)
		.padding(.horizontal, 14)
		.padding(.vertical, 14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(isSelected ? accent : WorkspaceTheme.elevatedSurface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.stroke(isSelected ? accent : WorkspaceTheme.border, lineWidth: 1)
		)
		.contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
		.onTapGesture(perform: action)
		.accessibilityAddTraits(.isButton)
	}

	private func pulseRow(icon: String, title: String, value: String, accent: Color) -> some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(accent.opacity(0.10))
					.frame(width: 32, height: 32)
				Image(systemName: icon)
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(accent)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline.weight(.medium))
				Text(value)
					.font(.system(size: 19, weight: .bold, design: .rounded))
					.foregroundStyle(accent)
			}

			Spacer(minLength: 0)
		}
	}

	private var mentorSection: some View {
		cardSurface(accent: .blue, padding: 22) {
			VStack(alignment: .leading, spacing: 16) {
				HStack(alignment: .center) {
					VStack(alignment: .leading, spacing: 4) {
						Text("AI Mentor")
							.font(.title3.bold())
							.foregroundStyle(WorkspaceTheme.strongText)
						Text(appState.selectedProfileGuidanceMode == .exploratory
							 ? "识别你最近的投入模式，并给出下一阶段的微行动建议。"
						 : "围绕你已有的方向，帮助你压缩主线、推进执行并持续复盘。")
						.font(.subheadline)
						.foregroundStyle(WorkspaceTheme.mutedText)
					}
					Spacer()
					dashboardActionChip(
						title: isRefreshingMentor ? "分析中…" : "刷新分析",
						accent: .blue,
						isDisabled: isRefreshingMentor
					) {
						mentorRefreshTask?.cancel()
					mentorRefreshTask = Task { await refreshMentorSummary(force: true) }
					}
				}

				Text(mentorSummary?.headline ?? "系统正在根据你的任务、笔记、目标与复盘记录，整理最近的成长轨迹。")
					.font(.headline)
					.foregroundStyle(WorkspaceTheme.strongText)
					.frame(maxWidth: .infinity, alignment: .leading)

				VStack(spacing: 12) {
					HStack(alignment: .top, spacing: 12) {
						mentorInsightBlock(
							title: "你正在形成的优势",
							items: mentorSummary?.strengths ?? [
								"继续记录你的推进结果，优势会更容易被识别。"
							],
							color: .blue
						)
						mentorInsightBlock(
							title: "最近出现的模式",
							items: mentorSummary?.patterns ?? [
								"系统会从完成节奏、卡点和情绪变化中识别重复模式。"
							],
							color: .orange
						)
					}

					HStack(alignment: .top, spacing: 12) {
						mentorInsightBlock(
							title: "下一阶段怎么做",
							items: mentorSummary?.nextSteps ?? [
								"先补齐一条 Daily Review，再让 AI 给你更细的引导。"
							],
							color: .purple
						)
						mentorInsightBlock(
							title: "使用提醒",
							items: [mentorSummary?.caution ?? "AI 的判断是阶段性假设，不是对你的身份定义。"],
							color: .secondary
						)
					}
				}
			}
		}
	}

	private var dailyReviewSection: some View {
		cardSurface(accent: .purple, padding: 22) {
			VStack(alignment: .leading, spacing: 16) {
			HStack(alignment: .center) {
				VStack(alignment: .leading, spacing: 4) {
					Text("Nightly Review")
						.font(.title3.bold())
						.foregroundStyle(WorkspaceTheme.strongText)
					Text("记录当下，识别模式，获得下一阶段的引导。")
						.font(.subheadline)
						.foregroundStyle(WorkspaceTheme.mutedText)
				}
				Spacer()
				dashboardActionChip(
					title: todayReview == nil ? "开始今晚复盘" : "继续今晚复盘",
					accent: .purple
				) {
					openTodayReview()
				}
			}

			HStack(spacing: 10) {
				scoreChip(
					title: "能量",
					value: todayReview?.energyScore ?? recentDailyReview?.energyScore ?? 3,
					color: .orange
				)
				scoreChip(
					title: "清晰度",
					value: todayReview?.clarityScore ?? recentDailyReview?.clarityScore ?? 3,
					color: .blue
				)
				scoreChip(
					title: "今日完成",
					value: max(completedTodayCount, 1),
					color: .green,
					maximum: max(completedTodayCount, 5)
				)
			}

			if let review = recentDailyReview {
					HStack(alignment: .top, spacing: 12) {
						mentorInsightBlock(
							title: "今天做成了什么",
							items: [compactSnippet(review.wins, fallback: "你已经完成了今天的记录。")],
							color: .green
						)
						mentorInsightBlock(
							title: "明天只推进什么",
							items: [compactSnippet(review.tomorrowPlan, fallback: "把明天的动作压缩成一个最小步骤。")],
							color: .purple
						)
					}

				if !review.aiGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					VStack(alignment: .leading, spacing: 8) {
						Text("AI 已识别出的下一步引导")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(.purple)
						Text(review.aiGuidance)
							.frame(maxWidth: .infinity, alignment: .leading)
							.padding(14)
							.background(Color.purple.opacity(0.08))
							.clipShape(RoundedRectangle(cornerRadius: 14))
					}
				}
			} else {
				Text("每天晚些时候补一条复盘，系统才会逐渐看清你的节奏、强项和卡点。")
					.font(.subheadline)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.padding(16)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(WorkspaceTheme.elevatedSurface)
					.clipShape(RoundedRectangle(cornerRadius: 14))
			}
		}
		}
	}

	private func dashboardActionChip(
		title: String,
		accent: Color,
		isDisabled: Bool = false,
		action: @escaping () -> Void
	) -> some View {
		Text(title)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(isDisabled ? Color.secondary : Color.white)
			.padding(.horizontal, 14)
			.padding(.vertical, 9)
			.background(
				Capsule()
					.fill(isDisabled ? Color.secondary.opacity(0.12) : accent)
			)
			.contentShape(Capsule())
			.opacity(isDisabled ? 0.72 : 1)
			.onTapGesture {
				guard !isDisabled else { return }
				action()
			}
			.accessibilityAddTraits(.isButton)
	}

	private var expenseTrendSection: some View {
		cardSurface(accent: .green, padding: 24) {
			VStack(alignment: .leading, spacing: 12) {
				Text("近 7 天支出")
					.font(.title3.bold())
					.foregroundStyle(WorkspaceTheme.strongText)

				if last7DaysExpenses.allSatisfy({ $0.amount == 0 }) {
					RoundedRectangle(cornerRadius: 16)
						.fill(WorkspaceTheme.elevatedSurface)
						.frame(height: 170)
						.overlay(
							Text("暂无支出数据")
								.foregroundStyle(WorkspaceTheme.mutedText)
						)
				} else {
					VStack(spacing: 12) {
						ForEach(last7DaysExpenses) { bar in
							HStack(spacing: 12) {
								Text(bar.label)
									.font(.caption.monospacedDigit())
									.foregroundStyle(WorkspaceTheme.mutedText)
									.frame(width: 36, alignment: .leading)

								ZStack(alignment: .leading) {
									Capsule()
										.fill(Color.gray.opacity(0.10))
										.frame(height: 10)
									Capsule()
										.fill(Color.green.gradient)
										.frame(
											width: max(
												12,
												220 * CGFloat(bar.amount / max(maxExpenseAmount, 1))
											),
											height: 10
										)
								}
								.frame(width: 220, alignment: .leading)

								Text(
									CurrencyService.format(
										bar.amount,
										currency: displayCurrency,
										showSign: false
									)
								)
								.font(.caption.monospacedDigit())
								.foregroundStyle(WorkspaceTheme.mutedText)
								.frame(width: 96, alignment: .trailing)
							}
						}
					}
					.padding(16)
					.background(WorkspaceTheme.elevatedSurface)
					.clipShape(RoundedRectangle(cornerRadius: 16))
				}
			}
		}
	}

	@MainActor
	private func refreshMentorSummary(force: Bool = false) async {
		if isRefreshingMentor { return }
		if mentorSummary != nil && !force { return }
		isRefreshingMentor = true
		defer { isRefreshingMentor = false }

		let summary = await aiService.generateProfileGuidance(
			context: ProfileGuidanceContext(
				guidanceMode: appState.selectedProfileGuidanceMode,
				inboxItems: inboxItems,
				tasks: tasks,
				notes: notes,
				goals: goals,
				goalProgressEntries: goalProgressEntries,
				vitals: vitals,
				connections: connections,
				dailyReviews: dailyReviews
			)
		)
		guard !Task.isCancelled else { return }
		mentorSummary = summary
	}

	@MainActor
	private func ensureInitialMentorSummary() {
		guard mentorSummary == nil, externalSnapshot == nil else { return }
		mentorSummary = ProfileGuidanceEngine.fallbackSummary(
			context: ProfileGuidanceContext(
				guidanceMode: appState.selectedProfileGuidanceMode,
				inboxItems: inboxItems,
				tasks: tasks,
				notes: notes,
				goals: goals,
				goalProgressEntries: goalProgressEntries,
				vitals: vitals,
				connections: connections,
				dailyReviews: dailyReviews
			),
			locale: appState.currentLocale
		)
	}

	private func openTodayReview() {
		if let todayReview {
			activeDailyReview = todayReview
			return
		}

		let review = DailyReviewEntry(day: .now)
		modelContext.insert(review)
		activeDailyReview = review
	}

	private func mentorInsightBlock(title: String, items: [String], color: Color) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(title)
				.font(.subheadline.bold())
				.foregroundStyle(color)
					VStack(alignment: .leading, spacing: 8) {
						ForEach(Array(items.enumerated()), id: \.offset) { _, item in
							HStack(alignment: .top, spacing: 8) {
								Circle()
									.fill(color)
								.frame(width: 6, height: 6)
								.padding(.top, 6)
							Text(item)
							.font(.subheadline)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.padding(16)
		.background(color.opacity(0.08))
		.clipShape(RoundedRectangle(cornerRadius: 16))
	}

	private func scoreChip(title: String, value: Int, color: Color, maximum: Int = 5) -> some View {
		HStack(spacing: 8) {
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text("\(value)/\(maximum)")
				.font(.subheadline.bold())
				.foregroundStyle(color)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(color.opacity(0.12))
		.clipShape(Capsule())
	}

	private func compactSnippet(_ text: String, fallback: String) -> String {
		let trimmed = text
			.replacingOccurrences(of: "\n", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return fallback }
		return trimmed.count > 70 ? String(trimmed.prefix(70)) + "…" : trimmed
	}
}

private struct FlexibleTagWrap: View {
	var tags: [String]
	var color: Color

	private var rows: [[String]] {
		let limited = Array(tags.prefix(6))
		guard !limited.isEmpty else { return [] }

		var result: [[String]] = []
		var index = 0
		while index < limited.count {
			let end = min(index + 3, limited.count)
			result.append(Array(limited[index..<end]))
			index = end
		}
		return result
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
				HStack(spacing: 8) {
					ForEach(Array(row.enumerated()), id: \.offset) { _, tag in
						Text(tag)
							.font(.caption)
							.padding(.horizontal, 10)
							.padding(.vertical, 4)
							.background(color.opacity(0.12))
							.foregroundStyle(color)
							.clipShape(Capsule())
					}
					Spacer(minLength: 0)
				}
				.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

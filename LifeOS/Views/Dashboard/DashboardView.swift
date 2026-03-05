//
//  DashboardView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//
//  DashboardView.swift

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.modelContext) private var modelContext

	@Query private var tasks:        [TaskItem]
	@Query private var inboxItems:   [InboxItem]
	@Query private var notes:        [Note]
	@Query private var transactions: [Transaction]
	@Query private var goals:        [Goal]
	@Query private var connections:  [Connection]
	@Query private var vitals:       [VitalsEntry]
	@Query(sort: \DashboardSnapshot.monthKey, order: .reverse)
	private var snapshots: [DashboardSnapshot]

	@Binding var externalSnapshot: DashboardSnapshot?
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
			.padding(44)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.onAppear {
			runAutomaticMonthlyArchiveIfNeeded()
		}
		.onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
			runAutomaticMonthlyArchiveIfNeeded()
		}
	}

	// MARK: - 当月实时视图
	private var currentDashboardView: some View {
		VStack(alignment: .leading, spacing: 28) {

			// 问候区
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 6) {
					Text("\(greeting)，\(appState.userName) 👋")
						.font(.system(size: 38, weight: .bold))
					Text(todayString)
						.font(.title3)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button {
					archiveCurrentMonth()
				} label: {
					Label("存档本月", systemImage: "archivebox")
				}
				.buttonStyle(.bordered)
				.help("将本月数据存档，开启新仪表盘")
			}

			// ✅ 四象限卡片 — 使用正确签名 title:value:subtitle:icon:color:
			LazyVGrid(
				columns: [GridItem(.flexible()), GridItem(.flexible())],
				spacing: 18
			) {
				moduleTagCard(
					title: "执行 Execution",
					value: "\(totalExecutionCount) 条任务",
					icon: "target",
					color: .orange,
					tags: [
						"待办 \(pendingTasks)",
						"进行中 \(inProgressTasks)",
						"已完成 \(doneTasks)"
					]
				)
				moduleTagCard(
					title: "知识 Knowledge",
					value: "\(totalNotes) 笔记",
					icon: "book.fill",
					color: .blue,
					tags: knowledgeTopicTags
				)
				moduleTagCard(
					title: "生活 Lifestyle",
					value: "\(CurrencyService.format(abs(monthlyExpense), currency: displayCurrency, showSign: false)) 支出",
					icon: "cup.and.saucer.fill",
					color: .green,
					tags: lifestyleTags
				)
				moduleTagCard(
					title: "觉知 Vitals",
					value: "\(coreCodeTags.filter { $0 != "暂无核心守则" }.count) 核心守则",
					icon: "sparkles",
					color: .purple,
					tags: coreCodeTags
				)
			}

			// 收件箱状态
			HStack(spacing: 16) {
				Label("\(unprocessedInbox) 条未处理", systemImage: "tray.and.arrow.down")
					.foregroundStyle(unprocessedInbox > 0 ? Color.orange : Color.secondary)
				Divider().frame(height: 16)
				Label("\(inboxItems.count) 条总计", systemImage: "tray.fill")
					.foregroundStyle(.secondary)
			}
			.font(.subheadline)
			.padding(14)
			.background(Color(nsColor: .controlBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 10))

			// System Alert
			if !systemAlerts.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					Label("系统提醒", systemImage: "bell.badge.fill")
						.font(.title3.bold())
						.foregroundStyle(.orange)
					ForEach(systemAlerts, id: \.self) { alert in
						HStack(spacing: 10) {
							Image(systemName: "exclamationmark.circle.fill")
								.foregroundStyle(.orange)
							Text(alert).font(.subheadline)
						}
						.padding(12)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(Color.orange.opacity(0.08))
						.clipShape(RoundedRectangle(cornerRadius: 10))
					}
				}
			}

			// 近7天支出图表
			VStack(alignment: .leading, spacing: 12) {
				Label("近 7 天支出", systemImage: "chart.bar.fill")
					.font(.title3.bold())

				if last7DaysExpenses.allSatisfy({ $0.amount == 0 }) {
					RoundedRectangle(cornerRadius: 16)
						.fill(Color.gray.opacity(0.07))
						.frame(height: 160)
						.overlay(
							Label("暂无支出数据", systemImage: "chart.bar")
								.foregroundStyle(.secondary)
						)
				} else {
					Chart {
						ForEach(last7DaysExpenses) { bar in
							BarMark(
								x: .value("日期", bar.label),
								y: .value("支出", bar.amount)
							)
							.foregroundStyle(Color.green.gradient)
						}
					}
					.chartXAxis {
						AxisMarks { _ in AxisValueLabel() }
					}
					.chartYAxis {
						AxisMarks { _ in
							AxisValueLabel()
							AxisGridLine()
						}
					}
					.frame(height: 160)
					.padding(16)
					.background(Color(nsColor: .controlBackgroundColor))
					.clipShape(RoundedRectangle(cornerRadius: 16))
				}
			}

			// 目标进度
			if !goals.filter({ !$0.isCompleted }).isEmpty {
				VStack(alignment: .leading, spacing: 12) {
					Label("目标进度", systemImage: "flag.checkered")
						.font(.title3.bold())
					ForEach(goals.filter { !$0.isCompleted }.prefix(3)) { goal in
						HStack(spacing: 12) {
							VStack(alignment: .leading, spacing: 4) {
								Text(goal.title)
									.font(.subheadline.bold())
									.lineLimit(1)
								ProgressView(value: goal.progress).tint(.blue)
							}
							Text(String(format: "%.0f%%", goal.progress * 100))
								.font(.subheadline.bold())
								.foregroundStyle(.blue)
								.frame(width: 40, alignment: .trailing)
						}
						.padding(12)
						.background(Color(nsColor: .controlBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 10))
					}
				}
			}
		}
	}

	// MARK: - 存档月份视图
	@ViewBuilder
	private func archivedSnapshotView(_ snap: DashboardSnapshot) -> some View {
		VStack(alignment: .leading, spacing: 28) {

			HStack {
				VStack(alignment: .leading, spacing: 4) {
					Text("\(snap.monthKey) 月度存档")
						.font(.system(size: 32, weight: .bold))
					Text("存档于 " + snap.createdAt.formatted(date: .long, time: .shortened))
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Button { externalSnapshot = nil } label: {
					Label("返回当月", systemImage: "arrow.uturn.left")
				}
				.buttonStyle(.bordered)
			}

			// ✅ 存档卡片 — 同样使用正确签名
			LazyVGrid(
				columns: [GridItem(.flexible()), GridItem(.flexible())],
				spacing: 18
			) {
				DashboardCard(
					title:    "执行 Execution",
					value:    "\(snap.pendingTasks) 待办",
					subtitle: "\(snap.doneTasks) 已完成",
					icon:     "target",
					color:    .orange
				)
				DashboardCard(
					title:    "知识 Knowledge",
					value:    "\(snap.totalNotes) 笔记",
					subtitle: "知识库快照",
					icon:     "book.fill",
					color:    .blue
				)
				moduleTagCard(
					title: "生活 Lifestyle",
					value: "\(CurrencyService.format(abs(snap.monthlyExpense), currency: displayCurrency, showSign: false)) 支出",
					icon: "cup.and.saucer.fill",
					color: .green,
					tags: [
						"\(CurrencyService.format(snap.monthlyIncome, currency: displayCurrency, showSign: true)) 收入",
						"\(snap.activeGoals) 目标",
						"月度归档"
					]
				)
				DashboardCard(
					title:    "觉知 Vitals",
					value:    "\(snap.vitalsCount) 条记录",
					subtitle: "Vitals 快照",
					icon:     "sparkles",
					color:    .purple
				)
			}

			if !snap.summary.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					Label("月度总结", systemImage: "text.bubble")
						.font(.title3.bold())
					Text(snap.summary)
						.padding(16)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(Color(nsColor: .controlBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 12))
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

		let snap = DashboardSnapshot(
			monthKey: targetMonthKey,
			pendingTasks: pendingCount,
			doneTasks: doneToArchive.count,
			totalNotes: notes.filter { $0.createdAt < monthEnd }.count,
			monthlyIncome: monthlyIncome(for: monthDate),
			monthlyExpense: monthlyExpense(for: monthDate),
			activeGoals: goals.filter { !$0.isCompleted }.count,
			vitalsCount: vitals.filter { $0.timestamp < monthEnd }.count
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

	private func moduleTagCard(
		title: String,
		value: String,
		icon: String,
		color: Color,
		tags: [String]
	) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Label(title, systemImage: icon)
				.font(.subheadline.bold())
				.foregroundStyle(color)
			Text(value)
				.font(.system(size: 26, weight: .bold))
			FlexibleTagWrap(tags: tags, color: color)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(22)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(Color(nsColor: .windowBackgroundColor))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.stroke(color.opacity(0.12), lineWidth: 1)
		)
	}
}

private struct FlexibleTagWrap: View {
	var tags: [String]
	var color: Color

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(tags, id: \.self) { tag in
					Text(tag)
						.font(.caption)
						.padding(.horizontal, 10)
						.padding(.vertical, 4)
						.background(color.opacity(0.12))
						.foregroundStyle(color)
						.clipShape(Capsule())
				}
			}
		}
	}
}

//
//  ConnectionView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct ConnectionView: View {
	@Query(sort: \Connection.name) private var connections: [Connection]

	@Binding var selectedConnection: Connection?
	@State private var searchText = ""

	private let calendar = Calendar.current

	private var filteredConnections: [Connection] {
		let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !keyword.isEmpty else { return connections }
		return connections.filter {
			$0.name.localizedCaseInsensitiveContains(keyword) ||
			$0.relationship.localizedCaseInsensitiveContains(keyword) ||
			$0.notes.localizedCaseInsensitiveContains(keyword)
		}
	}

	private var highPriorityCount: Int {
		connections.filter { $0.importanceLevel >= 4 }.count
	}

	private var needFollowUpCount: Int {
		let threshold = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
		return connections.filter { connection in
			guard let date = connection.lastContactDate else { return true }
			return date < threshold
		}.count
	}

	private var contactedThisWeekCount: Int {
		guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
		return connections.filter {
			guard let date = $0.lastContactDate else { return false }
			return date >= startOfWeek
		}.count
	}

	var body: some View {
		VStack(spacing: 0) {
			header

			Divider()

			HStack {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(.secondary)
				TextField("搜索联系人、关系、备注…", text: $searchText)
					.textFieldStyle(.plain)
				if !searchText.isEmpty {
					Button {
						searchText = ""
					} label: {
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(8)
			.background(Color(nsColor: .controlBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
			.padding(.horizontal, 12)
			.padding(.vertical, 8)

			Divider()

			List(selection: $selectedConnection) {
				if filteredConnections.isEmpty {
					ContentUnavailableView(
						searchText.isEmpty ? "还没有联系人" : "没有匹配结果",
						systemImage: "person.2",
						description: Text(searchText.isEmpty ? "点击右上角添加后，在右侧详情编辑" : "换个关键词")
					)
				} else {
					ForEach(filteredConnections) { connection in
						ConnectionRowView(connection: connection)
							.tag(connection)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
					}
				}
			}
		}
	}

	private var header: some View {
		LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
			ConnectionMetricCard(
				title: "联系人总数",
				value: "\(connections.count)",
				subtitle: "已建立档案",
				color: .teal
			)
			ConnectionMetricCard(
				title: "高优先级",
				value: "\(highPriorityCount)",
				subtitle: "重要性 4-5 分",
				color: .orange
			)
			ConnectionMetricCard(
				title: "待跟进",
				value: "\(needFollowUpCount)",
				subtitle: "30 天未联系或未记录",
				color: .red
			)
			ConnectionMetricCard(
				title: "本周已联系",
				value: "\(contactedThisWeekCount)",
				subtitle: "关系维护节奏",
				color: .blue
			)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(Color(nsColor: .windowBackgroundColor))
	}
}

private struct ConnectionMetricCard: View {
	var title: String
	var value: String
	var subtitle: String
	var color: Color

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
				.lineLimit(1)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(color.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}

// MARK: - 联系人行
struct ConnectionRowView: View {
	var connection: Connection

	private let calendar = Calendar.current
	private var normalizedImportance: Int {
		min(5, max(1, connection.importanceLevel))
	}

	private var followUpText: String {
		guard let lastContact = connection.lastContactDate else { return "未记录联系" }
		let days = calendar.dateComponents([.day], from: lastContact, to: Date()).day ?? 0
		if days > 30 { return "待跟进 \(days) 天" }
		return "最近联系 \(max(days, 0)) 天前"
	}

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(Color.teal.opacity(0.15))
					.frame(width: 40, height: 40)
				Text(String(connection.name.prefix(1)))
					.font(.headline)
					.foregroundStyle(.teal)
			}

			VStack(alignment: .leading, spacing: 4) {
				HStack(spacing: 6) {
					Text(connection.name)
						.font(.headline)
					Text("重要性 \(normalizedImportance)/5")
						.font(.caption2)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.orange.opacity(0.15))
						.clipShape(Capsule())
				}
				Text(connection.relationship.isEmpty ? "关系未填写" : connection.relationship)
					.font(.caption)
					.foregroundStyle(.secondary)
				Text(followUpText)
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}
			Spacer()
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

// MARK: - 联系人详情
struct ConnectionDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Binding var selectedConnection: Connection?
	@Bindable var connection: Connection

	@StateObject private var aiService = AIService()
	@State private var isEditingIdentity = false
	@State private var insightQuestion = "我应该如何与这个人脉保持关系？"
	@State private var isAnalyzing = false
	@State private var latestInsight: ConnectionInsight?

	private var normalizedImportanceLevel: Int {
		min(5, max(1, connection.importanceLevel))
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 22) {
				identitySection

				Divider()

				contactMetaSection

				Divider()

				strategySection

				Divider()

				aiInsightSection

				Spacer()

				Button(role: .destructive) {
					selectedConnection = nil
					modelContext.delete(connection)
				} label: {
					Label("删除联系人", systemImage: "trash")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
			}
			.padding(28)
		}
		.navigationTitle(connection.name.isEmpty ? "联系人详情" : connection.name)
	}

	private var identitySection: some View {
		HStack(alignment: .top, spacing: 16) {
			ZStack {
				Circle()
					.fill(Color.teal.opacity(0.15))
					.frame(width: 64, height: 64)
				Text(String(connection.name.prefix(1)))
					.font(.largeTitle)
					.foregroundStyle(.teal)
			}

			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("基础信息")
						.font(.headline)
					Spacer()
					Button(isEditingIdentity ? "完成编辑" : "编辑姓名/关系") {
						withAnimation {
							isEditingIdentity.toggle()
						}
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}

				if isEditingIdentity {
					HStack(spacing: 8) {
						Text("姓名")
							.frame(width: 44, alignment: .leading)
						TextField("姓名", text: $connection.name)
							.textFieldStyle(.roundedBorder)
					}
					HStack(spacing: 8) {
						Text("关系")
							.frame(width: 44, alignment: .leading)
						TextField("例如：朋友、同事、合作方", text: $connection.relationship)
							.textFieldStyle(.roundedBorder)
					}
				} else {
					Text(connection.name.isEmpty ? "未命名联系人" : connection.name)
						.font(.title2.bold())
					Text(connection.relationship.isEmpty ? "关系未填写（点击右上角可编辑）" : connection.relationship)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var contactMetaSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Toggle("记录最近联系时间", isOn: hasLastContactDateBinding)
				.font(.subheadline)

			if connection.lastContactDate != nil {
				DatePicker(
					"最近联系时间",
					selection: lastContactDateBinding,
					displayedComponents: .date
				)
				.datePickerStyle(.field)
				Text("日期：\(AppDateFormatter.ymd(lastContactDateBinding.wrappedValue))")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}

			HStack(spacing: 12) {
				Label("重要性", systemImage: "star.fill")
					.foregroundStyle(.secondary)
					.frame(width: 72, alignment: .leading)
				Slider(
					value: importanceLevelBinding,
					in: 1...5,
					step: 1
				)
				Text("\(normalizedImportanceLevel)/5")
					.font(.subheadline.bold())
					.foregroundStyle(.orange)
					.frame(width: 44, alignment: .trailing)
			}
		}
	}

	private var strategySection: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label("关系策略与备注", systemImage: "text.justify.left")
				.font(.headline)

			VStack(alignment: .leading, spacing: 6) {
				Text("我对 TA 的态度策略")
					.font(.caption)
					.foregroundStyle(.secondary)
				TextEditor(text: $connection.attitudeStrategy)
					.frame(minHeight: 68)
					.padding(8)
					.background(backgroundEditor())
			}

			VStack(alignment: .leading, spacing: 6) {
				Text("跟进计划")
					.font(.caption)
					.foregroundStyle(.secondary)
				TextEditor(text: $connection.followUpPlan)
					.frame(minHeight: 68)
					.padding(8)
					.background(backgroundEditor())
			}

			VStack(alignment: .leading, spacing: 6) {
				Text("备注")
					.font(.caption)
					.foregroundStyle(.secondary)
				TextEditor(text: $connection.notes)
					.frame(minHeight: 110)
					.padding(8)
					.background(Color(nsColor: .textBackgroundColor))
					.clipShape(RoundedRectangle(cornerRadius: 10))
					.overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
			}
		}
	}

	private var aiInsightSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Label("AI 关系分析", systemImage: "sparkles")
					.font(.headline)
				Spacer()
				if isAnalyzing {
					ProgressView()
						.scaleEffect(0.7)
				}
			}

			TextField(
				"提问：例如“我应该对这个人采取什么态度？”",
				text: $insightQuestion
			)
			.textFieldStyle(.roundedBorder)

			HStack(spacing: 10) {
				Button("分析态度与重要性") {
					Task { await runInsightAnalysis() }
				}
				.buttonStyle(.borderedProminent)
				.disabled(isAnalyzing || insightQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

				if !aiService.isConfigured {
					Text("未配置 API Key，将使用本地规则分析。")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}

			if let insight = latestInsight {
				VStack(alignment: .leading, spacing: 8) {
					HStack(spacing: 8) {
						Text("重要性 \(insight.importance)/5")
							.font(.subheadline.bold())
							.foregroundStyle(.orange)
						Text(insight.attitude)
							.font(.subheadline)
					}
					Text("依据：\(insight.reason)")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text("下一步：\(insight.nextAction)")
						.font(.caption)
						.foregroundStyle(.secondary)
					if !insight.keySignals.isEmpty {
						Text("关键信号：\(insight.keySignals.joined(separator: " · "))")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
				.padding(10)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.blue.opacity(0.08))
				.clipShape(RoundedRectangle(cornerRadius: 10))
			}
		}
	}

	private var hasLastContactDateBinding: Binding<Bool> {
		Binding(
			get: { connection.lastContactDate != nil },
			set: { enabled in
				if enabled {
					connection.lastContactDate = connection.lastContactDate ?? Date()
				} else {
					connection.lastContactDate = nil
				}
			}
		)
	}

	private var lastContactDateBinding: Binding<Date> {
		Binding(
			get: { connection.lastContactDate ?? Date() },
			set: { connection.lastContactDate = $0 }
		)
	}

	private var importanceLevelBinding: Binding<Double> {
		Binding(
			get: { Double(min(5, max(1, connection.importanceLevel))) },
			set: { connection.importanceLevel = Int($0.rounded()) }
		)
	}

	@MainActor
	private func runInsightAnalysis() async {
		isAnalyzing = true
		let insight = await aiService.analyzeConnection(
			name: connection.name,
			relationship: connection.relationship,
			notes: connection.notes,
			lastContactDate: connection.lastContactDate,
			question: insightQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
		)
		latestInsight = insight
		connection.importanceLevel = insight.importance
		connection.attitudeStrategy = insight.attitude
		connection.followUpPlan = insight.nextAction
		isAnalyzing = false
	}

	private func backgroundEditor() -> some View {
		Color(nsColor: .textBackgroundColor)
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
	}
}

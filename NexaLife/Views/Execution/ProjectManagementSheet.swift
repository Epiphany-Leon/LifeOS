//
//  ProjectManagementSheet.swift
//  NexaLife
//
//  Extracted from ExecutionView.swift on 2026-04-27 for readability.
//

import SwiftUI
import SwiftData
import OSLog

private let projectSheetLog = Logger(subsystem: "com.lihonggao.NexaLife", category: "ProjectSheet")

struct ProjectManagementSheet: View {
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@Query private var tasks: [TaskItem]

	@State private var projects: [ExecutionProject] = []
	@State private var selectedProjectID: UUID?
	@State private var draft: ProjectDraft = .init()
	@State private var isEditing = false
	@State private var refreshTick = 0

	var body: some View {
		HStack(spacing: 0) {
			projectListPanel
				.frame(width: 280)
				.background(Color(nsColor: .windowBackgroundColor))

			Divider()

			projectDetailPanel
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.frame(width: 980, height: 640)
		.onAppear {
			reloadProjects()
			if selectedProjectID == nil, let first = projects.first {
				selectedProjectID = first.id
				loadDraft(from: first)
			}
		}
		.id(refreshTick)
	}

	// MARK: - Left list

	private var projectListPanel: some View {
		VStack(spacing: 0) {
			HStack {
				Text("项目 Project")
					.font(.headline)
				Spacer()
				Button {
					projectSheetLog.notice("+ tapped, count=\(projects.count, privacy: .public)")
					createProject()
				} label: {
					Label("新建", systemImage: "plus")
						.labelStyle(.titleAndIcon)
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.small)
			}
			.padding(12)

			Divider()

			ScrollView {
				LazyVStack(alignment: .leading, spacing: 0) {
					if projects.isEmpty {
						Text("还没有项目，点击右上角「新建」")
							.font(.caption)
							.foregroundStyle(.secondary)
							.padding(20)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
					ForEach(ProjectHorizon.allCases, id: \.self) { horizon in
						let items = projects.filter { $0.horizon == horizon }
						if !items.isEmpty {
							Text(horizon.rawValue)
								.font(.caption.weight(.semibold))
								.foregroundStyle(.secondary)
								.padding(.horizontal, 14)
								.padding(.top, 12)
								.padding(.bottom, 4)
								.frame(maxWidth: .infinity, alignment: .leading)
							ForEach(items) { project in
								projectRow(project)
							}
						}
					}
				}
				.padding(.bottom, 8)
			}

			Divider()

			HStack {
				Button("关闭") {
					isPresented = false
				}
				.buttonStyle(.bordered)
				Spacer()
			}
			.padding(12)
		}
	}

	@ViewBuilder
	private func projectRow(_ project: ExecutionProject) -> some View {
		let isActive = selectedProjectID == project.id
		Button {
			selectProject(project)
		} label: {
			HStack(spacing: 8) {
				Circle()
					.fill(statusColor(project.status))
					.frame(width: 7, height: 7)
				VStack(alignment: .leading, spacing: 2) {
					Text(project.name.isEmpty ? "未命名项目" : project.name)
						.font(.subheadline.weight(isActive ? .semibold : .regular))
						.foregroundStyle(WorkspaceTheme.strongText)
						.lineLimit(1)
					Text(project.status.rawValue)
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
				Spacer(minLength: 0)
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 8)
			.background(isActive ? WorkspaceTheme.moduleAccent(for: .execution).opacity(0.18) : Color.clear)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.contextMenu {
			Button("删除", role: .destructive) {
				deleteProject(project)
			}
		}
	}

	// MARK: - Right detail

	@ViewBuilder
	private var projectDetailPanel: some View {
		if let project = selectedProject {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					HStack {
						Text("项目详情")
							.font(.title3.bold())
						Spacer()
						if isEditing {
							Button("取消") {
								isEditing = false
								loadDraft(from: project)
							}
							.buttonStyle(.bordered)

							Button("保存") {
								saveDraft(into: project)
							}
							.buttonStyle(.borderedProminent)
							.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
						} else {
							Button("修改") {
								loadDraft(from: project)
								isEditing = true
							}
							.buttonStyle(.bordered)

							Button("删除", role: .destructive) {
								deleteProject(project)
							}
							.buttonStyle(.bordered)
						}
					}

					if isEditing {
						editorBody
					} else {
						readOnlyBody(project)
					}
				}
				.padding(24)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		} else {
			VStack(spacing: 14) {
				Image(systemName: "folder")
					.font(.system(size: 36, weight: .semibold))
					.foregroundStyle(.secondary)
				Text("选择项目查看详情")
					.font(.title3.bold())
					.foregroundStyle(WorkspaceTheme.strongText)
				Text("左侧可创建短期、中期、长期项目")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}

	private var editorBody: some View {
		VStack(alignment: .leading, spacing: 16) {
			fieldRow(label: "名称") {
				TextField("项目名称", text: $draft.name)
					.textFieldStyle(.roundedBorder)
			}

			fieldRow(label: "周期") {
				Picker("周期", selection: $draft.horizon) {
					ForEach(ProjectHorizon.allCases, id: \.self) { h in
						Text(h.rawValue).tag(h)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}

			fieldRow(label: "状态") {
				Picker("状态", selection: $draft.status) {
					ForEach(ProjectStatus.allCases, id: \.self) { s in
						Text(s.rawValue).tag(s)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}

			fieldRow(label: "开始时间") {
				HStack {
					Toggle("已设置", isOn: Binding(
						get: { draft.startDate != nil },
						set: { on in draft.startDate = on ? (draft.startDate ?? Date()) : nil }
					))
					.toggleStyle(.checkbox)
					if draft.startDate != nil {
						DatePicker("", selection: Binding(
							get: { draft.startDate ?? Date() },
							set: { draft.startDate = $0 }
						), displayedComponents: .date)
						.labelsHidden()
					}
					Spacer()
				}
			}

			fieldRow(label: "结束时间") {
				HStack {
					Toggle("已设置", isOn: Binding(
						get: { draft.endDate != nil },
						set: { on in draft.endDate = on ? (draft.endDate ?? Date()) : nil }
					))
					.toggleStyle(.checkbox)
					if draft.endDate != nil {
						DatePicker("", selection: Binding(
							get: { draft.endDate ?? Date() },
							set: { draft.endDate = $0 }
						), displayedComponents: .date)
						.labelsHidden()
					}
					Spacer()
				}
			}

			VStack(alignment: .leading, spacing: 6) {
				HStack {
					Text("项目描述")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
					Spacer()
					Text("支持 Markdown")
						.font(.caption2)
						.foregroundStyle(.tertiary)
				}
				TextEditor(text: $draft.detail)
					.font(.body)
					.frame(minHeight: 180)
					.padding(8)
					.background(Color(nsColor: .textBackgroundColor))
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(WorkspaceTheme.border, lineWidth: 1)
					)
			}
		}
	}

	private func readOnlyBody(_ project: ExecutionProject) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			Text(project.name.isEmpty ? "未命名项目" : project.name)
				.font(.title2.bold())
				.foregroundStyle(WorkspaceTheme.strongText)

			HStack(spacing: 8) {
				MetaPill(text: project.horizon.rawValue, color: horizonColor(project.horizon))
				MetaPill(text: project.status.rawValue, color: statusColor(project.status))
				if let start = project.startDate {
					MetaPill(text: "开始 \(AppDateFormatter.ymd(start))", color: .blue)
				}
				if let end = project.endDate {
					MetaPill(text: "结束 \(AppDateFormatter.ymd(end))", color: .orange)
				}
				Spacer()
			}

			if project.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				Text("暂无项目描述")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				MarkdownText(project.detail)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Divider()

			Text("关联任务（按状态）")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(.secondary)
			HStack(spacing: 10) {
				ForEach(TaskStatus.allCases, id: \.self) { st in
					MetaPill(text: "\(st.rawValue) \(taskCount(in: project.name, status: st))", color: .gray)
				}
				Spacer()
			}
		}
	}

	private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(label)
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(.secondary)
			content()
		}
	}

	// MARK: - Helpers

	private var selectedProject: ExecutionProject? {
		guard let id = selectedProjectID else { return nil }
		return projects.first(where: { $0.id == id })
	}

	private func selectProject(_ project: ExecutionProject) {
		selectedProjectID = project.id
		isEditing = false
		loadDraft(from: project)
	}

	private func loadDraft(from project: ExecutionProject) {
		draft = ProjectDraft(
			name: project.name,
			detail: project.detail,
			horizon: project.horizon,
			status: project.status,
			startDate: project.startDate,
			endDate: project.endDate
		)
	}

	private func reloadProjects() {
		var descriptor = FetchDescriptor<ExecutionProject>(
			sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
		)
		descriptor.includePendingChanges = true
		do {
			projects = try modelContext.fetch(descriptor)
			projectSheetLog.notice("reloadProjects: count=\(projects.count, privacy: .public)")
		} catch {
			projectSheetLog.error("reloadProjects failed: \(error.localizedDescription, privacy: .public)")
		}
	}

	private func createProject() {
		let base = "新项目"
		var candidate = base
		var index = 1
		while projects.contains(where: { $0.name == candidate }) {
			index += 1
			candidate = "\(base)\(index)"
		}
		let project = ExecutionProject(name: candidate, horizon: .shortTerm)
		modelContext.insert(project)
		do {
			try modelContext.save()
			projectSheetLog.notice("createProject: saved id=\(project.id, privacy: .public)")
		} catch {
			projectSheetLog.error("createProject save failed: \(error.localizedDescription, privacy: .public)")
		}
		reloadProjects()
		selectedProjectID = project.id
		loadDraft(from: project)
		isEditing = true
		refreshTick &+= 1
		projectSheetLog.notice("createProject: end count=\(projects.count, privacy: .public)")
	}

	private func saveDraft(into project: ExecutionProject) {
		let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty else { return }
		let oldName = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
		project.name = trimmedName
		project.detail = draft.detail
		project.horizon = draft.horizon
		project.status = draft.status
		project.startDate = draft.startDate
		project.endDate = draft.endDate
		project.updatedAt = Date()
		if oldName != trimmedName && !oldName.isEmpty {
			for task in tasks where task.projectName == oldName {
				task.projectName = trimmedName
			}
		}
		try? modelContext.save()
		reloadProjects()
		isEditing = false
	}

	private func deleteProject(_ project: ExecutionProject) {
		let projName = project.name
		for task in tasks where task.projectName == projName {
			task.projectName = ""
		}
		modelContext.delete(project)
		try? modelContext.save()
		reloadProjects()
		if selectedProjectID == project.id {
			selectedProjectID = projects.first?.id
			if let next = selectedProject {
				loadDraft(from: next)
			}
		}
		isEditing = false
	}

	private func taskCount(in projectName: String, status: TaskStatus) -> Int {
		tasks.filter {
			$0.archivedMonthKey == nil &&
			$0.projectName == projectName &&
			$0.status == status
		}.count
	}

	private func horizonColor(_ horizon: ProjectHorizon) -> Color {
		switch horizon {
		case .shortTerm: return WorkspaceTheme.moduleAccent(for: .execution)
		case .midTerm:   return .blue
		case .longTerm:  return .green
		}
	}

	private func statusColor(_ status: ProjectStatus) -> Color {
		switch status {
		case .notStarted: return .gray
		case .inProgress: return .indigo
		case .finished:   return .green
		case .paused:     return .orange
		}
	}
}

private struct ProjectDraft {
	var name: String = ""
	var detail: String = ""
	var horizon: ProjectHorizon = .shortTerm
	var status: ProjectStatus = .notStarted
	var startDate: Date?
	var endDate: Date?
}

private struct MetaPill: View {
	let text: String
	let color: Color
	var body: some View {
		Text(text)
			.font(.caption.weight(.semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 10)
			.padding(.vertical, 4)
			.background(color.opacity(0.12))
			.clipShape(Capsule())
	}
}

private struct MarkdownText: View {
	let raw: String

	init(_ raw: String) { self.raw = raw }

	var body: some View {
		if let attr = try? AttributedString(
			markdown: raw,
			options: AttributedString.MarkdownParsingOptions(
				interpretedSyntax: .inlineOnlyPreservingWhitespace
			)
		) {
			Text(attr)
				.font(.body)
				.textSelection(.enabled)
		} else {
			Text(raw)
				.font(.body)
				.textSelection(.enabled)
		}
	}
}

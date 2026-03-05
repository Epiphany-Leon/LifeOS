//
//  ExecutionView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct ExecutionView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
	@Query(sort: \ExecutionProject.updatedAt, order: .reverse) private var projects: [ExecutionProject]

	@Binding var selectedTask: TaskItem?
	@State private var isAddingTask = false
	@State private var isManagingProjects = false
	@State private var selectedFilter: TaskFilter = .all

	enum TaskFilter: String, CaseIterable {
		case all = "全部"
		case todo = "待办"
		case inProgress = "进行中"
		case done = "已完成"
	}

	var activeTasks: [TaskItem] {
		tasks.filter { $0.archivedMonthKey == nil }
	}

	var pendingCount: Int { activeTasks.filter { $0.status == .todo }.count }
	var inProgressCount: Int { activeTasks.filter { $0.status == .inProgress }.count }
	var doneCount: Int { activeTasks.filter { $0.status == .done }.count }

	var filteredTasks: [TaskItem] {
		switch selectedFilter {
		case .all: return activeTasks
		case .todo: return activeTasks.filter { $0.status == .todo }
		case .inProgress: return activeTasks.filter { $0.status == .inProgress }
		case .done: return activeTasks.filter { $0.status == .done }
		}
	}

	var shortTermProjects: [ExecutionProject] {
		projects.filter { $0.horizon == .shortTerm }
	}
	var midTermProjects: [ExecutionProject] {
		projects.filter { $0.horizon == .midTerm }
	}
	var longTermProjects: [ExecutionProject] {
		projects.filter { $0.horizon == .longTerm }
	}

	var knownProjectNames: [String] {
		Array(Set(
			projects.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
			+ tasks.map { $0.projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
		))
		.filter { !$0.isEmpty }
		.sorted()
	}

	var groupedTasks: [(String, [TaskItem])] {
		let grouped = Dictionary(grouping: filteredTasks) { task in
			let normalized = task.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
			return normalized.isEmpty ? "收件箱" : normalized
		}
		let sortedKeys = grouped.keys.sorted { lhs, rhs in
			let lhsRank = projectSortRank(lhs)
			let rhsRank = projectSortRank(rhs)
			if lhsRank == rhsRank {
				return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
			}
			return lhsRank < rhsRank
		}
		return sortedKeys.map { key in
			(key, (grouped[key] ?? []).sorted(by: { $0.createdAt > $1.createdAt }))
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 20) {
				StatBadge(label: "待办", count: pendingCount, color: .orange)
				StatBadge(label: "进行中", count: inProgressCount, color: .blue)
				StatBadge(label: "已完成", count: doneCount, color: .green)
				Spacer()
				Button {
					isManagingProjects = true
				} label: {
					Label("项目管理", systemImage: "folder.badge.gearshape")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				Button {
					isAddingTask = true
				} label: {
					Label("新建任务", systemImage: "plus")
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.small)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(Color(nsColor: .windowBackgroundColor))

			Divider()

			Picker("筛选", selection: $selectedFilter) {
				ForEach(TaskFilter.allCases, id: \.self) { filter in
					Text(filter.rawValue).tag(filter)
				}
			}
			.pickerStyle(.segmented)
			.padding(12)

			projectOverviewStrip
				.padding(.horizontal, 12)
				.padding(.bottom, 8)

			List(selection: $selectedTask) {
				if filteredTasks.isEmpty {
					ContentUnavailableView(
						"没有任务",
						systemImage: "checkmark.circle",
						description: Text("点击右上角新建任务")
					)
				} else {
					ForEach(groupedTasks, id: \.0) { projectName, items in
						Section(projectName) {
							ForEach(items) { task in
								TaskRowView(task: task)
									.tag(task)
									.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
							}
							.onDelete { offsets in
								for index in offsets {
									let target = items[index]
									if selectedTask?.id == target.id {
										selectedTask = nil
									}
									modelContext.delete(target)
								}
							}
						}
					}
				}
			}
		}
		.navigationTitle("执行 Execution")
		.navigationSplitViewColumnWidth(min: ColumnWidth.min, ideal: ColumnWidth.ideal, max: ColumnWidth.max)
		.sheet(isPresented: $isAddingTask) {
			AddTaskSheet(
				isPresented: $isAddingTask,
				projectNames: knownProjectNames
			)
		}
		.sheet(isPresented: $isManagingProjects) {
			ProjectManagementSheet(isPresented: $isManagingProjects)
		}
		.onDeleteCommand {
			if let task = selectedTask {
				selectedTask = nil
				modelContext.delete(task)
			}
		}
		.onChange(of: tasks.map(\.id)) { _, ids in
			if let selected = selectedTask, !ids.contains(selected.id) {
				selectedTask = nil
			}
		}
	}

	private var projectOverviewStrip: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 10) {
				ProjectCountPill(title: "短期", count: shortTermProjects.count, color: .orange)
				ProjectCountPill(title: "中期", count: midTermProjects.count, color: .blue)
				ProjectCountPill(title: "长期", count: longTermProjects.count, color: .green)
			}

			if projects.isEmpty {
				Button("创建第一个项目") {
					isManagingProjects = true
				}
				.buttonStyle(.borderless)
				.foregroundStyle(.secondary)
				.font(.caption)
			} else {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(projects) { project in
							HStack(spacing: 6) {
								Text(project.horizon.rawValue)
									.font(.caption2)
									.foregroundStyle(.secondary)
								Text(project.name)
									.font(.caption)
									.lineLimit(1)
							}
							.padding(.horizontal, 10)
							.padding(.vertical, 5)
							.background(Color(nsColor: .controlBackgroundColor))
							.clipShape(Capsule())
						}
					}
					.padding(.trailing, 4)
				}
			}
		}
	}

	private func projectSortRank(_ projectName: String) -> Int {
		if projectName == "收件箱" { return 0 }
		guard let project = projects.first(where: { $0.name == projectName }) else { return 4 }
		switch project.horizon {
		case .shortTerm: return 1
		case .midTerm: return 2
		case .longTerm: return 3
		}
	}
}

struct StatBadge: View {
	var label: String
	var count: Int
	var color: Color

	var body: some View {
		VStack(spacing: 2) {
			Text("\(count)")
				.font(.system(size: 18, weight: .bold))
				.foregroundStyle(color)
			Text(label)
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
	}
}

struct ProjectCountPill: View {
	var title: String
	var count: Int
	var color: Color

	var body: some View {
		HStack(spacing: 6) {
			Text(title)
			Text("\(count)")
				.bold()
		}
		.font(.caption)
		.padding(.horizontal, 10)
		.padding(.vertical, 4)
		.background(color.opacity(0.12))
		.foregroundStyle(color)
		.clipShape(Capsule())
	}
}

struct TaskRowView: View {
	@Bindable var task: TaskItem

	var body: some View {
		HStack(spacing: 10) {
			Button {
				withAnimation {
					advanceStatus()
				}
			} label: {
				Image(systemName: statusIcon)
					.foregroundStyle(statusColor)
					.font(.title3)
			}
			.buttonStyle(.plain)

			VStack(alignment: .leading, spacing: 3) {
				Text(task.title)
					.font(.body)
					.lineLimit(1)
					.strikethrough(task.status == .done, color: .secondary)
					.foregroundStyle(task.status == .done ? .secondary : .primary)

				if let due = task.dueDate {
					Label(AppDateFormatter.ymd(due), systemImage: "calendar")
						.font(.caption)
						.foregroundStyle(due < Date() && !task.isDone ? .red : .secondary)
				}

				if !task.category.isEmpty || !task.tagList.isEmpty {
					HStack(spacing: 6) {
						if !task.category.isEmpty {
							Text(task.category)
								.font(.caption2)
								.padding(.horizontal, 6)
								.padding(.vertical, 1)
								.background(Color.secondary.opacity(0.12))
								.clipShape(Capsule())
						}
						if let firstTag = task.tagList.first {
							Text("#\(firstTag)")
								.font(.caption2)
								.foregroundStyle(.secondary)
						}
					}
				}
			}

			Spacer()

			Text(task.status.rawValue)
				.font(.caption2)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(statusColor.opacity(0.12))
				.foregroundStyle(statusColor)
				.clipShape(Capsule())
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 2)
	}

	private func advanceStatus() {
		switch task.status {
		case .todo:
			task.status = .inProgress
		case .inProgress:
			task.status = .done
			task.completedAt = Date()
		case .done:
			task.status = .todo
			task.completedAt = nil
		}
	}

	var statusIcon: String {
		switch task.status {
		case .todo: return "circle"
		case .inProgress: return "circle.dotted.circle"
		case .done: return "checkmark.circle.fill"
		}
	}

	var statusColor: Color {
		switch task.status {
		case .todo: return .orange
		case .inProgress: return .blue
		case .done: return .green
		}
	}
}

struct AddTaskSheet: View {
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@Query private var tasks: [TaskItem]
	@Query private var projects: [ExecutionProject]
	@StateObject private var aiService = AIService()
	let projectNames: [String]

	@State private var title: String = ""
	@State private var notes: String = ""
	@State private var category: String = ""
	@State private var tagsText: String = ""
	@State private var projectName: String = ""
	@State private var dueDate: Date = Date()
	@State private var hasDueDate: Bool = false
	@State private var status: TaskStatus = .todo
	@State private var isGeneratingSuggestion = false
	@State private var isSaving = false
	@State private var suggestionTask: _Concurrency.Task<Void, Never>?
	@State private var suggestionRequestID = 0

	var body: some View {
		VStack(spacing: 20) {
			HStack {
				Text("新建任务").font(.title3).bold()
				Spacer()
				Button("取消") { isPresented = false }
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
			}

			Form {
				TextField("任务标题", text: $title)

				TextField("所属项目（留空则归入收件箱）", text: $projectName)

				if !projectNames.isEmpty {
					Picker("快速选择项目", selection: $projectName) {
						Text("收件箱").tag("")
						ForEach(projectNames, id: \.self) { name in
							Text(name).tag(name)
						}
					}
					.pickerStyle(.menu)
				}

				Button {
					scheduleSuggestion(force: true)
				} label: {
					Label("自动归类项目", systemImage: "wand.and.stars")
				}
				.buttonStyle(.borderless)
				.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

				Picker("状态", selection: $status) {
					ForEach(TaskStatus.allCases, id: \.self) { s in
						Text(s.rawValue).tag(s)
					}
				}

				Toggle("设置截止日期", isOn: $hasDueDate)
				if hasDueDate {
					DatePicker("截止日期", selection: $dueDate, displayedComponents: .date)
						.datePickerStyle(.field)
					Text("日期：\(AppDateFormatter.ymd(dueDate))")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}

				TextField("备注", text: $notes, axis: .vertical)
					.lineLimit(3...6)

				TextField("分类（AI自动生成，可修改）", text: $category)
				TextField("标签（逗号分隔，AI自动生成，可修改）", text: $tagsText)

				if isGeneratingSuggestion {
					HStack(spacing: 8) {
						ProgressView().scaleEffect(0.7)
						Text("AI 生成分类和标签中…")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
			.formStyle(.grouped)

			HStack {
				Spacer()
				Button("创建任务") {
					_Concurrency.Task { await saveTask() }
				}
				.buttonStyle(.borderedProminent)
				.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
			}
		}
		.padding(24)
		.frame(width: 560, height: 520)
		.onChange(of: title) { _, _ in
			scheduleSuggestion(force: false)
		}
		.onChange(of: notes) { _, _ in
			scheduleSuggestion(force: false)
		}
		.onDisappear {
			suggestionTask?.cancel()
		}
	}

	private var existingProjectNames: [String] {
		Array(Set(
			tasks.map { $0.projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
			+ projects.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
		))
		.filter { !$0.isEmpty }
		.sorted()
	}

	private func parsedTags(from text: String) -> [String] {
		let separators = CharacterSet(charactersIn: ",，;；")
		return text
			.components(separatedBy: separators)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	private func scheduleSuggestion(force: Bool) {
		suggestionTask?.cancel()
		let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
		let hasContent = !normalizedTitle.isEmpty || !normalizedNotes.isEmpty
		guard hasContent else {
			isGeneratingSuggestion = false
			return
		}

		suggestionRequestID += 1
		let requestID = suggestionRequestID
		suggestionTask = _Concurrency.Task {
			if !force {
				try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000)
			}
			guard !_Concurrency.Task.isCancelled else { return }
			await runSuggestion(
				title: normalizedTitle,
				notes: normalizedNotes,
				requestID: requestID
			)
		}
	}

	@MainActor
	private func runSuggestion(title: String, notes: String, requestID: Int) async {
		isGeneratingSuggestion = true
		defer { isGeneratingSuggestion = false }
		let suggestion = await aiService.suggestTaskMetadata(
			title: title,
			notes: notes,
			existingProjects: existingProjectNames,
			currentProject: projectName
		)
		guard requestID == suggestionRequestID else { return }

		if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			category = suggestion.category
		}
		if tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			tagsText = suggestion.tags.joined(separator: ", ")
		}
		if projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
		   suggestion.projectName != "收件箱" {
			projectName = suggestion.projectName
		}
	}

	@MainActor
	private func saveTask() async {
		isSaving = true
		defer { isSaving = false }
		let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalizedTitle.isEmpty else { return }

		let suggestion = await aiService.suggestTaskMetadata(
			title: normalizedTitle,
			notes: normalizedNotes,
			existingProjects: existingProjectNames,
			currentProject: normalizedProject
		)

		let finalCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			? suggestion.category
			: category.trimmingCharacters(in: .whitespacesAndNewlines)
		let finalTags = parsedTags(from: tagsText)
		let finalTagsText = finalTags.isEmpty
			? suggestion.tags.joined(separator: ", ")
			: finalTags.joined(separator: ", ")
		let finalProject = normalizedProject.isEmpty ? suggestion.projectName : normalizedProject
		let savedProject = finalProject == "收件箱" ? "" : finalProject

		let task = TaskItem(
			title: normalizedTitle,
			notes: normalizedNotes,
			category: finalCategory,
			tagsText: finalTagsText,
			status: status,
			projectName: savedProject,
			dueDate: hasDueDate ? dueDate : nil,
			completedAt: status == .done ? Date() : nil
		)
		modelContext.insert(task)

		if !savedProject.isEmpty,
		   !projects.contains(where: { $0.name == savedProject }) {
			modelContext.insert(ExecutionProject(name: savedProject, horizon: .shortTerm))
		}

		isPresented = false
	}
}

struct ProjectManagementSheet: View {
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \ExecutionProject.updatedAt, order: .reverse) private var projects: [ExecutionProject]
	@Query private var tasks: [TaskItem]

	@State private var selectedProjectID: UUID?
	@State private var isEditing = false
	@State private var draftName = ""
	@State private var draftDetail = ""
	@State private var draftHorizon: ProjectHorizon = .shortTerm

	var body: some View {
		HStack(spacing: 0) {
			projectListPanel
				.frame(width: 280)
				.background(Color(nsColor: .windowBackgroundColor))

			Divider()

			projectDetailPanel
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.padding(20)
		}
		.frame(width: 980, height: 620)
		.onAppear {
			if selectedProjectID == nil {
				selectedProjectID = projects.first?.id
			}
			loadDraftFromSelectedProject()
		}
		.onChange(of: selectedProjectID) { _, _ in
			isEditing = false
			loadDraftFromSelectedProject()
		}
	}

	private var projectListPanel: some View {
		VStack(spacing: 0) {
			HStack {
				Text("项目 Project")
					.font(.headline)
				Spacer()
				Button {
					createProject()
				} label: {
					Image(systemName: "plus")
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.small)
			}
			.padding(12)

			List(selection: $selectedProjectID) {
				ForEach(ProjectHorizon.allCases, id: \.self) { horizon in
					let items = projects.filter { $0.horizon == horizon }
					if !items.isEmpty {
						Section(horizon.rawValue) {
							ForEach(items) { project in
								Text(project.name)
									.tag(project.id as UUID?)
							}
						}
					}
				}
			}

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
	private var projectDetailPanel: some View {
		if let project = selectedProject {
			VStack(alignment: .leading, spacing: 18) {
				HStack {
					Text("项目详情")
						.font(.title3.bold())
					Spacer()
					if isEditing {
						Button("取消") {
							isEditing = false
							loadDraftFromSelectedProject()
						}
						.buttonStyle(.bordered)

						Button("保存") {
							saveProjectEdits(project)
						}
						.buttonStyle(.borderedProminent)
						.disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					} else {
						Button("修改") {
							isEditing = true
						}
						.buttonStyle(.bordered)
					}
				}

				HStack(spacing: 10) {
					Text("名称")
						.frame(width: 44, alignment: .leading)
						.foregroundStyle(.secondary)
					if isEditing {
						TextField("项目名称", text: $draftName)
							.textFieldStyle(.roundedBorder)
					} else {
						Text(draftName)
							.textSelection(.enabled)
					}
				}

				HStack(spacing: 10) {
					Text("周期")
						.frame(width: 44, alignment: .leading)
						.foregroundStyle(.secondary)
					if isEditing {
						Picker("", selection: $draftHorizon) {
							ForEach(ProjectHorizon.allCases, id: \.self) { horizon in
								Text(horizon.rawValue).tag(horizon)
							}
						}
						.pickerStyle(.segmented)
						.frame(maxWidth: 360)
					} else {
						Text(draftHorizon.rawValue)
							.padding(.horizontal, 10)
							.padding(.vertical, 4)
							.background(Color.secondary.opacity(0.12))
							.clipShape(Capsule())
					}
				}

				VStack(alignment: .leading, spacing: 6) {
					Text("项目说明")
						.font(.subheadline.bold())
					if isEditing {
						TextEditor(text: $draftDetail)
							.frame(minHeight: 180)
							.padding(8)
							.background(Color(nsColor: .textBackgroundColor))
							.clipShape(RoundedRectangle(cornerRadius: 10))
					} else {
						ScrollView {
							Text(draftDetail.isEmpty ? "暂无说明" : draftDetail)
								.frame(maxWidth: .infinity, alignment: .leading)
								.textSelection(.enabled)
								.padding(8)
						}
						.frame(minHeight: 180)
						.background(Color(nsColor: .textBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 10))
					}
				}

				VStack(alignment: .leading, spacing: 6) {
					Text("关联任务")
						.font(.subheadline.bold())
					HStack(spacing: 8) {
						ProjectCountPill(
							title: "待办",
							count: taskCount(in: project.name, status: .todo),
							color: .orange
						)
						ProjectCountPill(
							title: "进行中",
							count: taskCount(in: project.name, status: .inProgress),
							color: .blue
						)
						ProjectCountPill(
							title: "已完成",
							count: taskCount(in: project.name, status: .done),
							color: .green
						)
					}
				}

				Spacer()

				HStack {
					Button(role: .destructive) {
						deleteProject(project)
					} label: {
						Label("删除项目", systemImage: "trash")
					}
					.buttonStyle(.bordered)
					Spacer()
				}
			}
		} else {
			ContentUnavailableView(
				"选择项目查看详情",
				systemImage: "folder",
				description: Text("左侧可创建短期、中期、长期项目")
			)
		}
	}

	private var selectedProject: ExecutionProject? {
		guard let id = selectedProjectID else { return nil }
		return projects.first(where: { $0.id == id })
	}

	private func taskCount(in projectName: String, status: TaskStatus) -> Int {
		tasks.filter {
			$0.archivedMonthKey == nil &&
			$0.projectName == projectName &&
			$0.status == status
		}.count
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
		selectedProjectID = project.id
		loadDraftFromSelectedProject()
		isEditing = true
	}

	private func deleteProject(_ project: ExecutionProject) {
		for task in tasks where task.projectName == project.name {
			task.projectName = ""
		}
		modelContext.delete(project)
		selectedProjectID = projects.first(where: { $0.id != project.id })?.id
		loadDraftFromSelectedProject()
		isEditing = false
	}

	private func saveProjectEdits(_ project: ExecutionProject) {
		let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty else { return }
		let oldName = project.name.trimmingCharacters(in: .whitespacesAndNewlines)

		project.name = trimmedName
		project.detail = draftDetail
		project.horizon = draftHorizon
		project.updatedAt = Date()

		if oldName != trimmedName && !oldName.isEmpty {
			for task in tasks where task.projectName == oldName {
				task.projectName = trimmedName
			}
		}
		isEditing = false
		loadDraftFromSelectedProject()
	}

	private func loadDraftFromSelectedProject() {
		guard let selectedProject else {
			draftName = ""
			draftDetail = ""
			draftHorizon = .shortTerm
			return
		}
		draftName = selectedProject.name
		draftDetail = selectedProject.detail
		draftHorizon = selectedProject.horizon
	}
}

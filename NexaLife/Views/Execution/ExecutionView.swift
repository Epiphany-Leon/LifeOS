//
//  ExecutionView.swift
//  NexaLife
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
	@State private var searchText = ""
	@State private var debouncedSearchText = ""
	@State private var searchDebounceTask: Task<Void, Never>?

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
		let source = searchedTasks
		switch selectedFilter {
		case .all: return source
		case .todo: return source.filter { $0.status == .todo }
		case .inProgress: return source.filter { $0.status == .inProgress }
		case .done: return source.filter { $0.status == .done }
		}
	}

	var searchedTasks: [TaskItem] {
		let keyword = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !keyword.isEmpty else { return activeTasks }
		return activeTasks.filter { task in
			task.title.localizedCaseInsensitiveContains(keyword)
				|| task.notes.localizedCaseInsensitiveContains(keyword)
				|| task.category.localizedCaseInsensitiveContains(keyword)
				|| task.tagsText.localizedCaseInsensitiveContains(keyword)
				|| task.projectName.localizedCaseInsensitiveContains(keyword)
		}
	}

	var todoTasks: [TaskItem] {
		filteredTasks.filter { $0.status == .todo }
	}

	var progressTasks: [TaskItem] {
		filteredTasks.filter { $0.status == .inProgress }
	}

	var completedTasks: [TaskItem] {
		filteredTasks.filter { $0.status == .done }
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
	var notStartedProjects: [ExecutionProject] {
		projects.filter { $0.status == .notStarted }
	}
	var inProgressProjects: [ExecutionProject] {
		projects.filter { $0.status == .inProgress }
	}
	var pausedProjects: [ExecutionProject] {
		projects.filter { $0.status == .paused }
	}

	var knownProjectNames: [String] {
		Array(Set(
			projects.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
			+ tasks.map { $0.projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
		))
		.filter { !$0.isEmpty }
		.sorted()
	}

	var body: some View {
		VStack(spacing: 0) {
			VStack(spacing: 0) {
				searchBar
				taskFilterBar
			}

			boardContent
		}
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
				deleteTask(task)
			}
		}
		.onAppear {
			debouncedSearchText = searchText
		}
		.onChange(of: searchText) { _, newValue in
			searchDebounceTask?.cancel()
			searchDebounceTask = Task {
				try? await Task.sleep(nanoseconds: 180_000_000)
				guard !Task.isCancelled else { return }
				await MainActor.run {
					debouncedSearchText = newValue
				}
			}
		}
		.onChange(of: tasks.map(\.id)) { _, ids in
			if let selected = selectedTask, !ids.contains(selected.id) {
				selectedTask = nil
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .nexaLifeExecutionCreateTask)) { _ in
			isAddingTask = true
		}
		.onReceive(NotificationCenter.default.publisher(for: .nexaLifeExecutionManageProjects)) { _ in
			isManagingProjects = true
		}
		.onDisappear {
			searchDebounceTask?.cancel()
		}
	}

	private var taskFilterBar: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(TaskFilter.allCases, id: \.self) { filter in
					taskFilterChip(filter)
				}
			}
			.padding(.horizontal, 16)
			.padding(.bottom, 14)
			.padding(.top, 8)
		}
	}

	private func isSelected(_ task: TaskItem) -> Bool {
		selectedTask?.id == task.id
	}

	private var searchBar: some View {
		HStack {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(WorkspaceTheme.mutedText)
			TextField("搜索标题、项目、分类、标签…", text: $searchText)
				.textFieldStyle(.plain)
			if !searchText.isEmpty {
				Image(systemName: "xmark.circle.fill")
					.foregroundStyle(WorkspaceTheme.mutedText)
					.contentShape(Rectangle())
					.onTapGesture {
						searchText = ""
					}
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
		.background(WorkspaceTheme.elevatedSurface)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(WorkspaceTheme.border, lineWidth: 1)
		)
		.padding(.horizontal, 16)
		.padding(.top, 14)
		.padding(.bottom, 4)
	}

	private var boardContent: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				LazyVGrid(
					columns: [
						GridItem(.flexible(minimum: 220), spacing: 18),
						GridItem(.flexible(minimum: 220), spacing: 18),
						GridItem(.flexible(minimum: 220), spacing: 18)
					],
					alignment: .leading,
					spacing: 18
				) {
					kanbanColumn(
						title: "To-do",
						subtitle: "等待推进",
						tasks: todoTasks,
						accent: WorkspaceTheme.moduleAccent(for: .execution),
						status: .todo
					)

					kanbanColumn(
						title: "In Progress",
						subtitle: "正在推进",
						tasks: progressTasks,
						accent: .blue,
						status: .inProgress
					)

					kanbanColumn(
						title: "Done",
						subtitle: "已完成",
						tasks: completedTasks,
						accent: .green,
						status: .done
					)
				}

				projectBoardColumn
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 18)
		}
	}

	private func kanbanColumn(
		title: String,
		subtitle: String,
		tasks: [TaskItem],
		accent: Color,
		status: TaskStatus
	) -> some View {
		WorkspaceCard(accent: accent, padding: 20, cornerRadius: 24, shadowY: 8) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 8) {
					WorkspacePanelHeader(
						title: title,
						subtitle: subtitle,
						accent: accent,
						icon: laneIcon(for: title),
						value: "\(tasks.count)"
					)
					Spacer(minLength: 0)
					Button {
						quickCreateTask(status: status)
					} label: {
						Image(systemName: "plus.circle.fill")
							.font(.system(size: 20, weight: .semibold))
							.foregroundStyle(accent)
					}
					.buttonStyle(.plain)
					.help("新建\(title)任务")
				}

				if tasks.isEmpty {
					WorkspaceSelectableCard(accent: accent) {
						Text(searchText.isEmpty ? "当前没有任务" : "当前筛选没有结果")
							.font(.subheadline)
							.foregroundStyle(WorkspaceTheme.mutedText)
							.frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
					}
				} else {
					ScrollView {
						LazyVStack(alignment: .leading, spacing: 12) {
							ForEach(tasks) { task in
								ExecutionBoardTaskCard(
									task: task,
									isSelected: isSelected(task),
									accent: accent,
									onSelect: { selectedTask = task },
									onDelete: { deleteTask(task) }
								)
								.contextMenu {
									Button("编辑") { selectedTask = task }
									Menu("移动到") {
										ForEach(TaskStatus.allCases, id: \.self) { st in
											if st != task.status {
												Button(st.rawValue) {
													task.status = st
													try? modelContext.save()
												}
											}
										}
									}
									Divider()
									Button("删除", role: .destructive) { deleteTask(task) }
								}
							}
						}
						.padding(.vertical, 2)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
	}

	private func quickCreateTask(status: TaskStatus) {
		let task = TaskItem(title: "新任务", status: status)
		modelContext.insert(task)
		try? modelContext.save()
		selectedTask = task
	}

	private func quickCreateProject() {
		let base = "新项目"
		var candidate = base
		var index = 1
		while projects.contains(where: { $0.name == candidate }) {
			index += 1
			candidate = "\(base)\(index)"
		}
		let project = ExecutionProject(name: candidate, horizon: .shortTerm)
		modelContext.insert(project)
		try? modelContext.save()
		isManagingProjects = true
	}

	private func deleteProjectInline(_ project: ExecutionProject) {
		for task in tasks where task.projectName == project.name {
			task.projectName = ""
		}
		modelContext.delete(project)
		try? modelContext.save()
	}

	private var projectBoardColumn: some View {
		WorkspaceCard(accent: .teal, padding: 20, cornerRadius: 24, shadowY: 8) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 8) {
					WorkspacePanelHeader(
						title: "Projects",
						subtitle: "短中长期推进视角",
						accent: .teal,
						icon: "folder",
						value: "\(projects.count)"
					)
					Spacer(minLength: 0)
					Button {
						quickCreateProject()
					} label: {
						Image(systemName: "plus.circle.fill")
							.font(.system(size: 20, weight: .semibold))
							.foregroundStyle(.teal)
					}
					.buttonStyle(.plain)
					.help("新建项目")
				}

				HStack(spacing: 8) {
					ProjectCountPill(title: "短期", count: shortTermProjects.count, color: WorkspaceTheme.moduleAccent(for: .execution))
					ProjectCountPill(title: "中期", count: midTermProjects.count, color: .blue)
					ProjectCountPill(title: "长期", count: longTermProjects.count, color: .green)
					ProjectCountPill(title: "未开始", count: notStartedProjects.count, color: .gray)
					ProjectCountPill(title: "进行中", count: inProgressProjects.count, color: .indigo)
					ProjectCountPill(title: "已暂停", count: pausedProjects.count, color: .orange)
					Spacer(minLength: 0)
				}

				if projects.isEmpty {
					WorkspaceSelectableCard(accent: .teal) {
						Text("创建第一个项目")
							.font(.subheadline)
							.foregroundStyle(WorkspaceTheme.mutedText)
							.frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
					}
						.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
						.onTapGesture {
							isManagingProjects = true
						}
				} else {
					ScrollView {
						LazyVStack(alignment: .leading, spacing: 10) {
							ForEach(projects) { project in
								WorkspaceSelectableCard(accent: .teal, cornerRadius: 18, padding: 14) {
									HStack(alignment: .center, spacing: 10) {
										// LEFT: horizon + status tags
										HStack(spacing: 6) {
											projectTag(project.horizon.rawValue, color: horizonColor(project.horizon))
											projectTag(project.status.rawValue, color: statusColor(project.status))
										}
										.fixedSize()

										// CENTER: name + description
										VStack(alignment: .leading, spacing: 3) {
											Text(project.name)
												.font(.subheadline.weight(.semibold))
												.foregroundStyle(WorkspaceTheme.strongText)
											Text(project.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "项目说明暂未填写" : project.detail)
												.font(.caption)
												.foregroundStyle(WorkspaceTheme.mutedText)
												.lineLimit(1)
										}
										.frame(maxWidth: .infinity, alignment: .leading)

										// RIGHT: edit + delete
										HStack(spacing: 6) {
											Button {
												isManagingProjects = true
											} label: {
												Image(systemName: "square.and.pencil")
													.font(.system(size: 12, weight: .semibold))
													.foregroundStyle(.teal)
											}
											.buttonStyle(.plain)
											.help("编辑")
											Button(role: .destructive) {
												deleteProjectInline(project)
											} label: {
												Image(systemName: "trash")
													.font(.system(size: 12, weight: .semibold))
													.foregroundStyle(.red)
											}
											.buttonStyle(.plain)
											.help("删除")
										}
									}
								}
								.contextMenu {
									Button("编辑") { isManagingProjects = true }
									Button("删除", role: .destructive) { deleteProjectInline(project) }
								}
							}
						}
						.padding(.vertical, 2)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
	}

	@ViewBuilder
	private func projectTag(_ label: String, color: Color) -> some View {
		Text(label)
			.font(.caption2.weight(.semibold))
			.foregroundStyle(color)
			.padding(.horizontal, 7)
			.padding(.vertical, 3)
			.background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 6, style: .continuous)
					.stroke(color.opacity(0.25), lineWidth: 0.5)
			)
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
		case .finished:   return .teal
		case .paused:     return .orange
		}
	}

	private func deleteTask(_ task: TaskItem) {
		if selectedTask?.id == task.id {
			selectedTask = nil
		}
		modelContext.delete(task)
	}

	private func taskFilterChip(_ filter: TaskFilter) -> some View {
		let isSelected = selectedFilter == filter
		return Text(filter.rawValue)
			.font(.subheadline.weight(isSelected ? .semibold : .medium))
			.foregroundStyle(isSelected ? Color.white : WorkspaceTheme.strongText)
			.padding(.horizontal, 14)
			.padding(.vertical, 7)
			.background(isSelected ? WorkspaceTheme.moduleAccent(for: .execution) : WorkspaceTheme.elevatedSurface)
			.clipShape(Capsule())
			.contentShape(Capsule())
			.onTapGesture {
				selectedFilter = filter
			}
	}

	private func laneIcon(for title: String) -> String {
		switch title {
		case "To-do":
			return "list.bullet.circle"
		case "In Progress":
			return "play.circle"
		case "Done":
			return "checkmark.circle"
		default:
			return "square.grid.2x2"
		}
	}
}

private struct ExecutionBoardTaskCard: View {
	@Bindable var task: TaskItem
	let isSelected: Bool
	let accent: Color
	let onSelect: () -> Void
	let onDelete: () -> Void

	var body: some View {
		WorkspaceSelectableCard(accent: accent, isSelected: isSelected, cornerRadius: 20, padding: 14) {
			HStack(alignment: .top, spacing: 10) {
				statusControl

				VStack(alignment: .leading, spacing: 5) {
					Text(task.title)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
						.lineLimit(2)

					if !task.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						Text(task.projectName)
							.font(.caption)
							.foregroundStyle(WorkspaceTheme.mutedText)
					}
				}

				Spacer(minLength: 0)
			}

			if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				Text(task.notes)
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.lineLimit(3)
			}

			HStack(spacing: 8) {
				if let due = task.dueDate {
					WorkspaceInlineStat(
						title: "Due",
						value: AppDateFormatter.ymd(due),
						accent: due < Date() && !task.isDone ? .red : accent
					)
				}

				if !task.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					WorkspaceInlineStat(title: "分类", value: task.category, accent: accent)
				}

				Spacer(minLength: 0)
			}
		}
		.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		.onTapGesture(perform: onSelect)
		.contextMenu {
			Button("标记为待办") {
				task.status = .todo
				task.completedAt = nil
			}
			Button("标记为进行中") {
				task.status = .inProgress
				task.completedAt = nil
			}
			Button("标记为已完成") {
				task.status = .done
				task.completedAt = Date()
			}
			Divider()
			Button(role: .destructive) {
				onDelete()
			} label: {
				Label("删除任务", systemImage: "trash")
			}
		}
	}

	private var statusControl: some View {
		ZStack {
			Circle()
				.fill(accent.opacity(0.10))
				.frame(width: 30, height: 30)
			Image(systemName: statusIcon)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(statusColor)
		}
		.contentShape(Circle())
		.onTapGesture {
			advanceStatus()
		}
	}

	private func advanceStatus() {
		switch task.status {
		case .todo:
			task.status = .inProgress
			task.completedAt = nil
		case .inProgress:
			task.status = .done
			task.completedAt = Date()
		case .done:
			task.status = .todo
			task.completedAt = nil
		}
	}

	private var statusIcon: String {
		switch task.status {
		case .todo:
			return "circle"
		case .inProgress:
			return "circle.dotted.circle"
		case .done:
			return "checkmark.circle.fill"
		}
	}

	private var statusColor: Color {
		switch task.status {
		case .todo:
			return WorkspaceTheme.moduleAccent(for: .execution)
		case .inProgress:
			return .blue
		case .done:
			return .green
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

//
//  TaskDetailView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Query private var allTasks: [TaskItem]
	@Query private var projects: [ExecutionProject]
	@Binding var selectedTask: TaskItem?
	@Bindable var task: TaskItem
	@StateObject private var aiService = AIService()
	@State private var isGeneratingSuggestion = false
	@State private var suggestionTask: _Concurrency.Task<Void, Never>?
	@State private var suggestionRequestID = 0

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// 标题
				TextField("任务标题", text: $task.title)
					.font(.title2.bold())
					.textFieldStyle(.plain)

				Divider()

				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 16) {
						Label("时间", systemImage: "clock")
							.foregroundStyle(.secondary)
						Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
							.foregroundStyle(.secondary)
					}
					.font(.subheadline)

					HStack(spacing: 16) {
						Label("状态", systemImage: "flag")
							.foregroundStyle(.secondary)
							.frame(width: 54, alignment: .trailing)
						Picker("", selection: $task.status) {
							ForEach(TaskStatus.allCases, id: \.self) { s in
								Text(s.rawValue).tag(s)
							}
						}
						.pickerStyle(.segmented)
						.frame(maxWidth: 300)
					}

					HStack(spacing: 12) {
						Label("项目", systemImage: "folder")
							.foregroundStyle(.secondary)
							.frame(width: 54, alignment: .trailing)
						TextField("所属项目", text: $task.projectName)
							.textFieldStyle(.roundedBorder)
						if !existingProjectNames.isEmpty {
							Menu("选择") {
								Button("收件箱") { task.projectName = "" }
								ForEach(existingProjectNames, id: \.self) { name in
									Button(name) { task.projectName = name }
								}
							}
						}
						Button("自动归类") {
							scheduleSuggestion(force: true)
						}
						.buttonStyle(.borderless)
					}

					HStack(spacing: 12) {
						Label("分类", systemImage: "square.grid.2x2")
							.foregroundStyle(.secondary)
							.frame(width: 54, alignment: .trailing)
						TextField("AI 自动生成，可修改", text: $task.category)
							.textFieldStyle(.roundedBorder)
					}

					HStack(spacing: 12) {
						Label("Tag", systemImage: "tag")
							.foregroundStyle(.secondary)
							.frame(width: 54, alignment: .trailing)
						TextField("逗号分隔，AI 自动生成，可修改", text: $task.tagsText)
							.textFieldStyle(.roundedBorder)
					}

					Toggle("设置截止日期", isOn: hasDueDateBinding)
					if task.dueDate != nil {
						DatePicker(
							"截止日期",
							selection: dueDateBinding,
							displayedComponents: .date
						)
						.datePickerStyle(.field)
						Text("日期：\(AppDateFormatter.ymd(dueDateBinding.wrappedValue))")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}

					if isGeneratingSuggestion {
						HStack(spacing: 8) {
							ProgressView().scaleEffect(0.7)
							Text("AI 正在更新分类、标签和项目建议…")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}

				Divider()

				// 备注
				VStack(alignment: .leading, spacing: 8) {
					Label("备注", systemImage: "note.text")
						.font(.headline)
					TextEditor(text: $task.notes)
						.frame(minHeight: 120)
						.padding(8)
						.background(Color(nsColor: .textBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 10))
						.overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
				}

				Spacer()

				// 删除按钮
				Button(role: .destructive) {
					if selectedTask?.id == task.id {
						selectedTask = nil
					}
					modelContext.delete(task)
				} label: {
					Label("删除任务", systemImage: "trash")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
			}
			.padding(28)
		}
		.navigationTitle(task.title.isEmpty ? "任务详情" : task.title)
		.onAppear {
			scheduleSuggestion(force: false)
		}
		.onChange(of: task.title) { _, _ in
			scheduleSuggestion(force: false)
		}
		.onChange(of: task.notes) { _, _ in
			scheduleSuggestion(force: false)
		}
		.onChange(of: task.status) { _, newStatus in
			if newStatus == .done && task.completedAt == nil {
				task.completedAt = Date()
			}
			if newStatus != .done {
				task.completedAt = nil
			}
		}
		.onDisappear {
			suggestionTask?.cancel()
			ensureProjectExistsIfNeeded()
		}
	}

	private var existingProjectNames: [String] {
		Array(Set(
			allTasks.map { $0.projectName.trimmingCharacters(in: .whitespacesAndNewlines) }
			+ projects.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
		))
			.filter { !$0.isEmpty }
			.sorted()
	}

	private var hasDueDateBinding: Binding<Bool> {
		Binding(
			get: { task.dueDate != nil },
			set: { enabled in
				if enabled {
					task.dueDate = task.dueDate ?? Date()
				} else {
					task.dueDate = nil
				}
			}
		)
	}

	private var dueDateBinding: Binding<Date> {
		Binding(
			get: { task.dueDate ?? Date() },
			set: { task.dueDate = $0 }
		)
	}

	private func scheduleSuggestion(force: Bool) {
		suggestionTask?.cancel()
		let normalizedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedNotes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
		let hasContent = !normalizedTitle.isEmpty || !normalizedNotes.isEmpty
		guard hasContent else {
			isGeneratingSuggestion = false
			return
		}
		let needsAutoFill =
			task.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
			task.tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
			task.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		guard force || needsAutoFill else { return }

		suggestionRequestID += 1
		let requestID = suggestionRequestID
		suggestionTask = _Concurrency.Task {
			if !force {
				try? await _Concurrency.Task.sleep(nanoseconds: 600_000_000)
			}
			guard !_Concurrency.Task.isCancelled else { return }
			await runSuggestion(
				title: normalizedTitle,
				notes: normalizedNotes,
				requestID: requestID,
				force: force
			)
		}
	}

	@MainActor
	private func runSuggestion(title: String, notes: String, requestID: Int, force: Bool) async {
		isGeneratingSuggestion = true
		let suggestion = await aiService.suggestTaskMetadata(
			title: title,
			notes: notes,
			existingProjects: existingProjectNames,
			currentProject: task.projectName
		)
		guard requestID == suggestionRequestID else { return }

		if force || task.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			task.category = suggestion.category
		}
		if force || task.tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			task.tagsText = suggestion.tags.joined(separator: ", ")
		}
		if force || task.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			task.projectName = suggestion.projectName == "收件箱" ? "" : suggestion.projectName
		}
		isGeneratingSuggestion = false
	}

	private func ensureProjectExistsIfNeeded() {
		let normalized = task.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return }
		if !projects.contains(where: { $0.name == normalized }) {
			modelContext.insert(ExecutionProject(name: normalized, horizon: .shortTerm))
		}
	}
}

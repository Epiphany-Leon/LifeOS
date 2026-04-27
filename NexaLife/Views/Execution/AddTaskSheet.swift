//
//  AddTaskSheet.swift
//  NexaLife
//
//  Extracted from ExecutionView.swift on 2026-04-27 for readability.
//

import SwiftUI
import SwiftData

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
	@State private var suggestionTask: Task<Void, Never>?
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
					Task { await saveTask() }
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
		suggestionTask = Task {
			if !force {
				try? await Task.sleep(nanoseconds: 500_000_000)
			}
			guard !Task.isCancelled else { return }
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

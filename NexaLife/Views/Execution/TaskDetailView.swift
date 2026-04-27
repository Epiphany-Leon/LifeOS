//
//  TaskDetailView.swift
//  NexaLife
//
//  v0.2.0 — 严格按 WorkspaceTheme / WorkspaceCard 设计语言
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale
	@Query private var allTasks: [TaskItem]
	@Query private var projects: [ExecutionProject]
	@Binding var selectedTask: TaskItem?
	@Bindable var task: TaskItem
	@StateObject private var aiService = AIService()
	@State private var isGeneratingSuggestion = false
	@State private var suggestionTask: _Concurrency.Task<Void, Never>?
	@State private var suggestionRequestID = 0

	private var accent: Color { WorkspaceTheme.moduleAccent(for: .execution) }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 22) {
				headerCard
				attributesCard
				notesCard
				deleteCard
			}
			.padding(.horizontal, 28)
			.padding(.vertical, 24)
		}
		.background(WorkspaceTheme.surface)
		.onAppear { scheduleSuggestion(force: false) }
		.onChange(of: task.title) { _, _ in scheduleSuggestion(force: false) }
		.onChange(of: task.notes) { _, _ in scheduleSuggestion(force: false) }
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

	// MARK: - Header

	private var headerCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 8) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 14) {
					WorkspaceIconBadge(icon: "target", accent: accent, size: 38)
					VStack(alignment: .leading, spacing: 4) {
						TextField(AppBrand.localized("任务标题", "Task title", locale: locale), text: $task.title)
							.font(.system(size: 22, weight: .bold, design: .rounded))
							.textFieldStyle(.plain)
							.foregroundStyle(WorkspaceTheme.strongText)
						HStack(spacing: 6) {
							Image(systemName: "clock")
								.font(.caption2)
							Text(AppDateFormatter.ymd(task.createdAt))
								.font(.caption)
						}
						.foregroundStyle(WorkspaceTheme.mutedText)
					}
					Spacer()
					statusPill
				}

				Divider()
					.background(WorkspaceTheme.divider)

				Picker("", selection: $task.status) {
					ForEach(TaskStatus.allCases, id: \.self) { s in
						Text(s.rawValue).tag(s)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}
		}
	}

	private var statusPill: some View {
		let (label, color): (String, Color) = {
			switch task.status {
			case .todo:       return ("待办", .orange)
			case .inProgress: return ("进行中", .blue)
			case .done:       return ("已完成", .green)
			}
		}()
		return WorkspacePill(title: label, accent: color, isFilled: task.status == .done)
	}

	// MARK: - Attributes

	private var attributesCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 16) {
				WorkspacePanelHeader(
					title: AppBrand.localized("属性", "Attributes", locale: locale),
					subtitle: isGeneratingSuggestion
						? AppBrand.localized("AI 正在更新分类、标签和项目建议…", "Updating category, tags & project…", locale: locale)
						: AppBrand.localized("AI 自动归类，可手动覆盖", "Auto-classified, manually overridable", locale: locale),
					accent: accent,
					icon: "slider.horizontal.3"
				)

				attributeRow(
					icon: "folder",
					label: AppBrand.localized("项目", "Project", locale: locale)
				) {
					HStack(spacing: 8) {
						// Combobox: text field + project picker dropdown in one control
						HStack(spacing: 0) {
							TextField(
								AppBrand.localized("输入或选择项目", "Type or pick project", locale: locale),
								text: $task.projectName
							)
							.textFieldStyle(.plain)
							.padding(.leading, 10)
							.padding(.vertical, 7)

							if !existingProjectNames.isEmpty {
								Divider().frame(height: 18)
								Menu {
									Button(AppBrand.localized("收件箱（无项目）", "Inbox (no project)", locale: locale)) {
										task.projectName = ""
									}
									Divider()
									ForEach(existingProjectNames, id: \.self) { name in
										Button(name) { task.projectName = name }
									}
								} label: {
									Image(systemName: "chevron.up.chevron.down")
										.font(.caption.weight(.semibold))
										.foregroundStyle(.secondary)
										.padding(.horizontal, 10)
										.padding(.vertical, 7)
								}
								.menuStyle(.borderlessButton)
								.menuIndicator(.hidden)
								.fixedSize()
							}
						}
						.background(Color(nsColor: .controlBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
						.overlay(
							RoundedRectangle(cornerRadius: 8, style: .continuous)
								.stroke(Color.secondary.opacity(0.2), lineWidth: 1)
						)

						Button {
							scheduleSuggestion(force: true)
						} label: {
							Image(systemName: "wand.and.stars")
								.font(.system(size: 12, weight: .semibold))
								.foregroundStyle(.purple)
								.frame(width: 28, height: 28)
								.background(Color.purple.opacity(0.10), in: Circle())
						}
						.buttonStyle(.plain)
						.help(AppBrand.localized("AI 自动归类", "AI auto-classify", locale: locale))
					}
				}

				attributeRow(
					icon: "square.grid.2x2",
					label: AppBrand.localized("分类", "Category", locale: locale)
				) {
					TextField(
						AppBrand.localized("AI 自动生成，可修改", "AI auto, editable", locale: locale),
						text: $task.category
					)
					.textFieldStyle(.roundedBorder)
				}

				attributeRow(
					icon: "tag",
					label: "Tag"
				) {
					TextField(
						AppBrand.localized("逗号分隔，AI 自动生成", "Comma-separated, AI auto", locale: locale),
						text: $task.tagsText
					)
					.textFieldStyle(.roundedBorder)
				}

				attributeRow(
					icon: "calendar",
					label: AppBrand.localized("截止", "Due", locale: locale)
				) {
					HStack(spacing: 10) {
						Toggle("", isOn: hasDueDateBinding)
							.toggleStyle(.switch)
							.labelsHidden()

						if task.dueDate != nil {
							DatePicker("", selection: dueDateBinding, displayedComponents: .date)
								.datePickerStyle(.compact)
								.labelsHidden()
							Spacer(minLength: 0)
						} else {
							Text(AppBrand.localized("未设置", "Not set", locale: locale))
								.font(.caption)
								.foregroundStyle(WorkspaceTheme.mutedText)
							Spacer()
						}
					}
				}
			}
		}
	}

	@ViewBuilder
	private func attributeRow<Content: View>(
		icon: String,
		label: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		HStack(alignment: .center, spacing: 12) {
			HStack(spacing: 6) {
				Image(systemName: icon)
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(accent)
				Text(label)
					.font(.system(size: 13, weight: .medium))
					.foregroundStyle(WorkspaceTheme.mutedText)
			}
			.frame(width: 76, alignment: .leading)

			content()
		}
	}

	// MARK: - Notes

	private var notesCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				WorkspacePanelHeader(
					title: AppBrand.localized("备注", "Notes", locale: locale),
					subtitle: AppBrand.localized("Markdown 自动保存", "Markdown · autosaved", locale: locale),
					accent: accent,
					icon: "note.text"
				)

				TextEditor(text: $task.notes)
					.font(.system(size: 13))
					.scrollContentBackground(.hidden)
					.frame(minHeight: 140)
					.padding(12)
					.background(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.fill(WorkspaceTheme.elevatedSurface)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.stroke(WorkspaceTheme.border, lineWidth: 1)
					)
			}
		}
	}

	// MARK: - Delete

	private var deleteCard: some View {
		HStack {
			Spacer()
			WorkspaceActionButton(
				title: AppBrand.localized("删除任务", "Delete task", locale: locale),
				icon: "trash",
				accent: .red,
				isPrimary: false
			) {
				if selectedTask?.id == task.id {
					selectedTask = nil
				}
				modelContext.delete(task)
			}
		}
	}

	// MARK: - Bindings & helpers

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

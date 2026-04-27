//
//  NoteDetailView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum MarkdownEditorMode: String, CaseIterable, Identifiable {
	case edit = "编辑"
	case preview = "预览"
	case split = "分栏"

	var id: String { rawValue }
}

struct NoteDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale
	@Binding var selectedNote: Note?
	@Bindable var note: Note
	@StateObject private var aiService = AIService()

	@State private var isGeneratingReport = false
	@State private var generatedReport: String = ""
	@State private var editorMode: MarkdownEditorMode = .split
	@State private var isImportingMarkdown = false
	@State private var markdownImportError: String?
	@State private var draftTagInput: String = ""

	private var accent: Color { WorkspaceTheme.moduleAccent(for: .knowledge) }

	private var markdownContentTypes: [UTType] {
		var types: [UTType] = [.plainText]
		if let md = UTType(filenameExtension: "md") {
			types.insert(md, at: 0)
		}
		return types
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 22) {
				headerSection
				markdownSection
				aiSection
				deleteSection
			}
			.padding(.horizontal, 28)
			.padding(.vertical, 24)
		}
		.background(WorkspaceTheme.surface)
		.fileImporter(
			isPresented: $isImportingMarkdown,
			allowedContentTypes: markdownContentTypes,
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				guard let url = urls.first else { return }
				importMarkdownFile(from: url)
			case .failure(let error):
				markdownImportError = error.localizedDescription
			}
		}
		.alert(
			"导入失败",
			isPresented: Binding(
				get: { markdownImportError != nil },
				set: { newValue in
					if !newValue { markdownImportError = nil }
				}
			)
		) {
			Button("确定", role: .cancel) {}
		} message: {
			Text(markdownImportError ?? "未知错误")
		}
	}

	private var headerSection: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 8) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 14) {
					WorkspaceIconBadge(icon: "book", accent: accent, size: 38)
					VStack(alignment: .leading, spacing: 4) {
						TextField(AppBrand.localized("笔记标题", "Note title", locale: locale), text: $note.title)
							.font(.system(size: 22, weight: .bold, design: .rounded))
							.textFieldStyle(.plain)
							.foregroundStyle(WorkspaceTheme.strongText)
							.onChange(of: note.title) { _, _ in note.updatedAt = Date() }
						HStack(spacing: 12) {
							Label("创建 " + AppDateFormatter.ymd(note.createdAt), systemImage: "calendar.badge.plus")
							Label("更新 " + AppDateFormatter.ymd(note.updatedAt), systemImage: "clock")
						}
						.font(.system(size: 11))
						.foregroundStyle(WorkspaceTheme.mutedText)
					}
					Spacer()
					WorkspaceActionButton(
						title: AppBrand.localized("新建", "New", locale: locale),
						icon: "plus",
						accent: accent,
						isPrimary: true,
						action: createBlankNote
					)
				}

				Divider()
					.background(WorkspaceTheme.divider)

				VStack(alignment: .leading, spacing: 10) {
					HStack(spacing: 6) {
						Image(systemName: "tag")
							.font(.system(size: 11, weight: .medium))
							.foregroundStyle(accent)
						Text(AppBrand.localized("主题", "Topic Tags", locale: locale))
							.font(.system(size: 12, weight: .semibold))
							.foregroundStyle(WorkspaceTheme.mutedText)
					}

					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 6) {
							ForEach(topicTags, id: \.self) { tag in
								HStack(spacing: 4) {
									Text(tag).font(.caption.weight(.semibold))
									Button {
										removeTag(tag)
									} label: {
										Image(systemName: "xmark.circle.fill")
											.font(.caption2)
									}
									.buttonStyle(.plain)
								}
								.foregroundStyle(accent)
								.padding(.horizontal, 10)
								.padding(.vertical, 5)
								.background(Capsule().fill(accent.opacity(0.10)))
							}
							if topicTags.isEmpty {
								Text(AppBrand.localized("未分类", "Uncategorized", locale: locale))
									.font(.caption)
									.foregroundStyle(WorkspaceTheme.mutedText)
									.padding(.horizontal, 10)
									.padding(.vertical, 5)
									.background(Capsule().fill(WorkspaceTheme.elevatedSurface))
							}
						}
					}

					HStack(spacing: 8) {
						TextField(
							AppBrand.localized("输入主题后回车，支持逗号分隔", "Type and press return; comma to split", locale: locale),
							text: $draftTagInput
						)
						.textFieldStyle(.roundedBorder)
						.onSubmit { addTagsFromInput() }

						Button(AppBrand.localized("添加", "Add", locale: locale)) {
							addTagsFromInput()
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
						.disabled(draftTagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					}
				}
			}
		}
	}

	private var deleteSection: some View {
		HStack {
			Spacer()
			WorkspaceActionButton(
				title: AppBrand.localized("删除笔记", "Delete note", locale: locale),
				icon: "trash",
				accent: .red,
				isPrimary: false
			) {
				selectedNote = nil
				modelContext.delete(note)
			}
		}
	}

	private var markdownSection: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 12) {
					WorkspacePanelHeader(
						title: AppBrand.localized("正文 Markdown", "Markdown Body", locale: locale),
						subtitle: AppBrand.localized("编辑/预览/分栏自动保存", "Edit · Preview · Split — autosaved", locale: locale),
						accent: accent,
						icon: "doc.text"
					)
					Picker("", selection: $editorMode) {
						ForEach(MarkdownEditorMode.allCases) { mode in
							Text(mode.rawValue).tag(mode)
						}
					}
					.pickerStyle(.segmented)
					.frame(width: 190)
					.labelsHidden()
					Button {
						isImportingMarkdown = true
					} label: {
						Image(systemName: "tray.and.arrow.down")
							.font(.system(size: 12, weight: .semibold))
							.foregroundStyle(accent)
							.frame(width: 28, height: 28)
							.background(accent.opacity(0.10), in: Circle())
					}
					.buttonStyle(.plain)
					.help(AppBrand.localized("导入 .md", "Import .md", locale: locale))
				}

				markdownToolbar

				Group {
					switch editorMode {
					case .edit:
						editorPane
					case .preview:
						previewPane
					case .split:
						HStack(spacing: 12) {
							editorPane
							previewPane
						}
					}
				}
			}
		}
	}

	private var markdownToolbar: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				MarkdownSnippetButton(label: "H1") {
					appendHeading(level: 1)
				}
				MarkdownSnippetButton(label: "H2") {
					appendHeading(level: 2)
				}
				MarkdownSnippetButton(label: "H3") {
					appendHeading(level: 3)
				}
				MarkdownSnippetButton(label: "粗体") {
					appendMarkdownSnippet("**重点内容**")
				}
				MarkdownSnippetButton(label: "斜体") {
					appendMarkdownSnippet("_补充说明_")
				}
				MarkdownSnippetButton(label: "列表") {
					appendMarkdownSnippet("- 条目 1\n- 条目 2")
				}
				MarkdownSnippetButton(label: "引用") {
					appendMarkdownSnippet("> 一段引用内容")
				}
				MarkdownSnippetButton(label: "代码") {
					appendMarkdownSnippet("```swift\nprint(\"Hello\")\n```")
				}
				MarkdownSnippetButton(label: "链接") {
					appendMarkdownSnippet("[链接标题](https://example.com)")
				}
			}
			.padding(.vertical, 2)
		}
	}

	private var editorPane: some View {
		TextEditor(text: $note.content)
			.font(.system(size: 13, design: .monospaced))
			.scrollContentBackground(.hidden)
			.frame(minHeight: 320)
			.padding(12)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(WorkspaceTheme.elevatedSurface)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(WorkspaceTheme.border, lineWidth: 1)
			)
			.onChange(of: note.content) { _, _ in
				note.updatedAt = Date()
			}
	}

	private var previewPane: some View {
		ScrollView {
			Group {
				if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					Text(AppBrand.localized("Markdown 预览会显示在这里", "Markdown preview shows here", locale: locale))
						.foregroundStyle(WorkspaceTheme.mutedText)
						.frame(maxWidth: .infinity, alignment: .leading)
				} else {
					MarkdownBlockPreview(markdown: note.content)
				}
			}
			.padding(14)
		}
		.frame(minHeight: 320)
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(WorkspaceTheme.subtleSurface)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.stroke(WorkspaceTheme.border, lineWidth: 1)
		)
	}

	private var aiSection: some View {
		WorkspaceCard(accent: .purple, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					WorkspacePanelHeader(
						title: AppBrand.localized("AI 专题报告", "AI Insight Report", locale: locale),
						subtitle: AppBrand.localized("基于本笔记内容生成结构化总结", "Structured summary from this note", locale: locale),
						accent: .purple,
						icon: "sparkles"
					)
					Button {
						generateAIReport()
					} label: {
						HStack(spacing: 6) {
							if isGeneratingReport {
								ProgressView().scaleEffect(0.6)
								Text(AppBrand.localized("生成中…", "Generating…", locale: locale))
									.font(.caption.weight(.semibold))
							} else {
								Image(systemName: "wand.and.stars")
									.font(.system(size: 11, weight: .semibold))
								Text(AppBrand.localized("生成报告", "Generate", locale: locale))
									.font(.caption.weight(.semibold))
							}
						}
						.foregroundStyle(Color.white)
						.padding(.horizontal, 12)
						.padding(.vertical, 7)
						.background(Capsule().fill(Color.purple))
					}
					.buttonStyle(.plain)
					.disabled(isGeneratingReport || note.content.isEmpty)
				}

				if !generatedReport.isEmpty {
					Text(generatedReport)
						.font(.system(size: 13))
						.foregroundStyle(WorkspaceTheme.strongText)
						.padding(14)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(Color.purple.opacity(0.06))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.stroke(Color.purple.opacity(0.18), lineWidth: 1)
						)

					HStack(spacing: 10) {
						WorkspaceActionButton(
							title: AppBrand.localized("存入 Knowledge", "Save to Knowledge", locale: locale),
							icon: "book",
							accent: WorkspaceTheme.moduleAccent(for: .knowledge),
							isPrimary: false
						) { archiveReport(to: "Knowledge") }

						WorkspaceActionButton(
							title: AppBrand.localized("存入 Vitals", "Save to Vitals", locale: locale),
							icon: "sparkles",
							accent: WorkspaceTheme.moduleAccent(for: .vitals),
							isPrimary: false
						) { archiveReport(to: "Vitals") }

						Spacer()

						Button {
							generatedReport = ""
						} label: {
							Image(systemName: "xmark.circle.fill")
								.font(.system(size: 14))
								.foregroundStyle(WorkspaceTheme.mutedText)
						}
						.buttonStyle(.plain)
						.help(AppBrand.localized("关闭报告", "Dismiss", locale: locale))
					}
				}
			}
		}
	}

	private func createBlankNote() {
		let newNote = Note(title: "新笔记")
		modelContext.insert(newNote)
		selectedNote = newNote
	}

	private var topicTags: [String] {
		KnowledgeTagCodec.parse(note.topic)
	}

	private func addTagsFromInput() {
		let inputTags = KnowledgeTagCodec.parse(draftTagInput)
		guard !inputTags.isEmpty else { return }
		var merged = topicTags
		for tag in inputTags where !merged.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
			merged.append(tag)
		}
		note.topic = KnowledgeTagCodec.serialize(merged)
		note.updatedAt = Date()
		draftTagInput = ""
	}

	private func removeTag(_ tag: String) {
		let next = topicTags.filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
		note.topic = KnowledgeTagCodec.serialize(next)
		note.updatedAt = Date()
	}

	private func appendHeading(level: Int) {
		let normalizedLevel = min(3, max(1, level))
		let prefix = String(repeating: "#", count: normalizedLevel)
		appendMarkdownSnippet("\(prefix) 标题")
	}

	private func appendMarkdownSnippet(_ snippet: String) {
		let existing = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
		if existing.isEmpty {
			note.content = snippet
		} else {
			note.content += "\n\n" + snippet
		}
		note.updatedAt = Date()
	}

	private func importMarkdownFile(from url: URL) {
		let hasAccess = url.startAccessingSecurityScopedResource()
		defer {
			if hasAccess {
				url.stopAccessingSecurityScopedResource()
			}
		}

		do {
			let data = try Data(contentsOf: url)
			let imported = decodeText(from: data).trimmingCharacters(in: .newlines)
			guard !imported.isEmpty else {
				markdownImportError = "文件内容为空，无法导入。"
				return
			}
			note.content = imported
			if note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				note.title = url.deletingPathExtension().lastPathComponent
			}
			note.updatedAt = Date()
		} catch {
			markdownImportError = error.localizedDescription
		}
	}

	private func decodeText(from data: Data) -> String {
		let encodings: [String.Encoding] = [
			.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .unicode, .ascii
		]
		for encoding in encodings {
			if let content = String(data: data, encoding: encoding) {
				return content
			}
		}
		return String(decoding: data, as: UTF8.self)
	}

	private func generateAIReport() {
		isGeneratingReport = true
		Task {
			let report = await aiService.generateReport(
				entries: [note.title, note.content],
				type: "Knowledge"
			)
			await MainActor.run {
				generatedReport = report
				isGeneratingReport = false
			}
		}
	}

	private func archiveReport(to destination: String) {
		let archiveNote = Note(
			title: "【AI报告】\(note.title)",
			content: generatedReport,
			topic: destination == "Vitals" ? "Vitals Review" : note.topic
		)
		modelContext.insert(archiveNote)
		generatedReport = ""
	}
}

private struct MarkdownSnippetButton: View {
	var label: String
	var action: () -> Void

	@State private var isHovering = false

	var body: some View {
		Button(action: action) {
			Text(label)
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(WorkspaceTheme.strongText)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(
					Capsule().fill(isHovering ? WorkspaceTheme.subtleSurface : WorkspaceTheme.elevatedSurface)
				)
				.overlay(
					Capsule().stroke(WorkspaceTheme.border, lineWidth: 1)
				)
		}
		.buttonStyle(.plain)
		.onHover { isHovering = $0 }
	}
}

private enum MarkdownPreviewBlock: Equatable {
	case heading(level: Int, text: String)
	case paragraph(String)
	case listItem(String)
	case quote(String)
	case code(String)
	case spacer
}

private struct MarkdownBlockPreview: View {
	let markdown: String

	private var blocks: [MarkdownPreviewBlock] {
		Self.parseBlocks(from: markdown)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
				blockView(block)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private func blockView(_ block: MarkdownPreviewBlock) -> some View {
		switch block {
		case let .heading(level, text):
			inlineText(text)
				.font(headingFont(for: level))
				.frame(maxWidth: .infinity, alignment: .leading)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.top, level == 1 ? 4 : 2)

		case let .paragraph(text):
			inlineText(text)
				.font(.body)
				.frame(maxWidth: .infinity, alignment: .leading)
				.fixedSize(horizontal: false, vertical: true)

		case let .listItem(text):
			HStack(alignment: .top, spacing: 8) {
				Text("•")
					.font(.body.weight(.semibold))
				inlineText(text)
					.font(.body)
					.frame(maxWidth: .infinity, alignment: .leading)
					.fixedSize(horizontal: false, vertical: true)
			}

		case let .quote(text):
			HStack(alignment: .top, spacing: 10) {
				Rectangle()
					.fill(Color.secondary.opacity(0.35))
					.frame(width: 3)
				inlineText(text)
					.font(.body)
					.foregroundStyle(.secondary)
					.italic()
					.frame(maxWidth: .infinity, alignment: .leading)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.leading, 2)

		case let .code(code):
			ScrollView(.horizontal, showsIndicators: false) {
				Text(verbatim: code)
					.font(.system(.body, design: .monospaced))
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
					.padding(10)
			}
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))

		case .spacer:
			Color.clear.frame(height: 8)
		}
	}

	private func headingFont(for level: Int) -> Font {
		switch level {
		case 1:
			return .system(size: 27, weight: .bold)
		case 2:
			return .system(size: 23, weight: .bold)
		default:
			return .system(size: 20, weight: .semibold)
		}
	}

	private func inlineText(_ raw: String) -> Text {
		Text(.init(raw))
	}

	private static func parseBlocks(from markdown: String) -> [MarkdownPreviewBlock] {
		let normalized = markdown
			.replacingOccurrences(of: "\r\n", with: "\n")
			.replacingOccurrences(of: "\r", with: "\n")
		let lines = normalized.components(separatedBy: "\n")

		var blocks: [MarkdownPreviewBlock] = []
		var isInCodeFence = false
		var codeLines: [String] = []

		for rawLine in lines {
			let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

			if trimmed.hasPrefix("```") {
				if isInCodeFence {
					blocks.append(.code(codeLines.joined(separator: "\n")))
					codeLines.removeAll()
				}
				isInCodeFence.toggle()
				continue
			}

			if isInCodeFence {
				codeLines.append(rawLine)
				continue
			}

			if trimmed.isEmpty {
				if blocks.last != .spacer {
					blocks.append(.spacer)
				}
				continue
			}

			if trimmed.hasPrefix("### ") {
				blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
				continue
			}
			if trimmed.hasPrefix("## ") {
				blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
				continue
			}
			if trimmed.hasPrefix("# ") {
				blocks.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
				continue
			}

			if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
				blocks.append(.listItem(String(trimmed.dropFirst(2))))
				continue
			}

			if let orderedText = orderedListContent(from: trimmed) {
				blocks.append(.listItem(orderedText))
				continue
			}

			if trimmed.hasPrefix("> ") {
				blocks.append(.quote(String(trimmed.dropFirst(2))))
				continue
			}

			blocks.append(.paragraph(trimmed))
		}

		if !codeLines.isEmpty {
			blocks.append(.code(codeLines.joined(separator: "\n")))
		}

		while blocks.last == .spacer {
			blocks.removeLast()
		}

		return blocks
	}

	private static func orderedListContent(from line: String) -> String? {
		let components = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
		guard components.count == 2 else { return nil }
		guard let order = Int(components[0]), order > 0 else { return nil }
		let content = String(components[1]).trimmingCharacters(in: .whitespaces)
		guard !content.isEmpty else { return nil }
		return "\(order). \(content)"
	}
}

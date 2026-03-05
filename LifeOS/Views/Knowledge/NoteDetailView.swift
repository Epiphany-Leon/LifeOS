//
//  NoteDetailView.swift
//  LifeOS
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
	@Binding var selectedNote: Note?
	@Bindable var note: Note
	@StateObject private var aiService = AIService()

	@State private var isGeneratingReport = false
	@State private var generatedReport: String = ""
	@State private var editorMode: MarkdownEditorMode = .split
	@State private var isImportingMarkdown = false
	@State private var markdownImportError: String?
	@State private var draftTagInput: String = ""

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

				Divider()

				markdownSection

				Divider()

				aiSection

				Spacer()

				Button(role: .destructive) {
					selectedNote = nil
					modelContext.delete(note)
				} label: {
					Label("删除笔记", systemImage: "trash")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
			}
			.padding(28)
		}
		.navigationTitle(note.title.isEmpty ? "笔记详情" : note.title)
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
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .top, spacing: 10) {
				TextField("标题", text: $note.title)
					.font(.title.bold())
					.textFieldStyle(.plain)
					.onChange(of: note.title) { _, _ in
						note.updatedAt = Date()
					}

				Button {
					createBlankNote()
				} label: {
					Label("新建", systemImage: "plus")
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.small)
			}

			HStack(alignment: .top, spacing: 12) {
				VStack(alignment: .leading, spacing: 8) {
					Label("主题 Tags", systemImage: "tag")
						.font(.caption)
						.foregroundStyle(.secondary)

					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 6) {
							ForEach(topicTags, id: \.self) { tag in
								HStack(spacing: 4) {
									Text(tag)
										.font(.caption)
									Button {
										removeTag(tag)
									} label: {
										Image(systemName: "xmark.circle.fill")
											.font(.caption2)
											.foregroundStyle(.secondary)
									}
									.buttonStyle(.plain)
								}
								.padding(.horizontal, 8)
								.padding(.vertical, 4)
								.background(Color.blue.opacity(0.1))
								.foregroundStyle(.blue)
								.clipShape(Capsule())
							}

							if topicTags.isEmpty {
								Text("未分类")
									.font(.caption)
									.foregroundStyle(.secondary)
									.padding(.horizontal, 8)
									.padding(.vertical, 4)
									.background(Color(nsColor: .controlBackgroundColor))
									.clipShape(Capsule())
							}
						}
					}

					HStack(spacing: 8) {
						TextField("输入主题后回车，可添加多个（支持逗号分隔）", text: $draftTagInput)
							.textFieldStyle(.roundedBorder)
							.onSubmit {
								addTagsFromInput()
							}

						Button("添加") {
							addTagsFromInput()
						}
						.buttonStyle(.bordered)
						.controlSize(.small)
						.disabled(draftTagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					}
				}

				Spacer()

				VStack(alignment: .trailing, spacing: 2) {
					Text("创建 " + note.createdAt.formatted(date: .abbreviated, time: .omitted))
					Text("更新 " + note.updatedAt.formatted(date: .abbreviated, time: .shortened))
				}
				.font(.caption2)
				.foregroundStyle(.tertiary)
			}
		}
	}

	private var markdownSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Label("正文 Markdown", systemImage: "doc.text")
					.font(.headline)
				Spacer()
				Picker("编辑模式", selection: $editorMode) {
					ForEach(MarkdownEditorMode.allCases) { mode in
						Text(mode.rawValue).tag(mode)
					}
				}
				.pickerStyle(.segmented)
				.frame(width: 190)
				Button {
					isImportingMarkdown = true
				} label: {
					Label("导入 .md", systemImage: "tray.and.arrow.down")
				}
				.buttonStyle(.bordered)
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
			.font(.body.monospaced())
			.frame(minHeight: 320)
			.padding(10)
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.onChange(of: note.content) { _, _ in
				note.updatedAt = Date()
			}
	}

		private var previewPane: some View {
			ScrollView {
				Group {
					if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						Text("Markdown 预览会显示在这里")
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
					} else {
						MarkdownBlockPreview(markdown: note.content)
					}
				}
				.padding(12)
			}
			.frame(minHeight: 320)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}

	private var aiSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Label("AI 专题报告", systemImage: "sparkles")
					.font(.headline)
				Spacer()
				Button {
					generateAIReport()
				} label: {
					if isGeneratingReport {
						ProgressView()
							scaleEffect(0.7)
						Text("生成中…")
					} else {
						Label("生成报告", systemImage: "wand.and.stars")
					}
				}
				.buttonStyle(.bordered)
				.disabled(isGeneratingReport || note.content.isEmpty)
			}

			if !generatedReport.isEmpty {
				VStack(alignment: .leading, spacing: 10) {
					Text(generatedReport)
						.font(.body)
						.padding(14)
						.background(Color.purple.opacity(0.06))
						.clipShape(RoundedRectangle(cornerRadius: 10))

					HStack(spacing: 10) {
						Button {
							archiveReport(to: "Knowledge")
						} label: {
							Label("存入 Knowledge", systemImage: "book")
						}
						.buttonStyle(.bordered)
						.tint(.blue)

						Button {
							archiveReport(to: "Vitals")
						} label: {
							Label("存入 Vitals", systemImage: "sparkles")
						}
						.buttonStyle(.bordered)
						.tint(.purple)

						Spacer()

						Button {
							generatedReport = ""
						} label: {
							Image(systemName: "xmark")
						}
						.buttonStyle(.plain)
						.foregroundStyle(.secondary)
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

	var body: some View {
		Button(action: action) {
			Text(label)
				.font(.caption)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(Color(nsColor: .controlBackgroundColor))
				.clipShape(Capsule())
		}
		.buttonStyle(.plain)
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

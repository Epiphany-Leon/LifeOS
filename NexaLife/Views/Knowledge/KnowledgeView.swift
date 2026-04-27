//
//  KnowledgeView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct KnowledgeView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
	@Binding var selectedNote: Note?

	@State private var searchText = ""
	@State private var selectedTopics: Set<String> = []
	@State private var showTopicList = false

	private let calendar = Calendar.current

	private var allTopics: [String] {
		Set(notes.flatMap { tags(of: $0) }).sorted()
	}

	private var filteredNotes: [Note] {
		let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		return notes.filter { note in
			let noteTags = tags(of: note)
			let matchTopic = selectedTopics.isEmpty || !Set(noteTags).isDisjoint(with: selectedTopics)
			guard matchTopic else { return false }

			guard !keyword.isEmpty else { return true }
			let tagText = noteTags.joined(separator: " ")
			return note.title.localizedCaseInsensitiveContains(keyword)
				|| note.content.localizedCaseInsensitiveContains(keyword)
				|| tagText.localizedCaseInsensitiveContains(keyword)
		}
	}

	private var groupedNotes: [KnowledgeTopicSection] {
		let grouped = Dictionary(grouping: filteredNotes) { primaryTopic(of: $0) }
		return grouped.keys.sorted().map { topic in
			KnowledgeTopicSection(
				topic: topic,
				items: (grouped[topic] ?? []).sorted(by: { $0.updatedAt > $1.updatedAt })
			)
		}
	}

	private var topicCount: Int {
		allTopics.filter { $0 != "未分类" }.count
	}

	private var uncategorizedCount: Int {
		notes.filter { KnowledgeTagCodec.parse($0.topic).isEmpty }.count
	}

	private var categorizedCount: Int {
		max(notes.count - uncategorizedCount, 0)
	}

	private var updatedThisWeekCount: Int {
		guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
		return notes.filter { $0.updatedAt >= weekStart }.count
	}

	var body: some View {
		VStack(spacing: 0) {
			searchBar

			topicFilterBar

			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)

			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					LazyVGrid(
						columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 14)],
						alignment: .leading,
						spacing: 14
					) {
						WorkspaceMetricTile(
							title: "活跃主题",
							value: "\(topicCount)",
							subtitle: "已经沉淀为主题的知识入口",
							icon: "tag",
							accent: WorkspaceTheme.moduleAccent(for: .knowledge)
						)
						WorkspaceMetricTile(
							title: "未分类",
							value: "\(uncategorizedCount)",
							subtitle: "还可以继续整理归类的笔记",
							icon: "tray.full",
							accent: .indigo
						)
						WorkspaceMetricTile(
							title: "本周更新",
							value: "\(updatedThisWeekCount)",
							subtitle: "最近 7 天有继续推进的知识条目",
							icon: "clock.arrow.circlepath",
							accent: .teal
						)
					}

					noteWorkspacePanels
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 18)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
			.sheet(isPresented: $showTopicList) {
				TopicFilterListSheet(
					isPresented: $showTopicList,
					topics: allTopics,
					counts: topicCounts(),
					selectedTopics: $selectedTopics,
					totalCount: notes.count
				)
			}
			.onChange(of: notes.map(\.id)) { _, ids in
				if let selected = selectedNote, !ids.contains(selected.id) {
					selectedNote = nil
				}
				let validTopics = Set(allTopics)
				selectedTopics = selectedTopics.intersection(validTopics)
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeKnowledgeCreateNote)) { _ in
				createNote()
			}
			.onReceive(NotificationCenter.default.publisher(for: .nexaLifeKnowledgeShowTopicList)) { _ in
				showTopicList = true
			}
	}

	private func createNote() {
		let note = Note(title: "新笔记")
		modelContext.insert(note)
		selectedNote = note
	}

	private var searchBar: some View {
		HStack {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(WorkspaceTheme.mutedText)
			TextField("搜索标题、正文或主题…", text: $searchText)
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
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	private var topicFilterBar: some View {
		HStack(spacing: 8) {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					TopicFilterChip(
						label: "全部",
						count: notes.count,
						isSelected: selectedTopics.isEmpty
					) {
						selectedTopics.removeAll()
					}

					ForEach(allTopics, id: \.self) { topic in
						TopicFilterChip(
							label: topic,
							count: topicCountForDisplay(topic),
							isSelected: selectedTopics.contains(topic)
						) {
							toggleTopic(topic)
						}
					}
				}
				.padding(.vertical, 2)
			}

			Image(systemName: "list.bullet")
				.font(.subheadline)
				.padding(.horizontal, 10)
				.padding(.vertical, 7)
				.background(WorkspaceTheme.elevatedSurface)
				.overlay(
					Capsule()
						.stroke(WorkspaceTheme.border, lineWidth: 1)
				)
				.clipShape(Capsule())
				.contentShape(Capsule())
				.onTapGesture {
					showTopicList = true
				}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	@ViewBuilder
	private var noteWorkspacePanels: some View {
		if filteredNotes.isEmpty {
			KnowledgeEmptyPanel(searchText: searchText)
		} else if selectedTopics.isEmpty {
			KnowledgeTopicPanels(
				sections: groupedNotes,
				selectedNote: selectedNote,
				onSelect: { note in
					selectedNote = note
				}
			)
		} else {
			KnowledgeFilteredPanel(
				notes: filteredNotes,
				selectedNote: selectedNote,
				onSelect: { note in
					selectedNote = note
				}
			)
		}
	}

	private func topicCounts() -> [String: Int] {
		Dictionary(uniqueKeysWithValues: allTopics.map { topic in
			(topic, topicCountForDisplay(topic))
		})
	}

	private func toggleTopic(_ topic: String) {
		if selectedTopics.contains(topic) {
			selectedTopics.remove(topic)
		} else {
			selectedTopics.insert(topic)
		}
	}

	private func topicCountForDisplay(_ topic: String) -> Int {
		notes.filter { tags(of: $0).contains(topic) }.count
	}

	private func tags(of note: Note) -> [String] {
		let parsed = KnowledgeTagCodec.parse(note.topic)
		return parsed.isEmpty ? ["未分类"] : parsed
	}

	private func primaryTopic(of note: Note) -> String {
		tags(of: note).first ?? "未分类"
	}
}

private struct KnowledgeTopicSection: Identifiable {
	let topic: String
	let items: [Note]

	var id: String { topic }
}

private struct KnowledgeEmptyPanel: View {
	var searchText: String

	var body: some View {
		WorkspaceCard(accent: WorkspaceTheme.moduleAccent(for: .knowledge), padding: 24, cornerRadius: 24, shadowY: 8) {
			ContentUnavailableView(
				searchText.isEmpty ? "还没有笔记" : "没有匹配结果",
				systemImage: searchText.isEmpty ? "book.closed" : "magnifyingglass",
				description: Text(
					searchText.isEmpty
					? "点击右上角新建笔记"
					: "换个关键词或主题筛选试试"
				)
			)
			.frame(maxWidth: .infinity)
			.padding(.vertical, 28)
		}
	}
}

private struct KnowledgeTopicPanels: View {
	var sections: [KnowledgeTopicSection]
	var selectedNote: Note?
	var onSelect: (Note) -> Void

	private func isSelected(_ note: Note) -> Bool {
		selectedNote?.id == note.id
	}

	var body: some View {
		LazyVGrid(
			columns: [GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 14)],
			alignment: .leading,
			spacing: 14
		) {
			ForEach(sections) { section in
				WorkspaceCard(accent: WorkspaceTheme.moduleAccent(for: .knowledge), padding: 18, cornerRadius: 24, shadowY: 8) {
					VStack(alignment: .leading, spacing: 12) {
						WorkspacePanelHeader(
							title: section.topic,
							subtitle: "主题知识卡组",
							accent: WorkspaceTheme.moduleAccent(for: .knowledge),
							icon: "tag",
							value: "\(section.items.count)"
						)

						ForEach(section.items) { note in
							WorkspaceSelectableCard(
								accent: WorkspaceTheme.moduleAccent(for: .knowledge),
								isSelected: isSelected(note),
								cornerRadius: 18,
								padding: 14
							) {
								NoteRowView(note: note)
							}
							.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
							.onTapGesture {
								onSelect(note)
							}
						}
					}
				}
			}
		}
	}
}

private struct KnowledgeFilteredPanel: View {
	var notes: [Note]
	var selectedNote: Note?
	var onSelect: (Note) -> Void

	private func isSelected(_ note: Note) -> Bool {
		selectedNote?.id == note.id
	}

	var body: some View {
		WorkspaceCard(accent: WorkspaceTheme.moduleAccent(for: .knowledge), padding: 20, cornerRadius: 24, shadowY: 8) {
			VStack(alignment: .leading, spacing: 14) {
				WorkspacePanelHeader(
					title: "Filtered Notes",
					subtitle: "当前主题筛选下的知识条目",
					accent: WorkspaceTheme.moduleAccent(for: .knowledge),
					icon: "line.3.horizontal.decrease.circle",
					value: "\(notes.count)"
				)

				LazyVGrid(
					columns: [GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 12)],
					alignment: .leading,
					spacing: 12
				) {
					ForEach(notes) { note in
						WorkspaceSelectableCard(
							accent: WorkspaceTheme.moduleAccent(for: .knowledge),
							isSelected: isSelected(note),
							cornerRadius: 18,
							padding: 14
						) {
							NoteRowView(note: note)
						}
						.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
						.onTapGesture {
							onSelect(note)
						}
					}
				}
			}
		}
	}
}

private struct TopicFilterChip: View {
	var label: String
	var count: Int
	var isSelected: Bool
	var action: () -> Void

	var body: some View {
		HStack(spacing: 6) {
			Text(label)
				.font(.caption)
				.fontWeight(isSelected ? .semibold : .regular)
			Text("\(count)")
				.font(.caption2)
				.padding(.horizontal, 5)
				.padding(.vertical, 1)
				.background(isSelected ? Color.white.opacity(0.28) : Color.secondary.opacity(0.15))
				.clipShape(Capsule())
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 5)
		.background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
		.foregroundStyle(isSelected ? .white : .primary)
		.overlay(
			Capsule()
				.stroke(isSelected ? Color.accentColor : WorkspaceTheme.border, lineWidth: 1)
		)
		.clipShape(Capsule())
		.contentShape(Capsule())
		.onTapGesture(perform: action)
	}
}

private struct TopicFilterListSheet: View {
	@Binding var isPresented: Bool
	var topics: [String]
	var counts: [String: Int]
	@Binding var selectedTopics: Set<String>
	var totalCount: Int

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("主题筛选")
					.font(.headline)
				Spacer()
				Button("关闭") {
					isPresented = false
				}
				.buttonStyle(.plain)
				.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)

			Divider()

			List {
				Button {
					selectedTopics.removeAll()
				} label: {
					HStack {
						Text("全部")
						Spacer()
						Text("\(totalCount)")
							.foregroundStyle(.secondary)
						if selectedTopics.isEmpty {
							Image(systemName: "checkmark")
								.foregroundStyle(Color.accentColor)
						}
					}
				}
				.buttonStyle(.plain)

				ForEach(topics, id: \.self) { topic in
					Button {
						if selectedTopics.contains(topic) {
							selectedTopics.remove(topic)
						} else {
							selectedTopics.insert(topic)
						}
					} label: {
						HStack {
							Text(topic)
							Spacer()
							Text("\(counts[topic] ?? 0)")
								.foregroundStyle(.secondary)
							if selectedTopics.contains(topic) {
								Image(systemName: "checkmark")
									.foregroundStyle(Color.accentColor)
							}
						}
					}
					.buttonStyle(.plain)
				}
			}

			Divider()

			HStack {
				Button("清空选择") {
					selectedTopics.removeAll()
				}
				.buttonStyle(.bordered)
				Spacer()
				Button("完成") {
					isPresented = false
				}
				.buttonStyle(.borderedProminent)
			}
			.padding(16)
		}
		.frame(width: 360, height: 460)
	}
}

private struct NoteRowView: View {
	var note: Note

	private var noteTags: [String] {
		let parsed = KnowledgeTagCodec.parse(note.topic)
		return parsed.isEmpty ? ["未分类"] : parsed
	}

	private var previewText: String {
		let normalized = note.content
			.replacingOccurrences(of: "\n", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return normalized.isEmpty ? "暂无正文" : normalized
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .top, spacing: 8) {
				Text(note.title.isEmpty ? "无标题" : note.title)
					.font(.headline)
					.foregroundStyle(WorkspaceTheme.strongText)
					.lineLimit(1)

				Spacer(minLength: 0)

				Text(note.updatedAt, style: .relative)
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}

			Text(previewText)
				.font(.caption)
				.foregroundStyle(WorkspaceTheme.mutedText)
				.lineLimit(2)

			HStack(spacing: 6) {
				ForEach(Array(noteTags.prefix(3)), id: \.self) { tag in
					Text(tag)
						.font(.caption2)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.blue.opacity(0.12))
						.foregroundStyle(.blue)
						.clipShape(Capsule())
				}
				if noteTags.count > 3 {
					Text("+\(noteTags.count - 3)")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
				Spacer()
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

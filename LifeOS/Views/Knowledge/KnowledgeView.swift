//
//  KnowledgeView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct KnowledgeView: View {
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

	private var groupedNotes: [(String, [Note])] {
		let grouped = Dictionary(grouping: filteredNotes) { primaryTopic(of: $0) }
		return grouped.keys.sorted().map { topic in
			(topic, (grouped[topic] ?? []).sorted(by: { $0.updatedAt > $1.updatedAt }))
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
			header

			Divider()

			searchBar

			topicFilterBar

			Divider()

			List(selection: $selectedNote) {
				if filteredNotes.isEmpty {
					ContentUnavailableView(
						searchText.isEmpty ? "还没有笔记" : "没有匹配结果",
						systemImage: searchText.isEmpty ? "book.closed" : "magnifyingglass",
						description: Text(
							searchText.isEmpty
							? "在右侧 Detail 栏新建或导入 .md 笔记"
							: "换个关键词或主题筛选试试"
						)
					)
				} else if selectedTopics.isEmpty {
					ForEach(groupedNotes, id: \.0) { topic, items in
						Section(header: TopicSectionHeader(topic: topic, count: items.count)) {
							ForEach(items) { note in
								NoteRowView(note: note)
									.tag(note)
									.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
							}
						}
					}
				} else {
					ForEach(filteredNotes) { note in
						NoteRowView(note: note)
							.tag(note)
							.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
					}
				}
			}
		}
		.navigationTitle("知识 Knowledge")
		.navigationSplitViewColumnWidth(min: ColumnWidth.min, ideal: ColumnWidth.ideal, max: ColumnWidth.max)
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
	}

	private var header: some View {
		LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
			KnowledgeMetricCard(
				title: "笔记总数",
				value: "\(notes.count)",
				subtitle: "知识沉淀规模",
				color: .blue
			)
			KnowledgeMetricCard(
				title: "主题数",
				value: "\(topicCount)",
				subtitle: "主题标签覆盖",
				color: .indigo
			)
			KnowledgeMetricCard(
				title: "本周更新",
				value: "\(updatedThisWeekCount)",
				subtitle: "最近活跃度",
				color: .teal
			)
			KnowledgeMetricCard(
				title: "已分类",
				value: "\(categorizedCount)",
				subtitle: "未分类 \(uncategorizedCount)",
				color: .orange
			)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(Color(nsColor: .windowBackgroundColor))
	}

	private var searchBar: some View {
		HStack {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
			TextField("搜索标题、正文或主题…", text: $searchText)
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

			Button {
				showTopicList = true
			} label: {
				Image(systemName: "list.bullet")
					.font(.subheadline)
					.padding(.horizontal, 10)
					.padding(.vertical, 7)
					.background(Color(nsColor: .controlBackgroundColor))
					.clipShape(Capsule())
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
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

private struct TopicFilterChip: View {
	var label: String
	var count: Int
	var isSelected: Bool
	var action: () -> Void

	var body: some View {
		Button(action: action) {
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
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
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

private struct TopicSectionHeader: View {
	var topic: String
	var count: Int

	var body: some View {
		HStack {
			Label(topic, systemImage: "tag")
				.font(.subheadline.bold())
			Spacer()
			Text("\(count) 条")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
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
			Text(note.title.isEmpty ? "无标题" : note.title)
				.font(.headline)
				.lineLimit(1)

			Text(previewText)
				.font(.caption)
				.foregroundStyle(.secondary)
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
				Text(note.updatedAt, style: .relative)
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

private struct KnowledgeMetricCard: View {
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

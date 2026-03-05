//
//  VitalsDetailView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct VitalsDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \VitalsEntry.timestamp, order: .reverse) private var allEntries: [VitalsEntry]
	@Binding var selectedEntry: VitalsEntry?
	@Bindable var entry: VitalsEntry
	@StateObject private var aiService = AIService()

	@State private var aiGuidance: String = ""
	@State private var isLoadingAI = false
	@State private var draftContent: String = ""
	@State private var isEditingContent = false

	var typeColor: Color {
		switch entry.type {
		case .coreCode:   return .purple
		case .treehol:    return .green
		case .motivation: return .orange
		}
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// 类型 + 时间
				HStack {
					Label(entry.type.rawValue, systemImage: typeIcon)
						.font(.subheadline)
						.padding(.horizontal, 10)
						.padding(.vertical, 4)
						.background(typeColor.opacity(0.1))
						.foregroundStyle(typeColor)
						.clipShape(Capsule())

					if entry.isProtected {
						Label("受保护", systemImage: "lock.fill")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Text(AppDateFormatter.ymd(entry.timestamp))
						.font(.caption)
						.foregroundStyle(.tertiary)

					Menu {
						ForEach(VitalsEntryType.allCases, id: \.self) { type in
							Button {
								createEntry(type: type)
							} label: {
								Label(type.rawValue, systemImage: typeIcon(for: type))
							}
						}
					} label: {
						Label("新建", systemImage: "plus")
					}
					.buttonStyle(.bordered)
				}

				Divider()

				if entry.type == .coreCode {
					coreCategorySection
					Divider()
				}

				// 动力评分（仅 motivation 显示）
				if entry.type == .motivation {
					HStack(spacing: 6) {
						Text("能量评分").font(.subheadline).foregroundStyle(.secondary)
						HStack(spacing: 3) {
							ForEach(1...5, id: \.self) { i in
								Button {
									entry.moodScore = i
								} label: {
									Image(systemName: i <= entry.moodScore ? "star.fill" : "star")
										.foregroundStyle(i <= entry.moodScore ? Color.orange : Color.secondary)
								}
								.buttonStyle(.plain)
							}
						}
					}
				}

				contentSection

				// AI 辅助区（核心守则专属）
				if entry.type == .coreCode {
					Divider()
					VStack(alignment: .leading, spacing: 12) {
						HStack {
							Label("AI 辅助指导", systemImage: "sparkles")
								.font(.headline)
							Spacer()
							Button {
								loadAIGuidance()
							} label: {
								if isLoadingAI {
									ProgressView().scaleEffect(0.7)
								} else {
									Label("获取建议", systemImage: "wand.and.stars")
								}
							}
							.buttonStyle(.bordered)
							.disabled(isLoadingAI)
						}

						if !aiGuidance.isEmpty {
							Text(aiGuidance)
								.font(.body)
								.padding(14)
								.background(Color.purple.opacity(0.06))
								.clipShape(RoundedRectangle(cornerRadius: 10))
						}
					}
				}

				// 存档区（动力/灵感 & 树洞）
				if entry.type != .coreCode {
					Divider()
					HStack(spacing: 12) {
						Button {
							archiveEntry(to: "Knowledge")
						} label: {
							Label(entry.isArchived ? "已存档" : "存入 Knowledge", systemImage: "book")
								.frame(maxWidth: .infinity)
						}
						.buttonStyle(.bordered)
						.tint(.blue)
						.disabled(entry.isArchived)

						Button {
							archiveEntry(to: "Vitals")
						} label: {
							Label("存入 Vitals Review", systemImage: "sparkles")
								.frame(maxWidth: .infinity)
						}
						.buttonStyle(.bordered)
						.tint(.purple)
						.disabled(entry.isArchived)
					}
				}

				Divider()
				Button(role: .destructive) {
					attemptDeleteCurrentEntry()
				} label: {
					Label("删除记录", systemImage: "trash")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)

				Spacer()
			}
			.padding(28)
		}
		.navigationTitle(entry.type.rawValue)
		.onAppear {
			normalizeEntryCategoryIfNeeded()
			draftContent = entry.content
			isEditingContent = false
		}
		.onChange(of: entry.id) { _, _ in
			draftContent = entry.content
			isEditingContent = false
		}
	}

	private var contentSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Label("正文内容", systemImage: "doc.text")
					.font(.headline)
				Spacer()
				if isEditingContent {
					Button("取消") {
						draftContent = entry.content
						isEditingContent = false
					}
					.buttonStyle(.bordered)
					.controlSize(.small)

					Button("保存") {
						entry.content = draftContent
						isEditingContent = false
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				} else {
					Button("修改") {
						draftContent = entry.content
						isEditingContent = true
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
			}

			if isEditingContent {
				TextEditor(text: $draftContent)
					.font(.body)
					.frame(minHeight: 180)
					.scrollContentBackground(.hidden)
					.padding(10)
					.background(typeColor.opacity(0.04))
					.clipShape(RoundedRectangle(cornerRadius: 10))
			} else {
				Text(entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无内容" : entry.content)
					.font(.body)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(14)
					.background(typeColor.opacity(0.05))
					.clipShape(RoundedRectangle(cornerRadius: 10))
			}
		}
	}

	private var coreCategorySection: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Label("守则分类", systemImage: "square.grid.2x2")
					.font(.subheadline)
					.foregroundStyle(.secondary)
				Spacer()
				if !coreCategoryOptions.isEmpty {
					Menu("快捷选择") {
						ForEach(coreCategoryOptions, id: \.self) { option in
							Button(option) {
								entry.category = option
							}
						}
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
			}

			TextField("输入分类，例如：决策原则、沟通原则、关系原则", text: $entry.category)
				.textFieldStyle(.roundedBorder)
				.onSubmit {
					normalizeEntryCategoryIfNeeded()
				}

			if !coreCategoryOptions.isEmpty {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 6) {
						ForEach(coreCategoryOptions, id: \.self) { option in
							Button(option) {
								entry.category = option
							}
							.buttonStyle(.plain)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(option == normalizedCoreCategory(entry.category) ? Color.purple.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
							.foregroundStyle(option == normalizedCoreCategory(entry.category) ? Color.purple : .primary)
							.clipShape(Capsule())
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
	}

	private var coreCategoryOptions: [String] {
		Set(allEntries.filter { $0.type == .coreCode }.map { normalizedCoreCategory($0.category) }).sorted()
	}

	private var typeIcon: String {
		typeIcon(for: entry.type)
	}

	private func typeIcon(for type: VitalsEntryType) -> String {
		switch type {
		case .coreCode:   return "shield.lefthalf.filled"
		case .treehol:    return "tree"
		case .motivation: return "bolt.heart"
		}
	}

	private func createEntry(type: VitalsEntryType) {
		let isProtected = type == .coreCode || type == .treehol
		let newEntry = VitalsEntry(
			content: "",
			type: type,
			category: type == .coreCode ? "未分类" : "",
			isProtected: isProtected,
			moodScore: type == .motivation ? 3 : 0
		)
		modelContext.insert(newEntry)
		selectedEntry = newEntry
	}

	private func normalizeEntryCategoryIfNeeded() {
		guard entry.type == .coreCode else { return }
		entry.category = normalizedCoreCategory(entry.category)
	}

	private func normalizedCoreCategory(_ raw: String) -> String {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}

	private func attemptDeleteCurrentEntry() {
		if entry.isProtected {
			authenticateAndDelete(entry: entry)
		} else {
			deleteEntry(entry)
		}
	}

	private func deleteEntry(_ target: VitalsEntry) {
		selectedEntry = nil
		modelContext.delete(target)
	}

	private func authenticateAndDelete(entry: VitalsEntry) {
		let context = LAContext()
		var error: NSError?
		guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
		context.evaluatePolicy(
			.deviceOwnerAuthentication,
			localizedReason: "需要验证身份才能删除「\(entry.type.rawValue)」记录"
		) { success, _ in
			DispatchQueue.main.async {
				if success {
					deleteEntry(entry)
				}
			}
		}
	}

	// MARK: - AI 辅助
	private func loadAIGuidance() {
		isLoadingAI = true
		Task {
			let guidance = await aiService.generateReport(
				entries: [entry.content],
				type: "核心守则指导"
			)
			await MainActor.run {
				aiGuidance = guidance
				isLoadingAI = false
			}
		}
	}

	// MARK: - 存档
	private func archiveEntry(to destination: String) {
		let note = Note(
			title: "【Vitals 存档】\(entry.type.rawValue)",
			subtitle: AppDateFormatter.ymd(entry.timestamp),
			content: entry.content,
			topic: destination == "Vitals" ? "Vitals Review" : "Vitals"
		)
		modelContext.insert(note)
		entry.isArchived = true
	}
}

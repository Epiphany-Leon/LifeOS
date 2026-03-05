//
//  AddVitalsEntrySheet.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

struct AddVitalsEntrySheet: View {
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext

	var defaultType: VitalsEntryType

	@State private var content: String = ""
	@State private var selectedType: VitalsEntryType = .motivation
	@State private var moodScore: Int = 3
	@State private var coreCategory: String = "未分类"

	init(isPresented: Binding<Bool>, defaultType: VitalsEntryType) {
		self._isPresented = isPresented
		self.defaultType = defaultType
		self._selectedType = State(initialValue: defaultType)
	}

	var typeColor: Color {
		switch selectedType {
		case .coreCode:   return .purple
		case .treehol:    return .green
		case .motivation: return .orange
		}
	}

	var body: some View {
		VStack(spacing: 20) {
			// 标题栏
			HStack {
				Label("新增觉知记录", systemImage: "sparkles")
					.font(.title3).bold()
				Spacer()
				Button("取消") { isPresented = false }
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
			}

			// 类型选择
			Picker("类型", selection: $selectedType) {
				ForEach(VitalsEntryType.allCases, id: \.self) { type in
					Text(type.rawValue).tag(type)
				}
			}
			.pickerStyle(.segmented)

			// 类型说明
			typeHintView

			if selectedType == .coreCode {
				VStack(alignment: .leading, spacing: 8) {
					Text("守则分类")
						.font(.caption)
						.foregroundStyle(.secondary)
					TextField("例如：决策原则、沟通原则、健康原则", text: $coreCategory)
						.textFieldStyle(.roundedBorder)
				}
			}

			// 内容输入
			TextEditor(text: $content)
				.frame(minHeight: 140)
				.padding(10)
				.background(Color(nsColor: .textBackgroundColor))
				.clipShape(RoundedRectangle(cornerRadius: 10))
				.overlay(
					RoundedRectangle(cornerRadius: 10)
						.stroke(typeColor.opacity(0.3), lineWidth: 1.5)
				)
				.overlay(
					Group {
						if content.isEmpty {
							Text(placeholder)
								.foregroundStyle(.tertiary)
								.padding(14)
								.allowsHitTesting(false)
						}
					},
					alignment: .topLeading
				)

			// 动力/灵感打分
			if selectedType == .motivation {
				HStack(spacing: 12) {
					Text("能量评分").font(.subheadline).foregroundStyle(.secondary)
					HStack(spacing: 4) {
						ForEach(1...5, id: \.self) { i in
							Button {
								moodScore = i
							} label: {
								Image(systemName: i <= moodScore ? "star.fill" : "star")
									.foregroundStyle(i <= moodScore ? Color.orange : Color.secondary)
									.font(.title3)
							}
							.buttonStyle(.plain)
						}
					}
					Spacer()
				}
			}

			// 保护提示
			if selectedType == .coreCode || selectedType == .treehol {
				HStack(spacing: 6) {
					Image(systemName: "lock.shield")
						.foregroundStyle(.secondary)
					Text(selectedType == .coreCode
						 ? "核心守则将被保护，删除需要身份验证"
						 : "树洞记录受保护，删除需要身份验证")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(10)
				.background(Color.secondary.opacity(0.08))
				.clipShape(RoundedRectangle(cornerRadius: 8))
			}

			// 操作按钮
			HStack {
				Spacer()
				Button("保存记录") { saveEntry() }
					.buttonStyle(.borderedProminent)
					.tint(typeColor)
					.disabled(content.isEmpty)
			}
		}
		.padding(24)
		.frame(width: 500, height: 460)
	}

	// MARK: - 类型提示
	@ViewBuilder
	private var typeHintView: some View {
		switch selectedType {
		case .coreCode:
			HStack(spacing: 8) {
				Image(systemName: "shield.lefthalf.filled").foregroundStyle(.purple)
				Text("记录你的核心价值观与行为准则，AI 可辅助提炼与指导")
					.font(.caption).foregroundStyle(.secondary)
			}
		case .treehol:
			HStack(spacing: 8) {
				Image(systemName: "tree").foregroundStyle(.green)
				Text("安全的情绪出口，这里的内容不会被删除，只会沉淀")
					.font(.caption).foregroundStyle(.secondary)
			}
		case .motivation:
			HStack(spacing: 8) {
				Image(systemName: "bolt.heart").foregroundStyle(.orange)
				Text("捕捉让你兴奋的想法与灵感，可归档到 Knowledge 或 Vitals Review")
					.font(.caption).foregroundStyle(.secondary)
			}
		}
	}

	private var placeholder: String {
		switch selectedType {
		case .coreCode:   return "写下你的核心守则，例如：做决定前先问自己这符合我的价值观吗…"
		case .treehol:    return "今天有什么想说的…不用整理，想到什么写什么…"
		case .motivation: return "是什么让你感到兴奋或有动力？"
		}
	}

	private func saveEntry() {
		let isProtected = selectedType == .coreCode || selectedType == .treehol
		let entry = VitalsEntry(
			content: content,
			type: selectedType,
			category: selectedType == .coreCode ? normalizedCoreCategory : "",
			isProtected: isProtected,
			moodScore: selectedType == .motivation ? moodScore : 0
		)
		modelContext.insert(entry)
		isPresented = false
	}

	private var normalizedCoreCategory: String {
		let trimmed = coreCategory.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "未分类" : trimmed
	}
}

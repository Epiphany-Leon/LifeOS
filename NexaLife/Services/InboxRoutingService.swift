//
//  InboxRoutingService.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-03-02.
//

import Foundation
import SwiftData

enum InboxRoutingService {
	static func transfer(content: String, to module: AppModule, modelContext: ModelContext) -> Bool {
		let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }

		switch module {
		case .execution:
			let title = shortTitle(from: trimmed)
			let notes = title == trimmed ? "" : trimmed
			let task = TaskItem(
				title: title,
				notes: notes,
				category: "收件箱归类",
				status: .todo
			)
			modelContext.insert(task)
			return true

		case .knowledge:
			let title = shortTitle(from: trimmed)
			let note = Note(
				title: title,
				subtitle: "来自收件箱归类",
				content: trimmed,
				topic: "Inbox"
			)
			modelContext.insert(note)
			return true

		case .lifestyle:
			if looksLikeGoal(trimmed) {
				let goal = Goal(
					title: shortTitle(from: trimmed),
					targetDescription: trimmed
				)
				modelContext.insert(goal)
				return true
			}

			if looksLikeConnection(trimmed) {
				let connection = Connection(
					name: shortTitle(from: trimmed),
					relationship: "收件箱归类",
					notes: trimmed
				)
				modelContext.insert(connection)
				return true
			}

			let inferredCurrency = inferCurrency(from: trimmed)
			let inferredAmount = inferLifestyleAmount(from: trimmed)
			let transaction = Transaction(
				amount: inferredAmount,
				category: inferLifestyleCategory(from: trimmed),
				title: shortTitle(from: trimmed),
				note: trimmed,
				date: .now,
				currencyCode: inferredCurrency.rawValue
			)
			modelContext.insert(transaction)
			return true

		case .vitals:
			let vitalsType = inferVitalsType(from: trimmed)
			let entry = VitalsEntry(
				content: trimmed,
				type: vitalsType,
				category: vitalsType == .coreCode ? "未分类" : "",
				isProtected: vitalsType == .coreCode || vitalsType == .treehol,
				moodScore: vitalsType == .motivation || vitalsType == .emotion ? 3 : 0
			)
			modelContext.insert(entry)
			return true

		case .dashboard, .inbox, .trash:
			return false
		}
	}

	private static func shortTitle(from content: String) -> String {
		let separators = CharacterSet(charactersIn: "\n。；;！!？?,，")
		let firstChunk = content
			.components(separatedBy: separators)
			.first?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? content

		if firstChunk.count <= 36 {
			return firstChunk
		}
		return String(firstChunk.prefix(36))
	}

	private static func inferLifestyleCategory(from content: String) -> String {
		let normalized = content.lowercased()
		let mapping: [(String, String)] = [
			("餐", "餐饮"), ("咖啡", "餐饮"), ("外卖", "餐饮"),
			("地铁", "交通"), ("打车", "交通"), ("公交", "交通"), ("油费", "交通"),
			("房租", "住房"), ("物业", "住房"), ("水电", "住房"),
			("工资", "收入"), ("奖金", "收入"), ("报销", "收入"), ("收入", "收入"),
			("数码", "数码"), ("电脑", "数码"), ("手机", "数码"), ("设备", "数码"),
			("学习", "学习"), ("课程", "学习"), ("书", "学习")
		]

		for (keyword, category) in mapping where normalized.contains(keyword) {
			return category
		}
		return "收件箱归类"
	}

	private static func inferLifestyleAmount(from content: String) -> Double {
		let amount = extractFirstAmount(from: content) ?? 0
		let normalized = content.lowercased()
		let incomeKeywords = ["收入", "工资", "奖金", "报销", "入账", "收款", "income", "salary", "revenue"]
		let isIncome = incomeKeywords.contains(where: { normalized.contains($0) })
		return isIncome ? abs(amount) : -abs(amount)
	}

	private static func extractFirstAmount(from content: String) -> Double? {
		let pattern = #"\d+(\.\d+)?"#
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
		let range = NSRange(location: 0, length: (content as NSString).length)
		guard let match = regex.firstMatch(in: content, options: [], range: range),
			  let swiftRange = Range(match.range, in: content) else { return nil }
		return Double(String(content[swiftRange]))
	}

	private static func inferCurrency(from content: String) -> CurrencyCode {
		let normalized = content.lowercased()
		if normalized.contains("$") || normalized.contains("usd") || normalized.contains("美元") {
			return .USD
		}
		if normalized.contains("eur") || normalized.contains("欧元") {
			return .EUR
		}
		if normalized.contains("gbp") || normalized.contains("英镑") {
			return .GBP
		}
		if normalized.contains("jpy") || normalized.contains("日元") {
			return .JPY
		}
		if normalized.contains("hkd") || normalized.contains("港币") {
			return .HKD
		}
		return .CNY
	}

	private static func looksLikeGoal(_ content: String) -> Bool {
		let normalized = content.lowercased()
		let keywords = ["目标", "计划", "里程碑", "goal", "milestone"]
		return keywords.contains { normalized.contains($0) }
	}

	private static func looksLikeConnection(_ content: String) -> Bool {
		let normalized = content.lowercased()
		let keywords = ["联系人", "通讯录", "名片", "电话", "微信", "加好友", "network", "contact"]
		return keywords.contains { normalized.contains($0) }
	}

	private static func inferVitalsType(from content: String) -> VitalsEntryType {
		let normalized = content.lowercased()
		let coreKeywords = ["原则", "守则", "底线", "价值观", "准则", "原则性", "core code"]
		if coreKeywords.contains(where: { normalized.contains($0) }) {
			return .coreCode
		}

		let emotionKeywords = ["情绪", "焦虑", "难过", "开心", "低落", "烦", "崩溃", "委屈", "激动", "emotion", "mood"]
		if emotionKeywords.contains(where: { normalized.contains($0) }) {
			return .emotion
		}

		let reflectionKeywords = ["复盘", "总结", "今天", "记录", "学到了", "反思", "review", "reflection"]
		if reflectionKeywords.contains(where: { normalized.contains($0) }) {
			return .reflection
		}

		let privateKeywords = ["树洞", "秘密", "不能说", "不想被看见", "private", "secret"]
		if privateKeywords.contains(where: { normalized.contains($0) }) {
			return .treehol
		}

		return .motivation
	}
}

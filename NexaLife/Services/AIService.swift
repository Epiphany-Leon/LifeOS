//
//  AIService.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//
//  AIService.swift

import Foundation
import Combine

struct TaskMetadataSuggestion: Equatable {
	var category: String
	var tags: [String]
	var projectName: String
}

struct ConnectionInsight: Equatable {
	var importance: Int           // 1~5
	var attitude: String
	var reason: String
	var nextAction: String
	var keySignals: [String]
}

struct InboxHandlingSuggestion: Equatable {
	var module: AppModule
	var headline: String
	var reason: String
}

private struct TaskMetadataAIResponse: Decodable {
	var category: String?
	var tags: [String]?
	var projectName: String?
}

private struct ConnectionInsightAIResponse: Decodable {
	var importance: Int?
	var attitude: String?
	var reason: String?
	var nextAction: String?
	var keySignals: [String]?
}

private struct InboxHandlingAIResponse: Decodable {
	var module: String?
	var headline: String?
	var reason: String?
}

private struct ProfileGuidanceAIResponse: Decodable {
	var headline: String?
	var strengths: [String]?
	var patterns: [String]?
	var nextSteps: [String]?
	var caution: String?
}

private struct DailyReviewAIResponse: Decodable {
	var summary: String?
	var guidance: String?
}

private struct AIChatResponse: Decodable {
	struct Choice: Decodable {
		struct Message: Decodable {
			var content: String?
		}

		var message: Message
	}

	var choices: [Choice]
}

private struct AIRequestConfiguration {
	var rawProvider: String
	var url: URL
	var modelName: String
	var apiKey: String
	var timeout: Double
}

private enum TaskSuggestionEngine {
	private struct Rule {
		let category: String
		let keywords: [String]
		let tags: [String]
	}

	private static let rules: [Rule] = [
		Rule(
			category: "工作",
			keywords: ["meeting", "会议", "汇报", "复盘", "交付", "客户", "需求", "roadmap", "milestone", "kpi"],
			tags: ["工作", "协作"]
		),
		Rule(
			category: "学习",
			keywords: ["学习", "读书", "课程", "整理", "总结", "note", "notes", "study", "research"],
			tags: ["学习", "沉淀"]
		),
		Rule(
			category: "产品",
			keywords: ["产品", "设计", "原型", "迭代", "版本", "体验", "需求池", "feature", "ux", "ui"],
			tags: ["产品", "迭代"]
		),
		Rule(
			category: "开发",
			keywords: ["开发", "编码", "调试", "上线", "修复", "重构", "api", "bug", "test", "release", "deploy"],
			tags: ["开发", "交付"]
		),
		Rule(
			category: "运营",
			keywords: ["运营", "增长", "活动", "推广", "转化", "留存", "内容", "campaign"],
			tags: ["运营", "增长"]
		),
		Rule(
			category: "个人",
			keywords: ["生活", "家务", "健康", "运动", "体检", "旅行", "家庭", "personal", "fitness"],
			tags: ["个人", "生活"]
		)
	]

	private static let moduleRules: [(AppModule, [String])] = [
		(.execution, ["待办", "任务", "项目", "截止", "计划", "执行", "安排", "todo", "deadline", "deliver"]),
		(.knowledge, ["学习", "笔记", "复盘", "总结", "读书", "知识", "note", "learn", "study"]),
		(.lifestyle, [
			"消费", "支出", "预算", "收入", "工资", "报销", "转账", "付款", "收款", "账单", "记账",
			"花了", "买了", "餐饮", "交通", "房租", "旅行", "社交", "理财", "扣费", "充值", "订阅",
			"会员", "开通", "续费", "购买", "付费", "费用", "花费", "消耗", "付了", "转了",
			"money", "budget", "expense", "income", "finance", "payment", "fee", "subscription",
			"membership", "purchase", "bought", "paid", "charged", "billing"
		]),
		(.vitals, ["情绪", "反思", "焦虑", "动力", "灵感", "价值观", "心理", "mood", "reflect"])
	]

	static func moduleSuggestion(for text: String) -> AppModule {
		let normalized = text.lowercased()
		var bestModule: AppModule = .inbox
		var bestScore = 0
		for (module, keywords) in moduleRules {
			let score = keywords.reduce(into: 0) { partial, word in
				if normalized.contains(word) { partial += 1 }
			}
			if score > bestScore {
				bestScore = score
				bestModule = module
			}
		}
		return bestScore == 0 ? .inbox : bestModule
	}

	/// Suggest a financial category for an expense or income entry.
	static func financialCategoryFallback(title: String, note: String, isExpense: Bool) -> String {
		let text = "\(title) \(note)".lowercased()
		if isExpense {
			let rules: [(String, [String])] = [
				("餐饮", ["餐", "饭", "吃", "外卖", "咖啡", "奶茶", "饮品", "food", "restaurant", "coffee", "lunch", "dinner", "breakfast"]),
				("交通", ["打车", "地铁", "公交", "滴滴", "taxi", "uber", "bus", "metro", "train", "高铁", "机票", "flight"]),
				("购物", ["买了", "购买", "淘宝", "京东", "亚马逊", "shopping", "amazon", "buy", "order"]),
				("数码", ["手机", "电脑", "耳机", "iphone", "ipad", "macbook", "apple", "数码", "设备"]),
				("娱乐", ["电影", "游戏", "ktv", "演唱会", "concert", "movie", "game", "netflix", "spotify"]),
				("学习", ["课程", "书", "培训", "课", "study", "course", "book", "learning"]),
				("通讯", ["话费", "流量", "宽带", "phone bill", "internet", "通讯", "网费"]),
				("住房", ["房租", "租金", "物业", "水电", "rent", "utility", "电费", "水费"]),
				("医疗", ["医院", "药", "体检", "hospital", "medicine", "doctor", "clinic"]),
				("旅行", ["旅行", "旅游", "酒店", "hotel", "travel", "trip", "vacation"]),
				("社交", ["请客", "AA", "聚餐", "礼金", "红包", "gift", "social"]),
				("订阅", ["会员", "订阅", "membership", "subscription", "premium", "vip", "续费", "扣费", "自动扣"]),
				("投资", ["基金", "股票", "理财", "fund", "stock", "invest"]),
			]
			for (category, keywords) in rules {
				if keywords.contains(where: { text.contains($0) }) { return category }
			}
			return "其他"
		} else {
			let rules: [(String, [String])] = [
				("工资", ["工资", "薪资", "salary", "payroll", "月薪"]),
				("理财", ["基金", "股票", "分红", "利息", "fund", "dividend", "interest"]),
				("租金", ["租金", "rent"]),
				("年终奖", ["年终", "奖金", "bonus"]),
			]
			for (category, keywords) in rules {
				if keywords.contains(where: { text.contains($0) }) { return category }
			}
			return "收款"
		}
	}

	static func suggestTaskMetadata(
		title: String,
		notes: String,
		existingProjects: [String],
		currentProject: String = "",
		locale: Locale
	) -> TaskMetadataSuggestion {
		let trimmedProject = currentProject.trimmingCharacters(in: .whitespacesAndNewlines)
		let content = "\(title) \(notes)".lowercased()

		let inferredCategory = inferCategory(from: content)
		let inferredTags = inferTags(from: content, category: inferredCategory)
		let inferredProject = inferProject(
			title: title,
			content: content,
			existingProjects: existingProjects,
			currentProject: trimmedProject
		)

		return TaskMetadataSuggestion(
			category: localizedCategory(inferredCategory, locale: locale),
			tags: localizedTags(inferredTags, locale: locale),
			projectName: inferredProject
		)
	}

	private static func inferCategory(from content: String) -> String {
		var bestCategory = "通用"
		var bestScore = 0

		for rule in rules {
			let score = rule.keywords.reduce(into: 0) { partial, word in
				if content.contains(word.lowercased()) { partial += 1 }
			}
			if score > bestScore {
				bestScore = score
				bestCategory = rule.category
			}
		}

		return bestCategory
	}

	private static func inferTags(from content: String, category: String) -> [String] {
		var tags: [String] = []
		if let matchedRule = rules.first(where: { $0.category == category }) {
			tags.append(contentsOf: matchedRule.tags)
		}

		let extraTagRules: [(String, String)] = [
			("紧急", "紧急"),
			("urgent", "紧急"),
			("本周", "本周"),
			("today", "今日"),
			("今天", "今日"),
			("review", "复盘"),
			("复盘", "复盘"),
			("计划", "规划"),
			("写作", "写作"),
			("沟通", "沟通"),
			("会议", "会议"),
			("文档", "文档")
		]

		for (keyword, tag) in extraTagRules where content.contains(keyword) {
			tags.append(tag)
		}

		return normalizeTags(tags)
	}

	private static func inferProject(
		title: String,
		content: String,
		existingProjects: [String],
		currentProject: String
	) -> String {
		if !currentProject.isEmpty { return currentProject }

		var bestProject = ""
		var bestScore = 0

		for original in existingProjects {
			let project = original.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !project.isEmpty, project != "收件箱" else { continue }

			let lowered = project.lowercased()
			var score = 0
			if content.contains(lowered) { score += 4 }

			let words = lowered
				.components(separatedBy: CharacterSet.alphanumerics.inverted)
				.filter { $0.count >= 2 }
			for word in words where content.contains(word) {
				score += 1
			}

			if score > bestScore {
				bestScore = score
				bestProject = project
			}
		}

		if bestScore > 0 { return bestProject }

		let separators = ["：", ":", "-", "｜", "|"]
		for separator in separators {
			let parts = title.components(separatedBy: separator)
			if let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
			   !first.isEmpty, first.count <= 20 {
				return first
			}
		}

		return "收件箱"
	}

	static func normalizeTags(_ tags: [String]) -> [String] {
		var seen: Set<String> = []
		var normalized: [String] = []
		for raw in tags {
			let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !value.isEmpty, !seen.contains(value) else { continue }
			seen.insert(value)
			normalized.append(value)
		}
		return Array(normalized.prefix(5))
	}

	private static func localizedCategory(_ category: String, locale: Locale) -> String {
		guard !locale.isChineseInterface else { return category }
		switch category {
		case "工作": return "Work"
		case "学习": return "Learning"
		case "产品": return "Product"
		case "开发": return "Engineering"
		case "运营": return "Operations"
		case "个人": return "Personal"
		default: return "General"
		}
	}

	private static func localizedTags(_ tags: [String], locale: Locale) -> [String] {
		guard !locale.isChineseInterface else { return tags }
		let map: [String: String] = [
			"工作": "Work",
			"协作": "Collaboration",
			"学习": "Learning",
			"沉淀": "Synthesis",
			"产品": "Product",
			"迭代": "Iteration",
			"开发": "Engineering",
			"交付": "Delivery",
			"运营": "Operations",
			"增长": "Growth",
			"个人": "Personal",
			"生活": "Life",
			"紧急": "Urgent",
			"本周": "This Week",
			"今日": "Today",
			"复盘": "Review",
			"规划": "Planning",
			"写作": "Writing",
			"沟通": "Communication",
			"会议": "Meeting",
			"文档": "Docs"
		]
		return tags.map { map[$0] ?? $0 }
	}
}

private enum ConnectionInsightEngine {
	static func fallback(
		name: String,
		relationship: String,
		notes: String,
		lastContactDate: Date?,
		question: String,
		locale: Locale
	) -> ConnectionInsight {
		let content = "\(name) \(relationship) \(notes) \(question)".lowercased()
		let isCore =
			["合伙", "核心", "投资", "家人", "partner", "mentor", "导师", "老板", "客户"].contains { content.contains($0) }
		let isWeak =
			["泛泛", "普通", "弱", "一般", "一般认识", "社群", "群友"].contains { content.contains($0) }

		var importance = isCore ? 4 : 3
		if isWeak { importance = 2 }
		if let date = lastContactDate {
			let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
			if days > 90 { importance = max(2, importance - 1) }
		}
		importance = min(5, max(1, importance))

		let attitude: String
		switch importance {
		case 5:
			attitude = AppBrand.localized("高信任 + 高频沟通，优先维护", "High trust and frequent communication. Maintain this relationship first.", locale: locale)
		case 4:
			attitude = AppBrand.localized("稳定投入，围绕互惠价值保持联系", "Invest consistently and keep contact around mutual value.", locale: locale)
		case 3:
			attitude = AppBrand.localized("保持温和连接，按周期跟进", "Keep a warm connection and follow up on a steady cadence.", locale: locale)
		default:
			attitude = AppBrand.localized("轻量维护，避免过度投入", "Maintain lightly and avoid over-investing.", locale: locale)
		}

		let reason = AppBrand.localized(
			"关系标签「\(relationship.isEmpty ? "未填写" : relationship)」与近况信息有限，已基于当前文本进行保守评估。",
			"The relationship label \"\(relationship.isEmpty ? "Not provided" : relationship)\" and recent context are limited, so this is a conservative assessment based on the current text.",
			locale: locale
		)

		let nextAction: String
		if let date = lastContactDate {
			let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
			nextAction = days > 30
				? AppBrand.localized("在 48 小时内发送一次近况问候并提出一个具体可帮忙点。", "Send a quick check-in within 48 hours and offer one concrete way to help.", locale: locale)
				: AppBrand.localized("维持当前沟通节奏，下一次沟通聚焦双方共同目标。", "Keep the current cadence and focus the next conversation on shared goals.", locale: locale)
		} else {
			nextAction = AppBrand.localized("先建立最近联系记录，再决定跟进频率。建议先发一条简短近况问候。", "Record a recent touchpoint first, then decide the cadence. Start with a short check-in.", locale: locale)
		}

		return ConnectionInsight(
			importance: importance,
			attitude: attitude,
			reason: reason,
			nextAction: nextAction,
			keySignals: locale.isChineseInterface
				? ["关系角色", "最近联系间隔", "备注关键词"]
				: ["Role", "Days Since Contact", "Note Keywords"]
		)
	}
}

private enum InboxSuggestionEngine {
	static func fallback(for text: String, locale: Locale) -> InboxHandlingSuggestion {
		let module = TaskSuggestionEngine.moduleSuggestion(for: text)
		switch module {
		case .execution:
			return InboxHandlingSuggestion(
				module: .execution,
				headline: AppBrand.localized("建议转成执行任务", "Turn this into an execution task", locale: locale),
				reason: AppBrand.localized("文本更像待办、计划或提醒，适合进入 Execution 继续拆解。", "This reads like a task, plan, or reminder, so Execution is the best next stop.", locale: locale)
			)
		case .knowledge:
			return InboxHandlingSuggestion(
				module: .knowledge,
				headline: AppBrand.localized("建议沉淀为知识笔记", "Capture this as a knowledge note", locale: locale),
				reason: AppBrand.localized("文本带有学习、总结或记录属性，进入 Knowledge 更容易继续补充。", "This looks like learning, synthesis, or documentation, so Knowledge will be easier to extend.", locale: locale)
			)
		case .lifestyle:
			return InboxHandlingSuggestion(
				module: .lifestyle,
				headline: AppBrand.localized("建议归入生活模块", "Move this into Lifestyle", locale: locale),
				reason: AppBrand.localized("内容偏向消费、目标、人脉或生活事务，适合在 Lifestyle 继续处理。", "This points to spending, goals, relationships, or life operations, so Lifestyle is a better fit.", locale: locale)
			)
		case .vitals:
			return InboxHandlingSuggestion(
				module: .vitals,
				headline: AppBrand.localized("建议沉淀到 Vitals", "Capture this in Vitals", locale: locale),
				reason: AppBrand.localized("文本更像情绪、反思或核心守则记录，留在 Vitals 更自然。", "This reads more like emotion, reflection, or a principle, so Vitals is the most natural place.", locale: locale)
			)
		case .dashboard, .inbox, .trash:
			return InboxHandlingSuggestion(
				module: .inbox,
				headline: AppBrand.localized("先留在收件箱", "Keep it in the inbox for now", locale: locale),
				reason: AppBrand.localized("当前信息还不够明确，建议补全上下文后再决定转移方向。", "The context is still too thin. Add more detail before moving it elsewhere.", locale: locale)
			)
		}
	}
}

@MainActor
class AIService: ObservableObject {

	enum AIProvider: String {
		case deepseek = "https://api.deepseek.com/v1/chat/completions"
		case qwen     = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
	}

	var apiKey: String {
		AICredentialStore.readAPIKey()
	}

	var isConfigured: Bool { !apiKey.isEmpty }

	private var interfaceLocale: Locale {
		let stored = UserDefaults.standard.string(forKey: "appLanguagePreference") ?? AppLanguagePreference.system.rawValue
		switch stored {
		case AppLanguagePreference.simplifiedChinese.rawValue:
			return Locale(identifier: AppLanguagePreference.simplifiedChinese.rawValue)
		case AppLanguagePreference.english.rawValue:
			return Locale(identifier: AppLanguagePreference.english.rawValue)
		default:
			return .autoupdatingCurrent
		}
	}

	private var requestConfiguration: AIRequestConfiguration? {
		let rawProvider = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProviderOption.deepseek.rawValue
		let providerURL = rawProvider == AIProviderOption.qwen.rawValue
			? AIProvider.qwen.rawValue
			: AIProvider.deepseek.rawValue
		let modelName: String = {
			if rawProvider == AIProviderOption.qwen.rawValue {
				return UserDefaults.standard.string(forKey: "aiModelQwen") ?? "qwen-turbo"
			}
			return UserDefaults.standard.string(forKey: "aiModelDeepSeek") ?? "deepseek-chat"
		}()
		let configuredTimeout = UserDefaults.standard.double(forKey: "aiTimeoutSeconds")
		let timeout = configuredTimeout > 0 ? configuredTimeout : 30
		let key = AICredentialStore.readAPIKey()

		guard !key.isEmpty, let url = URL(string: providerURL) else { return nil }
		return AIRequestConfiguration(
			rawProvider: rawProvider,
			url: url,
			modelName: modelName,
			apiKey: key,
			timeout: timeout
		)
	}

	private func requestJSON<T: Decodable>(_ type: T.Type, prompt: String, maxTokens: Int) async -> T? {
		guard
			let response = await callAPI(prompt: prompt, maxTokens: maxTokens),
			let jsonString = extractJSONObject(from: response),
			let data = jsonString.data(using: .utf8)
		else {
			return nil
		}

		return try? JSONDecoder().decode(type, from: data)
	}

	private func trimmedOrFallback(_ value: String?, fallback: String) -> String {
		value?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.nonEmpty ?? fallback
	}

	private func normalizedOrFallback(_ values: [String]?, fallback: [String]) -> [String] {
		let normalized = TaskSuggestionEngine.normalizeTags(values ?? [])
		return normalized.isEmpty ? fallback : normalized
	}

	// MARK: - 自动归类
	func classifyText(_ text: String) async -> AppModule {
		let locale = interfaceLocale
		let fallback = TaskSuggestionEngine.moduleSuggestion(for: text)
		guard isConfigured else {
			return fallback
		}
		let prompt = locale.isChineseInterface
			? """
			你是 NexaLife 的智能助手。根据以下文本，判断最适合归入哪个象限。
			- Execution：任务、待办、计划、项目、提醒
			- Knowledge：笔记、学习、想法、文章、读书
			- Lifestyle：消费、金钱、社交、目标、生活事务
			- Vitals：情绪、反思、心理、价值观、核心守则
			- Inbox：无法判断

			文本："\(text)"
			只回答一个英文单词：Execution / Knowledge / Lifestyle / Vitals / Inbox
			"""
			: """
			You are the intelligent assistant for NexaLife. Classify the following text into the most suitable module.
			- Execution: tasks, plans, projects, reminders
			- Knowledge: notes, learning, ideas, articles, reading
			- Lifestyle: spending, money, relationships, goals, life operations
			- Vitals: emotions, reflection, psychology, values, principles
			- Inbox: cannot determine yet

			Text: "\(text)"
			Reply with one word only: Execution / Knowledge / Lifestyle / Vitals / Inbox
			"""
		guard let response = await callAPI(prompt: prompt, maxTokens: 60) else { return fallback }
		// Scan response for the first matching module name (case-insensitive).
		let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
		let candidates: [AppModule] = [.execution, .knowledge, .lifestyle, .vitals, .inbox]
		if let match = candidates.first(where: { trimmed.localizedCaseInsensitiveContains($0.rawValue) }) {
			return match
		}
		return AppModule(rawValue: trimmed) ?? fallback
	}

	// MARK: - 财务分类建议
	func suggestFinancialCategory(title: String, note: String, amount: Double, isExpense: Bool) async -> String {
		let locale = interfaceLocale
		let fallback = TaskSuggestionEngine.financialCategoryFallback(title: title, note: note, isExpense: isExpense)
		guard isConfigured else { return fallback }

		let expenseList = "餐饮/购物/日用/交通/水果/零食/运动/娱乐/通讯/服饰/美容/住房/家庭/社交/旅行/数码/汽车/医疗/书籍/学习/宠物/礼品/办公/维修/游戏/快递/捐赠/烟酒/蔬菜/投资/订阅/其他"
		let incomeList = "工资/租金/分红/理财/年终奖/借入/收款"
		let categoryList = isExpense ? expenseList : incomeList
		let typeLabel = isExpense
			? (locale.isChineseInterface ? "支出" : "expense")
			: (locale.isChineseInterface ? "收入" : "income")

		let prompt = locale.isChineseInterface
			? """
			你是财务助手，根据以下条目信息，从分类列表中选出最合适的分类，只输出分类名称，不要输出其他文字。
			类型：\(typeLabel)
			金额：\(String(format: "%.2f", abs(amount)))
			标题：\(title)
			备注：\(note)
			可选分类：\(categoryList)
			"""
			: """
			You are a finance assistant. Pick the best category for this \(typeLabel) entry from the list below. Output the category name only.
			Amount: \(String(format: "%.2f", abs(amount)))
			Title: \(title)
			Note: \(note)
			Categories: \(categoryList)
			"""

		guard let response = await callAPI(prompt: prompt, maxTokens: 30) else { return fallback }
		let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
		// Validate the returned value is actually in our catalog.
		let allCategories = (expenseList + "/" + incomeList).components(separatedBy: "/")
		if allCategories.contains(cleaned) { return cleaned }
		// Try partial match (AI may return "订阅服务" when "订阅" is in catalog).
		if let partial = allCategories.first(where: { cleaned.contains($0) || $0.contains(cleaned) }) {
			return partial
		}
		return fallback
	}

	func suggestTaskMetadata(
		title: String,
		notes: String,
		existingProjects: [String],
		currentProject: String = ""
	) async -> TaskMetadataSuggestion {
		let locale = interfaceLocale
		let fallback = TaskSuggestionEngine.suggestTaskMetadata(
			title: title,
			notes: notes,
			existingProjects: existingProjects,
			currentProject: currentProject,
			locale: locale
		)

		guard isConfigured else { return fallback }

		let projectList = existingProjects
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty && $0 != "收件箱" }

		let prompt = locale.isChineseInterface
			? """
			你是任务管理助手，请基于输入内容生成执行任务元数据。
			输出 JSON 对象，禁止输出其他文本，结构如下：
			{"category":"分类名","tags":["tag1","tag2"],"projectName":"项目名或收件箱"}

			要求：
			1) category 要简短，中文 2-6 字
			2) tags 返回 2-5 个短标签
			3) projectName 如果无法判断，返回“收件箱”
			4) 可选项目池：\(projectList.joined(separator: "、"))

			任务标题：\(title)
			任务备注：\(notes)
			"""
			: """
			You are a task-management assistant. Generate metadata for this execution task.
			Return JSON only with this structure:
			{"category":"Category","tags":["tag1","tag2"],"projectName":"Project name or 收件箱"}

			Rules:
			1) category should be short and clear
			2) return 2-5 short tags
			3) if no project is clear, return "收件箱"
			4) available project pool: \(projectList.joined(separator: ", "))

			Title: \(title)
			Notes: \(notes)
			"""

		guard let parsed = await requestJSON(TaskMetadataAIResponse.self, prompt: prompt, maxTokens: 180) else {
			return fallback
		}

		return TaskMetadataSuggestion(
			category: trimmedOrFallback(parsed.category, fallback: fallback.category),
			tags: normalizedOrFallback(parsed.tags, fallback: fallback.tags),
			projectName: trimmedOrFallback(parsed.projectName, fallback: fallback.projectName)
		)
	}

	func analyzeConnection(
		name: String,
		relationship: String,
		notes: String,
		lastContactDate: Date?,
		question: String
	) async -> ConnectionInsight {
		let locale = interfaceLocale
		let fallback = ConnectionInsightEngine.fallback(
			name: name,
			relationship: relationship,
			notes: notes,
			lastContactDate: lastContactDate,
			question: question,
			locale: locale
		)

		guard isConfigured else { return fallback }

		let dateText = lastContactDate?.formatted(date: .abbreviated, time: .omitted)
			?? AppBrand.localized("未记录", "Not recorded", locale: locale)
		let prompt = locale.isChineseInterface
			? """
			你是人脉策略顾问，请基于输入判断关系重要性与互动策略。
			仅输出 JSON，不要输出其他文本：
			{"importance":1-5,"attitude":"一句话策略","reason":"40字内依据","nextAction":"下一步动作","keySignals":["信号1","信号2"]}

			要求：
			1) importance 必须是 1 到 5 的整数
			2) attitude 强调“我该如何对待此人”
			3) nextAction 必须可执行并具体
			4) keySignals 返回 2-4 个关键词

			姓名：\(name)
			关系：\(relationship)
			最近联系：\(dateText)
			备注：\(notes)
			我的问题：\(question)
			"""
			: """
			You are a relationship strategy advisor. Judge the importance of this relationship and suggest how to handle it.
			Return JSON only:
			{"importance":1-5,"attitude":"one-line strategy","reason":"reason in under 40 words","nextAction":"next step","keySignals":["signal1","signal2"]}

			Rules:
			1) importance must be an integer from 1 to 5
			2) attitude should answer how I should approach this person
			3) nextAction must be concrete and executable
			4) keySignals should include 2-4 short keywords

			Name: \(name)
			Relationship: \(relationship)
			Last Contact: \(dateText)
			Notes: \(notes)
			My Question: \(question)
			"""

		guard let parsed = await requestJSON(ConnectionInsightAIResponse.self, prompt: prompt, maxTokens: 260) else {
			return fallback
		}

		let importance = min(5, max(1, parsed.importance ?? fallback.importance))

		return ConnectionInsight(
			importance: importance,
			attitude: trimmedOrFallback(parsed.attitude, fallback: fallback.attitude),
			reason: trimmedOrFallback(parsed.reason, fallback: fallback.reason),
			nextAction: trimmedOrFallback(parsed.nextAction, fallback: fallback.nextAction),
			keySignals: normalizedOrFallback(parsed.keySignals, fallback: fallback.keySignals)
		)
	}

	func suggestInboxHandling(_ text: String) async -> InboxHandlingSuggestion {
		let locale = interfaceLocale
		let fallback = InboxSuggestionEngine.fallback(for: text, locale: locale)
		guard isConfigured else { return fallback }

		let prompt = locale.isChineseInterface
			? """
			你是 NexaLife 的收件箱分流助手，请基于输入给出一个处理建议。
			仅输出 JSON，不要输出其他文本：
			{"module":"Execution|Knowledge|Lifestyle|Vitals|Inbox","headline":"一句话建议","reason":"40字内原因"}

			输入：\(text)
			"""
			: """
			You are the inbox triage assistant for NexaLife. Based on the text below, suggest how it should be handled.
			Return JSON only:
			{"module":"Execution|Knowledge|Lifestyle|Vitals|Inbox","headline":"one-line suggestion","reason":"reason in under 40 words"}

			Input: \(text)
			"""

		guard let parsed = await requestJSON(InboxHandlingAIResponse.self, prompt: prompt, maxTokens: 180) else {
			return fallback
		}

		let module = parsed.module?
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.nonEmpty
			.flatMap(AppModule.init(rawValue:))
			?? fallback.module

		return InboxHandlingSuggestion(
			module: module,
			headline: trimmedOrFallback(parsed.headline, fallback: fallback.headline),
			reason: trimmedOrFallback(parsed.reason, fallback: fallback.reason)
		)
	}

	// MARK: - 生成报告
	func generateReport(entries: [String], type: String) async -> String {
		let locale = interfaceLocale
		guard isConfigured else {
			return AppBrand.localized(
				"⚠️ 请先在「偏好设置 → AI 设置」中配置 API Key",
				"⚠️ Configure an API key in Preferences -> AI first.",
				locale: locale
			)
		}
		let prompt = locale.isChineseInterface
			? """
			基于以下「\(type)」记录，生成一份简洁的个人总结报告（中文，300字以内，分段落）：
			\(entries.joined(separator: "\n---\n"))
			"""
			: """
			Based on the following "\(type)" records, write a concise personal summary report in English (under 300 words, split into paragraphs):
			\(entries.joined(separator: "\n---\n"))
			"""
		return await callAPI(prompt: prompt, maxTokens: 500)
			?? AppBrand.localized("报告生成失败，请检查网络与 API Key。", "Report generation failed. Check the network connection and API key.", locale: locale)
	}

	func generateProfileGuidance(context: ProfileGuidanceContext) async -> ProfileGuidanceSummary {
		let locale = interfaceLocale
		let fallback = ProfileGuidanceEngine.fallbackSummary(context: context, locale: locale)
		guard isConfigured else { return fallback }

		let compactReviews = context.dailyReviews
			.sorted { $0.day > $1.day }
			.prefix(5)
			.map { review in
				"\(review.day.formatted(date: .abbreviated, time: .omitted)) | wins: \(review.wins) | challenges: \(review.challenges) | tomorrow: \(review.tomorrowPlan)"
			}
			.joined(separator: "\n")

		let compactVitals = context.vitals
			.sorted { $0.timestamp > $1.timestamp }
			.prefix(8)
			.map { "\($0.type.rawValue): \($0.content)" }
			.joined(separator: "\n")

		let compactTasks = context.tasks
			.filter { $0.archivedMonthKey == nil }
			.prefix(10)
			.map { "\($0.status.rawValue) | \($0.title) | \($0.category) | \($0.tagsText)" }
			.joined(separator: "\n")

		let compactNotes = context.notes
			.sorted { $0.updatedAt > $1.updatedAt }
			.prefix(8)
			.map { "\($0.title) | \($0.topic)" }
			.joined(separator: "\n")

		let compactGoals = context.goals
			.prefix(8)
			.map { "\($0.title) | \($0.template.rawValue) | \($0.trackingFrequency.rawValue) | progress=\(Int($0.progress * 100))%" }
			.joined(separator: "\n")

		let userModeDescription = context.guidanceMode == .exploratory
			? AppBrand.localized("用户自述：目前仍在探索方向，需要更多模式识别与阶段性引导。", "User self-description: still exploring direction and needs more pattern recognition plus stage-based guidance.", locale: locale)
			: AppBrand.localized("用户自述：已有相对清晰的方向，更需要执行推进、优先级和复盘支持。", "User self-description: already has a relatively clear direction and mainly needs execution, prioritization, and review support.", locale: locale)

		let prompt = locale.isChineseInterface
			? """
			你是 NexaLife 的 AI 导师。请根据以下用户近期记录，输出一个温和、具体、非武断的引导结论。
			只输出 JSON，不要输出其他文本：
			{"headline":"一句话判断","strengths":["优点1","优点2"],"patterns":["模式1","模式2"],"nextSteps":["建议1","建议2","建议3"],"caution":"一句提醒"}

			要求：
			1) 语气像导师，不要像算命
			2) 不要给身份标签，只能说“最近呈现出的模式”
			3) nextSteps 必须是可执行的小动作
			4) 每个数组 2-3 条

			\(userModeDescription)

			任务：
			\(compactTasks)

			笔记：
			\(compactNotes)

			目标：
			\(compactGoals)

			Vitals：
			\(compactVitals)

			Daily Reviews：
			\(compactReviews)
			"""
			: """
			You are the AI mentor inside NexaLife. Based on the recent records below, produce a gentle, concrete, non-dogmatic guidance summary.
			Return JSON only:
			{"headline":"one-line read","strengths":["strength 1","strength 2"],"patterns":["pattern 1","pattern 2"],"nextSteps":["step 1","step 2","step 3"],"caution":"one reminder"}

			Rules:
			1) sound like a mentor, not a fortune teller
			2) do not assign identity labels; only describe recurring patterns
			3) nextSteps must be small executable actions
			4) each array should contain 2-3 items

			\(userModeDescription)

			Tasks:
			\(compactTasks)

			Notes:
			\(compactNotes)

			Goals:
			\(compactGoals)

			Vitals:
			\(compactVitals)

			Daily Reviews:
			\(compactReviews)
			"""

		guard let parsed = await requestJSON(ProfileGuidanceAIResponse.self, prompt: prompt, maxTokens: 420) else {
			return fallback
		}

		return ProfileGuidanceSummary(
			headline: trimmedOrFallback(parsed.headline, fallback: fallback.headline),
			strengths: normalizedOrFallback(parsed.strengths, fallback: fallback.strengths),
			patterns: normalizedOrFallback(parsed.patterns, fallback: fallback.patterns),
			nextSteps: normalizedOrFallback(parsed.nextSteps, fallback: fallback.nextSteps),
			caution: trimmedOrFallback(parsed.caution, fallback: fallback.caution)
		)
	}

	func generateDailyReviewInsight(context: DailyReviewContext) async -> DailyReviewInsight {
		let locale = interfaceLocale
		let fallback = ProfileGuidanceEngine.fallbackDailyReviewInsight(context: context, locale: locale)
		guard isConfigured else { return fallback }

		let recentTasks = context.tasks
			.filter { $0.archivedMonthKey == nil }
			.prefix(8)
			.map { "\($0.status.rawValue) | \($0.title)" }
			.joined(separator: "\n")

		let recentNotes = context.notes
			.sorted { $0.updatedAt > $1.updatedAt }
			.prefix(5)
			.map { "\($0.title) | \($0.topic)" }
			.joined(separator: "\n")

		let recentVitals = context.vitals
			.sorted { $0.timestamp > $1.timestamp }
			.prefix(6)
			.map { "\($0.type.rawValue) | \($0.content)" }
			.joined(separator: "\n")

		let review = context.review
		let prompt = locale.isChineseInterface
			? """
			你是 NexaLife 的每日复盘导师。根据用户今天填写的内容，输出一个简洁复盘。
			只输出 JSON，不要输出其他文本：
			{"summary":"100字内今日总结","guidance":"100字内明日建议"}

			今天的输入：
			- wins: \(review.wins)
			- challenges: \(review.challenges)
			- insight: \(review.insight)
			- tomorrowPlan: \(review.tomorrowPlan)
			- energyScore: \(review.energyScore)
			- clarityScore: \(review.clarityScore)

			近期任务：
			\(recentTasks)

			近期笔记：
			\(recentNotes)

			近期 Vitals：
			\(recentVitals)
			"""
			: """
			You are the daily review mentor inside NexaLife. Based on the user's input for today, return a compact reflection.
			Return JSON only:
			{"summary":"today summary under 100 words","guidance":"tomorrow guidance under 100 words"}

			Today's input:
			- wins: \(review.wins)
			- challenges: \(review.challenges)
			- insight: \(review.insight)
			- tomorrowPlan: \(review.tomorrowPlan)
			- energyScore: \(review.energyScore)
			- clarityScore: \(review.clarityScore)

			Recent tasks:
			\(recentTasks)

			Recent notes:
			\(recentNotes)

			Recent vitals:
			\(recentVitals)
			"""

		guard let parsed = await requestJSON(DailyReviewAIResponse.self, prompt: prompt, maxTokens: 220) else {
			return fallback
		}

		return DailyReviewInsight(
			summary: trimmedOrFallback(parsed.summary, fallback: fallback.summary),
			guidance: trimmedOrFallback(parsed.guidance, fallback: fallback.guidance)
		)
	}

	// MARK: - 通用 API 调用
	// ✅ 去掉 nonisolated，统一在 @MainActor 上下文，URLSession 本身是线程安全的
	func callAPI(prompt: String, maxTokens: Int = 300) async -> String? {
		switch await callAPIDetailed(prompt: prompt, maxTokens: maxTokens) {
		case .success(let text): return text
		case .failure: return nil
		}
	}

	/// Same as `callAPI` but surfaces the underlying HTTP/decoding error so
	/// callers (e.g. the AI connection test) can show a useful message.
	func callAPIDetailed(prompt: String, maxTokens: Int = 300) async -> Result<String, AIServiceError> {
		guard let configuration = requestConfiguration else {
			return .failure(.notConfigured)
		}

		let body: [String: Any] = [
			"model":      configuration.modelName,
			"messages":   [["role": "user", "content": prompt]],
			"max_tokens": maxTokens
		]

		var request = URLRequest(url: configuration.url)
		request.httpMethod = "POST"
		request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.timeoutInterval = configuration.timeout
		request.httpBody = try? JSONSerialization.data(withJSONObject: body)

		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard let http = response as? HTTPURLResponse else {
				return .failure(.transport("No HTTP response"))
			}
			guard http.statusCode == 200 else {
				let bodyText = String(data: data, encoding: .utf8) ?? ""
				let snippet = String(bodyText.prefix(280))
				AppLogger.warning(
					"AI API HTTP \(http.statusCode) provider=\(configuration.rawProvider) model=\(configuration.modelName) body=\(snippet)",
					category: "ai"
				)
				return .failure(.http(status: http.statusCode, body: snippet))
			}
			let decoded = try JSONDecoder().decode(AIChatResponse.self, from: data)
			guard let text = decoded.choices.first?.message.content else {
				return .failure(.transport("Empty response"))
			}
			return .success(text)
		} catch {
			AppLogger.warning(
				"AI API request failed provider=\(configuration.rawProvider) model=\(configuration.modelName): \(error.localizedDescription)",
				category: "ai"
			)
			return .failure(.transport(error.localizedDescription))
		}
	}

	private func extractJSONObject(from text: String) -> String? {
		let pattern = #"\{[\s\S]*\}"#
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
		let range = NSRange(text.startIndex..<text.endIndex, in: text)
		guard let match = regex.firstMatch(in: text, range: range),
			  let matchedRange = Range(match.range, in: text) else {
			return nil
		}
		return String(text[matchedRange])
	}
}

private extension String {
	var nonEmpty: String? { isEmpty ? nil : self }
}

enum AIServiceError: Error, LocalizedError {
	case notConfigured
	case http(status: Int, body: String)
	case transport(String)

	var errorDescription: String? {
		switch self {
		case .notConfigured:
			return "AI provider/key is not configured."
		case .http(let status, let body):
			let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? "HTTP \(status)" : "HTTP \(status) — \(trimmed)"
		case .transport(let message):
			return message
		}
	}
}

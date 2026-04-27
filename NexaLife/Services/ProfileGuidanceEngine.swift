//
//  ProfileGuidanceEngine.swift
//  NexaLife
//
//  Created by Codex on 2026-04-05.
//

import Foundation

struct ProfileGuidanceSummary: Equatable {
	var headline: String
	var strengths: [String]
	var patterns: [String]
	var nextSteps: [String]
	var caution: String
}

struct DailyReviewInsight: Equatable {
	var summary: String
	var guidance: String
}

struct ProfileGuidanceContext {
	var guidanceMode: ProfileGuidanceMode
	var inboxItems: [InboxItem]
	var tasks: [TaskItem]
	var notes: [Note]
	var goals: [Goal]
	var goalProgressEntries: [GoalProgressEntry]
	var vitals: [VitalsEntry]
	var connections: [Connection]
	var dailyReviews: [DailyReviewEntry]
}

struct DailyReviewContext {
	var review: DailyReviewEntry
	var tasks: [TaskItem]
	var notes: [Note]
	var vitals: [VitalsEntry]
}

enum ProfileGuidanceEngine {
	private enum Domain: String, CaseIterable {
		case engineering
		case learning
		case product
		case people
		case health
		case finance
		case reflection

		func label(locale: Locale) -> String {
			switch self {
			case .engineering:
				return AppBrand.localized("构建 / 开发", "Building / Engineering", locale: locale)
			case .learning:
				return AppBrand.localized("学习 / 沉淀", "Learning / Synthesis", locale: locale)
			case .product:
				return AppBrand.localized("产品 / 设计", "Product / Design", locale: locale)
			case .people:
				return AppBrand.localized("关系 / 协作", "Relationships / Collaboration", locale: locale)
			case .health:
				return AppBrand.localized("健康 / 体能", "Health / Energy", locale: locale)
			case .finance:
				return AppBrand.localized("财务 / 资源", "Finance / Resources", locale: locale)
			case .reflection:
				return AppBrand.localized("反思 / 内在感受", "Reflection / Inner State", locale: locale)
			}
		}

		var keywords: [String] {
			switch self {
			case .engineering:
				return ["开发", "编码", "重构", "bug", "api", "release", "deploy", "swift", "build", "工程", "技术", "程序"]
			case .learning:
				return ["学习", "研究", "总结", "笔记", "阅读", "课程", "读书", "知识", "review", "study", "learn"]
			case .product:
				return ["产品", "设计", "交互", "体验", "需求", "用户", "界面", "原型", "ui", "ux", "feature"]
			case .people:
				return ["沟通", "协作", "朋友", "客户", "合作", "联系", "人脉", "关系", "mentor", "team"]
			case .health:
				return ["健康", "运动", "睡眠", "饮食", "体检", "energy", "fitness", "walk", "rest"]
			case .finance:
				return ["支出", "收入", "预算", "消费", "理财", "投资", "money", "budget", "finance", "expense"]
			case .reflection:
				return ["情绪", "反思", "原则", "焦虑", "灵感", "动力", "树洞", "clarity", "emotion", "reflect"]
			}
		}
	}

	static func fallbackSummary(
		context: ProfileGuidanceContext,
		locale: Locale
	) -> ProfileGuidanceSummary {
		let activeTasks = context.tasks.filter { $0.archivedMonthKey == nil }
		let inProgressCount = activeTasks.filter { $0.status == .inProgress }.count
		let overdueCount = activeTasks.filter {
			guard let dueDate = $0.dueDate else { return false }
			return dueDate < .now && !$0.isDone
		}.count
		let recentReview = context.dailyReviews.sorted(by: { $0.day > $1.day }).first
		let lowEnergy = recentReview?.energyScore ?? 3 <= 2
		let lowClarity = recentReview?.clarityScore ?? 3 <= 2
		let domainScores = scoreDomains(context: context)
		let topDomains = domainScores
			.sorted { lhs, rhs in
				if lhs.value == rhs.value {
					return lhs.key.rawValue < rhs.key.rawValue
				}
				return lhs.value > rhs.value
			}
			.filter { $0.value > 0 }
			.prefix(2)
			.map(\.key)

		let domainLabels = topDomains.map { $0.label(locale: locale) }
		let mainFocus = domainLabels.first
			?? AppBrand.localized("探索", "exploration", locale: locale)
		let secondaryFocus = domainLabels.dropFirst().first

		let headline: String = {
			if context.guidanceMode == .exploratory {
				return AppBrand.localized(
					"你还在探索阶段，但最近的记录已经开始指向「\(mainFocus)」\(secondaryFocus == nil ? "" : "与「\(secondaryFocus!)」")。",
					"You are still exploring, but your recent records are already pointing toward \(mainFocus)\(secondaryFocus == nil ? "" : " and \(secondaryFocus!)").",
					locale: locale
				)
			}
			if let secondaryFocus {
				return AppBrand.localized(
					"你最近的重心正稳定落在「\(mainFocus)」与「\(secondaryFocus)」。",
					"Your recent center of gravity is settling around \(mainFocus) and \(secondaryFocus).",
					locale: locale
				)
			}
			return AppBrand.localized(
				"你最近最稳定的投入方向是「\(mainFocus)」。",
				"Your most stable recent investment is in \(mainFocus).",
				locale: locale
			)
		}()

		var strengths: [String] = []
		if context.notes.count >= 3 {
			strengths.append(AppBrand.localized("你有持续沉淀和总结的倾向。", "You show a steady tendency to synthesize and document.", locale: locale))
		}
		if activeTasks.filter(\.isDone).count >= 3 {
			strengths.append(AppBrand.localized("你已经在把想法转成可交付结果。", "You are already converting ideas into deliverable outcomes.", locale: locale))
		}
		if context.goalProgressEntries.count >= 2 {
			strengths.append(AppBrand.localized("你具备持续追踪目标的能力。", "You have the habit of tracking goals over time.", locale: locale))
		}
		if strengths.isEmpty {
			strengths.append(AppBrand.localized("你已经开始留下足够多的痕迹，足以被分析与引导。", "You are already leaving enough trace data to be guided by patterns.", locale: locale))
		}

		var patterns: [String] = []
		if inProgressCount >= 4 {
			patterns.append(AppBrand.localized("你同时推进的事项偏多，注意切回更少的主线。", "You are carrying too many concurrent efforts. Narrow back to fewer main threads.", locale: locale))
		}
		if overdueCount > 0 {
			patterns.append(AppBrand.localized("当前有逾期任务，执行压力正在堆积。", "Overdue tasks are accumulating and increasing execution pressure.", locale: locale))
		}
		if lowEnergy {
			patterns.append(AppBrand.localized("最近的能量偏低，说明节奏需要减压或重排。", "Recent energy looks low, which suggests the cadence needs relief or reprioritization.", locale: locale))
		}
		if lowClarity {
			patterns.append(AppBrand.localized("清晰度下降时，不要继续加任务，而应先整理方向。", "When clarity drops, avoid adding more tasks and reorganize direction first.", locale: locale))
		}
		if patterns.isEmpty {
			patterns.append(AppBrand.localized("你的记录正开始形成稳定模式，适合进入周期性复盘。", "Your records are starting to form stable patterns, which is a good time for periodic review.", locale: locale))
		}

		var nextSteps: [String] = []
		if context.guidanceMode == .exploratory {
			nextSteps.append(AppBrand.localized("从最强的兴趣方向里，选一个 7 天实验主题，只保留一条主线。", "Pick one 7-day experiment from your strongest direction and keep only one main thread.", locale: locale))
		} else {
			nextSteps.append(AppBrand.localized("围绕你最明确的目标，只保留本周最关键的一条执行主线。", "Keep only the single most important execution line for this week around your clearest goal.", locale: locale))
		}
		if let review = recentReview,
		   !review.tomorrowPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			nextSteps.append(AppBrand.localized("把你写下的“明日计划”压缩成一个最小可执行动作。", "Compress your written tomorrow plan into one smallest executable action.", locale: locale))
		} else {
			nextSteps.append(AppBrand.localized("今晚补一条 Daily Review，让系统能更准确识别你的卡点。", "Add a Daily Review tonight so the system can identify your friction points more accurately.", locale: locale))
		}
		if domainScores[.reflection, default: 0] > 0 && domainScores[.engineering, default: 0] > 0 {
			nextSteps.append(AppBrand.localized("把反思里重复出现的问题，转成一个真实的项目改动。", "Turn one repeated reflection into a real project change.", locale: locale))
		}

		let caution = AppBrand.localized(
			"AI 的结论应被理解为模式假设，而不是身份定义。持续记录和复盘，结论会越来越准。",
			"Treat AI output as a pattern hypothesis, not an identity verdict. The more you record and review, the more accurate it becomes.",
			locale: locale
		)

		return ProfileGuidanceSummary(
			headline: headline,
			strengths: Array(strengths.prefix(3)),
			patterns: Array(patterns.prefix(3)),
			nextSteps: Array(nextSteps.prefix(3)),
			caution: caution
		)
	}

	static func fallbackDailyReviewInsight(
		context: DailyReviewContext,
		locale: Locale
	) -> DailyReviewInsight {
		let review = context.review
		let energy = scoreLabel(review.energyScore, locale: locale)
		let clarity = scoreLabel(review.clarityScore, locale: locale)
		let taskDoneCount = context.tasks.filter { $0.status == .done && Calendar.current.isDateInToday($0.completedAt ?? .distantPast) }.count
		let summary = AppBrand.localized(
			"今天的整体状态偏\(energy)，清晰度为\(clarity)。你今天完成了 \(taskDoneCount) 项明确结果，记录里最值得保留的是：\(compactLine(from: review.wins, fallback: "你已经认真记录当下。")).",
			"Today felt \(energy) with \(clarity) clarity. You completed \(taskDoneCount) concrete outcomes, and the most valuable thing to keep is: \(compactLine(from: review.wins, fallback: "you showed up and recorded the day.")).",
			locale: locale
		)

		let guidanceSeed = compactLine(from: review.challenges, fallback: "")
		let guidance: String
		if review.energyScore <= 2 {
			guidance = AppBrand.localized(
				"明天先别加码，先把最重要的一件事做成，并为自己保留恢复空间。\(guidanceSeed.isEmpty ? "" : "尤其要处理：\(guidanceSeed)。")",
				"Tomorrow, do not add more load. Finish one most important task first and leave room for recovery.\(guidanceSeed.isEmpty ? "" : " Pay special attention to: \(guidanceSeed).")",
				locale: locale
			)
		} else if review.clarityScore <= 2 {
			guidance = AppBrand.localized(
				"明天的重点不是做更多，而是先确认方向。把“明日计划”压缩成一个最小动作，再开始执行。",
				"Tomorrow is not about doing more, but clarifying direction first. Compress the plan into one smallest action before execution.",
				locale: locale
			)
		} else {
			guidance = AppBrand.localized(
				"你已经有不错的推进基础。明天延续今天最有效的那条主线，不要同时开太多新分支。",
				"You already have a solid base for momentum. Continue the line that worked best today and avoid opening too many new branches.",
				locale: locale
			)
		}

		return DailyReviewInsight(summary: summary, guidance: guidance)
	}

	private static func scoreDomains(context: ProfileGuidanceContext) -> [Domain: Int] {
		var scores: [Domain: Int] = [:]

		let inboxTexts = context.inboxItems.map(\.content)
		let taskTexts = context.tasks.flatMap { [$0.title, $0.notes, $0.category, $0.tagsText, $0.projectName] }
		let noteTexts = context.notes.flatMap { [$0.title, $0.subtitle, $0.content, $0.topic] }
		let goalTexts = context.goals.flatMap { [$0.title, $0.targetDescription, $0.measurement, $0.nextActionHint] }
		let vitalTexts = context.vitals.flatMap { [$0.content, $0.category] }
		let reviewTexts = context.dailyReviews.flatMap { [$0.wins, $0.challenges, $0.insight, $0.tomorrowPlan] }
		let texts = inboxTexts + taskTexts + noteTexts + goalTexts + vitalTexts + reviewTexts

		for raw in texts {
			let normalized = raw.lowercased()
			for domain in Domain.allCases {
				for keyword in domain.keywords where normalized.contains(keyword.lowercased()) {
					scores[domain, default: 0] += 1
				}
			}
		}

		if context.notes.count >= 3 {
			scores[.learning, default: 0] += 2
		}
		if context.tasks.filter(\.isDone).count >= 3 {
			scores[.engineering, default: 0] += 2
		}
		if context.connections.count > 0 {
			scores[.people, default: 0] += 1
		}
		if context.dailyReviews.count >= 2 {
			scores[.reflection, default: 0] += 2
		}

		return scores
	}

	private static func scoreLabel(_ score: Int, locale: Locale) -> String {
		switch score {
		case 1...2:
			return AppBrand.localized("偏低", "low", locale: locale)
		case 4...5:
			return AppBrand.localized("较高", "strong", locale: locale)
		default:
			return AppBrand.localized("中等", "steady", locale: locale)
		}
	}

	private static func compactLine(from text: String, fallback: String) -> String {
		let trimmed = text
			.replacingOccurrences(of: "\n", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return fallback }
		return trimmed.count > 48 ? String(trimmed.prefix(48)) + "…" : trimmed
	}
}

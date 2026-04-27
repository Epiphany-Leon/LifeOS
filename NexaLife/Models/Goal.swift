//
//  Goal.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//
//  Goal.swift — Lifestyle/Goal

import Foundation
import SwiftData

enum GoalTemplateKind: String, Codable, CaseIterable, Identifiable {
	case custom = "自定义"
	case health = "健康"
	case career = "事业"
	case study = "学习"
	case finance = "财务"
	case relationship = "关系"

	var id: String { rawValue }
}

enum GoalTrackingFrequency: String, Codable, CaseIterable, Identifiable {
	case daily = "每日"
	case weekly = "每周"
	case monthly = "每月"

	var id: String { rawValue }
}

@Model
final class Goal: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var targetDescription: String = ""
    var progress: Double = 0.0          // 0.0 ~ 1.0
    var startDate: Date = Date()
    var dueDate: Date?
    var isCompleted: Bool = false
    var template: GoalTemplateKind = GoalTemplateKind.custom
    var trackingFrequency: GoalTrackingFrequency = GoalTrackingFrequency.weekly
    var measurement: String = ""
    var nextActionHint: String = ""

    init(title: String, targetDescription: String = "", dueDate: Date? = nil) {
        self.title = title
        self.targetDescription = targetDescription
        self.dueDate = dueDate
    }
}

//
//  VitalsEntry.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import Foundation
import SwiftData

enum VitalsEntryType: String, Codable, CaseIterable {
	case coreCode   = "核心守则"
	case treehol    = "树洞"
	case motivation = "动力/灵感"
}

@Model
final class VitalsEntry: Identifiable {
	var id: UUID = UUID()
	var content: String = ""
	var type: VitalsEntryType = VitalsEntryType.motivation
	var timestamp: Date = Date()
	var category: String = ""          // 核心守则分类，其他类型可留空
	var isProtected: Bool = false   // 核心守则 & 树洞 = true
	var isArchived: Bool = false    // 已存档到 Vitals/Knowledge
	var moodScore: Int = 0          // 动力/灵感打分 1-5，其他类型为 0

	init(
		content: String,
		type: VitalsEntryType = .motivation,
		category: String = "",
		isProtected: Bool = false,
		moodScore: Int = 0
	) {
		self.content = content
		self.type = type
		self.category = category
		self.isProtected = isProtected
		self.moodScore = moodScore
	}
}

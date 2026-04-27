//
//  DailyReviewEntry.swift
//  NexaLife
//
//  Created by Codex on 2026-04-05.
//

import Foundation
import SwiftData

@Model
final class DailyReviewEntry: Identifiable {
	var id: UUID = UUID()
	var day: Date = Date()
	var wins: String = ""
	var challenges: String = ""
	var insight: String = ""
	var tomorrowPlan: String = ""
	var energyScore: Int = 3
	var clarityScore: Int = 3
	var aiSummary: String = ""
	var aiGuidance: String = ""
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(day: Date = Date()) {
		self.day = Calendar.current.startOfDay(for: day)
	}
}

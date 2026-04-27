//
//  ExecutionProject.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-03-02.
//

import Foundation
import SwiftData

enum ProjectHorizon: String, Codable, CaseIterable {
	case shortTerm = "短期"
	case midTerm = "中期"
	case longTerm = "长期"
}

enum ProjectStatus: String, Codable, CaseIterable {
	case notStarted = "未开始"
	case inProgress = "进行中"
	case finished   = "已结项"
	case paused     = "已暂停"
}

@Model
final class ExecutionProject: Identifiable {
	var id: UUID = UUID()
	var name: String = ""
	var detail: String = ""
	var horizon: ProjectHorizon = ProjectHorizon.shortTerm
	var status: ProjectStatus = ProjectStatus.notStarted
	var startDate: Date?
	var endDate: Date?
	var createdAt: Date = Date()
	var updatedAt: Date = Date()

	init(
		name: String,
		detail: String = "",
		horizon: ProjectHorizon = ProjectHorizon.shortTerm,
		status: ProjectStatus = ProjectStatus.notStarted,
		startDate: Date? = nil,
		endDate: Date? = nil
	) {
		self.name = name
		self.detail = detail
		self.horizon = horizon
		self.status = status
		self.startDate = startDate
		self.endDate = endDate
	}
}

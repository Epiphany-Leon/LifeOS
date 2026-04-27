//
//  AppDataArchiveService.swift
//  NexaLife
//
//  Created by Codex on 2026-03-13.
//

import Foundation
import SwiftData

struct NexaLifeDataArchive: Codable {
	var version: Int
	var exportedAt: Date
	var latestChangeAt: Date
	var profile: AppProfileSnapshot
	var data: AppRecordsSnapshot
}

struct AppProfileSnapshot: Codable {
	var hasCompletedOnboarding: Bool
	var userName: String
	var avatarPNGBase64: String?
	var accountProvider: String
	var accountEmail: String
	var accountIdentifier: String
	var globalCurrency: String
	var monthlyBudget: Double
	var profileGuidanceMode: String
	var appLanguagePreference: String
	var appAppearanceMode: String
	var startupModule: String
	var aiProvider: String
	var aiModelDeepSeek: String
	var aiModelQwen: String
	var aiTimeoutSeconds: Double
	var backupFrequency: String
	var quickCaptureShortcut: String
	var globalSearchShortcut: String
	var logLevel: String
	var crashReportEnabled: Bool

	@MainActor
	init(appState: AppState) {
		hasCompletedOnboarding = appState.hasCompletedOnboarding
		userName = appState.userName
		avatarPNGBase64 = Self.readAvatarBase64(from: appState.avatarImagePath)
		accountProvider = appState.accountProvider
		accountEmail = appState.accountEmail
		accountIdentifier = appState.accountIdentifier
		globalCurrency = appState.globalCurrency
		monthlyBudget = appState.monthlyBudget
		profileGuidanceMode = appState.profileGuidanceMode
		appLanguagePreference = appState.appLanguagePreference
		appAppearanceMode = appState.appAppearanceMode
		startupModule = appState.startupModule
		aiProvider = appState.aiProvider
		aiModelDeepSeek = appState.aiModelDeepSeek
		aiModelQwen = appState.aiModelQwen
		aiTimeoutSeconds = appState.aiTimeoutSeconds
		backupFrequency = appState.backupFrequency
		quickCaptureShortcut = appState.quickCaptureShortcut
		globalSearchShortcut = appState.globalSearchShortcut
		logLevel = appState.logLevel
		crashReportEnabled = appState.crashReportEnabled
	}

	@MainActor
	func apply(to appState: AppState) {
		appState.userName = userName
		appState.hasCompletedOnboarding = hasCompletedOnboarding || !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		appState.accountProvider = accountProvider
		appState.accountEmail = accountEmail
		appState.accountIdentifier = accountIdentifier
		appState.authToken = accountIdentifier.isEmpty ? nil : accountIdentifier
		appState.globalCurrency = globalCurrency
		appState.monthlyBudget = monthlyBudget
		appState.profileGuidanceMode = profileGuidanceMode
		appState.appLanguagePreference = appLanguagePreference
		appState.appAppearanceMode = appAppearanceMode
		appState.startupModule = startupModule
		appState.aiProvider = aiProvider
		appState.aiModelDeepSeek = aiModelDeepSeek
		appState.aiModelQwen = aiModelQwen
		appState.aiTimeoutSeconds = aiTimeoutSeconds
		appState.backupFrequency = backupFrequency
		appState.quickCaptureShortcut = quickCaptureShortcut
		appState.globalSearchShortcut = globalSearchShortcut
		appState.logLevel = logLevel
		appState.crashReportEnabled = crashReportEnabled
		appState.avatarImagePath = Self.writeAvatarBase64(avatarPNGBase64)
	}

	private static func readAvatarBase64(from path: String) -> String? {
		guard !path.isEmpty,
			  let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
			  !data.isEmpty else {
			return nil
		}
		return data.base64EncodedString()
	}

	@MainActor
	private static func writeAvatarBase64(_ base64: String?) -> String {
		guard let base64,
			  let data = Data(base64Encoded: base64),
			  !data.isEmpty else {
			return ""
		}

		let folder = AppDataArchiveService.avatarStoreFolderURL()
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			let fileName = "avatar-import-\(UUID().uuidString).png"
			let targetURL = folder.appendingPathComponent(fileName)
			try data.write(to: targetURL, options: .atomic)
			return targetURL.path
		} catch {
			return ""
		}
	}
}

struct AppRecordsSnapshot: Codable {
	var inboxItems: [InboxItemSnapshot]
	var taskItems: [TaskItemSnapshot]
	var executionProjects: [ExecutionProjectSnapshot]
	var notes: [NoteSnapshot]
	var transactions: [TransactionSnapshot]
	var goals: [GoalSnapshot]
	var goalMilestones: [GoalMilestoneSnapshot]
	var goalProgressEntries: [GoalProgressEntrySnapshot]
	var dailyReviews: [DailyReviewEntrySnapshot]
	var vitalsEntries: [VitalsEntrySnapshot]
	var connections: [ConnectionSnapshot]
	var dashboardSnapshots: [DashboardSnapshotRecord]
}

struct InboxItemSnapshot: Codable {
	var id: UUID
	var timestamp: Date
	var content: String
	var isProcessed: Bool
	var suggestedModule: String?

	init(_ item: InboxItem) {
		id = item.id
		timestamp = item.timestamp
		content = item.content
		isProcessed = item.isProcessed
		suggestedModule = item.suggestedModule
	}

	func model() -> InboxItem {
		let item = InboxItem(
			content: content,
			timestamp: timestamp,
			isProcessed: isProcessed,
			suggestedModule: suggestedModule
		)
		item.id = id
		return item
	}
}

struct TaskItemSnapshot: Codable {
	var id: UUID
	var title: String
	var notes: String
	var category: String
	var tagsText: String
	var status: TaskStatus
	var projectName: String
	var dueDate: Date?
	var createdAt: Date
	var completedAt: Date?
	var archivedMonthKey: String?

	init(_ item: TaskItem) {
		id = item.id
		title = item.title
		notes = item.notes
		category = item.category
		tagsText = item.tagsText
		status = item.status
		projectName = item.projectName
		dueDate = item.dueDate
		createdAt = item.createdAt
		completedAt = item.completedAt
		archivedMonthKey = item.archivedMonthKey
	}

	func model() -> TaskItem {
		let item = TaskItem(
			title: title,
			notes: notes,
			category: category,
			tagsText: tagsText,
			status: status,
			projectName: projectName,
			dueDate: dueDate,
			completedAt: completedAt,
			archivedMonthKey: archivedMonthKey
		)
		item.id = id
		item.createdAt = createdAt
		return item
	}
}

struct ExecutionProjectSnapshot: Codable {
	var id: UUID
	var name: String
	var detail: String
	var horizon: ProjectHorizon
	var createdAt: Date
	var updatedAt: Date

	init(_ project: ExecutionProject) {
		id = project.id
		name = project.name
		detail = project.detail
		horizon = project.horizon
		createdAt = project.createdAt
		updatedAt = project.updatedAt
	}

	func model() -> ExecutionProject {
		let project = ExecutionProject(name: name, detail: detail, horizon: horizon)
		project.id = id
		project.createdAt = createdAt
		project.updatedAt = updatedAt
		return project
	}
}

struct NoteSnapshot: Codable {
	var id: UUID
	var title: String
	var subtitle: String
	var content: String
	var topic: String
	var createdAt: Date
	var updatedAt: Date

	init(_ note: Note) {
		id = note.id
		title = note.title
		subtitle = note.subtitle
		content = note.content
		topic = note.topic
		createdAt = note.createdAt
		updatedAt = note.updatedAt
	}

	func model() -> Note {
		let note = Note(title: title, subtitle: subtitle, content: content, topic: topic)
		note.id = id
		note.createdAt = createdAt
		note.updatedAt = updatedAt
		return note
	}
}

struct TransactionSnapshot: Codable {
	var id: UUID
	var amount: Double
	var category: String
	var title: String
	var note: String
	var date: Date
	var currencyCode: String
	var streamName: String

	init(_ transaction: Transaction) {
		id = transaction.id
		amount = transaction.amount
		category = transaction.category
		title = transaction.title
		note = transaction.note
		date = transaction.date
		currencyCode = transaction.currencyCode
		streamName = transaction.streamName
	}

	func model() -> Transaction {
		let transaction = Transaction(
			amount: amount,
			category: category,
			title: title,
			note: note,
			date: date,
			currencyCode: currencyCode,
			streamName: streamName
		)
		transaction.id = id
		return transaction
	}
}

struct GoalSnapshot: Codable {
	var id: UUID
	var title: String
	var targetDescription: String
	var progress: Double
	var startDate: Date
	var dueDate: Date?
	var isCompleted: Bool
	var template: GoalTemplateKind
	var trackingFrequency: GoalTrackingFrequency
	var measurement: String
	var nextActionHint: String

	init(_ goal: Goal) {
		id = goal.id
		title = goal.title
		targetDescription = goal.targetDescription
		progress = goal.progress
		startDate = goal.startDate
		dueDate = goal.dueDate
		isCompleted = goal.isCompleted
		template = goal.template
		trackingFrequency = goal.trackingFrequency
		measurement = goal.measurement
		nextActionHint = goal.nextActionHint
	}

	func model() -> Goal {
		let goal = Goal(title: title, targetDescription: targetDescription, dueDate: dueDate)
		goal.id = id
		goal.progress = progress
		goal.startDate = startDate
		goal.isCompleted = isCompleted
		goal.template = template
		goal.trackingFrequency = trackingFrequency
		goal.measurement = measurement
		goal.nextActionHint = nextActionHint
		return goal
	}
}

struct GoalMilestoneSnapshot: Codable {
	var id: UUID
	var goalID: UUID
	var title: String
	var isCompleted: Bool
	var createdAt: Date
	var dueDate: Date?

	init(_ milestone: GoalMilestone) {
		id = milestone.id
		goalID = milestone.goalID
		title = milestone.title
		isCompleted = milestone.isCompleted
		createdAt = milestone.createdAt
		dueDate = milestone.dueDate
	}

	func model() -> GoalMilestone {
		let milestone = GoalMilestone(
			goalID: goalID,
			title: title,
			isCompleted: isCompleted,
			dueDate: dueDate,
			createdAt: createdAt
		)
		milestone.id = id
		return milestone
	}
}

struct GoalProgressEntrySnapshot: Codable {
	var id: UUID
	var goalID: UUID
	var recordedAt: Date
	var progress: Double
	var title: String
	var note: String

	init(_ entry: GoalProgressEntry) {
		id = entry.id
		goalID = entry.goalID
		recordedAt = entry.recordedAt
		progress = entry.progress
		title = entry.title
		note = entry.note
	}

	func model() -> GoalProgressEntry {
		let entry = GoalProgressEntry(
			goalID: goalID,
			recordedAt: recordedAt,
			progress: progress,
			title: title,
			note: note
		)
		entry.id = id
		return entry
	}
}

struct DailyReviewEntrySnapshot: Codable {
	var id: UUID
	var day: Date
	var wins: String
	var challenges: String
	var insight: String
	var tomorrowPlan: String
	var energyScore: Int
	var clarityScore: Int
	var aiSummary: String
	var aiGuidance: String
	var createdAt: Date
	var updatedAt: Date

	init(_ review: DailyReviewEntry) {
		id = review.id
		day = review.day
		wins = review.wins
		challenges = review.challenges
		insight = review.insight
		tomorrowPlan = review.tomorrowPlan
		energyScore = review.energyScore
		clarityScore = review.clarityScore
		aiSummary = review.aiSummary
		aiGuidance = review.aiGuidance
		createdAt = review.createdAt
		updatedAt = review.updatedAt
	}

	func model() -> DailyReviewEntry {
		let review = DailyReviewEntry(day: day)
		review.id = id
		review.wins = wins
		review.challenges = challenges
		review.insight = insight
		review.tomorrowPlan = tomorrowPlan
		review.energyScore = energyScore
		review.clarityScore = clarityScore
		review.aiSummary = aiSummary
		review.aiGuidance = aiGuidance
		review.createdAt = createdAt
		review.updatedAt = updatedAt
		return review
	}
}

struct VitalsEntrySnapshot: Codable {
	var id: UUID
	var content: String
	var type: VitalsEntryType
	var timestamp: Date
	var category: String
	var isProtected: Bool
	var isArchived: Bool
	var moodScore: Int

	init(_ entry: VitalsEntry) {
		id = entry.id
		content = entry.content
		type = entry.type
		timestamp = entry.timestamp
		category = entry.category
		isProtected = entry.isProtected
		isArchived = entry.isArchived
		moodScore = entry.moodScore
	}

	func model() -> VitalsEntry {
		let entry = VitalsEntry(
			content: content,
			type: type,
			category: category,
			isProtected: isProtected,
			moodScore: moodScore
		)
		entry.id = id
		entry.timestamp = timestamp
		entry.isArchived = isArchived
		return entry
	}
}

struct ConnectionSnapshot: Codable {
	var id: UUID
	var name: String
	var relationship: String
	var notes: String
	var lastContactDate: Date?
	var importanceLevel: Int
	var attitudeStrategy: String
	var followUpPlan: String

	init(_ connection: Connection) {
		id = connection.id
		name = connection.name
		relationship = connection.relationship
		notes = connection.notes
		lastContactDate = connection.lastContactDate
		importanceLevel = connection.importanceLevel
		attitudeStrategy = connection.attitudeStrategy
		followUpPlan = connection.followUpPlan
	}

	func model() -> Connection {
		let connection = Connection(
			name: name,
			relationship: relationship,
			notes: notes,
			importanceLevel: importanceLevel,
			attitudeStrategy: attitudeStrategy,
			followUpPlan: followUpPlan
		)
		connection.id = id
		connection.lastContactDate = lastContactDate
		return connection
	}
}

struct DashboardSnapshotRecord: Codable {
	var id: UUID
	var monthKey: String
	var createdAt: Date
	var pendingTasks: Int
	var doneTasks: Int
	var totalNotes: Int
	var monthlyIncome: Double
	var monthlyExpense: Double
	var activeGoals: Int
	var vitalsCount: Int
	var summary: String

	init(_ snapshot: DashboardSnapshot) {
		id = snapshot.id
		monthKey = snapshot.monthKey
		createdAt = snapshot.createdAt
		pendingTasks = snapshot.pendingTasks
		doneTasks = snapshot.doneTasks
		totalNotes = snapshot.totalNotes
		monthlyIncome = snapshot.monthlyIncome
		monthlyExpense = snapshot.monthlyExpense
		activeGoals = snapshot.activeGoals
		vitalsCount = snapshot.vitalsCount
		summary = snapshot.summary
	}

	func model() -> DashboardSnapshot {
		let snapshot = DashboardSnapshot(
			monthKey: monthKey,
			pendingTasks: pendingTasks,
			doneTasks: doneTasks,
			totalNotes: totalNotes,
			monthlyIncome: monthlyIncome,
			monthlyExpense: monthlyExpense,
			activeGoals: activeGoals,
			vitalsCount: vitalsCount
		)
		snapshot.id = id
		snapshot.createdAt = createdAt
		snapshot.summary = summary
		return snapshot
	}
}

enum AppDataImportError: LocalizedError {
	case missingArchiveFile
	case invalidArchiveRoot

	var errorDescription: String? {
		switch self {
		case .missingArchiveFile:
			return "没有找到 NexaLife 数据包。"
		case .invalidArchiveRoot:
			return "选择的位置不是有效的 NexaLife 数据包。"
		}
	}
}

enum SyncDecision {
	case pushed(URL)
	case pulled(URL)
	case noChanges(URL)
}

@MainActor
enum AppDataArchiveService {
	static let archiveFileName = AppBrand.syncArchiveFileName
	private static let archiveVersion = 2

	static func captureSnapshot(
		modelContext: ModelContext,
		appState: AppState
	) throws -> NexaLifeDataArchive {
		let inboxItems = try modelContext.fetch(FetchDescriptor<InboxItem>())
		let taskItems = try modelContext.fetch(FetchDescriptor<TaskItem>())
		let executionProjects = try modelContext.fetch(FetchDescriptor<ExecutionProject>())
		let notes = try modelContext.fetch(FetchDescriptor<Note>())
		let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
		let goals = try modelContext.fetch(FetchDescriptor<Goal>())
		let goalMilestones = try modelContext.fetch(FetchDescriptor<GoalMilestone>())
		let goalProgressEntries = try modelContext.fetch(FetchDescriptor<GoalProgressEntry>())
		let dailyReviews = try modelContext.fetch(FetchDescriptor<DailyReviewEntry>())
		let vitalsEntries = try modelContext.fetch(FetchDescriptor<VitalsEntry>())
		let connections = try modelContext.fetch(FetchDescriptor<Connection>())
		let dashboardSnapshots = try modelContext.fetch(FetchDescriptor<DashboardSnapshot>())

		let inboxSnapshots = inboxItems.map(InboxItemSnapshot.init)
		let taskSnapshots = taskItems.map(TaskItemSnapshot.init)
		let projectSnapshots = executionProjects.map(ExecutionProjectSnapshot.init)
		let noteSnapshots = notes.map(NoteSnapshot.init)
		let transactionSnapshots = transactions.map(TransactionSnapshot.init)
		let goalSnapshots = goals.map(GoalSnapshot.init)
		let milestoneSnapshots = goalMilestones.map(GoalMilestoneSnapshot.init)
		let progressSnapshots = goalProgressEntries.map(GoalProgressEntrySnapshot.init)
		let dailyReviewSnapshots = dailyReviews.map(DailyReviewEntrySnapshot.init)
		let vitalsSnapshots = vitalsEntries.map(VitalsEntrySnapshot.init)
		let connectionSnapshots = connections.map(ConnectionSnapshot.init)
		let dashboardSnapshotRecords = dashboardSnapshots.map(DashboardSnapshotRecord.init)

		let records = AppRecordsSnapshot(
			inboxItems: inboxSnapshots,
			taskItems: taskSnapshots,
			executionProjects: projectSnapshots,
			notes: noteSnapshots,
			transactions: transactionSnapshots,
			goals: goalSnapshots,
			goalMilestones: milestoneSnapshots,
			goalProgressEntries: progressSnapshots,
			dailyReviews: dailyReviewSnapshots,
			vitalsEntries: vitalsSnapshots,
			connections: connectionSnapshots,
			dashboardSnapshots: dashboardSnapshotRecords
		)

		let profile = AppProfileSnapshot(appState: appState)
		let exportedAt = Date()
		let taskDates = taskItems.flatMap { [$0.createdAt, $0.completedAt].compactMap { $0 } }
		let projectDates = executionProjects.flatMap { [$0.createdAt, $0.updatedAt] }
		let noteDates = notes.flatMap { [$0.createdAt, $0.updatedAt] }
		let goalDates = goals.flatMap { [$0.startDate, $0.dueDate].compactMap { $0 } }
		let milestoneDates = goalMilestones.flatMap { [$0.createdAt, $0.dueDate].compactMap { $0 } }
		let latestChangeAt = maximumDate(
			exportedAt,
			inboxItems.map { $0.timestamp },
			taskDates,
			projectDates,
			noteDates,
			transactions.map { $0.date },
			goalDates,
			milestoneDates,
			goalProgressEntries.map { $0.recordedAt },
			dailyReviews.flatMap { [$0.day, $0.createdAt, $0.updatedAt] },
			vitalsEntries.map { $0.timestamp },
			connections.compactMap { $0.lastContactDate },
			dashboardSnapshots.map { $0.createdAt }
		)

		return NexaLifeDataArchive(
			version: archiveVersion,
			exportedAt: exportedAt,
			latestChangeAt: latestChangeAt,
			profile: profile,
			data: records
		)
	}

	static func writeSnapshot(
		_ archive: NexaLifeDataArchive,
		toDirectory directory: URL,
		fileName: String
	) throws -> URL {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		let target = directory.appendingPathComponent(fileName)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(archive).write(to: target, options: .atomic)
		return target
	}

	static func loadSnapshot(from source: URL) throws -> NexaLifeDataArchive {
		let fileURL = try resolveArchiveFileURL(for: source)
		let data = try Data(contentsOf: fileURL)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try decoder.decode(NexaLifeDataArchive.self, from: data)
	}

	static func replaceLocalData(
		with archive: NexaLifeDataArchive,
		modelContext: ModelContext,
		appState: AppState
	) throws {
		try clearAllModelData(modelContext: modelContext)

		for snapshot in archive.data.inboxItems {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.taskItems {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.executionProjects {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.notes {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.transactions {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.goals {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.goalMilestones {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.goalProgressEntries {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.dailyReviews {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.vitalsEntries {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.connections {
			modelContext.insert(snapshot.model())
		}
		for snapshot in archive.data.dashboardSnapshots {
			modelContext.insert(snapshot.model())
		}

		archive.profile.apply(to: appState)
		try modelContext.save()
		NotificationCenter.default.post(name: .nexaLifeResetSelections, object: nil)
	}

	static func clearAllModelData(modelContext: ModelContext) throws {
		try deleteAll(InboxItem.self, modelContext: modelContext)
		try deleteAll(TaskItem.self, modelContext: modelContext)
		try deleteAll(ExecutionProject.self, modelContext: modelContext)
		try deleteAll(Note.self, modelContext: modelContext)
		try deleteAll(Transaction.self, modelContext: modelContext)
		try deleteAll(Goal.self, modelContext: modelContext)
		try deleteAll(GoalMilestone.self, modelContext: modelContext)
		try deleteAll(GoalProgressEntry.self, modelContext: modelContext)
		try deleteAll(DailyReviewEntry.self, modelContext: modelContext)
		try deleteAll(VitalsEntry.self, modelContext: modelContext)
		try deleteAll(Connection.self, modelContext: modelContext)
		try deleteAll(DashboardSnapshot.self, modelContext: modelContext)
		try modelContext.save()
		NotificationCenter.default.post(name: .nexaLifeResetSelections, object: nil)
	}

	static func performFolderSync(
		at directory: URL,
		modelContext: ModelContext,
		appState: AppState
	) throws -> SyncDecision {
		let local = try captureSnapshot(modelContext: modelContext, appState: appState)
		let remoteURL = directory.appendingPathComponent(archiveFileName)
		let fm = FileManager.default

		guard fm.fileExists(atPath: remoteURL.path) else {
			let writtenURL = try writeSnapshot(local, toDirectory: directory, fileName: archiveFileName)
			return .pushed(writtenURL)
		}

		let remote = try loadSnapshot(from: remoteURL)
		if remote.latestChangeAt > local.latestChangeAt {
			try replaceLocalData(with: remote, modelContext: modelContext, appState: appState)
			return .pulled(remoteURL)
		}

		if local.latestChangeAt > remote.latestChangeAt {
			let writtenURL = try writeSnapshot(local, toDirectory: directory, fileName: archiveFileName)
			return .pushed(writtenURL)
		}

		return .noChanges(remoteURL)
	}

	static func maximumDate(_ seed: Date, _ dateGroups: [Date]...) -> Date {
		dateGroups
			.flatMap { $0 }
			.max() ?? seed
	}

	static func avatarStoreFolderURL() -> URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		return AppBrand.migratedDirectory(
			in: base,
			preferredPath: AppBrand.avatarFolderPath,
			legacyPath: AppBrand.legacyAvatarFolderPath
		)
	}

	private static func resolveArchiveFileURL(for source: URL) throws -> URL {
		var isDirectory: ObjCBool = false
		let fm = FileManager.default
		guard fm.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
			throw AppDataImportError.missingArchiveFile
		}
		if !isDirectory.boolValue {
			return source
		}

		for candidate in [archiveFileName, AppBrand.legacySyncArchiveFileName] {
			let fileURL = source.appendingPathComponent(candidate)
			if fm.fileExists(atPath: fileURL.path) {
				return fileURL
			}
		}

		let candidates = try fm.contentsOfDirectory(
			at: source,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		)
		if let firstJSON = candidates.first(where: { $0.pathExtension.lowercased() == "json" }) {
			return firstJSON
		}
		throw AppDataImportError.invalidArchiveRoot
	}

	private static func deleteAll<T: PersistentModel>(
		_ type: T.Type,
		modelContext: ModelContext
	) throws {
		let items = try modelContext.fetch(FetchDescriptor<T>())
		for item in items {
			modelContext.delete(item)
		}
	}
}

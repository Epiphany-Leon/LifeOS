//
//  AppNotifications.swift
//  NexaLife
//

import Foundation
import UserNotifications

extension Notification.Name {
	static let nexaLifeShowQuickInput = Notification.Name("nexaLife.showQuickInput")
	static let nexaLifeShowGlobalSearch = Notification.Name("nexaLife.showGlobalSearch")
	static let nexaLifeExecutionCreateTask = Notification.Name("nexaLife.execution.createTask")
	static let nexaLifeExecutionManageProjects = Notification.Name("nexaLife.execution.manageProjects")
	static let nexaLifeKnowledgeCreateNote = Notification.Name("nexaLife.knowledge.createNote")
	static let nexaLifeKnowledgeShowTopicList = Notification.Name("nexaLife.knowledge.showTopicList")
	static let nexaLifeLifestyleCreateTransaction = Notification.Name("nexaLife.lifestyle.createTransaction")
	static let nexaLifeLifestyleCreateGoal = Notification.Name("nexaLife.lifestyle.createGoal")
	static let nexaLifeLifestyleCreateConnection = Notification.Name("nexaLife.lifestyle.createConnection")
	static let nexaLifeVitalsCreateEntry = Notification.Name("nexaLife.vitals.createEntry")
	static let nexaLifePerformAutoBackup = Notification.Name("nexaLife.performAutoBackup")
	static let nexaLifeResetSelections = Notification.Name("nexaLife.resetSelections")
	static let nexaLifeOpenAISettings = Notification.Name("nexaLife.openAISettings")
	static let nexaLifeShowAIChat = Notification.Name("nexaLife.showAIChat")
}

enum DailyReviewReminderScheduler {
	private static let identifier = "nexalife.daily-review.reminder"

	static func configureIfNeeded() {
		let center = UNUserNotificationCenter.current()
		center.getNotificationSettings { settings in
			switch settings.authorizationStatus {
			case .authorized, .provisional, .ephemeral:
				scheduleReminder(on: center)
			case .notDetermined:
				center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
					guard granted else { return }
					scheduleReminder(on: center)
				}
			case .denied:
				break
			@unknown default:
				break
			}
		}
	}

	private static func scheduleReminder(on center: UNUserNotificationCenter) {
		center.removePendingNotificationRequests(withIdentifiers: [identifier])

		let content = UNMutableNotificationContent()
		content.title = "Nightly Review"
		content.body = "记录今天、识别模式，然后只给明天留一个最小动作。"
		content.sound = .default

		var dateComponents = DateComponents()
		dateComponents.hour = 22
		dateComponents.minute = 0

		let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
		let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
		center.add(request)
	}
}

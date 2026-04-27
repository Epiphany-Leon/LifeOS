//
//  CustomAIProviderStore.swift
//  NexaLife
//
//  User-defined AI providers persisted in UserDefaults. Built-in providers
//  (deepseek / qwen) live alongside these in the picker.
//

import Foundation

struct CustomAIProvider: Codable, Identifiable, Equatable {
	var id: UUID
	var name: String
	var endpoint: String
	var models: [String]

	init(id: UUID = UUID(), name: String, endpoint: String, models: [String]) {
		self.id = id
		self.name = name
		self.endpoint = endpoint
		self.models = models
	}
}

enum CustomAIProviderStore {
	private static let key = "customAIProviders"

	static func load() -> [CustomAIProvider] {
		guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
		return (try? JSONDecoder().decode([CustomAIProvider].self, from: data)) ?? []
	}

	static func save(_ providers: [CustomAIProvider]) {
		guard let data = try? JSONEncoder().encode(providers) else { return }
		UserDefaults.standard.set(data, forKey: key)
		NotificationCenter.default.post(name: .nexaLifeCustomProvidersChanged, object: nil)
	}

	static func add(_ provider: CustomAIProvider) {
		var providers = load()
		providers.append(provider)
		save(providers)
	}

	static func remove(id: UUID) {
		var providers = load()
		providers.removeAll { $0.id == id }
		save(providers)
	}
}

extension Notification.Name {
	static let nexaLifeCustomProvidersChanged = Notification.Name("nexaLife.customProvidersChanged")
}

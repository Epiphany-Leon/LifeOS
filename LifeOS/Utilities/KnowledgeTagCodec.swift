//
//  KnowledgeTagCodec.swift
//  LifeOS
//
//  Created by Codex on 2026-03-05.
//

import Foundation

enum KnowledgeTagCodec {
	private static let separators = CharacterSet(charactersIn: ",，|;；\n\t")

	static func parse(_ raw: String) -> [String] {
		let parts = raw.components(separatedBy: separators)
		var seen: Set<String> = []
		var tags: [String] = []
		for part in parts {
			let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			let dedupeKey = trimmed.lowercased()
			guard !seen.contains(dedupeKey) else { continue }
			seen.insert(dedupeKey)
			tags.append(trimmed)
		}
		return tags
	}

	static func serialize(_ tags: [String]) -> String {
		tags.joined(separator: " | ")
	}
}

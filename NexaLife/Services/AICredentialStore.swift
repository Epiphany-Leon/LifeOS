//
//  AICredentialStore.swift
//  NexaLife
//
//  Created by Codex on 2026-03-01.
//

import Foundation

enum APITokenStorageMode: String, CaseIterable, Identifiable {
	case keychain
	case localFile

	var id: String { rawValue }

	var label: String {
		switch self {
		case .keychain: return "系统钥匙串 Keychain"
		case .localFile: return "本地文件 Local File"
		}
	}
}

enum AICredentialStore {
	private static let service = AppBrand.keychainService
	private static let legacyService = AppBrand.legacyKeychainService
	private static let account = "aiApiKey"
	private static let storageModeKey = "apiTokenStorageMode"
	private static let localFilePathKey = "apiTokenLocalFilePath"
	private static let migratedLegacyTokenKey = "apiTokenMigratedToKeychain"
	private static let storageDirectoryKey = "storageDirectory"
	private static let fallbackFolderName = AppBrand.workspaceFolderName
	private static let legacyFallbackFolderName = AppBrand.legacyWorkspaceFolderName
	private static let tokenFileName = "ai_api_token.txt"

	/// Storage mode is fixed to local file. The enum is kept around for legacy
	/// migration purposes but the picker is no longer surfaced in the UI.
	static var mode: APITokenStorageMode { .localFile }

	static func bootstrapSecurityDefaults() {
		// Pin storage mode to local file, regardless of any legacy preference.
		UserDefaults.standard.set(APITokenStorageMode.localFile.rawValue, forKey: storageModeKey)

		// One-shot migration: if a token still lives in the Keychain (from
		// older builds), copy it to the local file and drop the Keychain copy.
		migrateLegacyKeychainServiceIfNeeded()
		let keychainToken = (KeychainHelper.shared.read(service: service, account: account) ?? "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		if !keychainToken.isEmpty {
			let localToken = (readFromLocalFile() ?? "")
				.trimmingCharacters(in: .whitespacesAndNewlines)
			if localToken.isEmpty {
				saveToLocalFile(keychainToken)
				AppLogger.info("Migrated AI token from Keychain to local file.", category: "security")
			}
			_ = KeychainHelper.shared.delete(service: service, account: account)
			_ = KeychainHelper.shared.delete(service: legacyService, account: account)
		}

		UserDefaults.standard.set(true, forKey: migratedLegacyTokenKey)
	}

	static func saveAPIKey(_ key: String) {
		let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !normalized.isEmpty else { return }
		saveToLocalFile(normalized)
		// Mirror the cleanup in case any legacy Keychain entry lingered.
		_ = KeychainHelper.shared.delete(service: service, account: account)
		_ = KeychainHelper.shared.delete(service: legacyService, account: account)
	}

	static func readAPIKey() -> String {
		(readFromLocalFile() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
	}

	static func storageLocationDescription() -> String {
		writableLocalTokenFileURL().path
	}

		static func localFileURL() -> URL {
			writableLocalTokenFileURL()
		}

	static func setLocalFileURL(_ url: URL) {
		UserDefaults.standard.set(url.path, forKey: localFilePathKey)
	}

	static func clearAPIKey() {
		_ = KeychainHelper.shared.delete(service: service, account: account)
		_ = KeychainHelper.shared.delete(service: legacyService, account: account)
		removeLocalFileIfExists()
		UserDefaults.standard.removeObject(forKey: localFilePathKey)
		UserDefaults.standard.set(APITokenStorageMode.localFile.rawValue, forKey: storageModeKey)
	}

	private static func saveToLocalFile(_ key: String) {
		let url = writableLocalTokenFileURL()
		do {
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(),
				withIntermediateDirectories: true,
				attributes: nil
			)
			guard let data = key.data(using: .utf8) else { return }
			try data.write(to: url, options: [.atomic])
			let legacyURL = legacyDefaultTokenFileURL()
			if legacyURL != url, FileManager.default.fileExists(atPath: legacyURL.path) {
				try? FileManager.default.removeItem(at: legacyURL)
			}
		} catch {
			AppLogger.error("AICredentialStore save file failed: \(error.localizedDescription)", category: "security")
		}
	}

	private static func readFromLocalFile() -> String? {
		let url = readableLocalTokenFileURL()
		guard let data = try? Data(contentsOf: url) else { return nil }
		return String(data: data, encoding: .utf8)
	}

	private static func writableLocalTokenFileURL() -> URL {
		if let customPath = UserDefaults.standard.string(forKey: localFilePathKey),
		   !customPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return URL(fileURLWithPath: customPath)
		}

		if let userPath = UserDefaults.standard.string(forKey: storageDirectoryKey),
		   !userPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return URL(fileURLWithPath: userPath).appendingPathComponent(tokenFileName)
		}

		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		let folder = AppBrand.migratedDirectory(
			in: base,
			preferredPath: fallbackFolderName,
			legacyPath: legacyFallbackFolderName
		)
		return folder.appendingPathComponent(tokenFileName)
	}

	private static func readableLocalTokenFileURL() -> URL {
		let preferredURL = writableLocalTokenFileURL()
		if FileManager.default.fileExists(atPath: preferredURL.path) {
			return preferredURL
		}
		let legacyURL = legacyDefaultTokenFileURL()
		if FileManager.default.fileExists(atPath: legacyURL.path) {
			return legacyURL
		}
		return preferredURL
	}

	private static func legacyDefaultTokenFileURL() -> URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		return base
			.appendingPathComponent(legacyFallbackFolderName, isDirectory: true)
			.appendingPathComponent(tokenFileName)
	}

	private static func removeLocalFileIfExists() {
		let candidates = [writableLocalTokenFileURL(), legacyDefaultTokenFileURL()]
		for fileURL in candidates where FileManager.default.fileExists(atPath: fileURL.path) {
			do {
				try FileManager.default.removeItem(at: fileURL)
			} catch {
				AppLogger.warning("Failed to remove local token file: \(error.localizedDescription)", category: "security")
			}
		}
	}

	private static func migrateLegacyKeychainServiceIfNeeded() {
		let currentToken = (KeychainHelper.shared.read(service: service, account: account) ?? "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard currentToken.isEmpty else {
			_ = KeychainHelper.shared.delete(service: legacyService, account: account)
			return
		}

		let legacyToken = (KeychainHelper.shared.read(service: legacyService, account: account) ?? "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !legacyToken.isEmpty else { return }

		if KeychainHelper.shared.save(service: service, account: account, value: legacyToken) {
			_ = KeychainHelper.shared.delete(service: legacyService, account: account)
			AppLogger.info("Migrated legacy Keychain token to NexaLife service.", category: "security")
		}
	}
}

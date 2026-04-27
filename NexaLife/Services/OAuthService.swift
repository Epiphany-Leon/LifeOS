//
//  OAuthService.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import Foundation
import Combine
import AuthenticationServices
import AppKit

struct AuthenticatedAccount: Equatable {
	var provider: AccountProviderOption
	var identifier: String
	var email: String
	var displayName: String
}

struct EmailVerificationDispatch {
	var destination: String
	var expiresAt: Date
	var previewCode: String?
	var sentViaEmailService: Bool
}

struct EmailAccountStatus: Equatable {
	var verifiedAt: Date?
	var lastSignedInAt: Date?
	var announcementOptIn: Bool
}

enum AuthType {
	case apple
	case email
	case localImport
}

enum EmailVerificationPurpose: String, Codable {
	case createAccount
	case signIn
}

enum EmailAuthError: LocalizedError {
	case invalidEmail
	case missingName
	case accountAlreadyExists
	case accountNotFound
	case appleAuthorizationUnavailable
	case verificationCodeExpired
	case incorrectVerificationCode
	case verificationCodeMissing
	case verificationSendFailed(String)
	case authorizationFailed(String)

	var errorDescription: String? {
		switch self {
		case .invalidEmail:
			return "请输入有效的邮箱地址。"
		case .missingName:
			return "请输入昵称。"
		case .accountAlreadyExists:
			return "这个邮箱已经创建过账户。"
		case .accountNotFound:
			return "没有找到这个邮箱对应的账户。"
		case .appleAuthorizationUnavailable:
			return "当前环境无法发起 Apple 登录。"
		case .verificationCodeExpired:
			return "验证码已过期，请重新发送。"
		case .incorrectVerificationCode:
			return "验证码不正确。"
		case .verificationCodeMissing:
			return "请先发送验证码。"
		case let .verificationSendFailed(message):
			return message
		case let .authorizationFailed(message):
			return message
		}
	}
}

private struct EmailAccountRecord: Codable {
	var identifier: String
	var email: String
	var displayName: String
	var createdAt: Date
	var verifiedAt: Date?
	var lastSignedInAt: Date?
	var announcementOptIn: Bool
}

private struct EmailVerificationTicket: Codable {
	var email: String
	var displayName: String
	var purpose: EmailVerificationPurpose
	var code: String
	var createdAt: Date
	var expiresAt: Date
	var announcementOptIn: Bool
}

private struct AppleAccountRecord: Codable {
	var identifier: String
	var email: String
	var displayName: String
}

private struct EmailDeliveryConfiguration {
	let endpoint: URL
	let apiKey: String

	init?() {
		let env = ProcessInfo.processInfo.environment
		guard
			let rawURL = env[AppBrand.emailVerificationEndpointEnv] ?? env[AppBrand.legacyEmailVerificationEndpointEnv],
			let endpoint = URL(string: rawURL),
			let apiKey = env[AppBrand.emailVerificationKeyEnv] ?? env[AppBrand.legacyEmailVerificationKeyEnv],
			!apiKey.isEmpty
		else {
			return nil
		}
		self.endpoint = endpoint
		self.apiKey = apiKey
	}
}

@MainActor
final class OAuthService: NSObject, ObservableObject {
	private enum Keys {
		static let emailAccounts = "nexalife.emailAccounts"
		static let legacyEmailAccounts = "life" + "os.emailAccounts"
		static let emailVerificationTickets = "nexalife.emailVerificationTickets"
		static let legacyEmailVerificationTickets = "life" + "os.emailVerificationTickets"
		static let appleAccounts = "nexalife.appleAccounts"
		static let legacyAppleAccounts = "life" + "os.appleAccounts"
	}

	private let verificationLifetime: TimeInterval = 10 * 60

	@Published var authToken: String? = nil
	@Published var currentAccount: AuthenticatedAccount?
	@Published var lastErrorMessage: String = ""

	private var appleCompletion: ((Result<AuthenticatedAccount, Error>) -> Void)?

	func startOAuthFlow(type: AuthType, completion: @escaping (Bool) -> Void) {
		switch type {
		case .apple:
			startAppleSignIn { result in
				switch result {
				case .success:
					completion(true)
				case .failure(let error):
					self.lastErrorMessage = error.localizedDescription
					completion(false)
				}
			}
		case .email, .localImport:
			lastErrorMessage = "请使用新的邮箱验证码流程或本地导入入口。"
			completion(false)
		}
	}

	func startAppleSignIn(completion: @escaping (Result<AuthenticatedAccount, Error>) -> Void) {
		guard NSApp.keyWindow != nil || NSApp.mainWindow != nil || !NSApp.windows.isEmpty else {
			completion(.failure(EmailAuthError.appleAuthorizationUnavailable))
			return
		}

		let request = ASAuthorizationAppleIDProvider().createRequest()
		request.requestedScopes = [.fullName, .email]

		let controller = ASAuthorizationController(authorizationRequests: [request])
		controller.delegate = self
		controller.presentationContextProvider = self
		appleCompletion = completion
		lastErrorMessage = ""
		controller.performRequests()
	}

	func sendEmailVerificationCode(
		name: String,
		email: String,
		purpose: EmailVerificationPurpose,
		announcementOptIn: Bool
	) async -> Result<EmailVerificationDispatch, Error> {
		let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let normalizedEmail = normalizeEmail(email)
		guard isValidEmail(normalizedEmail) else { return .failure(EmailAuthError.invalidEmail) }

		let accounts = loadEmailAccounts()
		switch purpose {
		case .createAccount:
			guard !displayName.isEmpty else { return .failure(EmailAuthError.missingName) }
			guard accounts[normalizedEmail] == nil else { return .failure(EmailAuthError.accountAlreadyExists) }
		case .signIn:
			guard accounts[normalizedEmail] != nil else { return .failure(EmailAuthError.accountNotFound) }
		}

		let code = generateVerificationCode()
		let sentAt = Date()
		let expiresAt = sentAt.addingTimeInterval(verificationLifetime)
		let ticket = EmailVerificationTicket(
			email: normalizedEmail,
			displayName: displayName,
			purpose: purpose,
			code: code,
			createdAt: sentAt,
			expiresAt: expiresAt,
			announcementOptIn: announcementOptIn
		)
		saveVerificationTicket(ticket)

		do {
			let dispatch = try await deliverVerificationCode(ticket)
			lastErrorMessage = ""
			return .success(dispatch)
		} catch {
			lastErrorMessage = error.localizedDescription
			return .failure(error)
		}
	}

	func completeEmailVerification(
		email: String,
		code: String,
		purpose: EmailVerificationPurpose
	) -> Result<AuthenticatedAccount, Error> {
		let normalizedEmail = normalizeEmail(email)
		guard isValidEmail(normalizedEmail) else { return .failure(EmailAuthError.invalidEmail) }

		var tickets = loadVerificationTickets()
		guard let ticket = tickets[normalizedEmail], ticket.purpose == purpose else {
			return .failure(EmailAuthError.verificationCodeMissing)
		}
		guard ticket.expiresAt >= .now else {
			tickets.removeValue(forKey: normalizedEmail)
			saveVerificationTickets(tickets)
			return .failure(EmailAuthError.verificationCodeExpired)
		}
		guard ticket.code == code.trimmingCharacters(in: .whitespacesAndNewlines) else {
			return .failure(EmailAuthError.incorrectVerificationCode)
		}

		var accounts = loadEmailAccounts()
		let now = Date()
		let account: AuthenticatedAccount

		switch purpose {
		case .createAccount:
			guard accounts[normalizedEmail] == nil else {
				return .failure(EmailAuthError.accountAlreadyExists)
			}
			let record = EmailAccountRecord(
				identifier: UUID().uuidString,
				email: normalizedEmail,
				displayName: ticket.displayName,
				createdAt: now,
				verifiedAt: now,
				lastSignedInAt: now,
				announcementOptIn: ticket.announcementOptIn
			)
			accounts[normalizedEmail] = record
			account = AuthenticatedAccount(
				provider: .email,
				identifier: record.identifier,
				email: record.email,
				displayName: record.displayName
			)
		case .signIn:
			guard var record = accounts[normalizedEmail] else {
				return .failure(EmailAuthError.accountNotFound)
			}
			record.verifiedAt = record.verifiedAt ?? now
			record.lastSignedInAt = now
			accounts[normalizedEmail] = record
			account = AuthenticatedAccount(
				provider: .email,
				identifier: record.identifier,
				email: record.email,
				displayName: record.displayName
			)
		}

		saveEmailAccounts(accounts)
		tickets.removeValue(forKey: normalizedEmail)
		saveVerificationTickets(tickets)
		applyAuthenticatedAccount(account)
		return .success(account)
	}

	func updateStoredProfile(_ account: AuthenticatedAccount) {
		switch account.provider {
		case .email:
			var records = loadEmailAccounts()
			let normalizedEmail = normalizeEmail(account.email)
			guard var record = records[normalizedEmail] else { return }
			record.displayName = account.displayName
			records[normalizedEmail] = record
			saveEmailAccounts(records)
		case .appleID:
			saveAppleAccount(
				AppleAccountRecord(
					identifier: account.identifier,
					email: account.email,
					displayName: account.displayName
				)
			)
		case .localOnly:
			break
		}

		if currentAccount?.identifier == account.identifier {
			applyAuthenticatedAccount(account)
		}
	}

	func emailAccountStatus(for email: String) -> EmailAccountStatus? {
		let normalizedEmail = normalizeEmail(email)
		guard let record = loadEmailAccounts()[normalizedEmail] else { return nil }
		return EmailAccountStatus(
			verifiedAt: record.verifiedAt,
			lastSignedInAt: record.lastSignedInAt,
			announcementOptIn: record.announcementOptIn
		)
	}

	func resetSession() {
		currentAccount = nil
		authToken = nil
		lastErrorMessage = ""
		appleCompletion = nil
	}

	private func deliverVerificationCode(_ ticket: EmailVerificationTicket) async throws -> EmailVerificationDispatch {
		if let config = EmailDeliveryConfiguration() {
			var request = URLRequest(url: config.endpoint)
			request.httpMethod = "POST"
			request.timeoutInterval = 15
			request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
			let payload: [String: Any] = [
				"email": ticket.email,
				"code": ticket.code,
				"purpose": ticket.purpose.rawValue,
				"displayName": ticket.displayName,
				"expiresAt": ISO8601DateFormatter().string(from: ticket.expiresAt),
				"app": AppBrand.englishName
			]
			request.httpBody = try JSONSerialization.data(withJSONObject: payload)

			let (_, response) = try await URLSession.shared.data(for: request)
			let status = (response as? HTTPURLResponse)?.statusCode ?? -1
			guard (200..<300).contains(status) else {
				throw EmailAuthError.verificationSendFailed("验证码发送失败，请检查邮件服务配置。")
			}

			return EmailVerificationDispatch(
				destination: ticket.email,
				expiresAt: ticket.expiresAt,
				previewCode: nil,
				sentViaEmailService: true
			)
		}

		AppLogger.info(
			"Email verification preview email=\(ticket.email) purpose=\(ticket.purpose.rawValue) code=\(ticket.code)",
			category: "auth"
		)
		return EmailVerificationDispatch(
			destination: ticket.email,
			expiresAt: ticket.expiresAt,
			previewCode: ticket.code,
			sentViaEmailService: false
		)
	}

	private func applyAuthenticatedAccount(_ account: AuthenticatedAccount) {
		currentAccount = account
		authToken = account.identifier
		lastErrorMessage = ""
	}

	private func generateVerificationCode() -> String {
		String(format: "%06d", Int.random(in: 0...999_999))
	}

	private func normalizeEmail(_ email: String) -> String {
		email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	}

	private func isValidEmail(_ email: String) -> Bool {
		let pattern = #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#
		return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
	}

	private func loadEmailAccounts() -> [String: EmailAccountRecord] {
		guard let data = storedData(forKey: Keys.emailAccounts, legacyKey: Keys.legacyEmailAccounts),
			  let records = try? JSONDecoder().decode([String: EmailAccountRecord].self, from: data) else {
			return [:]
		}
		return records
	}

	private func saveEmailAccounts(_ records: [String: EmailAccountRecord]) {
		guard let data = try? JSONEncoder().encode(records) else { return }
		storeData(data, forKey: Keys.emailAccounts, legacyKey: Keys.legacyEmailAccounts)
	}

	private func loadVerificationTickets() -> [String: EmailVerificationTicket] {
		guard let data = storedData(
			forKey: Keys.emailVerificationTickets,
			legacyKey: Keys.legacyEmailVerificationTickets
		),
			  let tickets = try? JSONDecoder().decode([String: EmailVerificationTicket].self, from: data) else {
			return [:]
		}
		return tickets
	}

	private func saveVerificationTicket(_ ticket: EmailVerificationTicket) {
		var tickets = loadVerificationTickets()
		tickets[ticket.email] = ticket
		saveVerificationTickets(tickets)
	}

	private func saveVerificationTickets(_ tickets: [String: EmailVerificationTicket]) {
		guard let data = try? JSONEncoder().encode(tickets) else { return }
		storeData(data, forKey: Keys.emailVerificationTickets, legacyKey: Keys.legacyEmailVerificationTickets)
	}

	private func loadAppleAccounts() -> [String: AppleAccountRecord] {
		guard let data = storedData(forKey: Keys.appleAccounts, legacyKey: Keys.legacyAppleAccounts),
			  let records = try? JSONDecoder().decode([String: AppleAccountRecord].self, from: data) else {
			return [:]
		}
		return records
	}

	private func saveAppleAccount(_ record: AppleAccountRecord) {
		var records = loadAppleAccounts()
		records[record.identifier] = record
		guard let data = try? JSONEncoder().encode(records) else { return }
		storeData(data, forKey: Keys.appleAccounts, legacyKey: Keys.legacyAppleAccounts)
	}

	private func storedData(forKey key: String, legacyKey: String) -> Data? {
		let defaults = UserDefaults.standard
		return defaults.data(forKey: key) ?? defaults.data(forKey: legacyKey)
	}

	private func storeData(_ data: Data, forKey key: String, legacyKey: String) {
		let defaults = UserDefaults.standard
		defaults.set(data, forKey: key)
		defaults.removeObject(forKey: legacyKey)
	}
}

extension OAuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
		NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first ?? NSWindow()
	}

	func authorizationController(
		controller: ASAuthorizationController,
		didCompleteWithAuthorization authorization: ASAuthorization
	) {
		guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			let error = EmailAuthError.authorizationFailed("Apple 登录返回了无效结果。")
			lastErrorMessage = error.localizedDescription
			appleCompletion?(.failure(error))
			appleCompletion = nil
			return
		}

		let cachedRecord = loadAppleAccounts()[credential.user]
		let formatter = PersonNameComponentsFormatter()
		let displayName = formatter.string(from: credential.fullName ?? PersonNameComponents())
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.nilIfEmpty
			?? cachedRecord?.displayName
			?? "Apple 用户"
		let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)
			.nilIfEmpty
			?? cachedRecord?.email
			?? ""

		let account = AuthenticatedAccount(
			provider: .appleID,
			identifier: credential.user,
			email: email,
			displayName: displayName
		)
		saveAppleAccount(
			AppleAccountRecord(
				identifier: account.identifier,
				email: account.email,
				displayName: account.displayName
			)
		)
		applyAuthenticatedAccount(account)
		appleCompletion?(.success(account))
		appleCompletion = nil
	}

	func authorizationController(
		controller: ASAuthorizationController,
		didCompleteWithError error: Error
	) {
		let mappedError = mapAppleAuthorizationError(error)
		lastErrorMessage = mappedError.localizedDescription
		appleCompletion?(.failure(mappedError))
		appleCompletion = nil
	}

	static var mock: OAuthService {
		let service = OAuthService()
		service.currentAccount = AuthenticatedAccount(
			provider: .localOnly,
			identifier: "preview-account",
			email: "preview@nexalife.local",
			displayName: "Preview"
		)
		service.authToken = "preview-account"
		return service
	}
}

private func mapAppleAuthorizationError(_ error: Error) -> Error {
	guard let authorizationError = error as? ASAuthorizationError else {
		return error
	}

	switch authorizationError.code {
	case .canceled:
		return EmailAuthError.authorizationFailed("你已取消 Apple 登录。")
	case .unknown, .failed, .invalidResponse, .notHandled:
		return EmailAuthError.authorizationFailed(
			"Apple 登录当前未完成签名或 Capabilities 配置。请先在 Xcode 里设置 Team，并启用 Sign in with Apple 后再试。原始错误：\(authorizationError.localizedDescription)"
		)
	case .notInteractive:
		return EmailAuthError.authorizationFailed("当前环境不能以交互方式发起 Apple 登录，请在正常 App 窗口内重试。")
	default:
		return authorizationError
	}
}

private extension String {
	var nilIfEmpty: String? {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

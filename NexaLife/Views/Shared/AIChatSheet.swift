//
//  AIChatSheet.swift
//  NexaLife
//

import SwiftUI

struct AIChatMessage: Identifiable, Equatable {
	let id = UUID()
	let role: Role
	let text: String
	let timestamp: Date

	enum Role { case user, assistant }
}

struct AIChatSheet: View {
	@Binding var isPresented: Bool
	@StateObject private var aiService = AIService()
	@Environment(\.locale) private var locale

	@State private var draft: String = ""
	@State private var messages: [AIChatMessage] = []
	@State private var isSending = false

	private var isConfigured: Bool {
		!AICredentialStore.readAPIKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		VStack(spacing: 0) {
			header
			Divider()
			if isConfigured {
				messageList
				Divider()
				composer
			} else {
				notConfiguredPrompt
			}
		}
		.frame(width: 520, height: 600)
		.background(WorkspaceTheme.surface)
	}

	private var notConfiguredPrompt: some View {
		VStack(spacing: 18) {
			Spacer()
			Image(systemName: "key.slash")
				.font(.system(size: 44, weight: .semibold))
				.foregroundStyle(WorkspaceTheme.accent)
			Text(AppBrand.localized("还没有配置 AI", "AI is not configured yet", locale: locale))
				.font(.title3.bold())
				.foregroundStyle(WorkspaceTheme.strongText)
			Text(AppBrand.localized(
				"在设置中填入 AI API Key 后就能与 Mentor 对话。",
				"Add an AI API key in Settings to start chatting with the mentor.",
				locale: locale
			))
			.font(.callout)
			.foregroundStyle(WorkspaceTheme.mutedText)
			.multilineTextAlignment(.center)
			.padding(.horizontal, 40)

			Button {
				NotificationCenter.default.post(name: .nexaLifeOpenAISettings, object: nil)
				isPresented = false
			} label: {
				Label(
					AppBrand.localized("打开设置", "Open Settings", locale: locale),
					systemImage: "gearshape"
				)
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
			}
			.buttonStyle(.borderedProminent)

			Spacer()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var header: some View {
		HStack(spacing: 10) {
			ZStack {
				Circle()
					.fill(LinearGradient(
						colors: [WorkspaceTheme.accent, .pink.opacity(0.85)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					))
					.frame(width: 30, height: 30)
				Image(systemName: "sparkles")
					.font(.system(size: 13, weight: .semibold))
					.foregroundStyle(.white)
			}
			VStack(alignment: .leading, spacing: 2) {
				Text(AppBrand.localized("AI Mentor", "AI Mentor", locale: locale))
					.font(.headline)
					.foregroundStyle(WorkspaceTheme.strongText)
				Text(AppBrand.localized("快速对话", "Quick chat", locale: locale))
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
			}
			Spacer()
			Button(AppBrand.localized("关闭", "Close", locale: locale)) {
				isPresented = false
			}
			.buttonStyle(.bordered)
		}
		.padding(14)
	}

	private var messageList: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: 12) {
					if messages.isEmpty {
						Text(AppBrand.localized(
							"在下方输入问题，AI Mentor 会帮你拆解或给出建议。",
							"Type a question below — the AI mentor will help break it down or offer suggestions.",
							locale: locale
						))
						.font(.callout)
						.foregroundStyle(WorkspaceTheme.mutedText)
						.padding(.vertical, 30)
						.frame(maxWidth: .infinity, alignment: .center)
					}
					ForEach(messages) { msg in
						messageRow(msg)
							.id(msg.id)
					}
				}
				.padding(16)
			}
			.onChange(of: messages.count) { _, _ in
				if let last = messages.last {
					withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
				}
			}
		}
	}

	private func messageRow(_ msg: AIChatMessage) -> some View {
		HStack(alignment: .top, spacing: 8) {
			if msg.role == .assistant {
				avatar(.assistant)
				bubble(msg, alignment: .leading)
				Spacer(minLength: 24)
			} else {
				Spacer(minLength: 24)
				bubble(msg, alignment: .trailing)
				avatar(.user)
			}
		}
	}

	private func avatar(_ role: AIChatMessage.Role) -> some View {
		Circle()
			.fill(role == .assistant ? WorkspaceTheme.accent : Color.blue)
			.frame(width: 24, height: 24)
			.overlay(
				Image(systemName: role == .assistant ? "sparkles" : "person.fill")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(.white)
			)
	}

	private func bubble(_ msg: AIChatMessage, alignment: HorizontalAlignment) -> some View {
		VStack(alignment: alignment, spacing: 4) {
			Text(msg.text)
				.font(.body)
				.foregroundStyle(WorkspaceTheme.strongText)
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(msg.role == .assistant ? WorkspaceTheme.elevatedSurface : WorkspaceTheme.accentWash)
				)
				.fixedSize(horizontal: false, vertical: true)
			Text(AppDateFormatter.ymd(msg.timestamp))
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
	}

	private var composer: some View {
		HStack(alignment: .bottom, spacing: 8) {
			TextField(
				AppBrand.localized("和 AI Mentor 聊点什么…", "Ask the AI mentor anything…", locale: locale),
				text: $draft,
				axis: .vertical
			)
			.textFieldStyle(.plain)
			.lineLimit(1...6)
			.padding(.horizontal, 12)
			.padding(.vertical, 10)
			.background(WorkspaceTheme.elevatedSurface)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.stroke(WorkspaceTheme.border, lineWidth: 1)
			)
			.onSubmit(send)
			.disabled(isSending)

			Button(action: send) {
				if isSending {
					ProgressView().controlSize(.small)
						.padding(8)
				} else {
					Image(systemName: "arrow.up.circle.fill")
						.font(.system(size: 26, weight: .semibold))
						.foregroundStyle(canSend ? WorkspaceTheme.accent : .gray.opacity(0.4))
				}
			}
			.buttonStyle(.plain)
			.disabled(!canSend || isSending)
		}
		.padding(14)
	}

	private var canSend: Bool {
		!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private func send() {
		let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty, !isSending else { return }
		messages.append(AIChatMessage(role: .user, text: text, timestamp: Date()))
		draft = ""
		isSending = true

		Task {
			let reply = await aiService.callAPI(prompt: text, maxTokens: 600) ?? AppBrand.localized(
				"AI 暂无响应，请检查 API Key 与网络。",
				"AI did not respond. Check your API key and network.",
				locale: locale
			)
			await MainActor.run {
				messages.append(AIChatMessage(role: .assistant, text: reply, timestamp: Date()))
				isSending = false
			}
		}
	}
}

//
//  ItemDetailView.swift
//  NexaLife
//
//  v0.2.0 — 严格按 WorkspaceTheme / WorkspaceCard 设计语言
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.modelContext) private var modelContext
	@Environment(\.locale) private var locale
	@Binding var selectedItem: InboxItem?
	@Bindable var item: InboxItem
	@StateObject private var aiService = AIService()
	@State private var isClassifying = false
	@State private var classifyTask: _Concurrency.Task<Void, Never>?
	@State private var classifyRequestID = 0
	@State private var handlingSuggestion: InboxHandlingSuggestion?

	private var accent: Color { WorkspaceTheme.moduleAccent(for: .inbox) }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 22) {
				headerCard
				editorCard
				if let suggestion = handlingSuggestion {
					aiSuggestionCard(suggestion)
				}
				routingCard
			}
			.padding(.horizontal, 28)
			.padding(.vertical, 24)
		}
		.background(WorkspaceTheme.surface)
		.onAppear { scheduleClassification(force: true) }
		.onChange(of: item.content) { _, _ in scheduleClassification(force: false) }
		.onDisappear { classifyTask?.cancel() }
	}

	// MARK: - Header

	private var headerCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 8) {
			HStack(alignment: .top, spacing: 14) {
				WorkspaceIconBadge(icon: "tray.and.arrow.down", accent: accent, size: 38)

				VStack(alignment: .leading, spacing: 4) {
					Text(AppBrand.localized("闪念详情", "Captured Entry", locale: locale))
						.font(.system(size: 17, weight: .bold, design: .rounded))
						.foregroundStyle(WorkspaceTheme.strongText)
					Text(AppDateFormatter.ymd(item.timestamp))
						.font(.caption)
						.foregroundStyle(WorkspaceTheme.mutedText)
				}

				Spacer()

				WorkspaceActionButton(
					title: AppBrand.localized("删除", "Delete", locale: locale),
					icon: "trash",
					accent: .red,
					isPrimary: false,
					action: deleteItem
				)
			}
		}
	}

	// MARK: - Editor

	private var editorCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				WorkspacePanelHeader(
					title: AppBrand.localized("内容", "Content", locale: locale),
					subtitle: AppBrand.localized("修改后会自动重新分析归类建议", "Changes auto-trigger AI re-classification", locale: locale),
					accent: accent,
					icon: "text.alignleft"
				)

				TextEditor(text: $item.content)
					.font(.system(size: 14))
					.scrollContentBackground(.hidden)
					.frame(minHeight: 160)
					.padding(12)
					.background(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.fill(WorkspaceTheme.elevatedSurface)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.stroke(WorkspaceTheme.border, lineWidth: 1)
					)
			}
		}
	}

	// MARK: - AI Suggestion

	private func aiSuggestionCard(_ suggestion: InboxHandlingSuggestion) -> some View {
		WorkspaceCard(accent: .purple, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				WorkspacePanelHeader(
					title: AppBrand.localized("AI 处理建议", "AI Handling Suggestion", locale: locale),
					subtitle: suggestion.headline,
					accent: .purple,
					icon: "sparkles"
				)

				Text(suggestion.reason)
					.font(.subheadline)
					.foregroundStyle(WorkspaceTheme.mutedText)
					.fixedSize(horizontal: false, vertical: true)

				if suggestion.module != .inbox {
					HStack(spacing: 8) {
						WorkspacePill(
							title: AppBrand.localized(
								"建议去往 \(suggestion.module.label(for: locale))",
								"Suggested destination: \(suggestion.module.label(for: locale))",
								locale: locale
							),
							icon: suggestion.module.icon,
							accent: WorkspaceTheme.moduleAccent(for: suggestion.module)
						)
						Spacer()
					}
				}
			}
		}
	}

	// MARK: - Routing

	private var routingCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				WorkspacePanelHeader(
					title: AppBrand.localized("归类到象限", "Move to Module", locale: locale),
					subtitle: AppBrand.localized("迁移后会从收件箱自动移除", "Moves out of the inbox after transfer", locale: locale),
					accent: accent,
					icon: "arrow.right.circle"
				)

				if let suggested = item.suggestedModule,
				   let suggestedModule = AppModule(rawValue: suggested) {
					HStack(spacing: 8) {
						WorkspacePill(
							title: AppBrand.localized(
								"AI 建议：\(suggestedModule.label(for: locale))",
								"AI suggestion: \(suggestedModule.label(for: locale))",
								locale: locale
							),
							icon: "sparkles",
							accent: .purple,
							isFilled: true
						)
						if isClassifying {
							ProgressView().scaleEffect(0.6)
						}
						Spacer()
						Button {
							scheduleClassification(force: true)
						} label: {
							Label(AppBrand.localized("重新分析", "Analyze Again", locale: locale), systemImage: "arrow.triangle.2.circlepath")
								.font(.caption.weight(.semibold))
						}
						.buttonStyle(.borderless)
						.foregroundStyle(.purple)
					}
				} else if isClassifying {
					HStack(spacing: 6) {
						ProgressView().scaleEffect(0.6)
						Text(AppBrand.localized("AI 正在分析…", "Analyzing…", locale: locale))
							.font(.caption)
							.foregroundStyle(WorkspaceTheme.mutedText)
					}
				}

				LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
					ForEach([AppModule.execution, .lifestyle, .knowledge, .vitals], id: \.self) { module in
						moduleTransferTile(module: module, isRecommended: item.suggestedModule == module.rawValue)
					}
				}
			}
		}
	}

	private func moduleTransferTile(module: AppModule, isRecommended: Bool) -> some View {
		let moduleAccent = WorkspaceTheme.moduleAccent(for: module)
		return Button {
			transferToModule(module)
		} label: {
			HStack(spacing: 10) {
				WorkspaceIconBadge(icon: module.icon, accent: moduleAccent, size: 30)
				VStack(alignment: .leading, spacing: 2) {
					Text(module.label(for: locale))
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.strongText)
					if isRecommended {
						Text(AppBrand.localized("推荐", "Recommended", locale: locale))
							.font(.system(size: 10, weight: .semibold))
							.foregroundStyle(moduleAccent)
					} else {
						Text(AppBrand.localized("移到这里", "Move here", locale: locale))
							.font(.system(size: 11))
							.foregroundStyle(WorkspaceTheme.mutedText)
					}
				}
				Spacer()
				Image(systemName: "arrow.right")
					.font(.system(size: 11, weight: .semibold))
					.foregroundStyle(moduleAccent)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 10)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(isRecommended ? moduleAccent.opacity(0.10) : WorkspaceTheme.elevatedSurface)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(isRecommended ? moduleAccent.opacity(0.32) : WorkspaceTheme.border, lineWidth: 1)
			)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	// MARK: - Logic

	private func scheduleClassification(force: Bool) {
		classifyTask?.cancel()
		let text = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
		if text.count <= 3 {
			if force {
				item.suggestedModule = nil
			}
			handlingSuggestion = nil
			isClassifying = false
			return
		}

		classifyRequestID += 1
		let requestID = classifyRequestID
		classifyTask = _Concurrency.Task {
			try? await _Concurrency.Task.sleep(nanoseconds: 600_000_000)
			guard !_Concurrency.Task.isCancelled else { return }
			await runClassification(text: text, requestID: requestID)
		}
	}

	@MainActor
	private func runClassification(text: String, requestID: Int) async {
		isClassifying = true
		defer { isClassifying = false }
		let result = await aiService.classifyText(text)
		let suggestion = await aiService.suggestInboxHandling(text)
		guard requestID == classifyRequestID else { return }
		let currentText = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
		if currentText == text {
			item.suggestedModule = result.rawValue
			handlingSuggestion = suggestion
		}
	}

	private func transferToModule(_ module: AppModule) {
		guard module != .inbox else { return }
		let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !content.isEmpty else { return }

		let transferred = InboxRoutingService.transfer(
			content: content,
			to: module,
			modelContext: modelContext
		)
		guard transferred else { return }

		item.suggestedModule = module.rawValue
		selectedItem = nil
		modelContext.delete(item)
		appState.updateModule(module)
	}

	private func deleteItem() {
		selectedItem = nil
		modelContext.delete(item)
	}
}

//
//  DailyReviewEditorSheet.swift
//  NexaLife
//
//  v0.2.0 — 严格按 WorkspaceTheme / WorkspaceCard 设计语言
//

import SwiftUI
import SwiftData

struct DailyReviewEditorSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.locale) private var locale
	@Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
	@Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
	@Query(sort: \VitalsEntry.timestamp, order: .reverse) private var allVitals: [VitalsEntry]

	@Bindable var review: DailyReviewEntry
	@StateObject private var aiService = AIService()
	@State private var isGeneratingInsight = false

	private let accent = WorkspaceTheme.accent

	var body: some View {
		AnyView(rootContent)
			.background(WorkspaceTheme.surface)
			.frame(minWidth: 640, idealWidth: 720, minHeight: 600, idealHeight: 720)
	}

	private var rootContent: some View {
		VStack(spacing: 0) {
			topBar
			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)

			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					header

					reviewTextCard(
						title: AppBrand.localized("今天做成了什么", "What moved today", locale: locale),
						icon: "checkmark.seal",
						accent: WorkspaceTheme.moduleAccent(for: .execution),
						text: $review.wins,
						prompt: AppBrand.localized("写下今天真正推进的结果、亮点或值得保留的片段", "Write the results, bright spots, or meaningful moments you want to keep from today", locale: locale)
					)

					reviewTextCard(
						title: AppBrand.localized("今天卡住了什么", "What felt heavy", locale: locale),
						icon: "exclamationmark.circle",
						accent: .orange,
						text: $review.challenges,
						prompt: AppBrand.localized("记录阻力、拖延、焦虑或没有处理好的地方", "Capture the resistance, procrastination, anxiety, or things that stayed unresolved", locale: locale)
					)

					reviewTextCard(
						title: AppBrand.localized("我看见了什么模式", "What pattern I noticed", locale: locale),
						icon: "waveform.path.ecg",
						accent: WorkspaceTheme.moduleAccent(for: .knowledge),
						text: $review.insight,
						prompt: AppBrand.localized("写下今天你看见的模式、习惯或值得继续观察的信号", "Write the patterns, habits, or signals that seem worth watching", locale: locale)
					)

					reviewTextCard(
						title: AppBrand.localized("明天只推进什么", "What to move tomorrow", locale: locale),
						icon: "arrow.forward.circle",
						accent: WorkspaceTheme.moduleAccent(for: .lifestyle),
						text: $review.tomorrowPlan,
						prompt: AppBrand.localized("尽量只保留 1 到 2 个最小可执行动作", "Try to keep this to 1-2 smallest executable next actions", locale: locale)
					)

					scoreCard
					aiCard
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 22)
			}
		}
	}

	// MARK: - Top bar

	private var topBar: some View {
		HStack(spacing: 12) {
			WorkspaceIconBadge(icon: "calendar.badge.clock", accent: accent, size: 30)
			VStack(alignment: .leading, spacing: 2) {
				Text(AppBrand.localized("Daily Review", "Daily Review", locale: locale))
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(WorkspaceTheme.strongText)
				Text(AppDateFormatter.ymd(review.day))
					.font(.caption)
					.foregroundStyle(WorkspaceTheme.mutedText)
			}
			Spacer()
			Button(AppBrand.localized("关闭", "Close", locale: locale)) {
				saveReview()
				dismiss()
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.keyboardShortcut(.cancelAction)

			WorkspaceActionButton(
				title: AppBrand.localized("保存", "Save", locale: locale),
				icon: "checkmark",
				accent: accent,
				isPrimary: true
			) {
				saveReview()
				dismiss()
			}
		}
		.padding(.horizontal, 18)
		.padding(.vertical, 11)
		.background(WorkspaceTheme.surface)
	}

	// MARK: - Header

	private var header: some View {
		WorkspaceSectionTitle(
			eyebrow: AppBrand.localized("复盘", "Review", locale: locale),
			title: AppBrand.localized("记录今天，识别模式", "Record today · spot patterns", locale: locale),
			subtitle: AppBrand.localized(
				"记录当下，识别模式，再决定下一步。",
				"Record the day, identify the pattern, then choose the next move.",
				locale: locale
			),
			accent: accent
		)
	}

	// MARK: - Score

	private var scoreCard: some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 14) {
				WorkspacePanelHeader(
					title: AppBrand.localized("今日状态", "Today's State", locale: locale),
					subtitle: AppBrand.localized("打分会随时间形成趋势线", "Daily scores form a trend over time", locale: locale),
					accent: accent,
					icon: "dial.medium"
				)

				scoreRow(
					title: AppBrand.localized("能量", "Energy", locale: locale),
					value: $review.energyScore,
					color: .orange
				)

				scoreRow(
					title: AppBrand.localized("清晰度", "Clarity", locale: locale),
					value: $review.clarityScore,
					color: WorkspaceTheme.moduleAccent(for: .knowledge)
				)
			}
		}
	}

	// MARK: - AI

	private var aiCard: some View {
		WorkspaceCard(accent: .purple, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					WorkspacePanelHeader(
						title: AppBrand.localized("AI 复盘引导", "AI Review Guidance", locale: locale),
						subtitle: AppBrand.localized("基于今日填写 + 最近任务/笔记/觉知", "Based on today + recent tasks · notes · vitals", locale: locale),
						accent: .purple,
						icon: "sparkles"
					)
					Button {
						Task { await generateInsight() }
					} label: {
						HStack(spacing: 6) {
							if isGeneratingInsight {
								ProgressView().scaleEffect(0.6)
								Text(AppBrand.localized("生成中…", "Generating…", locale: locale))
									.font(.caption.weight(.semibold))
							} else {
								Image(systemName: "wand.and.stars")
									.font(.system(size: 11, weight: .semibold))
								Text(AppBrand.localized("生成", "Generate", locale: locale))
									.font(.caption.weight(.semibold))
							}
						}
						.foregroundStyle(Color.white)
						.padding(.horizontal, 12)
						.padding(.vertical, 7)
						.background(Capsule().fill(Color.purple))
					}
					.buttonStyle(.plain)
					.disabled(isGeneratingInsight)
				}

				if !review.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					InsightBlock(
						title: AppBrand.localized("今日总结", "Today Summary", locale: locale),
						text: review.aiSummary,
						color: WorkspaceTheme.moduleAccent(for: .knowledge)
					)
				}

				if !review.aiGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
					InsightBlock(
						title: AppBrand.localized("下一步建议", "Next Guidance", locale: locale),
						text: review.aiGuidance,
						color: .purple
					)
				}
			}
		}
	}

	// MARK: - Reusable Text Card

	private func reviewTextCard(
		title: String,
		icon: String,
		accent: Color,
		text: Binding<String>,
		prompt: String
	) -> some View {
		WorkspaceCard(accent: accent, padding: 18, cornerRadius: 22, shadowY: 6) {
			VStack(alignment: .leading, spacing: 10) {
				WorkspacePanelHeader(
					title: title,
					subtitle: prompt,
					accent: accent,
					icon: icon
				)

				TextEditor(text: text)
					.font(.system(size: 13))
					.scrollContentBackground(.hidden)
					.frame(minHeight: 110)
					.padding(12)
					.background(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.fill(WorkspaceTheme.elevatedSurface)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 14, style: .continuous)
							.stroke(accent.opacity(0.15), lineWidth: 1)
					)
			}
		}
	}

	private func scoreRow(title: String, value: Binding<Int>, color: Color) -> some View {
		HStack {
			Text(title)
				.font(.system(size: 13, weight: .medium))
				.foregroundStyle(WorkspaceTheme.strongText)
			Spacer()
			HStack(spacing: 6) {
				ForEach(1...5, id: \.self) { score in
					Button {
						value.wrappedValue = score
					} label: {
						Image(systemName: score <= value.wrappedValue ? "circle.fill" : "circle")
							.font(.system(size: 14))
							.foregroundStyle(score <= value.wrappedValue ? color : WorkspaceTheme.mutedText.opacity(0.4))
					}
					.buttonStyle(.plain)
				}
			}
		}
	}

	@MainActor
	private func generateInsight() async {
		saveReview()
		isGeneratingInsight = true
		defer { isGeneratingInsight = false }

		let insight = await aiService.generateDailyReviewInsight(
			context: DailyReviewContext(
				review: review,
				tasks: Array(allTasks.prefix(12)),
				notes: Array(allNotes.prefix(8)),
				vitals: Array(allVitals.prefix(8))
			)
		)
		review.aiSummary = insight.summary
		review.aiGuidance = insight.guidance
		review.updatedAt = .now
	}

	private func saveReview() {
		review.day = Calendar.current.startOfDay(for: review.day)
		review.energyScore = min(5, max(1, review.energyScore))
		review.clarityScore = min(5, max(1, review.clarityScore))
		review.updatedAt = .now
	}
}

private struct InsightBlock: View {
	let title: String
	let text: String
	let color: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(color)
				.textCase(.uppercase)
				.tracking(0.6)
			Text(text)
				.font(.system(size: 13))
				.foregroundStyle(WorkspaceTheme.strongText)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(color.opacity(0.08))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.stroke(color.opacity(0.20), lineWidth: 1)
				)
		}
	}
}

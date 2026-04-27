//
//  AboutNexaLifeView.swift
//  NexaLife
//
//  Created by Codex on 2026-03-13.
//

import SwiftUI

struct AboutNexaLifeView: View {
	@Environment(\.locale) private var locale

	private var appName: String {
		AppBrand.displayName(for: locale)
	}

	private var versionText: String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
		return "v\(version) (\(build))"
	}

	private var manifestoTitle: String {
		AppBrand.localized("掌控，而非漂流。", "Steer, Don't Drift.", locale: locale)
	}

	private var manifestoParagraphs: [String] {
		if locale.isChineseInterface {
			return [
				"欢迎来到你的人生长效运转中枢。",
				"这不是一个随手记录的便签本，而是为你量身定制的执行引擎。在这里，庞大的梦想被拆解为可度量的节点，无序的日常被收束成清晰的轨迹。",
				"如果你执着于秩序，也渴望真实推进，这里就是你的工作台。",
				"摈弃混乱，拒绝失控。从此刻起，做自己人生的绝对架构师。"
			]
		}
		return [
			"Welcome to your life's operational command center.",
			"This is not a casual notepad. It is an execution engine built for you. Here, overwhelming ambitions are deconstructed into measurable milestones, and chaotic routines are refined into clear trajectories.",
			"If you care about order and insist on real progress, this is your workspace.",
			"Eliminate the noise. Reject the chaos. From this moment on, be the absolute architect of your own life."
		]
	}

	private var strategyTitle: String {
		AppBrand.localized("产品策略", "Product Strategy", locale: locale)
	}

	private var strategyBody: String {
		AppBrand.localized(
			"""
			1. 默认采用 App 内部主存储，保证本地稳定性与隐私性。
			2. 标准能力是 JSON 快照导入导出，方便迁移与长期保存。
			3. Apple 用户后续可选 iCloud 私有容器同步。
			4. 高级用户可把快照同步到外部目录，用于坚果云、NAS 或其他自管存储。
			""",
			"""
			1. App-internal storage is the default, keeping local data stable and private.
			2. JSON snapshot import and export remain the standard portability layer.
			3. Apple users will be able to opt into private iCloud sync later.
			4. Advanced users can sync snapshots to an external folder backed by Nutstore, NAS, or other self-managed storage.
			""",
			locale: locale
		)
	}

	private var privacyTitle: String {
		AppBrand.localized("数据与隐私", "Data and Privacy", locale: locale)
	}

	private var privacyBody: String {
		AppBrand.localized(
			"""
			构筑人生默认把核心数据保存在本机，不把你的日常记录默认托管到开发者数据库。
			API Key 不进入同步快照；外部目录与 iCloud 同步都以用户自管为前提。
			""",
			"""
			NexaLife keeps core data on-device by default instead of routing your daily records into a developer-hosted database.
			API keys are excluded from sync archives, and both external-folder sync and iCloud sync remain user-controlled.
			""",
			locale: locale
		)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			HStack(alignment: .center, spacing: 12) {
				ZStack {
					RoundedRectangle(cornerRadius: 14, style: .continuous)
						.fill(Color.accentColor.opacity(0.12))
						.frame(width: 52, height: 52)
					Image(systemName: "square.stack.3d.up.fill")
						.font(.system(size: 24))
						.foregroundStyle(Color.accentColor)
				}

				VStack(alignment: .leading, spacing: 2) {
					Text(appName)
						.font(.title3.bold())
					Text(versionText)
						.font(.subheadline)
						.foregroundStyle(.secondary)
					Text(AppBrand.alternateName(for: locale))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}

			VStack(alignment: .leading, spacing: 12) {
				Text(manifestoTitle)
					.font(.title2.bold())
				VStack(alignment: .leading, spacing: 10) {
					ForEach(Array(manifestoParagraphs.enumerated()), id: \.offset) { index, paragraph in
						Text(paragraph)
						if index == 1 {
							Color.clear
								.frame(height: 2)
						}
					}
				}
			}
			.fixedSize(horizontal: false, vertical: true)

			Divider()

			Text(strategyTitle)
				.font(.headline)
			Text(strategyBody)
				.fixedSize(horizontal: false, vertical: true)

			Text(privacyTitle)
				.font(.headline)
			Text(privacyBody)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.vertical, 4)
	}
}

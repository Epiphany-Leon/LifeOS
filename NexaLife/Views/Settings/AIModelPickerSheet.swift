//
//  AIModelPickerSheet.swift
//  NexaLife
//
//  Cherry Studio + Terminal Preferences inspired model picker.
//  Two-pane layout: provider list on the left (with bottom toolbar to add/
//  remove custom providers), provider details + model list on the right.
//

import SwiftUI

// MARK: - Selection model

struct AIModelSelection: Equatable {
	/// Either a built-in `AIProviderOption` or the UUID string of a custom provider.
	var providerKey: String
	var model: String

	static func builtIn(_ option: AIProviderOption, model: String) -> AIModelSelection {
		AIModelSelection(providerKey: option.rawValue, model: model)
	}

	var builtInOption: AIProviderOption? {
		AIProviderOption(rawValue: providerKey)
	}
}

// MARK: - Provider abstraction

private struct PickerProvider: Identifiable, Equatable {
	let id: String
	let name: String
	let icon: String
	let endpoint: String
	let models: [String]
	let isBuiltIn: Bool
}

// MARK: - Sheet

struct AIModelPickerSheet: View {
	@Binding var isPresented: Bool
	let initialSelection: AIModelSelection
	let onCommit: (AIModelSelection) -> Void

	@Environment(\.locale) private var locale

	@State private var providers: [PickerProvider] = []
	@State private var selectedProviderID: String
	@State private var selectedModel: String
	@State private var providerSearch: String = ""
	@State private var isAddingProvider = false
	@State private var syncStatusMessage: String = ""

	init(
		isPresented: Binding<Bool>,
		initialSelection: AIModelSelection,
		onCommit: @escaping (AIModelSelection) -> Void
	) {
		self._isPresented = isPresented
		self.initialSelection = initialSelection
		self.onCommit = onCommit
		self._selectedProviderID = State(initialValue: initialSelection.providerKey)
		self._selectedModel = State(initialValue: initialSelection.model)
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 0) {
				providerColumn
					.frame(width: 240)

				Divider()

				detailColumn
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}

			Divider()

			HStack(spacing: 10) {
				Spacer()
				Button(AppBrand.localized("取消", "Cancel", locale: locale)) {
					isPresented = false
				}
				.buttonStyle(.bordered)
				Button(AppBrand.localized("使用所选模型", "Use selected model", locale: locale)) {
					onCommit(AIModelSelection(providerKey: selectedProviderID, model: selectedModel))
					isPresented = false
				}
				.buttonStyle(.borderedProminent)
				.disabled(selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}
			.padding(14)
		}
		.frame(width: 760, height: 560)
		.background(WorkspaceTheme.surface)
		.onAppear(perform: reloadProviders)
		.onReceive(NotificationCenter.default.publisher(for: .nexaLifeCustomProvidersChanged)) { _ in
			reloadProviders()
		}
		.sheet(isPresented: $isAddingProvider) {
			CustomProviderEditor(isPresented: $isAddingProvider) { newProvider in
				CustomAIProviderStore.add(newProvider)
				selectedProviderID = newProvider.id.uuidString
				if let first = newProvider.models.first {
					selectedModel = first
				}
			}
			.environment(\.locale, locale)
		}
	}

	// MARK: - Providers data

	private func reloadProviders() {
		var list: [PickerProvider] = AIProviderOption.allCases.map { option in
			PickerProvider(
				id: option.rawValue,
				name: AIModelCatalog.label(for: option, locale: locale),
				icon: AIModelCatalog.icon(for: option),
				endpoint: AIModelCatalog.endpoint(for: option),
				models: AIModelCatalog.models(for: option),
				isBuiltIn: true
			)
		}
		for custom in CustomAIProviderStore.load() {
			list.append(PickerProvider(
				id: custom.id.uuidString,
				name: custom.name,
				icon: "globe",
				endpoint: custom.endpoint,
				models: custom.models,
				isBuiltIn: false
			))
		}
		providers = list
		// Repair selection if it points at a removed provider.
		if !list.contains(where: { $0.id == selectedProviderID }), let first = list.first {
			selectedProviderID = first.id
			selectedModel = first.models.first ?? ""
		}
	}

	private var filteredProviders: [PickerProvider] {
		let keyword = providerSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !keyword.isEmpty else { return providers }
		return providers.filter { $0.name.lowercased().contains(keyword) }
	}

	private var selectedProvider: PickerProvider? {
		providers.first(where: { $0.id == selectedProviderID })
	}

	// MARK: - Left column

	private var providerColumn: some View {
		VStack(spacing: 0) {
			searchField

			ScrollView {
				LazyVStack(alignment: .leading, spacing: 2) {
					ForEach(filteredProviders) { provider in
						providerRow(provider)
					}
					if filteredProviders.isEmpty {
						Text(AppBrand.localized("没有匹配的提供方", "No matching providers", locale: locale))
							.font(.caption)
							.foregroundStyle(.secondary)
							.padding(.horizontal, 14)
							.padding(.vertical, 14)
					}
				}
			}

			Divider()

			providerToolbar
		}
	}

	private var searchField: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.font(.caption)
				.foregroundStyle(.secondary)
			TextField(
				AppBrand.localized("搜索模型平台…", "Search providers…", locale: locale),
				text: $providerSearch
			)
			.textFieldStyle(.plain)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(WorkspaceTheme.elevatedSurface)
		.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
		.padding(10)
	}

	private func providerRow(_ provider: PickerProvider) -> some View {
		let isActive = provider.id == selectedProviderID
		return Button {
			if selectedProviderID != provider.id {
				selectedProviderID = provider.id
				selectedModel = provider.models.first ?? ""
			}
		} label: {
			HStack(spacing: 10) {
				Image(systemName: provider.icon)
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(isActive ? Color.white : WorkspaceTheme.accent)
					.frame(width: 26, height: 26)
					.background(
						RoundedRectangle(cornerRadius: 6, style: .continuous)
							.fill(isActive ? WorkspaceTheme.accent : WorkspaceTheme.accent.opacity(0.12))
					)
				VStack(alignment: .leading, spacing: 1) {
					Text(provider.name)
						.font(.subheadline.weight(isActive ? .semibold : .regular))
						.foregroundStyle(WorkspaceTheme.strongText)
					if !provider.isBuiltIn {
						Text(AppBrand.localized("自定义", "Custom", locale: locale))
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
				Spacer(minLength: 0)
				if provider.isBuiltIn && AIModelCatalog.isConfigured(AIProviderOption(rawValue: provider.id) ?? .deepseek) {
					Text("ON")
						.font(.caption2.weight(.bold))
						.foregroundStyle(.white)
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Color.green)
						.clipShape(Capsule())
				}
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(isActive ? WorkspaceTheme.accent.opacity(0.12) : Color.clear)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.padding(.horizontal, 6)
	}

	private var providerToolbar: some View {
		HStack(spacing: 0) {
			Button {
				isAddingProvider = true
			} label: {
				Image(systemName: "plus")
					.frame(width: 28, height: 22)
			}
			.buttonStyle(.plain)
			.help(AppBrand.localized("添加模型平台", "Add provider", locale: locale))

			Divider().frame(height: 14)

			Button {
				removeSelectedCustomProvider()
			} label: {
				Image(systemName: "minus")
					.frame(width: 28, height: 22)
					.foregroundStyle(canRemoveSelected ? Color.primary : Color.secondary.opacity(0.4))
			}
			.buttonStyle(.plain)
			.disabled(!canRemoveSelected)
			.help(AppBrand.localized("删除选中的平台 (仅自定义)", "Remove selected provider (custom only)", locale: locale))

			Spacer()
		}
		.padding(.horizontal, 6)
		.padding(.vertical, 4)
		.background(WorkspaceTheme.elevatedSurface.opacity(0.6))
	}

	private var canRemoveSelected: Bool {
		selectedProvider.map { !$0.isBuiltIn } ?? false
	}

	private func removeSelectedCustomProvider() {
		guard let provider = selectedProvider, !provider.isBuiltIn,
		      let uuid = UUID(uuidString: provider.id) else { return }
		CustomAIProviderStore.remove(id: uuid)
	}

	// MARK: - Right column

	private var detailColumn: some View {
		VStack(alignment: .leading, spacing: 16) {
			if let provider = selectedProvider {
				HStack(spacing: 10) {
					Image(systemName: provider.icon)
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(WorkspaceTheme.accent)
						.frame(width: 32, height: 32)
						.background(
							RoundedRectangle(cornerRadius: 8, style: .continuous)
								.fill(WorkspaceTheme.accent.opacity(0.12))
						)
					Text(provider.name)
						.font(.title3.bold())
						.foregroundStyle(WorkspaceTheme.strongText)
					Spacer()
				}

				VStack(alignment: .leading, spacing: 6) {
					Text(AppBrand.localized("API 地址", "API endpoint", locale: locale))
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
					Text(provider.endpoint)
						.font(.system(size: 13, design: .monospaced))
						.foregroundStyle(WorkspaceTheme.strongText)
						.padding(.horizontal, 10)
						.padding(.vertical, 8)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(WorkspaceTheme.elevatedSurface)
						.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
				}

				HStack(alignment: .center) {
					Text(AppBrand.localized("可用模型", "Available models", locale: locale))
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.secondary)
					Text("\(provider.models.count)")
						.font(.caption)
						.foregroundStyle(.tertiary)
					Spacer()
					Button {
						syncLatestModels(for: provider)
					} label: {
						Label(
							AppBrand.localized("发现/同步最新模型", "Sync latest models", locale: locale),
							systemImage: "arrow.triangle.2.circlepath"
						)
						.font(.caption)
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}

				if !syncStatusMessage.isEmpty {
					Text(syncStatusMessage)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				ScrollView {
					LazyVStack(alignment: .leading, spacing: 6) {
						ForEach(provider.models, id: \.self) { model in
							modelRow(model)
						}
						if provider.models.isEmpty {
							Text(AppBrand.localized("该平台还没有模型", "This provider has no models yet", locale: locale))
								.font(.caption)
								.foregroundStyle(.secondary)
								.padding(.vertical, 12)
						}
					}
					.padding(.vertical, 4)
				}
				.frame(maxHeight: .infinity, alignment: .top)
			} else {
				Text(AppBrand.localized("请选择一个模型平台", "Pick a provider on the left", locale: locale))
					.font(.callout)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		}
		.padding(20)
	}

	private func modelRow(_ model: String) -> some View {
		let isActive = model == selectedModel
		return Button {
			selectedModel = model
		} label: {
			HStack(spacing: 10) {
				Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(isActive ? WorkspaceTheme.accent : WorkspaceTheme.mutedText)
				Text(model)
					.font(.body.weight(isActive ? .semibold : .regular))
					.foregroundStyle(WorkspaceTheme.strongText)
				Spacer()
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 9)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(isActive ? WorkspaceTheme.accent.opacity(0.10) : Color.clear)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.stroke(isActive ? WorkspaceTheme.accent.opacity(0.5) : WorkspaceTheme.border, lineWidth: 1)
			)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	private func syncLatestModels(for provider: PickerProvider) {
		// Built-in providers ship a curated list. Real fetching would hit each
		// provider's "list models" endpoint and is left as a follow-up — this
		// stub at least surfaces the affordance the user asked for.
		syncStatusMessage = AppBrand.localized(
			"模型清单同步功能将在后续版本接入官方接口。",
			"Model-list sync will be wired to provider APIs in a follow-up release.",
			locale: locale
		)
	}
}

// MARK: - Custom provider editor

private struct CustomProviderEditor: View {
	@Binding var isPresented: Bool
	let onSave: (CustomAIProvider) -> Void

	@Environment(\.locale) private var locale
	@State private var name: String = ""
	@State private var endpoint: String = ""
	@State private var modelsText: String = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(AppBrand.localized("添加模型平台", "Add provider", locale: locale))
				.font(.title3.bold())

			Group {
				labeledField(
					AppBrand.localized("名称", "Name", locale: locale),
					placeholder: "OpenAI / Custom",
					text: $name
				)
				labeledField(
					AppBrand.localized("API 地址", "API endpoint", locale: locale),
					placeholder: "https://api.example.com/v1/chat/completions",
					text: $endpoint
				)
				VStack(alignment: .leading, spacing: 4) {
					Text(AppBrand.localized("模型 (每行一个)", "Models (one per line)", locale: locale))
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
					TextEditor(text: $modelsText)
						.font(.system(size: 13, design: .monospaced))
						.frame(height: 110)
						.padding(6)
						.background(WorkspaceTheme.elevatedSurface)
						.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
				}
			}

			HStack {
				Spacer()
				Button(AppBrand.localized("取消", "Cancel", locale: locale)) {
					isPresented = false
				}
				.buttonStyle(.bordered)
				Button(AppBrand.localized("保存", "Save", locale: locale)) {
					commit()
				}
				.buttonStyle(.borderedProminent)
				.disabled(!canSave)
			}
		}
		.padding(20)
		.frame(width: 460)
	}

	private var canSave: Bool {
		!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			&& !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			&& parsedModels.count > 0
	}

	private var parsedModels: [String] {
		modelsText
			.split(separator: "\n")
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	private func commit() {
		let provider = CustomAIProvider(
			name: name.trimmingCharacters(in: .whitespacesAndNewlines),
			endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
			models: parsedModels
		)
		onSave(provider)
		isPresented = false
	}

	private func labeledField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
			TextField(placeholder, text: text)
				.textFieldStyle(.roundedBorder)
		}
	}
}

// MARK: - Built-in catalog

enum AIModelCatalog {
	// Curated list. The "发现/同步最新模型" button will (in a follow-up) call
	// each provider's `GET /models` endpoint and refresh this from the wire.
	// DeepSeek officially shipped the v4 series; deepseek-chat / deepseek-reasoner
	// are slated for deprecation but remain available aliases. Keep them in the
	// picker until DeepSeek formally retires them.
	static let deepSeekModels = [
		"deepseek-v4-flash",
		"deepseek-v4-pro",
		"deepseek-chat",
		"deepseek-reasoner"
	]
	static let qwenModels = [
		"qwen-turbo",
		"qwen-plus",
		"qwen-max",
		"qwen-max-longcontext",
		"qwen3-coder-plus"
	]

	static func label(for provider: AIProviderOption, locale: Locale) -> String {
		switch provider {
		case .deepseek: return "DeepSeek"
		case .qwen:     return AppBrand.localized("通义千问 Qwen", "Qwen", locale: locale)
		}
	}

	static func icon(for provider: AIProviderOption) -> String {
		switch provider {
		case .deepseek: return "sparkle"
		case .qwen:     return "bolt.heart"
		}
	}

	static func endpoint(for provider: AIProviderOption) -> String {
		switch provider {
		case .deepseek: return "https://api.deepseek.com/v1/chat/completions"
		case .qwen:     return "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
		}
	}

	static func models(for provider: AIProviderOption) -> [String] {
		switch provider {
		case .deepseek: return deepSeekModels
		case .qwen:     return qwenModels
		}
	}

	static func isConfigured(_ provider: AIProviderOption) -> Bool {
		!AICredentialStore.readAPIKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}

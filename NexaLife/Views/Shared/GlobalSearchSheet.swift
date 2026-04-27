//
//  GlobalSearchSheet.swift
//  NexaLife
//
//  Extracted from ContentView.swift on 2026-04-27.
//

import SwiftUI

struct GlobalSearchSheet: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.dismiss) private var dismiss
	@Environment(\.locale) private var locale
	@State private var query: String = ""

	private var filteredModules: [AppModule] {
		let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !keyword.isEmpty else { return AppModule.allCases }
		return AppModule.allCases.filter { module in
			module.preferenceLabel(for: locale).lowercased().contains(keyword)
				|| module.rawValue.lowercased().contains(keyword)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("settings.global_search.title")
				.font(.title3.bold())

			TextField("settings.global_search.placeholder", text: $query)
				.textFieldStyle(.roundedBorder)

			Divider()

			ScrollView {
				VStack(alignment: .leading, spacing: 8) {
					ForEach(filteredModules) { module in
						Button {
							appState.updateModule(module)
							dismiss()
						} label: {
							HStack {
								Text(module.preferenceLabel(for: locale))
								Spacer()
							}
						}
						.buttonStyle(.plain)
						.padding(.horizontal, 10)
						.padding(.vertical, 8)
						.background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
					}
				}
			}

			HStack {
				Spacer()
				Button("settings.global_search.close") { dismiss() }
					.buttonStyle(.bordered)
			}
		}
		.padding(18)
		.frame(width: 420, height: 380)
	}
}

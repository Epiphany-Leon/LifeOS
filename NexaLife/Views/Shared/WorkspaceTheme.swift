//
//  WorkspaceTheme.swift
//  NexaLife
//
//  Created by Codex on 2026-04-08.
//

import SwiftUI
import AppKit

enum WorkspaceTheme {
	static let canvas = Color.white
	static let surface = Color.white
	static let elevatedSurface = Color(red: 0.978, green: 0.982, blue: 0.993)
	static let subtleSurface = Color(red: 0.964, green: 0.972, blue: 0.992)
	static let divider = Color.black.opacity(0.05)
	static let border = Color.black.opacity(0.08)
	static let strongText = Color(red: 0.117, green: 0.133, blue: 0.188)
	static let mutedText = Color(red: 0.420, green: 0.451, blue: 0.525)
	static let accent = Color(red: 0.369, green: 0.361, blue: 0.933)
	static let accentTint = Color(red: 0.369, green: 0.361, blue: 0.933).opacity(0.10)
	static let accentWash = Color(red: 0.369, green: 0.361, blue: 0.933).opacity(0.05)
	static let secondaryWash = Color(red: 0.180, green: 0.776, blue: 0.725).opacity(0.06)
	static let glowWash = Color(red: 0.988, green: 0.935, blue: 0.804)
	static let shadow = Color.black.opacity(0.06)

	static func moduleAccent(for module: AppModule) -> Color {
		switch module {
		case .dashboard:
			return accent
		case .inbox:
			return Color(red: 0.302, green: 0.612, blue: 1.000)
		case .execution:
			return Color(red: 1.000, green: 0.592, blue: 0.294)
		case .lifestyle:
			return Color(red: 0.267, green: 0.761, blue: 0.498)
		case .knowledge:
			return Color(red: 0.192, green: 0.737, blue: 0.812)
		case .vitals:
			return Color(red: 0.949, green: 0.412, blue: 0.620)
		case .trash:
			return Color(red: 0.482, green: 0.533, blue: 0.627)
		}
	}
}

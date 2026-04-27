//
//  LifestyleView.swift
//  NexaLife
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

enum LifestyleTab: String, CaseIterable {
	case accounting  = "账务"
	case goals       = "目标"
	case connections = "人脉"

	var icon: String {
		switch self {
		case .accounting:  return "yensign.circle"
		case .goals:       return "flag.checkered"
		case .connections: return "person.2"
		}
	}
}

struct LifestyleView: View {
	@Binding var selectedTab: LifestyleTab
	@Binding var selectedTransaction: Transaction?
	@Binding var selectedGoal: Goal?
	@Binding var selectedConnection: Connection?

	var body: some View {
		VStack(spacing: 0) {
			compactTabBar

			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)

			LifestyleTabWorkspaceRouter(
				selectedTab: selectedTab,
				selectedTransaction: $selectedTransaction,
				selectedGoal: $selectedGoal,
				selectedConnection: $selectedConnection
			)
		}
			.onChange(of: selectedTab) { _, tab in
				switch tab {
				case .accounting:
					selectedGoal = nil
					selectedConnection = nil
				case .goals:
					selectedTransaction = nil
					selectedConnection = nil
				case .connections:
					selectedTransaction = nil
					selectedGoal = nil
				}
			}
	}

	private var compactTabBar: some View {
		HStack(spacing: 8) {
			ForEach(LifestyleTab.allCases, id: \.self) { tab in
				lifestyleTabChip(tab)
			}

			Spacer(minLength: 0)

			WorkspacePill(
				title: tabSummary(for: selectedTab),
				icon: selectedTab.icon,
				accent: WorkspaceTheme.moduleAccent(for: .lifestyle)
			)

			WorkspaceActionButton(
				title: createButtonTitle(for: selectedTab),
				icon: "plus",
				accent: WorkspaceTheme.moduleAccent(for: .lifestyle),
				isPrimary: true
			) {
				postCreateNotification(for: selectedTab)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
	}

	private func createButtonTitle(for tab: LifestyleTab) -> String {
		switch tab {
		case .accounting:  return "新建条目"
		case .goals:       return "新建目标"
		case .connections: return "新建联系人"
		}
	}

	private func postCreateNotification(for tab: LifestyleTab) {
		switch tab {
		case .accounting:
			NotificationCenter.default.post(name: .nexaLifeLifestyleCreateTransaction, object: nil)
		case .goals:
			NotificationCenter.default.post(name: .nexaLifeLifestyleCreateGoal, object: nil)
		case .connections:
			NotificationCenter.default.post(name: .nexaLifeLifestyleCreateConnection, object: nil)
		}
	}

	private func lifestyleTabChip(_ tab: LifestyleTab) -> some View {
		let isSelected = selectedTab == tab
		return Button {
			selectedTab = tab
		} label: {
			HStack(spacing: 8) {
				Image(systemName: tab.icon)
					.font(.system(size: 12, weight: .semibold))
				Text(tab.rawValue)
					.font(.subheadline.weight(isSelected ? .semibold : .medium))
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 9)
		.background(isSelected ? WorkspaceTheme.moduleAccent(for: .lifestyle) : WorkspaceTheme.elevatedSurface)
		.foregroundStyle(isSelected ? Color.white : WorkspaceTheme.strongText)
		.overlay(
			RoundedRectangle(cornerRadius: 16, style: .continuous)
				.stroke(isSelected ? WorkspaceTheme.moduleAccent(for: .lifestyle) : WorkspaceTheme.border, lineWidth: 1)
		)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.buttonStyle(.plain)
	}

	private func tabSummary(for tab: LifestyleTab) -> String {
		switch tab {
		case .accounting:
			return "账务台面"
		case .goals:
			return "目标推进"
		case .connections:
			return "关系维护"
		}
	}
}

private struct LifestyleTabWorkspaceRouter: View {
	let selectedTab: LifestyleTab
	@Binding var selectedTransaction: Transaction?
	@Binding var selectedGoal: Goal?
	@Binding var selectedConnection: Connection?

	var body: some View {
		activeWorkspace
			.id(selectedTab)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	@ViewBuilder
	private var activeWorkspace: some View {
		switch selectedTab {
		case .accounting:
			AccountingView(selectedTransaction: $selectedTransaction)
		case .goals:
			GoalView(selectedGoal: $selectedGoal)
		case .connections:
			ConnectionView(selectedConnection: $selectedConnection)
		}
	}
}

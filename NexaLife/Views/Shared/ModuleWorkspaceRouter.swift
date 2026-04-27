//
//  ModuleWorkspaceRouter.swift
//  NexaLife
//
//  Workspace navigation, window frame, per-module hosts, and shell scaffolding.
//  Extracted from ContentView.swift on 2026-04-27.
//

import SwiftUI
import SwiftData
import Combine

final class WorkspaceNavigationState: ObservableObject {
	@Published var selectedDashboardSnapshot: DashboardSnapshot?
	@Published var selectedInboxItem: InboxItem?
	@Published var selectedTask: TaskItem?
	@Published var selectedNote: Note?
	@Published var selectedLifestyleTab: LifestyleTab = .accounting
	@Published var selectedTransaction: Transaction?
	@Published var selectedGoal: Goal?
	@Published var selectedConnection: Connection?
	@Published var selectedVitalsEntry: VitalsEntry?

	func resetAllSelections() {
		selectedDashboardSnapshot = nil
		selectedInboxItem = nil
		selectedTask = nil
		selectedNote = nil
		selectedLifestyleTab = .accounting
		selectedTransaction = nil
		selectedGoal = nil
		selectedConnection = nil
		selectedVitalsEntry = nil
	}
}
struct WorkspaceWindowFrame<Sidebar: View, Workspace: View>: View {
	let sidebar: Sidebar
	let workspace: Workspace
	init(
		@ViewBuilder sidebar: () -> Sidebar,
		@ViewBuilder workspace: () -> Workspace
	) {
		self.sidebar = sidebar()
		self.workspace = workspace()
	}
	var body: some View {
		HStack(spacing: 0) {
			sidebar
			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(width: 1)
			workspace
		}
	}
}
struct ModuleWorkspaceRouter: View {
	let selectedModule: AppModule
	@ObservedObject var navigation: WorkspaceNavigationState
	var body: some View {
		activeWorkspace
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
	@ViewBuilder
	private var activeWorkspace: some View {
		switch selectedModule {
		case .dashboard:
			DashboardWorkspaceHost(selectedDashboardSnapshot: $navigation.selectedDashboardSnapshot)
		case .inbox:
			InboxWorkspaceHost(selectedInboxItem: $navigation.selectedInboxItem)
		case .execution:
			ExecutionWorkspaceHost(selectedTask: $navigation.selectedTask)
		case .knowledge:
			KnowledgeWorkspaceHost(selectedNote: $navigation.selectedNote)
		case .lifestyle:
			LifestyleWorkspaceHost(
				selectedLifestyleTab: $navigation.selectedLifestyleTab,
				selectedTransaction: $navigation.selectedTransaction,
				selectedGoal: $navigation.selectedGoal,
				selectedConnection: $navigation.selectedConnection
			)
		case .vitals:
			VitalsWorkspaceHost(selectedVitalsEntry: $navigation.selectedVitalsEntry)
		case .trash:
			TrashWorkspaceHost()
		}
	}
}
struct DashboardWorkspaceHost: View {
	@Binding var selectedDashboardSnapshot: DashboardSnapshot?
	var body: some View {
		DashboardView(externalSnapshot: $selectedDashboardSnapshot)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}
struct InboxWorkspaceHost: View {
	@Binding var selectedInboxItem: InboxItem?
	var body: some View {
		ModuleWorkspaceShell(
			accent: WorkspaceTheme.moduleAccent(for: .inbox),
			showsDetail: selectedInboxItem != nil,
			onBack: { selectedInboxItem = nil },
			workspace: {
				ModuleWorkspaceLayout(module: .inbox) {
					InboxView(selectedItem: $selectedInboxItem)
				} trailing: {
					WorkspaceActionButton(
						title: "快速捕捉",
						icon: "plus",
						accent: WorkspaceTheme.moduleAccent(for: .inbox),
						isPrimary: true
					) {
						NotificationCenter.default.post(name: .nexaLifeShowQuickInput, object: nil)
					}
				}
			},
			detail: {
				if let item = selectedInboxItem {
					ItemDetailView(selectedItem: $selectedInboxItem, item: item)
				}
			}
		)
	}
}
struct ExecutionWorkspaceHost: View {
	@Binding var selectedTask: TaskItem?
	var body: some View {
		ModuleWorkspaceShell(
			accent: WorkspaceTheme.moduleAccent(for: .execution),
			showsDetail: selectedTask != nil,
			onBack: { selectedTask = nil },
			workspace: {
				ModuleWorkspaceLayout(module: .execution) {
					ExecutionView(selectedTask: $selectedTask)
				} trailing: {
					HStack(spacing: 8) {
						WorkspaceActionButton(
							title: "项目管理",
							icon: "folder.badge.gearshape",
							accent: .teal,
							isPrimary: false
						) {
							NotificationCenter.default.post(name: .nexaLifeExecutionManageProjects, object: nil)
						}
						WorkspaceActionButton(
							title: "新建任务",
							icon: "plus",
							accent: WorkspaceTheme.moduleAccent(for: .execution),
							isPrimary: true
						) {
							NotificationCenter.default.post(name: .nexaLifeExecutionCreateTask, object: nil)
						}
					}
				}
			},
			detail: {
				if let task = selectedTask {
					TaskDetailView(selectedTask: $selectedTask, task: task)
				}
			}
		)
	}
}
struct KnowledgeWorkspaceHost: View {
	@Binding var selectedNote: Note?
	var body: some View {
		ModuleWorkspaceShell(
			accent: WorkspaceTheme.moduleAccent(for: .knowledge),
			showsDetail: selectedNote != nil,
			onBack: { selectedNote = nil },
			workspace: {
				ModuleWorkspaceLayout(module: .knowledge) {
					KnowledgeView(selectedNote: $selectedNote)
				} trailing: {
					HStack(spacing: 8) {
						WorkspaceActionButton(
							title: "主题列表",
							icon: "line.3.horizontal.decrease.circle",
							accent: WorkspaceTheme.moduleAccent(for: .knowledge),
							isPrimary: false
						) {
							NotificationCenter.default.post(name: .nexaLifeKnowledgeShowTopicList, object: nil)
						}
						WorkspaceActionButton(
							title: "新建笔记",
							icon: "plus",
							accent: WorkspaceTheme.moduleAccent(for: .knowledge),
							isPrimary: true
						) {
							NotificationCenter.default.post(name: .nexaLifeKnowledgeCreateNote, object: nil)
						}
					}
				}
			},
			detail: {
				if let note = selectedNote {
					NoteDetailView(selectedNote: $selectedNote, note: note)
				}
			}
		)
	}
}
struct LifestyleWorkspaceHost: View {
	@Binding var selectedLifestyleTab: LifestyleTab
	@Binding var selectedTransaction: Transaction?
	@Binding var selectedGoal: Goal?
	@Binding var selectedConnection: Connection?
	var body: some View {
		ModuleWorkspaceShell(
			accent: WorkspaceTheme.moduleAccent(for: .lifestyle),
			showsDetail: isShowingDetail,
			onBack: clearSelection,
			workspace: {
				ModuleWorkspaceLayout(module: .lifestyle) {
					LifestyleView(
						selectedTab: $selectedLifestyleTab,
						selectedTransaction: $selectedTransaction,
						selectedGoal: $selectedGoal,
						selectedConnection: $selectedConnection
					)
				}
			},
			detail: {
				lifestyleDetailView
			}
		)
	}
	private var isShowingDetail: Bool {
		switch selectedLifestyleTab {
		case .accounting:
			return selectedTransaction != nil
		case .goals:
			return selectedGoal != nil
		case .connections:
			return selectedConnection != nil
		}
	}
	@ViewBuilder
	private var lifestyleDetailView: some View {
		if selectedLifestyleTab == .accounting, let transaction = selectedTransaction {
			AccountingTransactionDetailView(
				selectedTransaction: $selectedTransaction,
				transaction: transaction
			)
		} else if selectedLifestyleTab == .goals, let goal = selectedGoal {
			GoalDetailView(selectedGoal: $selectedGoal, goal: goal)
		} else if selectedLifestyleTab == .connections, let connection = selectedConnection {
			ConnectionDetailView(selectedConnection: $selectedConnection, connection: connection)
		}
	}
	private func clearSelection() {
		switch selectedLifestyleTab {
		case .accounting:
			selectedTransaction = nil
		case .goals:
			selectedGoal = nil
		case .connections:
			selectedConnection = nil
		}
	}
}
struct VitalsWorkspaceHost: View {
	@Binding var selectedVitalsEntry: VitalsEntry?
	var body: some View {
		ModuleWorkspaceShell(
			accent: WorkspaceTheme.moduleAccent(for: .vitals),
			showsDetail: selectedVitalsEntry != nil,
			onBack: { selectedVitalsEntry = nil },
			workspace: {
				ModuleWorkspaceLayout(module: .vitals) {
					VitalsView(selectedEntry: $selectedVitalsEntry)
				} trailing: {
					WorkspaceActionButton(
						title: "新建记录",
						icon: "plus",
						accent: WorkspaceTheme.moduleAccent(for: .vitals),
						isPrimary: true
					) {
						NotificationCenter.default.post(name: .nexaLifeVitalsCreateEntry, object: nil)
					}
				}
			},
			detail: {
				if let entry = selectedVitalsEntry {
					VitalsDetailView(selectedEntry: $selectedVitalsEntry, entry: entry)
				}
			}
		)
	}
}
struct TrashWorkspaceHost: View {
	var body: some View {
		ModuleWorkspaceLayout(module: .trash) {
			TrashWorkspaceView()
		}
	}
}
struct ModuleWorkspaceShell<Workspace: View, Detail: View>: View {
	let accent: Color
	let showsDetail: Bool
	let onBack: () -> Void
	let workspace: Workspace
	let detail: Detail
	init(
		accent: Color,
		showsDetail: Bool,
		onBack: @escaping () -> Void,
		@ViewBuilder workspace: () -> Workspace,
		@ViewBuilder detail: () -> Detail
	) {
		self.accent = accent
		self.showsDetail = showsDetail
		self.onBack = onBack
		self.workspace = workspace()
		self.detail = detail()
	}
	var body: some View {
		Group {
			if showsDetail {
				ModuleDetailScaffold(accent: accent, onBack: onBack) {
					detail
				}
			} else {
				workspace
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}
}
struct ModuleDetailScaffold<Content: View>: View {
	let accent: Color
	let onBack: () -> Void
	let content: Content
	init(
		accent: Color,
		onBack: @escaping () -> Void,
		@ViewBuilder content: () -> Content
	) {
		self.accent = accent
		self.onBack = onBack
		self.content = content()
	}
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Button(action: onBack) {
					HStack(spacing: 6) {
						Image(systemName: "chevron.left")
							.font(.system(size: 12, weight: .semibold))
						Text("返回")
							.font(.subheadline.weight(.semibold))
					}
					.foregroundStyle(accent)
					.padding(.horizontal, 12)
					.padding(.vertical, 8)
					.background(accent.opacity(0.10))
					.clipShape(Capsule())
				}
				.buttonStyle(.plain)
				Spacer(minLength: 0)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
			Rectangle()
				.fill(WorkspaceTheme.divider)
				.frame(height: 1)
			content
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(WorkspaceTheme.surface)
	}
}
struct TrashWorkspaceView: View {
	private let accent = WorkspaceTheme.moduleAccent(for: .trash)
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				LazyVGrid(
					columns: [GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 14)],
					alignment: .leading,
					spacing: 14
				) {
					WorkspaceMetricTile(
						title: "已删除",
						value: "0",
						subtitle: "等待恢复或彻底清理的条目数",
						icon: "trash",
						accent: accent
					)
					WorkspaceMetricTile(
						title: "待清理",
						value: "0",
						subtitle: "超过保留期限可永久删除",
						icon: "clock.arrow.circlepath",
						accent: .orange
					)
				}
				WorkspaceCard(accent: accent, padding: 28, cornerRadius: 24, shadowY: 8) {
					VStack(spacing: 18) {
						Image(systemName: "trash")
							.font(.system(size: 44, weight: .semibold))
							.foregroundStyle(accent)
						Text("Trash 工作区")
							.font(.system(size: 28, weight: .bold, design: .rounded))
							.foregroundStyle(WorkspaceTheme.strongText)
						Text("当前还没有内容进入 Trash。后续被删除的条目会先集中出现在这里，恢复与清理也都会在这一整块工作区里完成。")
							.font(.body)
							.foregroundStyle(WorkspaceTheme.mutedText)
							.multilineTextAlignment(.center)
							.frame(maxWidth: 460)
					}
					.frame(maxWidth: .infinity, minHeight: 360)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 18)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

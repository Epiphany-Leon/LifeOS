//
//  AccountingView.swift
//  LifeOS
//
//  Created by Lihong Gao on 2026-02-26.
//

import SwiftUI
import SwiftData

private enum AccountingCategoryCatalog {
	static let expenseCategories: [String] = [
		"餐饮", "购物", "日用", "交通", "水果", "零食", "运动", "娱乐", "通讯", "服饰",
		"美容", "住房", "家庭", "社交", "旅行", "数码", "汽车", "医疗", "书籍", "学习",
		"宠物", "礼品", "办公", "维修", "彩票", "红包", "还款", "借出", "饮品", "追星",
		"游戏", "快递", "捐赠", "礼金", "烟酒", "蔬菜", "投资", "其他"
	]

	static let incomeCategories: [String] = [
		"工资", "租金", "分红", "理财", "年终奖", "借入", "收款"
	]

	static let expenseCategorySet: Set<String> = Set(expenseCategories)
	static let incomeCategorySet: Set<String> = Set(incomeCategories)
	static let allCategories: [String] = expenseCategories + incomeCategories

	static func isIncomeCategory(_ category: String) -> Bool {
		incomeCategorySet.contains(category)
	}
}

private enum AccountingFlowTag: String, CaseIterable, Hashable {
	case expense = "支出"
	case income = "收入"

	var tint: Color {
		switch self {
		case .expense: return .orange
		case .income: return .green
		}
	}
}

struct AccountingView: View {
	@EnvironmentObject private var appState: AppState
	@Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

	@Binding var selectedTransaction: Transaction?

	@State private var searchText = ""
	@State private var selectedFlowTags: Set<AccountingFlowTag> = []
	@State private var selectedCategories: Set<String> = []
	@State private var isShowingFilterList = false

	private var globalCurrency: CurrencyCode {
		appState.selectedCurrencyCode
	}

	private var dynamicExpenseCategories: [String] {
		Set(
			transactions
				.filter { $0.amount < 0 }
				.map { normalizedCategory(for: $0) }
				.filter { !AccountingCategoryCatalog.expenseCategorySet.contains($0) }
		)
		.sorted()
	}

	private var dynamicIncomeCategories: [String] {
		Set(
			transactions
				.filter { $0.amount >= 0 }
				.map { normalizedCategory(for: $0) }
				.filter { !AccountingCategoryCatalog.incomeCategorySet.contains($0) }
		)
		.sorted()
	}

	private var visibleFilterCategories: [String] {
		if selectedFlowTags == [.expense] {
			return uniqueCategories(AccountingCategoryCatalog.expenseCategories + dynamicExpenseCategories)
		}
		if selectedFlowTags == [.income] {
			return uniqueCategories(AccountingCategoryCatalog.incomeCategories + dynamicIncomeCategories)
		}
		let dynamic = Set(dynamicExpenseCategories + dynamicIncomeCategories)
		return uniqueCategories(AccountingCategoryCatalog.allCategories + dynamic.sorted())
	}

	private var flowFilteredTransactions: [Transaction] {
		guard !selectedFlowTags.isEmpty else { return transactions }
		return transactions.filter { tx in
			let flow: AccountingFlowTag = tx.amount >= 0 ? .income : .expense
			return selectedFlowTags.contains(flow)
		}
	}

	private var categoryFilteredTransactions: [Transaction] {
		guard !selectedCategories.isEmpty else { return flowFilteredTransactions }
		return flowFilteredTransactions.filter { selectedCategories.contains(normalizedCategory(for: $0)) }
	}

	private var filteredTransactions: [Transaction] {
		let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !keyword.isEmpty else { return categoryFilteredTransactions }
		return categoryFilteredTransactions.filter { tx in
			let title = tx.title.trimmingCharacters(in: .whitespacesAndNewlines)
			let stream = tx.streamName.trimmingCharacters(in: .whitespacesAndNewlines)
			let category = normalizedCategory(for: tx)
			let note = tx.note.trimmingCharacters(in: .whitespacesAndNewlines)
			let amountText = String(format: "%.2f", abs(tx.amount))
			return title.localizedCaseInsensitiveContains(keyword)
				|| stream.localizedCaseInsensitiveContains(keyword)
				|| category.localizedCaseInsensitiveContains(keyword)
				|| note.localizedCaseInsensitiveContains(keyword)
				|| amountText.localizedCaseInsensitiveContains(keyword)
		}
	}

	private var monthlyTransactions: [Transaction] {
		let now = Date()
		return transactions.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
	}

	private var monthlyBudget: Double {
		max(0, appState.monthlyBudget)
	}

	private var monthlySpent: Double {
		abs(monthlyTransactions.map(convertedAmount).filter { $0 < 0 }.reduce(0, +))
	}

	private var monthlyIncome: Double {
		monthlyTransactions.map(convertedAmount).filter { $0 > 0 }.reduce(0, +)
	}

	private var monthlyBalance: Double {
		monthlyIncome - monthlySpent
	}

	var body: some View {
		VStack(spacing: 0) {
			header

			Divider()

			filterTagBar

			searchBar

			Divider()

			List(selection: $selectedTransaction) {
				if filteredTransactions.isEmpty {
					ContentUnavailableView(
						"还没有记录",
						systemImage: "yensign.circle",
						description: Text("在右侧详情新建后，可在这里按分类筛选")
					)
				} else {
					ForEach(filteredTransactions) { tx in
						TransactionRowView(
							transaction: tx,
							displayAmount: convertedAmount(tx),
							displayCurrency: globalCurrency
						)
						.tag(tx)
						.listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
					}
				}
			}
		}
		.sheet(isPresented: $isShowingFilterList) {
			AccountingFilterListSheet(
				isPresented: $isShowingFilterList,
				selectedFlowTags: $selectedFlowTags,
				selectedCategories: $selectedCategories,
				flowCounts: flowCounts,
				categoryCounts: categoryCounts,
				categories: visibleFilterCategories
			)
		}
		.onChange(of: transactions.map(\.id)) { _, ids in
			if let selected = selectedTransaction, !ids.contains(selected.id) {
				selectedTransaction = nil
			}
			normalizeSelectedCategories()
		}
		.onChange(of: selectedFlowTags) { _, _ in
			normalizeSelectedCategories()
		}
	}

	private var filterTagBar: some View {
		HStack(spacing: 8) {
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					AccountingFilterChip(
						title: "全部",
						count: transactions.count,
						isSelected: selectedFlowTags.isEmpty && selectedCategories.isEmpty,
						tint: .accentColor
					) {
						selectedFlowTags.removeAll()
						selectedCategories.removeAll()
					}

					ForEach(AccountingFlowTag.allCases, id: \.self) { flow in
						AccountingFilterChip(
							title: flow.rawValue,
							count: flowCounts[flow] ?? 0,
							isSelected: selectedFlowTags.contains(flow),
							tint: flow.tint
						) {
							toggleFlow(flow)
						}
					}

					ForEach(visibleFilterCategories, id: \.self) { category in
						AccountingFilterChip(
							title: category,
							count: categoryCounts[category] ?? 0,
							isSelected: selectedCategories.contains(category),
							tint: AccountingCategoryCatalog.isIncomeCategory(category) ? .green : .orange
						) {
							toggleCategory(category)
						}
					}
				}
				.padding(.vertical, 2)
			}

			Button {
				isShowingFilterList = true
			} label: {
				Image(systemName: "list.bullet")
					.font(.subheadline)
					.padding(.horizontal, 10)
					.padding(.vertical, 7)
					.background(Color(nsColor: .controlBackgroundColor))
					.clipShape(Capsule())
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	private var searchBar: some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
			TextField("搜索分类、标题、备注、金额…", text: $searchText)
				.textFieldStyle(.plain)
			if !searchText.isEmpty {
				Button {
					searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 8))
		.padding(.horizontal, 12)
		.padding(.bottom, 8)
	}

	private var header: some View {
		VStack(spacing: 10) {
			LazyVGrid(
				columns: [GridItem(.flexible()), GridItem(.flexible())],
				spacing: 8
			) {
				AccountingMetricCard(
					title: "月度预算",
					value: CurrencyService.format(monthlyBudget, currency: globalCurrency, showSign: false),
					color: .blue
				)
				AccountingMetricCard(
					title: "实际支出",
					value: CurrencyService.format(monthlySpent, currency: globalCurrency, showSign: false),
					color: .red
				)
				AccountingMetricCard(
					title: "收入",
					value: CurrencyService.format(monthlyIncome, currency: globalCurrency, showSign: false),
					color: .green
				)
				AccountingMetricCard(
					title: "净收支",
					value: CurrencyService.format(monthlyBalance, currency: globalCurrency),
					color: monthlyBalance >= 0 ? .teal : .orange
				)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(Color(nsColor: .windowBackgroundColor))
	}

	private var flowCounts: [AccountingFlowTag: Int] {
		[
			.expense: transactions.filter { $0.amount < 0 }.count,
			.income: transactions.filter { $0.amount >= 0 }.count
		]
	}

	private var categoryCounts: [String: Int] {
		Dictionary(uniqueKeysWithValues: visibleFilterCategories.map { category in
			(category, transactions.filter { normalizedCategory(for: $0) == category }.count)
		})
	}

	private func toggleFlow(_ flow: AccountingFlowTag) {
		if selectedFlowTags.contains(flow) {
			selectedFlowTags.remove(flow)
		} else {
			selectedFlowTags.insert(flow)
		}
	}

	private func toggleCategory(_ category: String) {
		if selectedCategories.contains(category) {
			selectedCategories.remove(category)
		} else {
			selectedCategories.insert(category)
		}
	}

	private func normalizedCategory(for transaction: Transaction) -> String {
		let trimmed = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			return transaction.amount >= 0 ? "收款" : "其他"
		}
		if trimmed == "收入" {
			return "收款"
		}
		return trimmed
	}

	private func normalizeSelectedCategories() {
		let validCategories = Set(visibleFilterCategories)
		selectedCategories = selectedCategories.intersection(validCategories)
	}

	private func uniqueCategories(_ source: [String]) -> [String] {
		var seen: Set<String> = []
		return source.filter { seen.insert($0).inserted }
	}

	private func convertedAmount(_ transaction: Transaction) -> Double {
		let source = CurrencyCode(rawValue: transaction.currencyCode) ?? .CNY
		return CurrencyService.convert(transaction.amount, from: source, to: globalCurrency)
	}
}

private struct AccountingFilterChip: View {
	var title: String
	var count: Int
	var isSelected: Bool
	var tint: Color
	var action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Text(title)
					.font(.caption)
					.fontWeight(isSelected ? .semibold : .regular)
				Text("\(count)")
					.font(.caption2)
					.padding(.horizontal, 5)
					.padding(.vertical, 1)
					.background(isSelected ? Color.white.opacity(0.28) : Color.secondary.opacity(0.15))
					.clipShape(Capsule())
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(isSelected ? tint : Color(nsColor: .controlBackgroundColor))
			.foregroundStyle(isSelected ? .white : .primary)
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
	}
}

private struct AccountingFilterListSheet: View {
	@Binding var isPresented: Bool
	@Binding var selectedFlowTags: Set<AccountingFlowTag>
	@Binding var selectedCategories: Set<String>

	var flowCounts: [AccountingFlowTag: Int]
	var categoryCounts: [String: Int]
	var categories: [String]

	@State private var searchText = ""

	private var visibleCategories: [String] {
		let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !keyword.isEmpty else { return categories }
		return categories.filter { $0.localizedCaseInsensitiveContains(keyword) }
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("筛选分类")
					.font(.headline)
				Spacer()
				Button("关闭") { isPresented = false }
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)

			Divider()

			TextField("搜索分类…", text: $searchText)
				.textFieldStyle(.roundedBorder)
				.padding(12)

			List {
				Section("收支类型") {
					ForEach(AccountingFlowTag.allCases, id: \.self) { flow in
						Button {
							if selectedFlowTags.contains(flow) {
								selectedFlowTags.remove(flow)
							} else {
								selectedFlowTags.insert(flow)
							}
						} label: {
							HStack {
								Text(flow.rawValue)
								Spacer()
								Text("\(flowCounts[flow] ?? 0)")
									.foregroundStyle(.secondary)
								if selectedFlowTags.contains(flow) {
									Image(systemName: "checkmark")
										.foregroundStyle(Color.accentColor)
								}
							}
						}
						.buttonStyle(.plain)
					}
				}

				Section("分类") {
					ForEach(visibleCategories, id: \.self) { category in
						Button {
							if selectedCategories.contains(category) {
								selectedCategories.remove(category)
							} else {
								selectedCategories.insert(category)
							}
						} label: {
							HStack {
								Text(category)
								Spacer()
								Text("\(categoryCounts[category] ?? 0)")
									.foregroundStyle(.secondary)
								if selectedCategories.contains(category) {
									Image(systemName: "checkmark")
										.foregroundStyle(Color.accentColor)
								}
							}
						}
						.buttonStyle(.plain)
					}
				}
			}

			Divider()

			HStack {
				Button("清空筛选") {
					selectedFlowTags.removeAll()
					selectedCategories.removeAll()
				}
				.buttonStyle(.bordered)
				Spacer()
				Button("完成") { isPresented = false }
					.buttonStyle(.borderedProminent)
			}
			.padding(16)
		}
		.frame(width: 380, height: 520)
	}
}

private struct AccountingMetricCard: View {
	var title: String
	var value: String
	var color: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(title)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
			Text(value)
				.font(.system(size: 20, weight: .bold))
				.foregroundStyle(color)
				.lineLimit(1)
				.minimumScaleFactor(0.75)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(color.opacity(0.08))
		.clipShape(RoundedRectangle(cornerRadius: 10))
	}
}

private struct TransactionRowView: View {
	var transaction: Transaction
	var displayAmount: Double
	var displayCurrency: CurrencyCode

	private var sourceCurrency: CurrencyCode {
		CurrencyCode(rawValue: transaction.currencyCode) ?? .CNY
	}

	private var displayTitle: String {
		let title = transaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
		if !title.isEmpty { return title }
		if !transaction.streamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return transaction.streamName
		}
		return normalizedCategory
	}

	private var normalizedCategory: String {
		let trimmed = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isEmpty {
			return transaction.amount >= 0 ? "收款" : "其他"
		}
		return trimmed
	}

	var body: some View {
		HStack(spacing: 12) {
			ZStack {
				Circle()
					.fill(transaction.amount >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
					.frame(width: 36, height: 36)
				Image(systemName: transaction.amount >= 0 ? "plus.circle" : "minus.circle")
					.foregroundStyle(transaction.amount >= 0 ? Color.green : Color.red)
			}

			VStack(alignment: .leading, spacing: 3) {
				Text(displayTitle)
					.font(.body)
					.lineLimit(1)

				Text(normalizedCategory)
					.font(.caption)
					.foregroundStyle(.secondary)

				HStack(spacing: 6) {
					Text(AppDateFormatter.ymd(transaction.date))
						.font(.caption2)
						.foregroundStyle(.tertiary)
					Text("·")
						.font(.caption2)
						.foregroundStyle(.tertiary)
					Text(sourceCurrency.rawValue)
						.font(.caption2)
						.foregroundStyle(.tertiary)
				}
			}

			Spacer()

			Text(CurrencyService.format(displayAmount, currency: displayCurrency))
				.font(.system(size: 18, weight: .bold))
				.foregroundStyle(displayAmount >= 0 ? Color.green : Color.red)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 4)
	}
}

struct AccountingTransactionDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Binding var selectedTransaction: Transaction?
	@Bindable var transaction: Transaction

	@State private var amountText: String = ""
	@State private var isExpense: Bool = true
	@State private var category: String = ""
	@State private var title: String = ""
	@State private var note: String = ""
	@State private var date: Date = .now
	@State private var currencyCode: String = CurrencyCode.CNY.rawValue
	@State private var isShowingCategoryPicker = false

	private var categories: [String] {
		isExpense ? AccountingCategoryCatalog.expenseCategories : AccountingCategoryCatalog.incomeCategories
	}

	private var transactionCurrency: CurrencyCode {
		CurrencyCode(rawValue: currencyCode) ?? .CNY
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				HStack {
					Text("财务条目详情")
						.font(.title3.bold())
					Spacer()
					Button("保存") {
						saveChanges()
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}

				Picker("类型", selection: $isExpense) {
					Text("支出").tag(true)
					Text("收入").tag(false)
				}
				.pickerStyle(.segmented)
				.onChange(of: isExpense) { _, newValue in
					let valid = Set(newValue ? AccountingCategoryCatalog.expenseCategories : AccountingCategoryCatalog.incomeCategories)
					if !valid.contains(category) {
						category = defaultCategory(forExpense: newValue)
					}
				}

				HStack(spacing: 10) {
					Text(isExpense ? "-" : "+")
						.font(.system(size: 26, weight: .black))
						.foregroundStyle(isExpense ? .red : .green)
					Text(transactionCurrency.symbol)
						.font(.system(size: 26, weight: .black))
					TextField("金额", text: $amountText)
						.font(.system(size: 24, weight: .bold))
						.textFieldStyle(.roundedBorder)
						.frame(width: 180)

					Picker("币种", selection: $currencyCode) {
						ForEach(CurrencyCode.allCases) { code in
							Text(code.displayName).tag(code.rawValue)
						}
					}
					.pickerStyle(.menu)
				}

				LabeledContent("分类") {
					Button {
						isShowingCategoryPicker = true
					} label: {
						HStack {
							Text(category.isEmpty ? "选择分类" : category)
							Spacer()
							Image(systemName: "chevron.down")
						}
						.padding(.horizontal, 10)
						.padding(.vertical, 6)
						.background(Color(nsColor: .controlBackgroundColor))
						.clipShape(RoundedRectangle(cornerRadius: 8))
					}
					.buttonStyle(.plain)
				}

				TextField("标题", text: $title)
					.textFieldStyle(.roundedBorder)

				TextField("备注", text: $note, axis: .vertical)
					.lineLimit(3...5)
					.textFieldStyle(.roundedBorder)

				DatePicker("日期", selection: $date, displayedComponents: .date)
					.datePickerStyle(.field)
				Text("日期：\(AppDateFormatter.ymd(date))")
					.font(.caption2)
					.foregroundStyle(.secondary)

				Button(role: .destructive) {
					selectedTransaction = nil
					modelContext.delete(transaction)
				} label: {
					Label("删除条目", systemImage: "trash")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
			}
			.padding(24)
		}
		.sheet(isPresented: $isShowingCategoryPicker) {
			AccountingCategoryPickerSheet(
				isPresented: $isShowingCategoryPicker,
				title: "选择分类",
				categories: categories,
				selectedCategory: $category
			)
		}
		.onAppear {
			loadFromTransaction()
		}
		.onChange(of: transaction.id) { _, _ in
			loadFromTransaction()
		}
	}

	private func defaultCategory(forExpense: Bool) -> String {
		forExpense ? "其他" : "收款"
	}

	private func loadFromTransaction() {
		amountText = String(format: "%.2f", abs(transaction.amount))
		isExpense = transaction.amount < 0
		let fallback = defaultCategory(forExpense: isExpense)
		let rawCategory = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
		category = rawCategory.isEmpty ? fallback : rawCategory
		title = transaction.title.isEmpty ? transaction.streamName : transaction.title
		note = transaction.note
		date = transaction.date
		currencyCode = transaction.currencyCode
	}

	private func saveChanges() {
		let parsed = Double(amountText) ?? 0
		transaction.amount = isExpense ? -abs(parsed) : abs(parsed)
		transaction.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
		transaction.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
		transaction.note = note
		transaction.date = date
		transaction.currencyCode = currencyCode
	}
}

struct AccountingCategoryPickerSheet: View {
	@Binding var isPresented: Bool
	let title: String
	let categories: [String]
	@Binding var selectedCategory: String

	@State private var searchText = ""

	private var filteredCategories: [String] {
		let source = categories.isEmpty ? ["其他"] : categories
		let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !keyword.isEmpty else { return source }
		return source.filter { $0.localizedCaseInsensitiveContains(keyword) }
	}

	var body: some View {
		VStack(spacing: 12) {
			HStack {
				Text(title)
					.font(.headline)
				Spacer()
				Button("关闭") { isPresented = false }
					.buttonStyle(.plain)
			}

			TextField("搜索分类…", text: $searchText)
				.textFieldStyle(.roundedBorder)

			List(filteredCategories, id: \.self) { category in
				Button {
					selectedCategory = category
					isPresented = false
				} label: {
					HStack {
						Text(category)
						Spacer()
						if selectedCategory == category {
							Image(systemName: "checkmark")
								.foregroundColor(.accentColor)
						}
					}
				}
				.buttonStyle(.plain)
			}
		}
		.padding(16)
		.frame(width: 360, height: 460)
	}
}

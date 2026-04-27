//
//  CurrencyService.swift
//  NexaLife
//
//  Created by Codex on 2026-03-01.
//

import Foundation

enum CurrencyCode: String, CaseIterable, Identifiable, Codable {
	case CNY
	case USD
	case EUR
	case GBP
	case JPY
	case HKD

	var id: String { rawValue }

	var symbol: String {
		switch self {
		case .CNY: return "¥"
		case .USD: return "$"
		case .EUR: return "€"
		case .GBP: return "£"
		case .JPY: return "¥"
		case .HKD: return "HK$"
		}
	}

	var displayName: String {
		switch self {
		case .CNY: return "人民币 CNY"
		case .USD: return "美元 USD"
		case .EUR: return "欧元 EUR"
		case .GBP: return "英镑 GBP"
		case .JPY: return "日元 JPY"
		case .HKD: return "港币 HKD"
		}
	}
}

enum CurrencyService {
	private static let customRatesKey = "customCurrencyRatesToUSD"

	// 表示 1 单位对应多少 USD
	private static let builtInRatesToUSD: [CurrencyCode: Double] = [
		.USD: 1.0,
		.CNY: 0.14,
		.EUR: 1.09,
		.GBP: 1.27,
		.JPY: 0.0067,
		.HKD: 0.128
	]

	static func convert(_ amount: Double, from source: CurrencyCode, to target: CurrencyCode) -> Double {
		guard source != target else { return amount }
		let sourceToUSD = rateToUSD(for: source)
		let targetToUSD = rateToUSD(for: target)
		guard sourceToUSD > 0, targetToUSD > 0 else { return amount }
		let amountInUSD = amount * sourceToUSD
		return amountInUSD / targetToUSD
	}

	static func format(_ amount: Double, currency: CurrencyCode, showSign: Bool = true) -> String {
		let prefix: String
		if showSign {
			prefix = amount >= 0 ? "+" : "-"
		} else {
			prefix = ""
		}
		return "\(prefix)\(currency.symbol)\(String(format: "%.2f", abs(amount)))"
	}

	static func updateCustomRate(toUSD: Double, for currency: CurrencyCode) {
		guard toUSD > 0 else { return }
		var current = customRatesToUSD()
		current[currency.rawValue] = toUSD
		UserDefaults.standard.set(current, forKey: customRatesKey)
	}

	private static func rateToUSD(for currency: CurrencyCode) -> Double {
		if let custom = customRatesToUSD()[currency.rawValue], custom > 0 {
			return custom
		}
		return builtInRatesToUSD[currency] ?? 1.0
	}

	private static func customRatesToUSD() -> [String: Double] {
		(UserDefaults.standard.dictionary(forKey: customRatesKey) as? [String: Double]) ?? [:]
	}
}

enum AppDateFormatter {
	private static let ymdFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "zh_CN_POSIX")
		formatter.calendar = Calendar(identifier: .gregorian)
		formatter.dateFormat = "yyyy/MM/dd"
		return formatter
	}()

	static func ymd(_ date: Date) -> String {
		ymdFormatter.string(from: date)
	}
}

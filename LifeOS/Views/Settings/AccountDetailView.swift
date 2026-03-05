//
//  AccountDetailView.swift
//  LifeOS
//
//  Created by Codex on 2026-03-01.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AccountDetailView: View {
	@EnvironmentObject private var appState: AppState
	@Environment(\.dismiss) private var dismiss

	@State private var draftUserName: String = ""
	@State private var draftBudgetText: String = ""
	@State private var apiKeyInput: String = ""
	@State private var savedApiKey: String = ""
	@State private var showTokenValue = false
	@State private var copiedToken = false
	@State private var savedProfile = false
	@State private var savedBudget = false
	@State private var savedToken = false
	private let formLabelWidth: CGFloat = 72
	private let trailingContentWidth: CGFloat = 360
	private let trailingEdgePadding: CGFloat = 12

	private var avatarImage: NSImage? {
		guard !appState.avatarImagePath.isEmpty else { return nil }
		return NSImage(contentsOfFile: appState.avatarImagePath)
	}

	private var tokenDisplayText: String {
		guard !savedApiKey.isEmpty else { return "未保存" }
		if showTokenValue { return savedApiKey }
		return String(repeating: "*", count: max(8, min(savedApiKey.count, 24)))
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("账户")
					.font(.title3.bold())
				Spacer()
				Button("关闭") {
					dismiss()
				}
				.buttonStyle(.bordered)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 14)

			Divider()

			Form {
				Section("账户") {
					HStack(spacing: 14) {
						Group {
							if let image = avatarImage {
								Image(nsImage: image)
									.resizable()
									.scaledToFill()
							} else {
								Image(systemName: "person.circle.fill")
									.resizable()
									.scaledToFit()
									.foregroundStyle(.secondary)
							}
						}
						.frame(width: 72, height: 72)
						.clipShape(Circle())

						Spacer(minLength: 12)

						VStack(alignment: .trailing, spacing: 8) {
							Button("修改头像并裁剪…") {
								selectAndCropAvatar()
							}
							.buttonStyle(.bordered)
							if !appState.avatarImagePath.isEmpty {
								Button("移除头像", role: .destructive) {
									appState.avatarImagePath = ""
								}
								.buttonStyle(.plain)
							}
						}
					}
					.padding(.trailing, trailingEdgePadding)

					rightAlignedRow(label: "昵称") {
						HStack(spacing: 8) {
							TextField("", text: $draftUserName)
								.textFieldStyle(.roundedBorder)
								.frame(width: 180)
							Button("保存") {
								appState.userName = draftUserName.trimmingCharacters(in: .whitespacesAndNewlines)
								showSavedFlag($savedProfile)
							}
							.buttonStyle(.borderedProminent)
							.controlSize(.small)
							if savedProfile {
								Image(systemName: "checkmark.circle.fill")
									.foregroundStyle(.green)
							}
						}
					}
				}

				Section("偏好") {
					rightAlignedRow(label: "全局货币") {
						Picker("全局货币", selection: $appState.globalCurrency) {
							ForEach(CurrencyCode.allCases) { code in
								Text(code.displayName).tag(code.rawValue)
							}
						}
						.labelsHidden()
						.frame(width: 220)
					}

					rightAlignedRow(label: "月度预算") {
						HStack(spacing: 8) {
							TextField("", text: $draftBudgetText)
								.textFieldStyle(.roundedBorder)
								.frame(width: 140)
							Button("保存") {
								let parsed = Double(draftBudgetText) ?? 0
								appState.monthlyBudget = max(0, parsed)
								draftBudgetText = String(format: "%.2f", appState.monthlyBudget)
								showSavedFlag($savedBudget)
							}
							.buttonStyle(.borderedProminent)
							.controlSize(.small)
							if savedBudget {
								Image(systemName: "checkmark.circle.fill")
									.foregroundStyle(.green)
							}
						}
					}
				}

				Section("API Token") {
					rightAlignedRow(label: "保存位置") {
						Picker("保存位置", selection: $appState.apiTokenStorageMode) {
							ForEach(APITokenStorageMode.allCases) { mode in
								Text(mode.label).tag(mode.rawValue)
							}
						}
						.labelsHidden()
						.frame(width: 220)
						.onChange(of: appState.apiTokenStorageMode) { _, _ in
							savedApiKey = AICredentialStore.readAPIKey()
						}
					}

					if appState.selectedAPITokenStorageMode == .localFile {
						rightAlignedRow(label: "本地文件") {
							HStack(spacing: 8) {
								Text(AICredentialStore.localFileURL().path)
									.foregroundStyle(.secondary)
									.truncationMode(.middle)
									.frame(width: 220, alignment: .trailing)
								Button("选择文件…") {
									selectTokenFile()
								}
								.buttonStyle(.bordered)
								.controlSize(.small)
							}
						}
					}

					rightAlignedRow(label: "已保存 Token") {
						HStack(spacing: 8) {
							if showTokenValue && !savedApiKey.isEmpty {
								Button(savedApiKey) {
									copyTokenToPasteboard()
								}
								.buttonStyle(.plain)
								.help("点击复制到剪贴板")
								.textSelection(.enabled)
								.lineLimit(1)
								.truncationMode(.middle)
							} else {
								Text(tokenDisplayText)
									.foregroundStyle(savedApiKey.isEmpty ? .secondary : .primary)
							}
							Button {
								showTokenValue.toggle()
							} label: {
								Image(systemName: showTokenValue ? "eye.slash" : "eye")
							}
							.buttonStyle(.plain)
							if copiedToken {
								Text("已复制")
									.font(.caption)
									.foregroundStyle(.green)
							}
						}
					}

					rightAlignedRow(label: "更新 Token") {
						SecureField("sk-...", text: $apiKeyInput)
							.textFieldStyle(.roundedBorder)
							.frame(width: 260)
					}

					rightAlignedRow(label: "") {
						HStack(spacing: 10) {
							Button("保存 API Key") {
								AICredentialStore.saveAPIKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
								savedApiKey = AICredentialStore.readAPIKey()
								showSavedFlag($savedToken)
							}
							.buttonStyle(.borderedProminent)
							.disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

							if savedToken {
								Label("已保存", systemImage: "checkmark.circle.fill")
									.font(.subheadline)
									.foregroundStyle(.green)
							}
						}
					}

					rightAlignedRow(label: "实际保存地") {
						Text(AICredentialStore.storageLocationDescription())
							.foregroundStyle(.secondary)
							.truncationMode(.middle)
							.frame(width: 300, alignment: .trailing)
					}
				}

				Section("数据存储") {
					rightAlignedRow(label: "数据目录") {
						Text(appState.storageDirectory?.path ?? "默认路径")
							.foregroundStyle(.secondary)
							.truncationMode(.middle)
							.frame(width: 300, alignment: .trailing)
					}

					rightAlignedRow(label: "") {
						Button("更改存储文件夹…") {
							selectDataFolder()
						}
						.buttonStyle(.bordered)
					}
				}
			}
			.formStyle(.grouped)
		}
		.frame(width: 640, height: 620)
		.onAppear {
			draftUserName = appState.userName
			draftBudgetText = String(format: "%.2f", appState.monthlyBudget)
			let key = AICredentialStore.readAPIKey()
			savedApiKey = key
			apiKeyInput = key
		}
	}

	private func rightAlignedRow<Content: View>(
		label: String,
		@ViewBuilder content: () -> Content
	) -> some View {
		HStack(alignment: .center, spacing: 12) {
			Text(label)
				.frame(width: formLabelWidth, alignment: .leading)
			Spacer(minLength: 12)
			content()
				.frame(maxWidth: trailingContentWidth, alignment: .trailing)
		}
		.padding(.trailing, trailingEdgePadding)
	}

	private func showSavedFlag(_ flag: Binding<Bool>) {
		withAnimation { flag.wrappedValue = true }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
			withAnimation { flag.wrappedValue = false }
		}
	}

	private func selectAndCropAvatar() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.image]
		guard panel.runModal() == .OK, let sourceURL = panel.url,
			  let sourceImage = NSImage(contentsOf: sourceURL),
			  let croppedImage = circularCroppedImage(from: sourceImage),
			  let pngData = croppedImage.pngData()
		else {
			return
		}

		let folder = avatarStoreFolderURL()
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			let targetURL = folder.appendingPathComponent("avatar.png")
			try pngData.write(to: targetURL, options: .atomic)
			appState.avatarImagePath = targetURL.path
		} catch {
			NSLog("Avatar save error: \(error.localizedDescription)")
		}
	}

	private func circularCroppedImage(from image: NSImage) -> NSImage? {
		guard let cg = image.cgImageFromImage else { return nil }
		let side = min(cg.width, cg.height)
		let x = (cg.width - side) / 2
		let y = (cg.height - side) / 2
		let cropRect = CGRect(x: x, y: y, width: side, height: side)
		guard let square = cg.cropping(to: cropRect) else { return nil }

		let size = NSSize(width: side, height: side)
		let output = NSImage(size: size)
		output.lockFocus()
		let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
		path.addClip()
		NSGraphicsContext.current?.imageInterpolation = .high
		NSImage(cgImage: square, size: size).draw(in: NSRect(origin: .zero, size: size))
		output.unlockFocus()
		return output
	}

	private func avatarStoreFolderURL() -> URL {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
			?? URL(fileURLWithPath: NSTemporaryDirectory())
		return base.appendingPathComponent("LifeOS/Avatars", isDirectory: true)
	}

	private func selectTokenFile() {
		let panel = NSSavePanel()
		panel.nameFieldStringValue = "ai_api_token.txt"
		panel.allowedContentTypes = [.plainText]
		panel.canCreateDirectories = true
		guard panel.runModal() == .OK, let url = panel.url else { return }
		AICredentialStore.setLocalFileURL(url)
		if !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			AICredentialStore.saveAPIKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
			savedApiKey = AICredentialStore.readAPIKey()
		}
	}

	private func copyTokenToPasteboard() {
		guard !savedApiKey.isEmpty else { return }
		let board = NSPasteboard.general
		board.clearContents()
		board.setString(savedApiKey, forType: .string)
		withAnimation { copiedToken = true }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
			withAnimation { copiedToken = false }
		}
	}

	private func selectDataFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		if panel.runModal() == .OK {
			appState.storageDirectory = panel.url
		}
	}
}

private extension NSImage {
	var cgImageFromImage: CGImage? {
		if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
			return cgImage
		}
		guard let data = tiffRepresentation,
			  let rep = NSBitmapImageRep(data: data) else {
			return nil
		}
		return rep.cgImage
	}

	func pngData() -> Data? {
		guard let tiffData = tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData) else {
			return nil
		}
		return bitmap.representation(using: .png, properties: [:])
	}
}

//
//  AccountDetailView.swift
//  NexaLife
//
//  Created by Codex on 2026-03-01.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AccountDetailView: View {
	@EnvironmentObject private var appState: AppState
	@EnvironmentObject private var oauthService: OAuthService
	@Environment(\.dismiss) private var dismiss
	@Environment(\.locale) private var locale

	@State private var draftUserName: String = ""
	@State private var draftBudgetText: String = ""
	@State private var savedProfile = false
	@State private var savedBudget = false
	@State private var isShowingAvatarCropper = false
	@State private var pendingAvatarImage: NSImage?
	private let formLabelWidth: CGFloat = 72
	private let trailingContentWidth: CGFloat = 360
	private let trailingEdgePadding: CGFloat = 12

	private var avatarImage: NSImage? {
		AvatarImageLoader.load(from: appState.avatarImagePath)
	}

	private var emailAccountStatus: EmailAccountStatus? {
		guard appState.selectedAccountProvider == .email else { return nil }
		return oauthService.emailAccountStatus(for: appState.accountEmail)
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text(AppBrand.localized("Profile", "Profile", locale: locale))
					.font(.title3.bold())
				Spacer()
				Button(AppBrand.localized("关闭", "Close", locale: locale)) {
					dismiss()
				}
				.buttonStyle(.bordered)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 14)

			Divider()

			Form {
				Section(AppBrand.localized("Profile", "Profile", locale: locale)) {
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
							Button(AppBrand.localized("修改头像并裁剪…", "Edit and Crop Avatar…", locale: locale)) {
								selectAvatarForManualCrop()
							}
							.buttonStyle(.bordered)
							if !appState.avatarImagePath.isEmpty {
								Button(AppBrand.localized("移除头像", "Remove Avatar", locale: locale), role: .destructive) {
									appState.avatarImagePath = ""
								}
								.buttonStyle(.plain)
							}
						}
					}
					.padding(.trailing, trailingEdgePadding)

					rightAlignedRow(label: AppBrand.localized("昵称", "Profile Name", locale: locale)) {
						HStack(spacing: 8) {
							TextField("", text: $draftUserName)
								.textFieldStyle(.roundedBorder)
								.frame(width: 180)
							Button(AppBrand.localized("保存", "Save", locale: locale)) {
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

					rightAlignedRow(label: AppBrand.localized("Profile 类型", "Profile Type", locale: locale)) {
						Text(appState.selectedAccountProvider.label(for: locale))
							.foregroundStyle(.secondary)
					}

					if !appState.accountEmail.isEmpty {
						rightAlignedRow(label: AppBrand.localized("邮箱", "Email", locale: locale)) {
							Text(appState.accountEmail)
								.foregroundStyle(.secondary)
								.textSelection(.enabled)
						}
					}

					if let emailAccountStatus {
						rightAlignedRow(label: AppBrand.localized("邮箱验证", "Email Verification", locale: locale)) {
							Text(emailAccountStatus.verifiedAt == nil
								? AppBrand.localized("待验证", "Pending", locale: locale)
								: AppBrand.localized("已验证", "Verified", locale: locale)
							)
								.foregroundStyle(emailAccountStatus.verifiedAt == nil ? .orange : .green)
						}

						rightAlignedRow(label: AppBrand.localized("通知订阅", "Notifications", locale: locale)) {
							Text(emailAccountStatus.announcementOptIn
								? AppBrand.localized("接收版本更新与重要通知", "Receiving release updates and important notices", locale: locale)
								: AppBrand.localized("未订阅通知", "No notification subscription", locale: locale)
							)
								.foregroundStyle(.secondary)
						}
					}
				}

				Section(AppBrand.localized("偏好", "Preferences", locale: locale)) {
					rightAlignedRow(label: AppBrand.localized("全局货币", "Currency", locale: locale)) {
						HStack {
							Spacer(minLength: 0)
							Picker(AppBrand.localized("全局货币", "Currency", locale: locale), selection: $appState.globalCurrency) {
								ForEach(CurrencyCode.allCases) { code in
									Text(code.displayName).tag(code.rawValue)
								}
							}
							.labelsHidden()
							.frame(width: 220, alignment: .trailing)
						}
					}

					rightAlignedRow(label: AppBrand.localized("月度预算", "Monthly Budget", locale: locale)) {
						HStack(spacing: 8) {
							TextField("", text: $draftBudgetText)
								.textFieldStyle(.roundedBorder)
								.frame(width: 140)
							Button(AppBrand.localized("保存", "Save", locale: locale)) {
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

					rightAlignedRow(label: AppBrand.localized("高级设置", "Advanced Settings", locale: locale)) {
						SettingsLink {
							Text(AppBrand.localized("在设置中管理 API Token 与数据存储…", "Manage API tokens and data storage in Settings…", locale: locale))
						}
					}
				}
			}
			.formStyle(.grouped)
		}
		.frame(width: 640, height: 420)
		.sheet(isPresented: $isShowingAvatarCropper, onDismiss: {
			pendingAvatarImage = nil
		}) {
			if let source = pendingAvatarImage {
				AvatarCropperSheet(sourceImage: source) { cropped in
					saveAvatarImage(cropped)
				}
			}
		}
		.onAppear {
			draftUserName = appState.userName
			draftBudgetText = String(format: "%.2f", appState.monthlyBudget)
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

	private func selectAvatarForManualCrop() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.allowedContentTypes = [.image]
		guard panel.runModal() == .OK,
			  let sourceURL = panel.url,
			  let sourceImage = NSImage(contentsOf: sourceURL) else {
			return
		}
		pendingAvatarImage = sourceImage
		isShowingAvatarCropper = true
	}

	private func saveAvatarImage(_ image: NSImage) {
		guard let pngData = image.pngData() else { return }
		let folder = avatarStoreFolderURL()
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			if !appState.avatarImagePath.isEmpty {
				let previousURL = URL(fileURLWithPath: appState.avatarImagePath)
				if previousURL.deletingLastPathComponent() == folder {
					try? FileManager.default.removeItem(at: previousURL)
				}
			}
			let targetURL = folder.appendingPathComponent("avatar-\(UUID().uuidString).png")
			try pngData.write(to: targetURL, options: .atomic)
			appState.avatarImagePath = targetURL.path
		} catch {
			AppLogger.warning("Avatar save failed: \(error.localizedDescription)", category: "profile")
		}
	}

	private func avatarStoreFolderURL() -> URL {
		AppDataArchiveService.avatarStoreFolderURL()
	}
}

private struct AvatarCropperSheet: View {
	@Environment(\.dismiss) private var dismiss

	let sourceImage: NSImage
	let onSave: (NSImage) -> Void

	@State private var zoom: CGFloat = 1
	@State private var offset: CGSize = .zero
	@State private var dragStartOffset: CGSize = .zero

	private let previewSide: CGFloat = 340
	private let cropDiameter: CGFloat = 260
	private let outputSide: CGFloat = 512

	private var sourceSize: CGSize {
		let intrinsicSize = sourceImage.size
		if intrinsicSize.width > 0, intrinsicSize.height > 0 {
			return intrinsicSize
		}
		guard let cg = sourceImage.cgImageFromImage else { return .zero }
		return CGSize(width: cg.width, height: cg.height)
	}

	private var baseScale: CGFloat {
		guard sourceSize.width > 0, sourceSize.height > 0 else { return 1 }
		return max(cropDiameter / sourceSize.width, cropDiameter / sourceSize.height)
	}

	private var renderedWidth: CGFloat { sourceSize.width * baseScale * zoom }
	private var renderedHeight: CGFloat { sourceSize.height * baseScale * zoom }

	private var imageFrameInPreview: CGRect {
		CGRect(
			x: (previewSide - renderedWidth) / 2 + offset.width,
			y: (previewSide - renderedHeight) / 2 + offset.height,
			width: renderedWidth,
			height: renderedHeight
		)
	}

	private var cropFrameInPreview: CGRect {
		CGRect(
			x: (previewSide - cropDiameter) / 2,
			y: (previewSide - cropDiameter) / 2,
			width: cropDiameter,
			height: cropDiameter
		)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text("手动裁剪头像")
				.font(.title3.bold())

			ZStack {
				Color.black.opacity(0.06)

				Image(nsImage: sourceImage)
					.resizable()
					.interpolation(.high)
					.frame(width: renderedWidth, height: renderedHeight)
					.offset(offset)
					.gesture(dragGesture)

				Color.black.opacity(0.44)
					.compositingGroup()
					.mask {
						Rectangle()
							.overlay {
								Circle()
									.frame(width: cropDiameter, height: cropDiameter)
									.blendMode(.destinationOut)
							}
					}
					.allowsHitTesting(false)

				Circle()
					.strokeBorder(.white.opacity(0.95), lineWidth: 2)
					.frame(width: cropDiameter, height: cropDiameter)
					.shadow(color: .black.opacity(0.25), radius: 3, y: 1)
			}
			.frame(width: previewSide, height: previewSide)
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

			HStack(spacing: 10) {
				Text("缩放")
					.foregroundStyle(.secondary)
				Slider(value: $zoom, in: 1...4, step: 0.01)
					.onChange(of: zoom) { _, newValue in
						offset = clampedOffset(offset, zoom: newValue)
						dragStartOffset = offset
					}
				Button("重置") {
					zoom = 1
					offset = .zero
					dragStartOffset = .zero
				}
				.buttonStyle(.bordered)
			}

			HStack {
				Spacer()
				Button("取消") {
					dismiss()
				}
				.buttonStyle(.bordered)
				Button("保存头像") {
					guard let image = renderCroppedAvatar() else { return }
					onSave(image)
					dismiss()
				}
				.buttonStyle(.borderedProminent)
			}
		}
		.padding(18)
		.frame(width: 380)
	}

	private var dragGesture: some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { value in
				let next = CGSize(
					width: dragStartOffset.width + value.translation.width,
					height: dragStartOffset.height + value.translation.height
				)
				offset = clampedOffset(next)
			}
			.onEnded { _ in
				dragStartOffset = offset
			}
	}

	private func clampedOffset(_ candidate: CGSize, zoom: CGFloat? = nil) -> CGSize {
		let resolvedZoom = zoom ?? self.zoom
		let width = sourceSize.width * baseScale * resolvedZoom
		let height = sourceSize.height * baseScale * resolvedZoom

		let maxX = max(0, (width - cropDiameter) / 2)
		let maxY = max(0, (height - cropDiameter) / 2)

		return CGSize(
			width: min(max(candidate.width, -maxX), maxX),
			height: min(max(candidate.height, -maxY), maxY)
		)
	}

	private func renderCroppedAvatar() -> NSImage? {
		guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

		let outputSize = NSSize(width: outputSide, height: outputSide)
		let scaleFactor = outputSide / cropDiameter
		let imageFrame = imageFrameInPreview
		let cropFrame = cropFrameInPreview
		let drawRect = CGRect(
			x: (imageFrame.minX - cropFrame.minX) * scaleFactor,
			y: (imageFrame.minY - cropFrame.minY) * scaleFactor,
			width: imageFrame.width * scaleFactor,
			height: imageFrame.height * scaleFactor
		)

		return NSImage(size: outputSize, flipped: true) { rect in
			NSGraphicsContext.current?.imageInterpolation = .high
			NSColor.clear.setFill()
			rect.fill()

			let clipPath = NSBezierPath(ovalIn: rect)
			clipPath.addClip()

			sourceImage.draw(
				in: drawRect,
				from: CGRect(origin: .zero, size: sourceSize),
				operation: .sourceOver,
				fraction: 1,
				respectFlipped: true,
				hints: [.interpolation: NSImageInterpolation.high]
			)
			return true
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

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QR Code Generator

struct QRCodeGenerator {
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    /// Generates a QR code image from a string
    func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else { return nil }

        // Scale the image to the desired size
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Convert to UIImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200
    var foregroundColor: Color = .black
    var backgroundColor: Color = .white

    @State private var qrImage: UIImage?
    private let generator = QRCodeGenerator()

    var body: some View {
        ZStack {
            backgroundColor

            if let qrImage = qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size + 16, height: size + 16)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await generateQRCode()
        }
        .onChange(of: content) { _, _ in
            Task {
                await generateQRCode()
            }
        }
    }

    private func generateQRCode() async {
        // Generate on background thread
        let image = await Task.detached(priority: .userInitiated) {
            generator.generateQRCode(from: content, size: size * 2) // 2x for Retina
        }.value

        await MainActor.run {
            qrImage = image
        }
    }
}

// MARK: - QR Code Card View (with optional label)

struct QRCodeCardView: View {
    let content: String
    let title: String?
    var size: CGFloat = 200

    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false

    private let generator = QRCodeGenerator()

    var body: some View {
        VStack(spacing: 16) {
            if let title = title {
                Text(title)
                    .font(.headline)
            }

            QRCodeView(content: content, size: size)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            Text(String(localized: "share.qrcode.scanHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Save button
            Button {
                saveQRCodeToPhotos()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if showSaveSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(showSaveSuccess
                        ? String(localized: "share.qrcode.saved")
                        : String(localized: "share.qrcode.save")
                    )
                }
                .font(.footnote)
                .foregroundStyle(showSaveSuccess ? .green : Color.appPrimary)
            }
            .disabled(isSaving)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert(String(localized: "share.qrcode.saveError.title"), isPresented: $showSaveError) {
            Button(String(localized: "button.ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "share.qrcode.saveError.message"))
        }
    }

    private func saveQRCodeToPhotos() {
        isSaving = true

        Task.detached(priority: .userInitiated) {
            guard let image = generator.generateQRCode(from: content, size: 512) else {
                await MainActor.run {
                    isSaving = false
                    showSaveError = true
                }
                return
            }

            await MainActor.run {
                let imageSaver = ImageSaver { success in
                    isSaving = false
                    if success {
                        withAnimation {
                            showSaveSuccess = true
                        }
                        // Reset after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSaveSuccess = false
                            }
                        }
                    } else {
                        showSaveError = true
                    }
                }
                imageSaver.writeToPhotoAlbum(image: image)
            }
        }
    }
}

// MARK: - Image Saver Helper

final class ImageSaver: NSObject {
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error == nil)
    }
}

// MARK: - Previews

#Preview("QR Code View") {
    QRCodeView(content: "https://wishwith.me/wishlists/follow/abc123")
        .padding()
}

#Preview("QR Code Card") {
    QRCodeCardView(
        content: "https://wishwith.me/wishlists/follow/abc123",
        title: "Birthday Wishlist"
    )
    .padding()
}

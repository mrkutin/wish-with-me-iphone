import SwiftUI
import PhotosUI

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Mode: CaseIterable {
        case url
        case manual

        var localizedName: LocalizedStringKey {
            switch self {
            case .url: return "By URL"
            case .manual: return "Manual"
            }
        }
    }

    @State private var mode: Mode = .url
    @State private var urlText: String = ""
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var priceText: String = ""
    @State private var currency: String = "RUB"
    @State private var quantity: Int = 1
    @State private var sourceUrl: String = ""

    // Photo picker state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageBase64: String?
    @State private var previewImage: UIImage?
    @State private var isLoadingImage: Bool = false
    @State private var imageError: String?

    let onCreateByURL: (String) -> Void
    let onCreateManually: (String, String?, Double?, String?, Int, String?, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if mode == .url {
                    urlSection
                } else {
                    manualSection
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        handleCreate()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - URL Mode

    private var urlSection: some View {
        Section {
            TextField("https://example.com/product", text: $urlText)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Product URL")
        } footer: {
            Text("Paste a link and we will automatically fetch the product details.")
        }
    }

    // MARK: - Manual Mode

    private var manualSection: some View {
        Group {
            Section("Details") {
                TextField("Title", text: $title)

                TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Price") {
                HStack {
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)

                    TextField("Currency", text: $currency)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                }
            }

            Section("Quantity") {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
            }

            Section {
                TextField("Source URL (optional)", text: $sourceUrl)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Link")
            } footer: {
                Text("Optional link to the product page.")
            }

            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                        Text(previewImage == nil ? "Upload photo" : "Change photo")
                            .foregroundStyle(previewImage == nil ? .secondary : .primary)
                    }
                }
                .accessibilityLabel(previewImage == nil ? "Upload photo" : "Change photo")

                if isLoadingImage {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading image...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let previewImage {
                    HStack {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Spacer()

                        Button(role: .destructive) {
                            self.selectedPhoto = nil
                            self.previewImage = nil
                            self.imageBase64 = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove photo")
                    }
                }

                if let imageError {
                    Text(imageError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Photo")
            } footer: {
                Text("Optional photo of the item (max 5 MB).")
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else {
            previewImage = nil
            imageBase64 = nil
            imageError = nil
            return
        }

        isLoadingImage = true
        imageError = nil

        Task {
            defer { isLoadingImage = false }

            guard let data = try? await item.loadTransferable(type: Data.self) else {
                imageError = String(localized: "Failed to load image")
                return
            }

            // Check size (5 MB max)
            if data.count > 5_242_880 {
                imageError = String(localized: "Image is too large (max 5 MB)")
                selectedPhoto = nil
                return
            }

            guard let uiImage = UIImage(data: data) else {
                imageError = String(localized: "Invalid image format")
                return
            }

            // Resize if needed (max 800px on longest side) and compress as JPEG
            let resized = resizeImage(uiImage, maxDimension: 800)
            guard let jpegData = resized.jpegData(compressionQuality: 0.7) else {
                imageError = String(localized: "Failed to process image")
                return
            }

            let base64String = jpegData.base64EncodedString()
            previewImage = resized
            imageBase64 = "data:image/jpeg;base64,\(base64String)"
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        switch mode {
        case .url:
            return isValidURL(urlText)
        case .manual:
            let urlValid = sourceUrl.isEmpty || isValidURL(sourceUrl)
            return !title.trimmingCharacters(in: .whitespaces).isEmpty && urlValid
        }
    }

    private func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    // MARK: - Actions

    private func handleCreate() {
        switch mode {
        case .url:
            onCreateByURL(urlText.trimmingCharacters(in: .whitespaces))
        case .manual:
            let price: Double? = Double(priceText)
            let desc: String? = descriptionText.isEmpty ? nil : descriptionText
            let src: String? = sourceUrl.isEmpty ? nil : sourceUrl
            let cur: String? = currency.isEmpty ? nil : currency

            onCreateManually(
                title.trimmingCharacters(in: .whitespaces),
                desc,
                price,
                cur,
                quantity,
                src,
                imageBase64
            )
        }
        dismiss()
    }
}

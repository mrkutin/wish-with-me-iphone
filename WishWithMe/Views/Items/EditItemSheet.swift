import SwiftUI
import PhotosUI

struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: Item
    let onSave: (String, String?, Double?, String?, Int, String?, String?) -> Void

    @State private var title: String
    @State private var descriptionText: String
    @State private var priceText: String
    @State private var currency: String
    @State private var quantity: Int
    @State private var sourceUrl: String

    // Photo picker state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageBase64: String?
    @State private var previewImage: UIImage?
    @State private var isLoadingImage: Bool = false
    @State private var imageError: String?
    @State private var hasExistingImage: Bool = false

    init(
        item: Item,
        onSave: @escaping (String, String?, Double?, String?, Int, String?, String?) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _descriptionText = State(initialValue: item.descriptionText ?? "")
        _priceText = State(initialValue: item.price.map { String($0) } ?? "")
        _currency = State(initialValue: item.currency ?? "RUB")
        _quantity = State(initialValue: item.quantity)
        _sourceUrl = State(initialValue: item.sourceUrl ?? "")
        _imageBase64 = State(initialValue: item.imageBase64)
        _hasExistingImage = State(initialValue: item.imageBase64 != nil || item.imageUrl != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                }

                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                            Text(currentImageAvailable ? "Change photo" : "Upload photo")
                                .foregroundStyle(currentImageAvailable ? .primary : .secondary)
                        }
                    }
                    .accessibilityLabel(currentImageAvailable ? "Change photo" : "Upload photo")

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
                                self.hasExistingImage = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove photo")
                        }
                    } else if hasExistingImage {
                        HStack {
                            existingImagePreview
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Spacer()

                            Button(role: .destructive) {
                                self.imageBase64 = nil
                                self.hasExistingImage = false
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
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    loadImage(from: newValue)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Existing Image Preview

    @ViewBuilder
    private var existingImagePreview: some View {
        if let base64 = item.imageBase64,
           let data = Data(base64Encoded: cleanBase64(base64)),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray6)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        }
                }
            }
        } else {
            Color(.systemGray6)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private var currentImageAvailable: Bool {
        previewImage != nil || hasExistingImage
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else {
            previewImage = nil
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

            if data.count > 5_242_880 {
                imageError = String(localized: "Image is too large (max 5 MB)")
                selectedPhoto = nil
                return
            }

            guard let uiImage = UIImage(data: data) else {
                imageError = String(localized: "Invalid image format")
                return
            }

            let resized = resizeImage(uiImage, maxDimension: 800)
            guard let jpegData = resized.jpegData(compressionQuality: 0.7) else {
                imageError = String(localized: "Failed to process image")
                return
            }

            let base64String = jpegData.base64EncodedString()
            previewImage = resized
            imageBase64 = "data:image/jpeg;base64,\(base64String)"
            hasExistingImage = false
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

    private func cleanBase64(_ base64: String) -> String {
        if let range = base64.range(of: ";base64,") {
            return String(base64[range.upperBound...])
        }
        return base64
    }

    // MARK: - Validation

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let urlValid = sourceUrl.isEmpty || isValidURL(sourceUrl)
        return !trimmedTitle.isEmpty && urlValid
    }

    private func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    // MARK: - Actions

    private func handleSave() {
        let price: Double? = Double(priceText)
        let desc: String? = descriptionText.isEmpty ? nil : descriptionText
        let src: String? = sourceUrl.isEmpty ? nil : sourceUrl
        let cur: String? = currency.isEmpty ? nil : currency

        onSave(
            title.trimmingCharacters(in: .whitespaces),
            desc,
            price,
            cur,
            quantity,
            src,
            imageBase64
        )
        dismiss()
    }
}

import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String?
    let avatarBase64: String?
    let size: CGFloat

    init(name: String? = nil, avatarBase64: String? = nil, size: CGFloat = 32) {
        self.name = name
        self.avatarBase64 = avatarBase64
        self.size = size
    }

    var body: some View {
        Group {
            if let base64 = avatarBase64,
               !isPlaceholder(base64),
               let image = decodeBase64(base64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initial = name?.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.brandPrimary.gradient)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color(.systemGray3).gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func isPlaceholder(_ base64: String) -> Bool {
        base64.contains("PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI")
    }

    private func decodeBase64(_ base64String: String) -> UIImage? {
        let cleaned: String
        if let commaIndex = base64String.firstIndex(of: ",") {
            cleaned = String(base64String[base64String.index(after: commaIndex)...])
        } else {
            cleaned = base64String
        }
        guard let data = Data(base64Encoded: cleaned) else { return nil }
        return UIImage(data: data)
    }
}

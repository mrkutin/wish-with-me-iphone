import SwiftUI

struct OfflineBanner: View {
    let isOffline: Bool

    var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.orange)
                    .imageScale(.small)
                Text("You are offline")
                    .fontWeight(.medium)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .accessibilityLabel("You are offline")
        }
    }
}

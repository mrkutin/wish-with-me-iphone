import SwiftUI

struct SyncStatusIndicator: View {
    let state: SyncEngine.SyncState

    var body: some View {
        Group {
            switch state {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Synced")
            case .syncing:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Syncing")
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Sync error")
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Offline")
            }
        }
        .font(.system(size: 20))
        .frame(width: 28, height: 28)
    }
}

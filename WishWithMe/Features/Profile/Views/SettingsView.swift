import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"
    @AppStorage("viewMode") private var viewMode = ViewMode.list
    @AppStorage("showBoughtItems") private var showBoughtItems = true
    @AppStorage("enableHaptics") private var enableHaptics = true

    enum ViewMode: String, CaseIterable {
        case list
        case grid

        var title: String {
            switch self {
            case .list: return String(localized: "settings.viewMode.list")
            case .grid: return String(localized: "settings.viewMode.grid")
            }
        }

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }

    var body: some View {
        List {
            // Appearance Section
            Section(String(localized: "settings.appearance")) {
                Picker(String(localized: "settings.viewMode"), selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.title, systemImage: mode.icon)
                            .tag(mode)
                    }
                }

                Toggle(String(localized: "settings.showBoughtItems"), isOn: $showBoughtItems)
            }

            // Behavior Section
            Section(String(localized: "settings.behavior")) {
                Toggle(String(localized: "settings.haptics"), isOn: $enableHaptics)
            }

            // Language Section
            Section {
                Picker(String(localized: "settings.language"), selection: $preferredLanguage) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(String(localized: "settings.language"))
            } footer: {
                Text(String(localized: "settings.language.hint"))
            }

            // Data Section
            Section(String(localized: "settings.data")) {
                Button {
                    // TODO: Implement manual sync
                } label: {
                    Label(String(localized: "settings.syncNow"), systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    // TODO: Implement clear cache
                } label: {
                    Label(String(localized: "settings.clearCache"), systemImage: "trash")
                }
            }

            // Notifications Section
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(String(localized: "settings.notificationSettings"), systemImage: "bell.badge")
                }
            } header: {
                Text(String(localized: "settings.notifications"))
            } footer: {
                Text(String(localized: "settings.notifications.hint"))
            }
        }
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("Settings View") {
    NavigationStack {
        SettingsView()
    }
}

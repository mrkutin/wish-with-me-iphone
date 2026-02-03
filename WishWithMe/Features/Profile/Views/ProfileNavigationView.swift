import SwiftUI

struct ProfileNavigationView: View {
    @State private var coordinator = ProfileNavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ProfileView(coordinator: coordinator)
                .navigationDestination(for: ProfileDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView()
                    case .editProfile:
                        EditProfileView()
                    case .changePassword:
                        ChangePasswordView()
                    case .about:
                        AboutView()
                    }
                }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            switch sheet {
            case .editProfile:
                EditProfileView()
            case .changePassword:
                ChangePasswordView()
            }
        }
        .alert(item: $coordinator.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alertButton(from: alert.primaryButton),
                secondaryButton: alert.secondaryButton.map { alertButton(from: $0) } ?? .cancel()
            )
        }
    }

    private func alertButton(from button: AlertItem.AlertButton) -> Alert.Button {
        switch button.role {
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        default:
            return .default(Text(button.title), action: button.action)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.appPrimary)

                    Text("WishWithMe")
                        .font(.title.bold())

                    Text(String(localized: "about.description"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Section(String(localized: "about.features.title")) {
                FeatureRow(
                    icon: "list.bullet.clipboard",
                    title: String(localized: "about.features.wishlists"),
                    description: String(localized: "about.features.wishlists.description")
                )

                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: String(localized: "about.features.sharing"),
                    description: String(localized: "about.features.sharing.description")
                )

                FeatureRow(
                    icon: "icloud",
                    title: String(localized: "about.features.sync"),
                    description: String(localized: "about.features.sync.description")
                )

                FeatureRow(
                    icon: "cart",
                    title: String(localized: "about.features.marketplaces"),
                    description: String(localized: "about.features.marketplaces.description")
                )
            }

            Section {
                Link(destination: URL(string: "https://wishwith.me")!) {
                    Label(String(localized: "about.website"), systemImage: "globe")
                }

                Link(destination: URL(string: "mailto:support@wishwith.me")!) {
                    Label(String(localized: "about.support"), systemImage: "envelope")
                }
            }
        }
        .navigationTitle(String(localized: "about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Change Password View (Placeholder)

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Change Password - Coming Soon")
                .navigationTitle(String(localized: "profile.changePassword"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "button.cancel")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Profile Navigation") {
    ProfileNavigationView()
        .withDependencies(DependencyContainer.preview)
}

#Preview("About View") {
    NavigationStack {
        AboutView()
    }
}

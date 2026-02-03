import SwiftUI

struct ProfileView: View {
    @Environment(\.authManager) private var authManager
    @Bindable var coordinator: ProfileNavigationCoordinator

    var body: some View {
        List {
            // User Info Section
            Section {
                if let user = authManager?.currentUser {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Text(user.name.prefix(1).uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(Color.appPrimary)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.headline)

                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        ProgressView()
                        Text(String(localized: "profile.loading"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Actions Section
            Section {
                Button {
                    coordinator.navigate(to: .editProfile)
                } label: {
                    Label(String(localized: "profile.edit"), systemImage: "person.text.rectangle")
                }

                Button {
                    coordinator.navigate(to: .settings)
                } label: {
                    Label(String(localized: "profile.settings"), systemImage: "gearshape")
                }
            }

            // Info Section
            Section {
                Button {
                    coordinator.navigate(to: .about)
                } label: {
                    Label(String(localized: "profile.about"), systemImage: "info.circle")
                }

                Link(destination: URL(string: "https://wishwith.me/privacy")!) {
                    Label(String(localized: "profile.privacy"), systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://wishwith.me/terms")!) {
                    Label(String(localized: "profile.terms"), systemImage: "doc.text")
                }
            }

            // Logout Section
            Section {
                Button(role: .destructive) {
                    coordinator.showAlert(
                        AlertItem.confirmation(
                            title: String(localized: "profile.logout.title"),
                            message: String(localized: "profile.logout.message"),
                            confirmTitle: String(localized: "profile.logout"),
                            confirmRole: .destructive,
                            onConfirm: {
                                Task {
                                    await authManager?.logout()
                                }
                            }
                        )
                    )
                } label: {
                    Label(String(localized: "profile.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            // Delete Account Section
            Section {
                Button(role: .destructive) {
                    coordinator.showAlert(
                        AlertItem.confirmation(
                            title: String(localized: "profile.deleteAccount.title"),
                            message: String(localized: "profile.deleteAccount.message"),
                            confirmTitle: String(localized: "profile.deleteAccount"),
                            confirmRole: .destructive,
                            onConfirm: {
                                Task {
                                    try? await authManager?.deleteAccount()
                                }
                            }
                        )
                    )
                } label: {
                    Label(String(localized: "profile.deleteAccount"), systemImage: "trash")
                        .foregroundStyle(Color.appError)
                }
            } footer: {
                Text(String(localized: "profile.deleteAccount.warning"))
            }

            // Version Info
            Section {
                HStack {
                    Text(String(localized: "profile.version"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "profile.title"))
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview("Profile View") {
    NavigationStack {
        ProfileView(coordinator: ProfileNavigationCoordinator())
    }
    .withDependencies(DependencyContainer.preview)
}

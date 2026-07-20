import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?

    @State private var connectedAccounts: [ConnectedAccount] = []
    @State private var hasPassword: Bool = true
    @State private var availableProviders: [String] = []
    @State private var isLoadingAccounts: Bool = false
    @State private var isLinking: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @AppStorage("appLocale") private var appLocale: String = "en"
    @State private var selectedLocale: String = "en"

    private var canUnlink: Bool {
        hasPassword || connectedAccounts.count > 1
    }

    var body: some View {
        List {
            languageSection

            accountsSection

            messagesSection

            logoutSection
        }
        .navigationTitle("Settings")
        .task {
            selectedLocale = authManager.currentUser?.locale ?? "en"
            await loadAccounts()
        }
    }

    // MARK: - Sections

    private var languageSection: some View {
        Section("Language") {
            Picker("Language", selection: $selectedLocale) {
                Text("English").tag("en")
                Text("Русский").tag("ru")
            }
            .onChange(of: selectedLocale) { _, newLocale in
                updateLocale(newLocale)
            }
        }
    }

    private var accountsSection: some View {
        Section("Connected Accounts") {
            if isLoadingAccounts {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                ForEach(availableProviders, id: \.self) { provider in
                    SettingsAccountRow(
                        provider: provider,
                        connectedAccount: connectedAccounts.first(where: { $0.provider == provider }),
                        canUnlink: canUnlink,
                        isLinking: isLinking,
                        onConnect: { Task { await linkProvider(provider) } },
                        onDisconnect: { Task { await unlinkProvider(provider) } }
                    )
                }

                if !canUnlink {
                    Text("You cannot disconnect your only sign-in method. Add a password or another account first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let error = errorMessage {
            Section {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }

        if let success = successMessage {
            Section {
                Text(success)
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    try? await authManager.logout()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Log Out")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func updateLocale(_ locale: String) {
        guard let userId = authManager.currentUser?.id else { return }

        let fetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in user.id == userId }
        )

        guard let user = try? modelContext.fetch(fetchDescriptor).first else { return }

        user.locale = locale
        user.updatedAt = ISO8601DateFormatter().string(from: Date())
        user.isDirty = true

        do {
            try modelContext.save()
            authManager.currentUser?.locale = locale
            appLocale = locale
            syncEngine?.triggerSync()
        } catch {
            errorMessage = String(localized: "Failed to update language")
        }
    }

    private func loadAccounts() async {
        isLoadingAccounts = true
        defer { isLoadingAccounts = false }

        do {
            availableProviders = try await APIClient.shared.getOAuthProviders()
            let response = try await APIClient.shared.getConnectedAccounts()
            connectedAccounts = response.accounts
            hasPassword = response.hasPassword
        } catch {
            availableProviders = ["google", "yandex"]
        }
    }

    private func linkProvider(_ provider: String) async {
        isLinking = true
        errorMessage = nil
        successMessage = nil
        defer { isLinking = false }

        do {
            let response = try await APIClient.shared.initiateOAuthLink(provider: provider)
            guard let authURL = URL(string: response.authorizationUrl) else {
                errorMessage = String(localized: "Invalid authorization URL")
                return
            }

            let callbackURL = try await OAuthSessionHelper.shared.openSession(url: authURL)

            if let url = callbackURL {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let params = components?.queryItems ?? []

                if let linked = params.first(where: { $0.name == "linked" })?.value {
                    successMessage = String(format: String(localized: "%@ connected successfully"), linked.capitalized)
                    await loadAccounts()
                } else if let errorParam = params.first(where: { $0.name == "error" })?.value {
                    errorMessage = errorParam.replacingOccurrences(of: "_", with: " ").capitalized
                }
            }
        } catch OAuthSessionError.cancelled {
            // User cancelled — no error to show
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unlinkProvider(_ provider: String) async {
        isLinking = true
        errorMessage = nil
        successMessage = nil
        defer { isLinking = false }

        do {
            try await APIClient.shared.unlinkOAuthProvider(provider: provider)
            successMessage = String(format: String(localized: "%@ disconnected"), provider.capitalized)
            await loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

// MARK: - Account Row (extracted to avoid compiler complexity)

private struct SettingsAccountRow: View {
    let provider: String
    let connectedAccount: ConnectedAccount?
    let canUnlink: Bool
    let isLinking: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            providerIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                if let account = connectedAccount {
                    Text(account.email ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if connectedAccount != nil {
                Button("Disconnect") { onDisconnect() }
                    .font(.subheadline)
                    .tint(.red)
                    .disabled(!canUnlink || isLinking)
                    .accessibilityLabel("Disconnect \(displayName) account")
            } else {
                Button("Connect") { onConnect() }
                    .font(.subheadline)
                    .tint(Color.brandPrimary)
                    .disabled(isLinking)
                    .accessibilityLabel("Connect \(displayName) account")
            }
        }
    }

    private var displayName: String {
        switch provider {
        case "google": return "Google"
        case "yandex": return "Yandex"
        default: return provider.capitalized
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        switch provider {
        case "google":
            Image(systemName: "g.circle.fill")
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
        case "yandex":
            Image(systemName: "y.circle.fill")
                .foregroundStyle(Color(red: 0.988, green: 0.247, blue: 0.114))
        default:
            Image(systemName: "person.circle")
                .foregroundStyle(.secondary)
        }
    }
}

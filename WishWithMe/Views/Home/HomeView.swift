import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var selectedTab: MainTab

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Greeting
                HStack(spacing: 12) {
                    AvatarView(
                        name: authManager.currentUser?.name,
                        avatarBase64: authManager.currentUser?.avatarBase64,
                        size: 48
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(authManager.currentUser?.name ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                // Navigation cards
                homeCard(
                    icon: "rectangle.stack.fill",
                    title: String(localized: "My Wishlists"),
                    subtitle: String(localized: "Create and manage your wish lists"),
                    color: .brandPrimary
                ) {
                    selectedTab = .ownWishlists
                }

                homeCard(
                    icon: "person.2.fill",
                    title: String(localized: "Shared with me"),
                    subtitle: String(localized: "Wishlists from friends and family"),
                    color: .orange
                ) {
                    selectedTab = .sharedWithMe
                }

                homeCard(
                    icon: "person.fill",
                    title: String(localized: "Profile"),
                    subtitle: String(localized: "Edit your profile and settings"),
                    color: .teal
                ) {
                    selectedTab = .profile
                }

                // Log out
                Button {
                    Task { try? await authManager.logout() }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.red.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text("Sign out of your account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wish With Me")
    }

    private func homeCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

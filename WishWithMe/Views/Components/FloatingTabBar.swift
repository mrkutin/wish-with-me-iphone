import SwiftUI

enum MainTab: Hashable {
    case home
    case ownWishlists
    case sharedWithMe
    case profile
}

struct FloatingTabBar: View {
    @Binding var selectedTab: MainTab
    let isCollapsed: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Home — always visible
            tabButton(
                icon: selectedTab == .home ? "house.fill" : "house",
                label: "tab.home",
                isSelected: isCollapsed ? selectedTab != .profile : selectedTab == .home
            ) {
                selectedTab = .home
            }

            // Middle buttons — fade on collapse
            if !isCollapsed {
                tabButton(
                    icon: selectedTab == .ownWishlists ? "rectangle.stack.fill" : "rectangle.stack",
                    label: "tab.wishlists",
                    isSelected: selectedTab == .ownWishlists
                ) {
                    selectedTab = .ownWishlists
                }

                tabButton(
                    icon: selectedTab == .sharedWithMe ? "person.2.fill" : "person.2",
                    label: "tab.shared",
                    isSelected: selectedTab == .sharedWithMe
                ) {
                    selectedTab = .sharedWithMe
                }
            }

            Spacer()

            // Profile — always visible
            profileButton
        }
        .padding(.horizontal, isCollapsed ? 0 : 6)
        .padding(.vertical, isCollapsed ? 0 : 6)
        .background {
            if !isCollapsed {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isCollapsed)
    }

    // MARK: - Tab Button

    private func tabButton(icon: String, label: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isCollapsed {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.brandPrimary : .secondary)
                    .frame(width: 44, height: 44)
                    .background {
                        tabItemBackground(isSelected: isSelected)
                    }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 28, height: 24)
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(isSelected ? Color.brandPrimary : .secondary)
                .frame(width: 68, height: 48)
                .background {
                    tabItemBackground(isSelected: isSelected)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        tabButton(
            icon: selectedTab == .profile ? "person.fill" : "person",
            label: "tab.profile",
            isSelected: selectedTab == .profile
        ) {
            selectedTab = .profile
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func tabItemBackground(isSelected: Bool) -> some View {
        if isCollapsed {
            Circle()
                .fill(isSelected ? AnyShapeStyle(Color(.systemGray5)) : AnyShapeStyle(.ultraThinMaterial))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        } else if isSelected {
            Capsule()
                .fill(Color(.systemGray5))
        }
    }
}

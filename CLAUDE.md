# WishWithMe iOS App Development Guide

## Project Overview

Build a native iOS app for WishWithMe - a wishlist management platform. The app must provide feature parity with the existing PWA while following Apple's Human Interface Guidelines and implementing robust offline-first architecture.

**Existing Backend API**: `https://api.wishwith.me` (same API used by PWA)

---

## Technology Stack

### Required Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 16.0+ minimum)
- **Architecture**: MVVM with Repository pattern
- **Local Database**: SwiftData (or Core Data for iOS 16 compatibility)
- **Networking**: URLSession with async/await
- **Authentication**: Keychain Services for secure token storage
- **Offline Sync**: Custom sync engine with operation queue

### Recommended Dependencies (Swift Package Manager)
- `KeychainAccess` - Secure credential storage
- `Kingfisher` - Image caching and loading
- `QRCode` - QR code generation for sharing

---

## Project Structure

```
WishWithMe/
├── App/
│   ├── WishWithMeApp.swift          # App entry point
│   └── AppDelegate.swift            # Push notifications, deep links
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift          # HTTP client with retry logic
│   │   ├── APIEndpoints.swift       # Endpoint definitions
│   │   ├── NetworkMonitor.swift     # Connectivity monitoring
│   │   └── AuthInterceptor.swift    # JWT token injection
│   ├── Persistence/
│   │   ├── DataController.swift     # SwiftData/CoreData setup
│   │   ├── SyncEngine.swift         # Offline sync coordinator
│   │   └── OperationQueue.swift     # Pending operations store
│   ├── Auth/
│   │   ├── AuthManager.swift        # Authentication state
│   │   ├── KeychainService.swift    # Secure storage
│   │   └── OAuthHandler.swift       # OAuth flow handling
│   └── Extensions/
├── Models/
│   ├── User.swift
│   ├── Wishlist.swift
│   ├── WishlistItem.swift
│   └── SyncOperation.swift
├── Features/
│   ├── Auth/
│   │   ├── Views/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignupView.swift
│   │   │   └── OAuthWebView.swift
│   │   └── ViewModels/
│   │       └── AuthViewModel.swift
│   ├── Wishlists/
│   │   ├── Views/
│   │   │   ├── WishlistsView.swift
│   │   │   ├── WishlistDetailView.swift
│   │   │   ├── WishlistCardView.swift
│   │   │   └── CreateWishlistSheet.swift
│   │   └── ViewModels/
│   │       ├── WishlistsViewModel.swift
│   │       └── WishlistDetailViewModel.swift
│   ├── Items/
│   │   ├── Views/
│   │   │   ├── ItemCardView.swift
│   │   │   ├── AddItemSheet.swift
│   │   │   └── ItemDetailView.swift
│   │   └── ViewModels/
│   │       └── ItemViewModel.swift
│   ├── Sharing/
│   │   ├── Views/
│   │   │   ├── ShareSheet.swift
│   │   │   ├── QRCodeView.swift
│   │   │   └── FollowWishlistView.swift
│   │   └── ViewModels/
│   │       └── SharingViewModel.swift
│   ├── Profile/
│   │   ├── Views/
│   │   │   ├── ProfileView.swift
│   │   │   └── SettingsView.swift
│   │   └── ViewModels/
│   │       └── ProfileViewModel.swift
│   └── Shared/
│       ├── Components/
│       │   ├── LoadingView.swift
│       │   ├── EmptyStateView.swift
│       │   ├── ErrorView.swift
│       │   └── MarketplaceButton.swift
│       └── Modifiers/
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings (en, ru)
│   └── Info.plist
└── Tests/
```

---

## Features to Implement

### 1. Authentication

**Email/Password Auth:**
- Sign up with name, email, password
- Login with email/password
- Password validation (min 6 characters)
- Secure token storage in Keychain

**OAuth Integration:**
- Google Sign-In (use `ASWebAuthenticationSession`)
- Yandex OAuth
- VK OAuth
- Handle OAuth callback URLs via deep links

**Session Management:**
- Auto-refresh token on app launch
- Handle 401 responses with logout
- Persist auth state across app restarts

**API Endpoints:**
```
POST /auth/signup      - { name, email, password }
POST /auth/login       - { email, password }
GET  /auth/google      - Redirect to Google OAuth
GET  /auth/yandex      - Redirect to Yandex OAuth
GET  /auth/vk          - Redirect to VK OAuth
POST /auth/logout      - Invalidate session
GET  /auth/me          - Get current user
DELETE /auth/me        - Delete account
```

### 2. Wishlist Management

**Features:**
- View all wishlists (grid and list layouts)
- Create wishlist with name, description, due date
- Edit wishlist details
- Delete wishlist with confirmation
- Pull-to-refresh
- Search/filter wishlists

**API Endpoints:**
```
GET    /wishlists           - Get all wishlists
POST   /wishlists           - Create wishlist
GET    /wishlists/:id       - Get wishlist details
PUT    /wishlists/:id       - Update wishlist
DELETE /wishlists/:id       - Delete wishlist
```

**Data Model:**
```swift
@Model
class Wishlist {
    @Attribute(.unique) var id: String
    var userId: String
    var userName: String
    var name: String
    var description: String?
    var dueDate: Date?
    var items: [WishlistItem]
    var sharedWith: [SharedUser]
    var sharedToken: String
    var createdAt: Date
    var updatedAt: Date

    // Sync metadata
    var localVersion: Int
    var serverVersion: Int
    var needsSync: Bool
    var pendingDeletion: Bool
}
```

### 3. Item Management

**Features:**
- Add item manually (name, URL, price, currency, description)
- Add item via URL with auto-resolution
- Edit item details
- Delete item
- Mark item as bought/unbought
- View item in external browser
- Group items by marketplace

**URL Resolution:**
- Call backend `/wishlists/resolve-item` with URL
- Auto-populate title, price, image from marketplaces
- Supported: Ozon, Wildberries, Yandex Market, AliExpress

**API Endpoints:**
```
POST   /wishlists/resolve-item          - { url } -> item details
POST   /wishlists/:id/items             - Add item
PATCH  /wishlists/:wishlistId/items/:itemId - Update item
DELETE /wishlists/:id/items/:itemId     - Delete item
```

**Data Model:**
```swift
@Model
class WishlistItem {
    @Attribute(.unique) var id: String
    var name: String
    var description: String?
    var url: String?
    var price: Double?
    var currency: String?
    var image: String?
    var bought: Bool
    var priority: Priority?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // Sync metadata
    var needsSync: Bool
    var pendingDeletion: Bool
}

enum Priority: String, Codable {
    case low, medium, high
}
```

### 4. Sharing

**Features:**
- Generate shareable link with token
- Generate QR code for wishlist
- Copy link to clipboard
- Share via iOS share sheet
- Follow shared wishlist
- Unfollow wishlist
- View shared wishlists from others

**API Endpoints:**
```
GET  /wishlists/get-by-token/:token  - Get wishlist by share token
POST /wishlists/:token/follow        - Follow shared wishlist
POST /wishlists/:id/unfollow         - Unfollow wishlist
GET  /wishlists/shared               - Get wishlists shared with user
```

**Deep Link Handling:**
- URL scheme: `wishwithme://`
- Universal links: `https://wishwith.me/wishlists/follow/:token`
- Handle in `AppDelegate` or `SceneDelegate`

### 5. Profile Management

**Features:**
- View profile info
- Edit name
- Change email
- Change password
- Delete account with confirmation
- Logout

**API Endpoints:**
```
PATCH  /users/me  - Update profile { name?, email?, password? }
DELETE /auth/me   - Delete account
```

### 6. Settings

**Features:**
- Language selection (English, Russian)
- View mode preference (grid/list)
- Notification preferences
- About/version info
- Privacy policy link
- Terms of service link

---

## Offline-First Architecture

### Design Principles

1. **Local-First**: All data operations write to local database first
2. **Optimistic Updates**: UI updates immediately, sync happens in background
3. **Conflict Resolution**: Server wins for concurrent edits (timestamp-based)
4. **Operation Queue**: Failed operations are queued and retried

### Sync Engine Implementation

```swift
class SyncEngine {
    private let networkMonitor: NetworkMonitor
    private let apiClient: APIClient
    private let dataController: DataController
    private var pendingOperations: [SyncOperation] = []

    // Monitor connectivity changes
    func startMonitoring() {
        networkMonitor.onStatusChange = { [weak self] isConnected in
            if isConnected {
                self?.processPendingOperations()
            }
        }
    }

    // Queue operation for sync
    func queueOperation(_ operation: SyncOperation) {
        pendingOperations.append(operation)
        persistOperations()

        if networkMonitor.isConnected {
            processPendingOperations()
        }
    }

    // Process all pending operations
    func processPendingOperations() async {
        for operation in pendingOperations {
            do {
                try await executeOperation(operation)
                removeOperation(operation)
            } catch {
                operation.retryCount += 1
                if operation.retryCount > 3 {
                    // Mark as failed, notify user
                }
            }
        }
    }

    // Full sync on app launch or pull-to-refresh
    func performFullSync() async throws {
        // 1. Push local changes
        await processPendingOperations()

        // 2. Pull remote changes
        let remoteWishlists = try await apiClient.getWishlists()

        // 3. Merge with local data
        await mergeWishlists(remoteWishlists)
    }
}
```

### Sync Operation Model

```swift
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let entityType: EntityType
    let entityId: String
    let payload: Data
    let createdAt: Date
    var retryCount: Int

    enum OperationType: String, Codable {
        case create, update, delete
    }

    enum EntityType: String, Codable {
        case wishlist, item
    }
}
```

### Network Monitor

```swift
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = true
    var onStatusChange: ((Bool) -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                self?.isConnected = connected
                self?.onStatusChange?(connected)
            }
        }
        monitor.start(queue: queue)
    }
}
```

### Offline UI Indicators

- Show banner when offline: "You're offline. Changes will sync when connected."
- Show sync indicator when syncing
- Show badge on items pending sync
- Show error state for failed syncs with retry option

---

## UI/UX Guidelines (Apple HIG)

### Navigation Structure

```
TabView
├── Wishlists Tab (house icon)
│   ├── WishlistsView (list of wishlists)
│   │   └── WishlistDetailView (items in wishlist)
│   │       └── ItemDetailView (single item)
│   └── SharedWishlistsView (wishlists from others)
├── Profile Tab (person icon)
│   ├── ProfileView
│   └── SettingsView
```

### Color Palette

```swift
extension Color {
    static let appPrimary = Color(hex: "#4F46E5")      // Indigo
    static let appPrimaryDark = Color(hex: "#4338CA")
    static let appPrimaryLight = Color(hex: "#6366F1")
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appError = Color(hex: "#EF4444")
    static let appSuccess = Color(hex: "#22C55E")

    // Marketplace colors
    static let ozonBlue = Color(hex: "#005BFF")
    static let wildberriesPurple = Color(hex: "#CB11AB")
    static let yandexYellow = Color(hex: "#FFCC00")
    static let aliexpressOrange = Color(hex: "#FF4747")
}
```

### Typography

Use system fonts with Dynamic Type support:

```swift
extension Font {
    static let appTitle = Font.largeTitle.bold()
    static let appHeadline = Font.headline
    static let appBody = Font.body
    static let appCaption = Font.caption
}
```

### Component Patterns

**Cards:**
```swift
struct WishlistCard: View {
    let wishlist: Wishlist

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(wishlist.name)
                .font(.headline)

            if let dueDate = wishlist.dueDate {
                Label(dueDate.formatted(), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(wishlist.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}
```

**Sheets for Forms:**
- Use `.sheet()` for create/edit forms
- Use `.confirmationDialog()` for destructive actions
- Use `.alert()` for errors and confirmations

**Loading States:**
- Use `ProgressView()` for loading
- Use `.redacted(reason: .placeholder)` for skeleton loading
- Show inline loading for actions (button spinner)

**Empty States:**
```swift
struct EmptyWishlistsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Wishlists",
            systemImage: "list.bullet.clipboard",
            description: Text("Create your first wishlist to get started")
        )
    }
}
```

### Accessibility

- Support VoiceOver with proper labels
- Support Dynamic Type
- Ensure sufficient color contrast
- Provide haptic feedback for actions
- Support reduced motion preferences

---

## API Client Implementation

```swift
actor APIClient {
    private let baseURL = URL(string: "https://api.wishwith.me")!
    private let session: URLSession
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if let token = await authManager.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            await authManager.logout()
            throw APIError.unauthorized
        case 400...499:
            let error = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.clientError(error?.message ?? "Request failed")
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown
        }
    }
}

enum APIEndpoint {
    case login
    case signup
    case me
    case wishlists
    case wishlist(id: String)
    case createWishlist
    case addItem(wishlistId: String)
    case updateItem(wishlistId: String, itemId: String)
    case deleteItem(wishlistId: String, itemId: String)
    case resolveItem
    case shareToken(token: String)
    case follow(token: String)
    case unfollow(wishlistId: String)
    case sharedWishlists
    case updateProfile

    var path: String { /* ... */ }
    var method: HTTPMethod { /* ... */ }
}
```

---

## Localization

Support English and Russian:

```swift
// Localizable.strings (en)
"wishlists.title" = "My Wishlists";
"wishlists.empty" = "No wishlists yet";
"wishlists.create" = "Create Wishlist";
"item.add" = "Add Item";
"item.bought" = "Bought";
"item.markBought" = "Mark as Bought";
"share.title" = "Share Wishlist";
"share.copyLink" = "Copy Link";
"profile.title" = "Profile";
"settings.language" = "Language";
"offline.banner" = "You're offline";
"sync.pending" = "Syncing...";

// Localizable.strings (ru)
"wishlists.title" = "Мои списки";
"wishlists.empty" = "Нет списков";
"wishlists.create" = "Создать список";
// ... etc
```

Use `String(localized:)` or `LocalizedStringKey`:

```swift
Text("wishlists.title")
```

---

## Testing Strategy

### Unit Tests
- Test ViewModels business logic
- Test SyncEngine operations
- Test API response parsing
- Test offline queue management

### UI Tests
- Test critical user flows
- Test offline mode behavior
- Test deep link handling

### Test Targets
```
WishWithMeTests/
├── ViewModelTests/
├── SyncEngineTests/
├── APIClientTests/
└── ModelTests/

WishWithMeUITests/
├── AuthFlowTests/
├── WishlistFlowTests/
└── OfflineTests/
```

---

## Build Configuration

### Xcode Project Settings
- Deployment Target: iOS 16.0
- Swift Language Version: 5.9
- Enable Strict Concurrency Checking

### Schemes
- **Debug**: Local API, verbose logging
- **Release**: Production API, crash reporting

### Info.plist Keys
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>wishwithme</string>
        </array>
    </dict>
</array>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
</array>
```

### Associated Domains (for Universal Links)
```
applinks:wishwith.me
```

---

## Development Workflow

### Phase 1: Foundation
1. Set up Xcode project with SwiftUI
2. Implement data models with SwiftData
3. Create APIClient with basic endpoints
4. Implement AuthManager with Keychain storage
5. Create basic navigation structure

### Phase 2: Core Features
1. Implement authentication views and flow
2. Build wishlist CRUD operations
3. Build item management
4. Implement pull-to-refresh

### Phase 3: Offline Support
1. Implement NetworkMonitor
2. Build SyncEngine with operation queue
3. Add offline indicators to UI
4. Test offline scenarios thoroughly

### Phase 4: Sharing & Polish
1. Implement sharing with QR codes
2. Add deep link handling
3. Implement localization
4. Add accessibility support
5. Polish animations and transitions

### Phase 5: Testing & Release
1. Write unit and UI tests
2. Test on multiple devices
3. Performance optimization
4. App Store submission

---

## Agent Usage

When implementing this app, use these specialized agents:

- **mobile-dev**: For React Native/cross-platform questions (if needed)
- **frontend-dev**: For SwiftUI component patterns
- **backend-dev**: For API integration questions
- **ui-ux-designer**: For design system decisions
- **qa**: For testing strategy
- **security**: For auth and data protection review

---

## Important Notes

1. **Never store tokens in UserDefaults** - use Keychain only
2. **Always handle network errors gracefully** - show retry options
3. **Support iOS Dark Mode** - use semantic colors
4. **Test on real devices** - simulator misses many issues
5. **Follow App Store guidelines** - especially for OAuth
6. **Implement proper error logging** - consider Crashlytics or similar

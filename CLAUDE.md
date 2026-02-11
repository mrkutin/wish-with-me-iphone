# CLAUDE.md — Wish With Me iPhone App

## Project Overview

Native iOS (Swift/SwiftUI) client for the **Wish With Me** platform (wishwith.me).
Replicates every screen, flow, and feature of the existing Vue 3 + Quasar PWA.
Talks to the **same backend** (core-api, CouchDB, item-resolver) — no API changes needed.

| Layer | Choice | Why |
|---|---|---|
| Language | Swift 5.10+ | Modern concurrency (async/await, actors) |
| UI | SwiftUI (iOS 17+) | Declarative, fast iteration, native feel |
| Networking | URLSession + async/await | No third-party dependency needed |
| Local DB | SwiftData (backed by SQLite) | Apple-native offline store, replaces PouchDB role |
| Auth tokens | Keychain (via Security framework) | Secure credential storage |
| Images | AsyncImage + NSCache | Lightweight, no Kingfisher/SDWebImage needed initially |
| i18n | String Catalogs (.xcstrings) | Native Xcode localization (en, ru) |
| Testing | XCTest + Swift Testing | Unit + UI tests |
| CI | xcodebuild CLI | Claude Code can build & test from terminal |

**Target**: iOS 17.0+, iPhone only (no iPad), portrait primary.

---

## Source PWA Reference

Repository: https://github.com/mrkutin/wish-with-me-codex
Live: https://wishwith.me | API: https://api.wishwith.me

The PWA codebase is the **single source of truth** for features, flows, and business logic.
When in doubt, read the PWA source at `~/wish-with-me-codex/`.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  SwiftUI Views (Screens + Components)           │
├─────────────────────────────────────────────────┤
│  ViewModels (@Observable)                       │
├──────────────────┬──────────────────────────────┤
│  SyncEngine      │  AuthManager                 │
│  (@MainActor     │  (JWT, OAuth,                │
│   @Observable)   │   Keychain)                  │
├──────────────────┼──────────────────────────────┤
│  LocalStore      │  APIClient                   │
│  (SwiftData)     │  (URLSession)                │
├──────────────────┴──────────────────────────────┤
│  Models (@Model) + DTOs (Codable structs)       │
└─────────────────────────────────────────────────┘
```

**Important architectural pattern**: Each model has TWO types:
1. `@Model final class Foo` — SwiftData persistence only, NOT Codable
2. `struct FooDTO: Codable` — JSON encoding/decoding only, NOT persisted

Conversion happens via `init(from dto:)` and `toDTO()` methods on the `@Model` class.
This avoids known conflicts between SwiftData's `@Model` macro and `Codable` synthesis.

### Key Principle: Offline-First

The app must work without internet. All reads come from SwiftData.
Writes go to SwiftData first, then sync to server when online.
This mirrors the PWA's PouchDB → CouchDB sync pattern.

---

## Project Structure

```
WishWithMe/
├── App/
│   ├── WishWithMeApp.swift          # @main entry, dependency injection, deep link handling
│   └── ContentView.swift            # Root navigation (auth gate)
├── Models/
│   ├── User.swift                   # UserDoc — @Model + UserDTO (Codable)
│   ├── Wishlist.swift               # WishlistDoc — @Model + WishlistDTO
│   ├── Item.swift                   # ItemDoc — @Model + ItemDTO
│   ├── Mark.swift                   # MarkDoc (surprise mode) — @Model + MarkDTO
│   ├── Share.swift                  # ShareDoc — @Model + ShareDTO
│   └── Bookmark.swift               # BookmarkDoc — @Model + BookmarkDTO
├── Services/
│   ├── APIClient.swift              # HTTP client, base URL, headers, error mapping
│   ├── AuthManager.swift            # Login, register, OAuth, JWT refresh
│   ├── SyncEngine.swift             # Push/Pull/Reconcile (@MainActor @Observable class)
│   ├── SyncDTOs.swift               # AnyCodable, push/pull request/response DTOs
│   ├── NetworkMonitor.swift         # NWPathMonitor wrapper
│   ├── OAuthAPI.swift               # APIClient extension for OAuth endpoints
│   └── ShareAPI.swift               # APIClient extension for share endpoints
├── Stores/
│   └── LocalStore.swift             # SwiftData ModelContainer setup + clearAllData
├── ViewModels/
│   ├── WishlistsViewModel.swift
│   ├── WishlistDetailViewModel.swift  # Also handles add-item logic (URL + manual)
│   ├── SharedWishlistViewModel.swift
│   ├── AuthViewModel.swift
│   ├── ProfileViewModel.swift
│   └── ShareViewModel.swift         # Share link CRUD (create, revoke, load)
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Home/
│   │   └── HomeView.swift           # Dashboard with navigation cards
│   ├── Wishlists/
│   │   ├── WishlistsView.swift
│   │   ├── WishlistDetailView.swift
│   │   ├── WishlistRow.swift
│   │   ├── CreateEditWishlistSheet.swift  # Name, description, icon, color picker
│   │   └── BookmarkRow.swift        # Bookmark list entry
│   ├── Items/
│   │   ├── ItemCard.swift
│   │   ├── SharedItemCard.swift
│   │   ├── AddItemSheet.swift
│   │   └── EditItemSheet.swift      # Item editing form
│   ├── Shared/
│   │   ├── SharedWishlistView.swift  # Two modes: shareToken or wishlistId
│   │   ├── SharedBookmarksView.swift # Bookmarked shared wishlists (full tab)
│   │   └── ShareSheet.swift         # Create/revoke links, copy, QR code
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── SettingsView.swift
│   └── Components/
│       ├── MainTabView.swift        # Custom tab container (4 tabs)
│       ├── FloatingTabBar.swift     # Floating tab bar with scroll-to-collapse
│       ├── SyncStatusIndicator.swift
│       ├── OfflineBanner.swift
│       ├── SocialLoginButtons.swift
│       ├── AvatarView.swift         # Base64 decode + initials fallback
│       ├── IconPickerView.swift     # Grid-based icon picker for wishlists
│       ├── ColorPickerView.swift    # Color picker for wishlist icons
│       └── ScrollOffsetTracker.swift # UIViewRepresentable for scroll monitoring
├── Utilities/
│   ├── IDGenerator.swift            # {type}:{uuid} format
│   ├── Constants.swift              # API URLs, timeouts, Keychain keys
│   ├── KeychainHelper.swift         # Secure token storage
│   ├── OAuthSessionHelper.swift     # ASWebAuthenticationSession wrapper
│   ├── HapticManager.swift          # Haptic feedback utility
│   ├── Colors.swift                 # Color extensions with hex init, brandPrimary
│   ├── IconMapper.swift             # Material icon → SF Symbol mapping
│   └── IconColorMapper.swift        # Icon color name → SwiftUI Color mapping
├── Resources/
│   ├── Localizable.xcstrings        # en + ru strings
│   ├── Assets.xcassets
│   ├── Info.plist                   # URL schemes for deep links
│   └── WishWithMe.entitlements      # App entitlements
├── WishWithMeTests/                 # Test target (separate from main target)
│   ├── ModelTests/
│   │   ├── UserModelTests.swift
│   │   └── WishlistModelTests.swift
│   ├── ServiceTests/
│   │   ├── KeychainHelperTests.swift
│   │   └── IDGeneratorTests.swift
│   └── ViewModelTests/
│       └── ProfileViewModelTests.swift
├── WishWithMe.xcodeproj
└── project.yml                      # XcodeGen project definition
```

---

## Data Models

All documents use **type-prefixed IDs**: `{type}:{uuid}`.
All have an `access` array for ACL and `created_at`/`updated_at` timestamps.
Each model is a SwiftData `@Model` class with a companion `Codable` DTO struct (see Architecture section).

All models include these **local-only sync-tracking fields** (not sent to server):
- `isDirty: Bool` — set `true` on local create/update/delete, cleared after successful sync
- `softDeleted: Bool` — marks entity for deletion; `toDTO()` maps this to `_deleted: true`
- `lastSyncedAt: Date?` — timestamp of last successful sync

### User
```swift
@Model final class User {
    @Attribute(.unique) var id: String          // "user:{uuid}"
    var rev: String?
    var email: String
    var name: String
    var avatarBase64: String?
    var bio: String?
    var publicUrlSlug: String?
    var locale: String                          // "ru" | "en"
    var birthday: String?
    var access: [String]
    var createdAt: String
    var updatedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

### Wishlist
```swift
@Model final class Wishlist {
    @Attribute(.unique) var id: String          // "wishlist:{uuid}"
    var rev: String?
    var ownerId: String
    var name: String
    var descriptionText: String?
    var icon: String                            // Material icon name
    var iconColor: String?                      // Icon tint color
    var isPublic: Bool
    var access: [String]
    var createdAt: String
    var updatedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

### Item
```swift
@Model final class Item {
    @Attribute(.unique) var id: String          // "item:{uuid}"
    var rev: String?
    var wishlistId: String
    var ownerId: String
    var title: String
    var descriptionText: String?
    var price: Double?
    var currency: String?
    var quantity: Int
    var sourceUrl: String?
    var imageUrl: String?
    var imageBase64: String?
    var status: String                          // "pending" | "resolved" | "error"
    var resolveConfidence: Double?
    var resolveError: String?
    var resolvedAt: String?
    var access: [String]
    var createdAt: String
    var updatedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

**Note**: Item and Mark DTOs include defensive Bool-to-Int coercion for `quantity`
to handle a CouchDB JSON quirk where boolean `true` may be stored as quantity.

### Mark (Surprise Mode)
```swift
@Model final class Mark {
    @Attribute(.unique) var id: String          // "mark:{uuid}"
    var rev: String?
    var itemId: String
    var wishlistId: String
    var ownerId: String                         // Wishlist owner — marks HIDDEN from this user
    var markedBy: String                        // User who marked it
    var quantity: Int
    var access: [String]                        // All viewers EXCEPT owner
    var createdAt: String
    var updatedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

### Share
```swift
@Model final class Share {
    @Attribute(.unique) var id: String          // "share:{uuid}"
    var rev: String?
    var wishlistId: String
    var ownerId: String
    var token: String
    var linkType: String                        // "view" | "mark"
    var expiresAt: String?
    var accessCount: Int
    var revoked: Bool
    var grantedUsers: [String]
    var qrCodeBase64: String?                   // QR code image for share link
    var access: [String]
    var createdAt: String
    var updatedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

### Bookmark
```swift
@Model final class Bookmark {
    @Attribute(.unique) var id: String          // "bookmark:{uuid}"
    var rev: String?
    var userId: String
    var shareId: String
    var wishlistId: String?
    var ownerName: String?
    var ownerAvatarBase64: String?
    var wishlistName: String?
    var wishlistIcon: String?
    var wishlistIconColor: String?              // Icon tint color for bookmarked wishlist
    var access: [String]
    var createdAt: String
    var updatedAt: String
    var lastAccessedAt: String
    // Local-only sync tracking
    var isDirty: Bool
    var softDeleted: Bool
    var lastSyncedAt: Date?
}
```

### JSON Coding Strategy

CouchDB uses `snake_case` keys. Swift uses `camelCase`.
All snake_case mapping is handled via **explicit `CodingKeys`** in each DTO struct.
The global `JSONDecoder`/`JSONEncoder` use default settings (no automatic key conversion),
because `convertFromSnakeCase` cannot handle leading-underscore keys like `_id`, `_rev`, `_deleted`.

Each DTO includes CodingKeys for:
- `_id` → `id`
- `_rev` → `rev`
- `_deleted` → `deleted`
- `type` — document type string (e.g. `"wishlist"`)
- All snake_case fields (e.g. `created_at` → `createdAt`, `avatar_base64` → `avatarBase64`)

---

## API Reference

Base URL: `https://api.wishwith.me` (configurable via `Constants.apiBaseURL`)

### Auth (`/api/v2/auth`)

| Method | Path | Auth | Body / Notes |
|--------|------|------|---|
| POST | `/register` | — | `{email, password, name, locale}` → AuthResponse |
| POST | `/login` | — | `{email, password}` → AuthResponse |
| POST | `/refresh` | — | `{refresh_token}` → TokenResponse |
| POST | `/logout` | Bearer | `{refresh_token}` in body |
| GET | `/me` | Bearer | → User |

**AuthResponse**: `{access_token, refresh_token, token_type, user: {...}}`
**TokenResponse**: `{access_token, refresh_token, token_type}`

JWT: access_token expires in 15min, refresh_token in 30 days.
**AuthManager must auto-refresh** when receiving 401.

### OAuth (`/api/v1/oauth`)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/providers` | List available providers |
| GET | `/{provider}/authorize` | Returns redirect URL → open in ASWebAuthenticationSession |
| GET | `/{provider}/callback` | Handles OAuth callback |
| POST | `/{provider}/link/initiate` | Link existing account |
| DELETE | `/{provider}/unlink` | Unlink provider |
| GET | `/connected` | List connected providers |

Providers: `google`, `yandex`
For iOS: use `ASWebAuthenticationSession` to open the authorize URL,
capture the callback redirect, extract tokens.

### Sync (`/api/v2/sync`)

**This is the most critical part of the app.**

| Method | Path | Notes |
|--------|------|-------|
| GET | `/pull/{collection}` | Returns all docs user has access to |
| POST | `/push/{collection}` | Push local changes, LWW conflict resolution |

Collections: `wishlists`, `items`, `marks`, `bookmarks`, `users`, `shares`

#### Sync Algorithm (must match PWA exactly)

```
1. PUSH all collections (local changes → server)
   For each collection (wishlists, items, marks, bookmarks, users, shares):
     - Gather locally modified docs (isDirty == true)
     - POST /push/{collection} with array of docs
     - Server validates ownership + LWW (client_updated_at vs server)
     - Server returns conflicts array; all pushed docs marked clean except conflicts

2. PULL all collections (server → local)
   For each collection:
     - GET /pull/{collection}
     - Server returns all docs where access includes current user
     - Upsert into SwiftData (match by _id, update _rev)

3. RECONCILE
     - For each collection: delete local docs whose _id is NOT in the pull response
     - This handles revoked access, deleted docs, etc.
```

**Push ownership rules:**
- `wishlists` — owner only
- `items` — must have wishlist access
- `marks` — marker only
- `bookmarks` — owner only
- `shares` — owner only

**LWW (Last Write Wins):**
Server compares `client_updated_at` (from pushed doc) vs `server_updated_at`.
If client > server → client wins. Otherwise server wins.

### Share (`/api/v1/wishlists/{wishlist_id}/share`)

| Method | Path | Notes |
|--------|------|-------|
| POST | `/` | Create share link `{link_type: "view" or "mark"}` |
| DELETE | `/{share_id}` | Revoke share |

Share links are listed via sync (`/pull/shares`).

### Shared (`/api/v1/shared`)

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/{token}/grant-access` | Bearer | Grant access to shared wishlist |

After grant-access, the shared wishlist's items/marks become available via sync.

### Item Resolver

Not called directly from the iOS app. Items with `status: "pending"` and a `source_url`
are automatically resolved by the backend item-resolver service.
The iOS app just sets `status: "pending"` when adding URL items and waits for
sync to return the resolved metadata.

---

## API Request/Response Contracts

All DTOs use **explicit `CodingKeys`** — no global `convertFromSnakeCase`. The `JSONDecoder`
and `JSONEncoder` in `APIClient` use default settings.

### Auth DTOs

```swift
// POST /api/v2/auth/login — Request
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// POST /api/v2/auth/register — Request
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    let locale: String
}

// POST /api/v2/auth/refresh — Request
struct RefreshRequest: Codable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// POST /api/v2/auth/logout — Request
struct LogoutRequest: Codable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// POST /api/v2/auth/login, /register — Response
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthUserResponse
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

// POST /api/v2/auth/refresh — Response
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// GET /api/v2/auth/me — Response (also nested in AuthResponse)
// NOTE: Auth endpoints return `id` (no underscore), unlike sync endpoints which return `_id`
struct AuthUserResponse: Codable {
    let id: String          // plain "id", NOT "_id"
    var email: String
    var name: String
    var avatarBase64: String?
    var bio: String?
    var publicUrlSlug: String?
    var socialLinks: SocialLinksResponse?
    var locale: String
    var birthday: String?
    var createdAt: String
    var updatedAt: String
    enum CodingKeys: String, CodingKey {
        case id, email, name
        case avatarBase64 = "avatar_base64"
        case bio
        case publicUrlSlug = "public_url_slug"
        case socialLinks = "social_links"
        case locale, birthday
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Converts to sync-compatible UserDTO (adds "user:" prefix logic, etc.)
    func toUserDTO() -> UserDTO { ... }
}

struct SocialLinksResponse: Codable {
    var instagram: String?
    var telegram: String?
    var vk: String?
    var twitter: String?
    var facebook: String?
}
```

### Sync DTOs

The sync layer uses a **type-erased `AnyCodable`** wrapper for generic document handling.
Push/pull operates on `[[String: AnyCodable]]` dictionaries. Typed DTOs are decoded
from these dictionaries inside `SyncEngine.upsertFromServer()` via `JSONSerialization` round-tripping.

```swift
// Type-erased JSON value wrapper (handles NSNumber/CFBoolean edge cases)
struct AnyCodable: Codable {
    let value: Any?
    // Handles: String, Int, Double, Bool, [AnyCodable], [String: AnyCodable], nil
    // Special care: NSNumber with CFBoolean type → Bool, otherwise → numeric
}

// POST /api/v2/sync/push/{collection} — Request
struct SyncPushRequest: Encodable {
    let documents: [[String: AnyCodable]]
}

// POST /api/v2/sync/push/{collection} — Response
struct SyncPushResponse: Decodable {
    let conflicts: [SyncConflict]    // NOTE: "conflicts" not "accepted"
}

struct SyncConflict: Decodable {
    let documentId: String
    let error: String
    let serverDocument: [String: AnyCodable]?
    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case error
        case serverDocument = "server_document"
    }
}

// GET /api/v2/sync/pull/{collection} — Response
struct SyncPullResponse: Decodable {
    let documents: [[String: AnyCodable]]
}
```

### Share DTOs

```swift
// POST /api/v1/wishlists/{wishlist_id}/share — Request
struct CreateShareRequest: Encodable {
    let linkType: String     // "view" | "mark"
    enum CodingKeys: String, CodingKey {
        case linkType = "link_type"
    }
}

// POST /api/v1/wishlists/{wishlist_id}/share — Response
struct CreateShareResponse: Decodable {
    let id: String
    let wishlistId: String
    let token: String
    let linkType: String
    let expiresAt: String?
    let accessCount: Int
    let createdAt: String
    let shareUrl: String
    let qrCodeBase64: String?
    enum CodingKeys: String, CodingKey {
        case id, token
        case wishlistId = "wishlist_id"
        case linkType = "link_type"
        case expiresAt = "expires_at"
        case accessCount = "access_count"
        case createdAt = "created_at"
        case shareUrl = "share_url"
        case qrCodeBase64 = "qr_code_base64"
    }
}

// POST /api/v1/shared/{token}/grant-access — Response
struct GrantAccessResponse: Decodable {
    let wishlistId: String
    let permissions: [String]     // e.g. ["mark"]
    enum CodingKeys: String, CodingKey {
        case wishlistId = "wishlist_id"
        case permissions
    }
}
```

### OAuth DTOs

```swift
// GET /api/v1/oauth/providers — Response
struct OAuthProvidersResponse: Decodable {
    let providers: [String]
}

// GET /api/v1/oauth/connected — Response
struct ConnectedAccountsResponse: Decodable {
    let accounts: [ConnectedAccount]
    let hasPassword: Bool
    enum CodingKeys: String, CodingKey {
        case accounts
        case hasPassword = "has_password"
    }
}

struct ConnectedAccount: Decodable, Identifiable {
    let provider: String
    let email: String?
    let connectedAt: String?
    var id: String { provider }
    enum CodingKeys: String, CodingKey {
        case provider, email
        case connectedAt = "connected_at"
    }
}

// POST /api/v1/oauth/{provider}/link/initiate — Response
struct OAuthLinkInitiateResponse: Decodable {
    let authorizationUrl: String
    let state: String
    enum CodingKeys: String, CodingKey {
        case authorizationUrl = "authorization_url"
        case state
    }
}

// DELETE /api/v1/oauth/{provider}/unlink — Response
struct OAuthUnlinkResponse: Decodable {
    let message: String
}
```

### Error DTOs

```swift
struct APIErrorResponse: Codable {
    let error: ErrorDetail
    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: String]?
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL, invalidResponse, unauthorized, forbidden
    case notFound, conflict, invalidURLForItem, serverError
    case decodingError(Error), networkError(Error), unknown(String)
}
```

### Model DTOs (Sync Documents)

Each `@Model` class has a companion `Codable` DTO struct. Key conventions:
- `_id` → `id`, `_rev` → `rev`, `_deleted` → `deleted` via CodingKeys
- `type` field with default value per model (e.g. `"user"`, `"wishlist"`)
- `init(from decoder:)` uses `decodeIfPresent` with sensible defaults
- `toDTO()` on `@Model` maps `softDeleted` to `deleted: true` (or `nil` if not deleted)
- Local-only fields (`isDirty`, `softDeleted`, `lastSyncedAt`) are NOT on DTOs
- `quantity` fields (Item, Mark) handle Bool-to-Int coercion for CouchDB quirk

Example — `UserDTO`:
```swift
struct UserDTO: Codable {
    let id: String; var rev: String?; var deleted: Bool?; var type: String = "user"
    let email: String; var name: String; var avatarBase64: String?
    var bio: String?; var publicUrlSlug: String?; var locale: String
    var birthday: String?; var access: [String]
    let createdAt: String; var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id", rev = "_rev", deleted = "_deleted", type
        case email, name, avatarBase64 = "avatar_base64", bio
        case publicUrlSlug = "public_url_slug", locale, birthday, access
        case createdAt = "created_at", updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        rev = try c.decodeIfPresent(String.self, forKey: .rev)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "user"
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        // ... remaining fields use decodeIfPresent with defaults ...
        createdAt = try c.decode(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
    }
}
```

**All DTO CodingKeys** (complete reference):

| DTO | CodingKeys (Swift → JSON) |
|-----|---------------------------|
| `UserDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `email`, `name`, `avatarBase64→"avatar_base64"`, `bio`, `publicUrlSlug→"public_url_slug"`, `locale`, `birthday`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"` |
| `WishlistDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `ownerId→"owner_id"`, `name`, `descriptionText→"description"`, `icon`, `iconColor→"icon_color"`, `isPublic→"is_public"`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"` |
| `ItemDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `wishlistId→"wishlist_id"`, `ownerId→"owner_id"`, `title`, `descriptionText→"description"`, `price`, `currency`, `quantity`, `sourceUrl→"source_url"`, `imageUrl→"image_url"`, `imageBase64→"image_base64"`, `status`, `resolveConfidence→"resolve_confidence"`, `resolveError→"resolve_error"`, `resolvedAt→"resolved_at"`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"` |
| `MarkDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `itemId→"item_id"`, `wishlistId→"wishlist_id"`, `ownerId→"owner_id"`, `markedBy→"marked_by"`, `quantity`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"` |
| `ShareDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `wishlistId→"wishlist_id"`, `ownerId→"owner_id"`, `token`, `linkType→"link_type"`, `expiresAt→"expires_at"`, `accessCount→"access_count"`, `revoked`, `grantedUsers→"granted_users"`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"`, `qrCodeBase64→"qr_code_base64"` |
| `BookmarkDTO` | `id→"_id"`, `rev→"_rev"`, `deleted→"_deleted"`, `type`, `userId→"user_id"`, `shareId→"share_id"`, `wishlistId→"wishlist_id"`, `ownerName→"owner_name"`, `ownerAvatarBase64→"owner_avatar_base64"`, `wishlistName→"wishlist_name"`, `wishlistIcon→"wishlist_icon"`, `wishlistIconColor→"wishlist_icon_color"`, `access`, `createdAt→"created_at"`, `updatedAt→"updated_at"`, `lastAccessedAt→"last_accessed_at"` |

**Note**: `ShareDTO.updatedAt` is `String?` (optional), unlike all other DTOs where it's `String`.
The `Share.init(from dto:)` handles this with `dto.updatedAt ?? dto.createdAt`.

**JSON field name quirk**: `descriptionText` maps to `"description"` (not `"description_text"`)
in all DTOs that have it (Wishlist, Item).

### @Model ↔ DTO Conversion Pattern

Every `@Model` class implements two conversion methods:

**`convenience init(from dto:)`** — Creates a new SwiftData entity from a decoded DTO (used during pull/upsert):

```swift
// Example: Wishlist
convenience init(from dto: WishlistDTO) {
    self.init(
        id: dto.id,
        rev: dto.rev,
        ownerId: dto.ownerId,
        name: dto.name,
        descriptionText: dto.descriptionText,
        icon: dto.icon ?? "card_giftcard",    // Default fallback for optional DTO fields
        iconColor: dto.iconColor,
        isPublic: dto.isPublic,
        access: dto.access,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt
        // isDirty, softDeleted, lastSyncedAt → use init defaults (false, false, nil)
    )
}
```

**`func toDTO()`** — Converts a SwiftData entity to a Codable DTO for push:

```swift
// Example: Wishlist
func toDTO() -> WishlistDTO {
    WishlistDTO(
        id: id,
        rev: rev,
        deleted: softDeleted ? true : nil,   // Map softDeleted → _deleted
        ownerId: ownerId,
        name: name,
        descriptionText: descriptionText,
        icon: icon.isEmpty ? nil : icon,      // Omit empty strings
        iconColor: iconColor,
        isPublic: isPublic,
        access: access,
        createdAt: createdAt,
        updatedAt: updatedAt
    )
}
```

**Key rules:**
- `convenience init(from:)` calls the full designated `init(...)` — sync-tracking fields use defaults
- `toDTO()` maps `softDeleted` → `deleted: true` (or `nil` if not deleted)
- Optional DTO fields with nil values are handled with `?? default` in `init(from:)`
- Empty strings are often converted to `nil` in `toDTO()` (e.g. empty icon)
- `AuthUserResponse.toUserDTO()` is a special case: converts auth endpoint response to `UserDTO`,
  setting `access: [id]` and `rev: nil` (auth endpoints don't return `_rev`)

### DTO Custom Decoder Pattern

All DTOs implement `init(from decoder:)` manually with defensive decoding:

```swift
// Example: WishlistDTO.init(from decoder:)
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)              // Required
    rev = try container.decodeIfPresent(String.self, forKey: .rev)   // Optional
    deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
    type = try container.decodeIfPresent(String.self, forKey: .type) ?? "wishlist"  // Default
    ownerId = try container.decode(String.self, forKey: .ownerId)
    name = try container.decode(String.self, forKey: .name)
    descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText)
    icon = try container.decodeIfPresent(String.self, forKey: .icon)
    iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor)
    isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
    access = try container.decodeIfPresent([String].self, forKey: .access) ?? []
    createdAt = try container.decode(String.self, forKey: .createdAt)
    updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
}
```

**Pattern**: `decodeIfPresent` with `?? default` for fields that may be absent in server JSON.
The `updatedAt ?? createdAt` fallback handles legacy docs that lack `updated_at`.

---

## APIClient Internals

`APIClient` is a `@MainActor` singleton that handles all HTTP communication.

```swift
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let baseURL: String          // from AppConfig.apiBaseURL
    private let session: URLSession      // configured with AppConfig.requestTimeout
    private var authManager: AuthManager? // injected via setAuthManager() after app init

    private init() {
        self.baseURL = AppConfig.apiBaseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.requestTimeout  // 30s
        self.session = URLSession(configuration: config)
    }

    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }
}
```

### Generic Request Method

```swift
func request<T: Decodable>(
    endpoint: String,
    method: String = "GET",
    body: Encodable? = nil,
    requiresAuth: Bool = true
) async throws -> T
```

Internally calls `performRequest<T>()` which:
1. Builds URL from `baseURL + endpoint`
2. Sets `Content-Type: application/json` header
3. If `requiresAuth`: reads access token from Keychain, adds `Authorization: Bearer {token}`
4. Encodes body with `JSONEncoder()` (default settings — no key strategy)
5. On **401 response** (and not already a retry): calls `authManager.refreshToken()`,
   then retries the same request once with `isRetry: true`
6. On **non-2xx response**: attempts to decode `APIErrorResponse` from body, maps to `APIError`
7. On **success**: decodes response body with `JSONDecoder()` (default settings)

### Void Request Method

```swift
func requestVoid(
    endpoint: String,
    method: String = "DELETE",
    body: Encodable? = nil,
    requiresAuth: Bool = true
) async throws
```

Same as `request<T>()` but discards the response body. Used for DELETE operations.

### Error Mapping

Two-tier error mapping: JSON error body first, HTTP status fallback.

```swift
private func mapError(statusCode: Int, errorResponse: APIErrorResponse?) -> APIError {
    // 1. If server returned structured error JSON:
    if let errorResponse = errorResponse {
        switch errorResponse.error.code {
        case "UNAUTHORIZED": return .unauthorized
        case "FORBIDDEN":    return .forbidden
        case "NOT_FOUND":    return .notFound
        case "CONFLICT":     return .conflict
        case "INVALID_URL":  return .invalidURLForItem
        default:             return .unknown(errorResponse.error.message)
        }
    }
    // 2. Fallback to HTTP status code:
    switch statusCode {
    case 401:     return .unauthorized
    case 403:     return .forbidden
    case 404:     return .notFound
    case 409:     return .conflict
    case 422:     return .invalidURLForItem
    case 500...599: return .serverError
    default:      return .unknown("HTTP \(statusCode)")
    }
}
```

### 401 Refresh → Retry Flow

```
Request → 401 → authManager.refreshToken() → Retry (once) → Success or throw
                                                          → 401 again → throw .unauthorized
```

The `isRetry` flag prevents infinite loops. If authManager is nil (not yet injected),
401 throws `.unauthorized` immediately.

---

## Screens & Navigation

```
App Launch
  ├── Not authenticated → LoginView
  │     ├── RegisterView (toggle)
  │     └── OAuth → SocialLoginButtons → OAuthSessionHelper → ASWebAuthenticationSession
  │
  └── Authenticated → MainTabView (custom FloatingTabBar, 4 tabs)
        ├── Tab 1: HomeView (dashboard with navigation cards)
        ├── Tab 2: WishlistsView (my wishlists list)
        │     └── WishlistDetailView (push)
        │           ├── ItemCard (tap → EditItemSheet)
        │           ├── AddItemSheet (sheet: URL or manual)
        │           └── ShareSheet (share link management + QR code)
        ├── Tab 3: SharedBookmarksView (bookmarked shared wishlists)
        │     └── SharedWishlistView (push, via wishlistId)
        │           └── SharedItemCard (with mark capability)
        └── Tab 4: ProfileView
              └── SettingsView (push)
```

**Note**: OAuth callbacks are handled inline by `SocialLoginButtons` + `OAuthSessionHelper`
using `ASWebAuthenticationSession`, not a dedicated `AuthCallbackView`.

The `FloatingTabBar` is a custom component that collapses middle tabs on scroll
(using `ScrollOffsetTracker` to monitor `UIScrollView.contentOffset` via KVO).

`SharedWishlistView` has two initialization modes:
- `shareToken` — for deep link access (`/s/{token}`)
- `wishlistId` — for bookmark navigation (direct access)

### Screen → PWA Page Mapping

| iOS Screen | PWA Page | Route |
|---|---|---|
| LoginView / RegisterView | LoginPage / RegisterPage | /login, /register |
| HomeView | (no direct equivalent) | — |
| WishlistsView | WishlistsPage | /wishlists |
| WishlistDetailView | WishlistDetailPage | /wishlists/:id |
| SharedBookmarksView | (bookmarks section in PWA) | — |
| SharedWishlistView | SharedWishlistPage | /s/:token |
| ProfileView | ProfilePage | /profile |
| SettingsView | SettingsPage | /settings |

### Deep Links

The app handles these URL patterns (via `.onOpenURL` in `WishWithMeApp.swift`):
- `wishwithme://s/{token}` → SharedWishlistView (custom scheme)
- `https://wishwith.me/s/{token}` → SharedWishlistView (universal link)

**Not yet implemented**: `https://wishwith.me/shared/wishlist/{wishlistId}` pattern.

**Note**: Universal links (`https://wishwith.me/...`) require an Associated Domains entitlement
(`applinks:wishwith.me`) which is not currently in `WishWithMe.entitlements`. Only the custom
scheme (`wishwithme://`) works for deep linking until Associated Domains is configured.

Deep links are deferred if user is not authenticated (`pendingShareToken` mechanism).

---

## Key Features to Implement

### 1. Offline-First Data
- All reads from SwiftData
- Writes to SwiftData immediately, sync in background
- SyncStatusIndicator shows current state (idle/syncing/error/offline)
- OfflineBanner appears when no network
- NetworkMonitor uses NWPathMonitor

### 2. Wishlist Management
- Create, edit, delete wishlists (via `CreateEditWishlistSheet`)
- Icon picker (`IconPickerView` — grid-based, Material → SF Symbols via `IconMapper`)
- Icon color picker (`ColorPickerView` — tint color via `IconColorMapper`)
- Wishlist description
- **Note**: Public/private toggle (`isPublic` field) exists in the model but is not currently exposed in the UI

### 3. Item Management
- **Add by URL**: Paste URL → create item with status "pending" → sync → server resolves
- **Add manually**: Title, description, price, currency, quantity, optional photo
- Edit item details
- Delete item
- Show resolution status (pending spinner, resolved, error)
- Display item image (from image_base64 or image_url)

### 4. Surprise Mode (Marks)
- When viewing someone else's wishlist: can "mark" items ("I'll get this")
- Marks are HIDDEN from the wishlist owner
- Mark quantity tracking
- Access array excludes owner — enforced by server, client must not show marks to owner

### 5. Sharing
- Create share links (view-only or mark permission) via `ShareViewModel`
- Copy link to clipboard
- QR code generation for share links (via `CIFilter.qrCodeGenerator()`)
- Share via iOS share sheet (UIActivityViewController)
- Revoke share links
- Accept shared wishlist via deep link → grant-access → bookmark

### 6. Bookmarks
- Save shared wishlists as bookmarks
- Dedicated `SharedBookmarksView` tab (not a section — full tab in FloatingTabBar)
- `BookmarkRow` component for list entries
- Cache owner info for offline display

### 7. Authentication
- Email/password register & login
- OAuth via Google and Yandex (ASWebAuthenticationSession)
- Auto-refresh JWT on 401
- Secure token storage in Keychain
- Logout (revoke refresh token)

### 8. Profile
- Edit name, bio, avatar (base64 photo)
- Birthday, locale (ru/en)
- Public URL slug
- Connected OAuth providers

### 9. Localization
- English and Russian
- Use String Catalogs (.xcstrings)
- Locale synced with server user profile
- Reference PWA i18n files: `~/wish-with-me-codex/services/frontend/src/i18n/en/` and `/ru/`

### 10. Pull-to-Refresh
- All list views support pull-to-refresh triggering full sync cycle

---

## Sync Engine Design

This is the **hardest and most important** part. Get this right first.

### Class Structure

```swift
@MainActor
@Observable
final class SyncEngine {
    enum SyncState: Equatable { case idle, syncing, error(String), offline }

    var state: SyncState = .idle

    private let apiClient: APIClient
    private let modelContainer: ModelContainer
    private let networkMonitor: NetworkMonitor
    private var failedPushDocIds: Set<String> = []

    private var syncTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    private static let debounceInterval: TimeInterval = 1.0
    private static let periodicInterval: TimeInterval = 30.0

    private let pushCollections = ["wishlists", "items", "marks", "bookmarks", "users", "shares"]
    private let pullCollections = ["wishlists", "items", "marks", "bookmarks", "users", "shares"]

    // Gets ModelContext from ModelContainer's mainContext (not creating a new one)
    private var mainContext: ModelContext { modelContainer.mainContext }

    init(apiClient: APIClient, modelContainer: ModelContainer, networkMonitor: NetworkMonitor) { ... }
}
```

### fullSync()

```swift
func fullSync() async {
    guard networkMonitor.isConnected else { state = .offline; return }
    state = .syncing
    do {
        try await pushAll()
        try await pullAndReconcileAll()   // pull + reconcile in one method
        state = .idle
    } catch {
        if error is CancellationError { return }
        state = .error(error.localizedDescription)
    }
}
```

### triggerSync() — Debounced Fire-and-Forget

```swift
func triggerSync() {
    syncTask?.cancel()                     // cancel any pending debounced sync
    syncTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(Self.debounceInterval))  // 1s debounce
        guard !Task.isCancelled else { return }
        await self?.fullSync()
    }
}
```

### startPeriodicSync() / stopSync()

```swift
func startPeriodicSync() {
    periodicTask?.cancel()
    periodicTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.periodicInterval))  // 30s
            guard !Task.isCancelled else { return }
            await self?.fullSync()
        }
    }
}

func stopSync() {
    periodicTask?.cancel()
    syncTask?.cancel()
}
```

### Sync Triggers (wired in WishWithMeApp.swift)
- App foreground (`scenePhase == .active`)
- Pull-to-refresh (calls `fullSync()` directly)
- After any local write (via `triggerSync()` — debounced **1-second** delay)
- Network restored (from offline → online)
- Periodic (every **30 seconds** when active)
- Auth state change (`isAuthenticated` → `fullSync()` + `startPeriodicSync()`)

### pushAll() — Gather Dirty Docs and Send

```swift
private func pushAll() async throws {
    failedPushDocIds = []
    let context = mainContext

    for collection in pushCollections {
        // 1. Gather dirty docs → convert @Model → DTO → [String: AnyCodable] dict
        let dirtyDTOs = try getDirtyDTOs(collection: collection, context: context)
        if dirtyDTOs.isEmpty { continue }

        // 2. Send to server
        let request = SyncPushRequest(documents: dirtyDTOs)
        let response: SyncPushResponse = try await apiClient.request(
            endpoint: "/api/v2/sync/push/\(collection)", method: "POST", body: request
        )

        // 3. Track conflicts; mark non-conflicting docs as clean
        let conflictIds = Set(response.conflicts.map(\.documentId))
        for conflict in response.conflicts {
            if conflict.serverDocument == nil { failedPushDocIds.insert(conflict.documentId) }
        }
        try markClean(collection: collection, excludeIds: conflictIds, context: context)
    }
    try context.save()
}
```

**getDirtyDTOs()** pattern (repeated per collection via switch):
```swift
// For each collection (e.g. "wishlists"):
let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.isDirty })
let wishlists = try context.fetch(descriptor)
dtos = try wishlists.map { try dtoToDict($0.toDTO()) }
```

**dtoToDict() — DTO → [String: AnyCodable] round-trip:**
```swift
private func dtoToDict<T: Encodable>(_ dto: T) throws -> [String: AnyCodable] {
    let data = try JSONEncoder().encode(dto)                  // DTO → JSON Data
    let jsonObject = try JSONSerialization.jsonObject(with: data)  // JSON Data → Any
    guard let dict = jsonObject as? [String: Any] else { throw ... }
    return dict.mapValues { AnyCodable($0) }                  // [String: Any] → [String: AnyCodable]
}
```

### pullAndReconcileAll() — Pull + Upsert + Reconcile

```swift
private func pullAndReconcileAll() async throws {
    let context = mainContext
    var pulledIds: [String: Set<String>] = [:]

    // PULL phase
    for collection in pullCollections {
        let response: SyncPullResponse = try await apiClient.request(
            endpoint: "/api/v2/sync/pull/\(collection)", method: "GET"
        )
        let serverIds = Set(response.documents.compactMap { ($0["_id"]?.value as? String) })

        for docDict in response.documents {
            do {
                try upsertFromServer(collection: collection, docDict: docDict, context: context)
            } catch {
                continue  // skip bad docs, don't fail entire sync
            }
        }
        pulledIds[collection] = serverIds
    }
    try context.save()

    // RECONCILE phase — delete orphans, protecting dirty and failed-push docs
    for (collection, serverIds) in pulledIds {
        let localIds = try getAllLocalIds(collection: collection, context: context)
        let dirtyIds = try getDirtyLocalIds(collection: collection, context: context)
        let orphans = localIds
            .subtracting(serverIds)        // not on server
            .subtracting(failedPushDocIds)  // failed push — keep locally
            .subtracting(dirtyIds)          // dirty — keep locally
        for orphanId in orphans {
            try deleteLocal(id: orphanId, collection: collection, context: context)
        }
    }
    try context.save()
}
```

### upsertFromServer() — [String: AnyCodable] → DTO → @Model

This is the key conversion method. Per collection via switch:

```swift
private func upsertFromServer(collection: String, docDict: [String: AnyCodable], context: ModelContext) throws {
    guard let id = docDict["_id"]?.value as? String else { return }

    // Round-trip: [String: AnyCodable] → [String: Any] → JSON Data → typed DTO
    let jsonData = try JSONSerialization.data(withJSONObject: docDict.mapValues(\.value))

    switch collection {
    case "wishlists":
        let dto = try JSONDecoder().decode(WishlistDTO.self, from: jsonData)
        let descriptor = FetchDescriptor<Wishlist>(predicate: #Predicate { $0.id == id })

        if let existing = try context.fetch(descriptor).first {
            guard !existing.isDirty else { return }  // SKIP if dirty (push-first protocol)
            // Update all mutable fields from DTO:
            existing.rev = dto.rev
            existing.name = dto.name
            existing.descriptionText = dto.descriptionText
            existing.icon = dto.icon ?? existing.icon
            existing.iconColor = dto.iconColor
            existing.isPublic = dto.isPublic
            existing.access = dto.access
            existing.updatedAt = dto.updatedAt
            existing.isDirty = false
            existing.lastSyncedAt = Date()
        } else {
            context.insert(Wishlist(from: dto))  // New doc — create @Model from DTO
        }
    case "items": // ... same pattern with ItemDTO fields ...
    case "marks": // ... same pattern with MarkDTO fields ...
    case "bookmarks": // ... same pattern with BookmarkDTO fields ...
    case "users": // ... same pattern with UserDTO fields ...
    case "shares": // ... same pattern with ShareDTO fields ...
    }
}
```

**Key upsert rules:**
- **Existing + dirty → SKIP** (push-first protocol: local changes take priority)
- **Existing + clean → UPDATE** all mutable fields, set `isDirty = false`, `lastSyncedAt = Date()`
- **New doc → INSERT** using `@Model.init(from: DTO)` convenience initializer
- **Decode errors → skip and continue** (don't fail entire sync for one bad doc)

### Dirty Tracking
Each SwiftData model has an `isDirty: Bool` flag (not synced to server).
Set `isDirty = true` on any local create/update/delete.
Clear after successful push (via `markClean`) and during upsert.

### Soft Delete
Entities are marked `softDeleted = true` rather than being removed from SwiftData.
The `toDTO()` method maps `softDeleted` to `_deleted: true` for the server push.
Reconciliation removes orphaned local docs whose `_id` is not in the pull response,
but **protects dirty docs and failed-push docs** from deletion.

---

## Data Flow Patterns

### View → ViewModel Creation

ViewModels use a **lazy `@State` optional pattern** with deferred `onAppear` initialization:

```swift
struct WishlistsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    let syncEngine: SyncEngine?              // constructor injection, NOT @Environment

    @State private var viewModel: WishlistsViewModel?  // optional @State

    var body: some View {
        Group {
            if let viewModel = viewModel {
                wishlistContent(viewModel: viewModel)
            } else {
                ProgressView()               // shown until ViewModel is created
            }
        }
        .onAppear {
            if viewModel == nil {            // guard: create only once
                viewModel = WishlistsViewModel(
                    modelContext: modelContext,
                    syncEngine: syncEngine,
                    authManager: authManager
                )
            }
            viewModel?.syncEngine = syncEngine   // always refresh
            viewModel?.loadWishlists()           // always reload
        }
        .onChange(of: syncEngine?.state) { _, newState in
            viewModel?.syncEngine = syncEngine
            if newState == .idle {
                viewModel?.loadWishlists()   // reload when sync completes
            }
        }
    }
}
```

**Rules**:
- ViewModel is `@State private var viewModel: SomeViewModel?` (optional)
- Created in `onAppear`, guarded by `if viewModel == nil`
- `syncEngine` is always re-assigned on appear AND in `onChange(of: syncEngine?.state)`
- Data load method is called on every appear (not just first)

### ViewModel → SwiftData

ViewModels are `@MainActor @Observable final class` with a stored `ModelContext`.
All data access uses **`FetchDescriptor`** — there are NO `@Query` wrappers anywhere.

```swift
@MainActor @Observable final class WishlistsViewModel {
    var wishlists: [Wishlist] = []
    private let modelContext: ModelContext

    func loadWishlists() {
        guard let userId = authManager.currentUser?.id else { return }
        let descriptor = FetchDescriptor<Wishlist>(
            predicate: #Predicate<Wishlist> { $0.ownerId == userId && $0.softDeleted == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        wishlists = try modelContext.fetch(descriptor)
    }
}
```

**FetchDescriptor conventions**:
- Always filter `softDeleted == false` for user-facing queries
- Ownership queries: filter by `ownerId == userId`
- Relation queries: filter by foreign key (e.g. `item.wishlistId == wId`)
- Sort by `\.updatedAt` descending for "most recent first"
- Count queries use `modelContext.fetchCount(descriptor)`

### Write Pattern (4-Step Sequence)

**Every write** follows the same pattern:

```swift
func createWishlist(name: String, ...) {
    // 1. Mutate/insert (set isDirty = true, update updatedAt)
    let wishlist = Wishlist(id: IDGenerator.create(type: "wishlist"), ..., isDirty: true)
    modelContext.insert(wishlist)

    // 2. Explicit save
    try modelContext.save()

    // 3. Reload data
    loadWishlists()

    // 4. Trigger background sync
    syncEngine?.triggerSync()
}
```

### Dependency Injection Map

| Dependency | Injection Method | Passed via |
|---|---|---|
| `AuthManager` | `@Environment(AuthManager.self)` | `.environment(authManager)` on root view |
| `NetworkMonitor` | `@Environment(NetworkMonitor.self)` | `.environment(networkMonitor)` on root view |
| `ModelContext` | `@Environment(\.modelContext)` | `.modelContainer(...)` on root view |
| `SyncEngine` | `let` constructor parameter | Passed down every View's `init` |
| `APIClient` | Singleton `APIClient.shared` | Direct access, no injection |
| `OAuthSessionHelper` | Singleton `OAuthSessionHelper.shared` | Direct access, no injection |
| `LocalStore` | Singleton `LocalStore.shared` | Used only in `WishWithMeApp` |
| `KeychainHelper` | Static methods | Direct access, no injection |

**Why SyncEngine uses constructor injection**: It is created asynchronously after auth loads
and may be `nil` during app startup. All Views declare it as `let syncEngine: SyncEngine?`
and all ViewModels declare it as `var syncEngine: SyncEngine?` (mutable, reassigned from Views).

### Cross-View Communication

One `NotificationCenter` notification exists for cross-view updates:

```swift
// Defined in WishlistDetailViewModel.swift
extension Notification.Name {
    static let itemsDidChange = Notification.Name("itemsDidChange")
}

// Posted after every item create/update/delete
NotificationCenter.default.post(name: .itemsDidChange, object: nil)

// Received in WishlistsView to refresh item count badges
.onReceive(NotificationCenter.default.publisher(for: .itemsDidChange)) { _ in
    viewModel?.refreshItemCounts()
}
```

---

## Auth Flow

```
┌─────────────┐     ┌─────────────────────┐
│  LoginView   │────►│ POST /auth/login    │
│  (email/pwd) │     │ → tokens + user     │
└─────────────┘     └────────┬────────────┘
                             │
                    ┌────────▼────────────┐
                    │ Store in Keychain:   │
                    │  access_token        │
                    │  refresh_token       │
                    │ Store User in        │
                    │  SwiftData           │
                    └────────┬────────────┘
                             │
                    ┌────────▼────────────┐
                    │ Navigate to          │
                    │ WishlistsView        │
                    │ Trigger fullSync()   │
                    └─────────────────────┘

On 401 from any API call:
  → AuthManager.refreshToken()
  → POST /auth/refresh {refresh_token}
  → Update Keychain
  → Retry original request (once)
  → If refresh fails → logout → LoginView
```

### OAuth Flow (Google / Yandex)

Uses `OAuthSessionHelper` — a `@MainActor` singleton wrapping `ASWebAuthenticationSession`
with async/await via `withCheckedThrowingContinuation`.

**Constants**:
- Callback scheme: `"wishwithme"`
- Callback URL: `"wishwithme://auth/callback"`

**Complete flow** (implemented in `SocialLoginButtons.swift`):

```swift
// 1. Build authorize URL (synchronous — no network call)
//    → https://api.wishwith.me/api/v1/oauth/{provider}/authorize?callback_url=wishwithme://auth/callback
guard let authURL = APIClient.shared.getOAuthAuthorizeURL(provider: "google") else { return }

// 2. Open ASWebAuthenticationSession (async, shows system browser sheet)
let callbackURL = try await OAuthSessionHelper.shared.openSession(url: authURL)
// OAuthSessionHelper uses:
//   - callbackURLScheme: "wishwithme"
//   - prefersEphemeralWebBrowserSession: false (preserves login state)

// 3. Extract tokens from callback URL query parameters
//    Server redirects to: wishwithme://auth/callback?access_token=...&refresh_token=...
//    Or on error:         wishwithme://auth/callback?error=email_exists
let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
let params = components?.queryItems ?? []

if let accessToken = params.first(where: { $0.name == "access_token" })?.value,
   let refreshToken = params.first(where: { $0.name == "refresh_token" })?.value {
    // 4. Save tokens to Keychain, fetch user profile via GET /auth/me
    try await authManager.handleOAuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    // → Sets isAuthenticated = true, navigates to main app
} else if let error = params.first(where: { $0.name == "error" })?.value {
    // Handle errors (e.g. "email_exists" — account already linked to different provider)
}
```

**Linking an existing account** (different from login):
```swift
// Uses POST /api/v1/oauth/{provider}/link/initiate → returns { authorization_url, state }
let response = try await APIClient.shared.initiateOAuthLink(provider: "google")
let callbackURL = try await OAuthSessionHelper.shared.openSession(url: URL(string: response.authorizationUrl)!)
// Callback returns: wishwithme://auth/callback?linked=google (or ?error=...)
```

### AuthManager Implementation

`AuthManager` is a `@MainActor @Observable` class that manages authentication state.
It holds `isAuthenticated`, `currentUser`, and `isLoading` observable properties.

```swift
@MainActor
@Observable
final class AuthManager {
    var isAuthenticated: Bool = false
    var currentUser: UserDTO?           // NOTE: UserDTO, not @Model User
    var isLoading: Bool = false

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        apiClient.setAuthManager(self)   // Wire circular dependency
    }
}
```

**Method implementations:**

**`loadStoredAuth()`** — Called once at app launch. Checks Keychain for stored token, validates with server:
```swift
func loadStoredAuth() async {
    if let accessToken = try KeychainHelper.read(key: AppConfig.accessTokenKey),
       !accessToken.isEmpty {
        let authUser: AuthUserResponse = try await apiClient.request(
            endpoint: "/api/v2/auth/me", method: "GET", requiresAuth: true
        )
        currentUser = authUser.toUserDTO()
        isAuthenticated = true
    }
    // On ANY error: clear Keychain, set isAuthenticated = false
}
```

**`login(email:password:)`** — Email/password login:
```swift
func login(email: String, password: String) async throws {
    isLoading = true; defer { isLoading = false }
    let response: AuthResponse = try await apiClient.request(
        endpoint: "/api/v2/auth/login", method: "POST",
        body: LoginRequest(email: email, password: password), requiresAuth: false
    )
    try KeychainHelper.save(key: AppConfig.accessTokenKey, value: response.accessToken)
    try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: response.refreshToken)
    currentUser = response.user.toUserDTO()
    isAuthenticated = true
}
```

**`register(email:password:name:locale:)`** — Same pattern as login with RegisterRequest.

**`refreshToken()`** — Called by APIClient on 401. Does NOT set isLoading (silent refresh):
```swift
func refreshToken() async throws {
    guard let refreshToken = try KeychainHelper.read(key: AppConfig.refreshTokenKey) else {
        throw APIError.unauthorized
    }
    let response: TokenResponse = try await apiClient.request(
        endpoint: "/api/v2/auth/refresh", method: "POST",
        body: RefreshRequest(refreshToken: refreshToken), requiresAuth: false
    )
    try KeychainHelper.save(key: AppConfig.accessTokenKey, value: response.accessToken)
    try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: response.refreshToken)
}
```

**`handleOAuthTokens(accessToken:refreshToken:)`** — Called after OAuth callback:
```swift
func handleOAuthTokens(accessToken: String, refreshToken: String) async throws {
    isLoading = true; defer { isLoading = false }
    try KeychainHelper.save(key: AppConfig.accessTokenKey, value: accessToken)
    try KeychainHelper.save(key: AppConfig.refreshTokenKey, value: refreshToken)
    let authUser: AuthUserResponse = try await apiClient.request(
        endpoint: "/api/v2/auth/me", method: "GET", requiresAuth: true
    )
    currentUser = authUser.toUserDTO()
    isAuthenticated = true
}
```

**`logout()`** — Revokes refresh token server-side, clears Keychain. Errors are silenced (`try?`):
```swift
func logout() async throws {
    isLoading = true; defer { isLoading = false }
    if let refreshToken = try? KeychainHelper.read(key: AppConfig.refreshTokenKey) {
        let _: EmptyResponse? = try? await apiClient.request(
            endpoint: "/api/v2/auth/logout", method: "POST",
            body: LogoutRequest(refreshToken: refreshToken), requiresAuth: true
        )
    }
    try? KeychainHelper.delete(key: AppConfig.accessTokenKey)
    try? KeychainHelper.delete(key: AppConfig.refreshTokenKey)
    isAuthenticated = false
    currentUser = nil
}
```

**Key points:**
- `currentUser` is `UserDTO?` (not `@Model User`) — it's a lightweight in-memory value
- `logout()` uses `try?` for both the API call and Keychain cleanup — must always succeed
- `refreshToken()` is the only method that does NOT set `isLoading` (called silently by APIClient)
- `loadStoredAuth()` on failure clears everything and leaves user logged out (no crash)
- The `apiClient.setAuthManager(self)` call in `init()` creates the circular dependency needed
  for the APIClient → 401 → AuthManager.refreshToken() → retry flow

---

## ID Generation

Match the PWA pattern exactly:

```swift
enum IDGenerator {
    static func create(type: String) -> String {
        "\(type):\(UUID().uuidString.lowercased())"
    }

    static func extractUUID(_ docId: String) -> String {
        let parts = docId.split(separator: ":")
        return parts.count > 1 ? String(parts[1]) : docId
    }

    static func extractType(_ docId: String) -> String? {
        let parts = docId.split(separator: ":")
        return parts.count > 1 ? String(parts[0]) : nil
    }
}
```

Types: `user`, `wishlist`, `item`, `mark`, `share`, `bookmark`

---

## Error Handling

Match the API error format:

```json
{"error": {"code": "ERROR_CODE", "message": "...", "details": {}}}
```

| Code | HTTP | Meaning |
|------|------|---------|
| BAD_REQUEST | 400 | Invalid input |
| UNAUTHORIZED | 401 | Not authenticated / token expired |
| FORBIDDEN | 403 | No access to resource |
| NOT_FOUND | 404 | Resource not found |
| CONFLICT | 409 | Sync conflict (LWW should handle) |
| INVALID_URL | 422 | Bad URL for item resolution |
| INTERNAL_ERROR | 500 | Server error |

---

## Business Rules

### Cascade Delete

When deleting a wishlist, the client **must also soft-delete all items** in that wishlist:

```swift
func deleteWishlist(_ wishlist: Wishlist) {
    let now = ISO8601DateFormatter().string(from: Date())
    wishlist.softDeleted = true
    wishlist.isDirty = true
    wishlist.updatedAt = now

    // Cascade: soft-delete ALL items in this wishlist
    let wId = wishlist.id
    let itemDescriptor = FetchDescriptor<Item>(
        predicate: #Predicate<Item> { $0.wishlistId == wId && $0.softDeleted == false }
    )
    for item in try modelContext.fetch(itemDescriptor) {
        item.softDeleted = true
        item.isDirty = true
        item.updatedAt = now
    }
    try modelContext.save()
    syncEngine?.triggerSync()
}
```

**Marks and shares are NOT explicitly cascaded** by the client. They are orphaned and cleaned
up by reconciliation during the next sync (server removes them from access arrays).

### Bookmark Creation

Bookmarks are **created server-side** during `grant-access`, NOT by the client.
The flow is:
1. Client calls `POST /api/v1/shared/{token}/grant-access`
2. Server creates a Bookmark document and adds user to wishlist's access array
3. Client calls `fullSync()` — bookmark arrives via `GET /api/v2/sync/pull/bookmarks`
4. Client finds bookmark in local SwiftData for display

### Access Array Construction

| Collection | Access Array Value | Rule |
|---|---|---|
| Wishlists | `[ownerId]` | Only the owner |
| Items | Inherited from parent wishlist | `wishlist.access` (or `[ownerId]` as fallback) |
| Marks | Wishlist access **minus** owner | `wishlist.access.filter { $0 != wishlist.ownerId }` |
| Shares | `[ownerId]` | Only the owner |
| Bookmarks | `[userId]` | Only the bookmark owner |

The Mark access array **must exclude the wishlist owner** — this is the core mechanism
for surprise mode. Both client and server enforce this, as defense-in-depth.

### Surprise Mode (Client-Side Defense)

Even if marks somehow exist locally for the owner, the client never displays them:

```swift
// In WishlistDetailViewModel.loadData():
if !isOwner {
    let markDescriptor = FetchDescriptor<Mark>(...)
    marks = try modelContext.fetch(markDescriptor)
} else {
    marks = []   // Owner NEVER sees marks
}
```

---

## Icon Mapping

The PWA uses Material Design icon names. `IconMapper.materialToSFSymbol()` maps them:

| PWA Icon | SF Symbol |
|----------|-----------|
| card_giftcard | gift |
| checklist | checklist |
| celebration | party.popper |
| cake | birthday.cake |
| favorite | heart.fill |
| star | star.fill |
| redeem | giftcard |
| shopping_bag | bag.fill |
| shopping_cart | cart.fill |
| home | house.fill |
| flight | airplane |
| child_care | figure.and.child.holdinghands |
| pets | pawprint.fill |
| devices | laptopcomputer |
| checkroom | tshirt.fill |
| auto_stories | book.fill |
| sports_esports | gamecontroller.fill |
| palette | paintpalette.fill |
| music_note | music.note |
| restaurant | fork.knife |
| fitness_center | dumbbell.fill |
| photo_camera | camera.fill |
| spa | leaf.fill |
| directions_car | car.fill |
| diamond | sparkles |

**Fallback**: Unknown icons → `"list.bullet"`

### Icon Color Mapping

`IconColorMapper.color(for:)` maps color names to SwiftUI `Color`:

| Name | SwiftUI Color |
|------|---------------|
| `"primary"` | `Color.brandPrimary` (#4F46E5) |
| `"red"` | `.red` |
| `"pink"` | `.pink` |
| `"purple"` | `.purple` |
| `"deep-purple"` | `.indigo` |
| `"indigo"` | `Color(hex: "3F51B5")` |
| `"blue"` | `.blue` |
| `"cyan"` | `.cyan` |
| `"teal"` | `.teal` |
| `"green"` | `.green` |
| `"orange"` | `.orange` |
| `"brown"` | `.brown` |
| `nil` / unknown | `Color.brandPrimary` |

`IconColorMapper.allColors` provides the ordered list for the color picker UI.

---

## Development Phases

**IMPORTANT: This project follows a strict phased approach.**

Each phase must be fully completed and verified before starting the next.
This ensures a stable foundation — sync bugs caught early prevent rework across multiple screens.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
Foundation   Sync       UI/CRUD     Sharing     Profile     Polish
   │          │           │           │           │
   ▼          ▼           ▼           ▼           ▼
 Gate 1    Gate 2      Gate 3      Gate 4      Gate 5
```

---

### Phase 1: Foundation

**Goal**: Xcode project with models, networking, and auth — can login and see empty main screen.

**Deliverables**:
1. Create Xcode project (SwiftUI, iOS 17+, Swift, iPhone only)
2. Define all SwiftData models (User, Wishlist, Item, Mark, Share, Bookmark)
3. Implement `Constants.swift` (API URLs, Keychain keys)
4. Implement `IDGenerator.swift` (type-prefixed UUIDs)
5. Implement `KeychainHelper.swift` (secure token storage)
6. Implement `APIClient.swift` (URLSession, JSON coding, auth header injection)
7. Implement `AuthManager.swift` (login, register, JWT refresh)
8. Implement `LoginView.swift` + `RegisterView.swift`
9. Implement `ContentView.swift` (auth gate → placeholder main view)
10. Implement `WishWithMeApp.swift` (dependency injection via environment)

**Tests Required**:
- [ ] All models encode/decode to/from JSON correctly (snake_case ↔ camelCase)
- [ ] `_id`/`_rev` CodingKeys work properly
- [ ] KeychainHelper stores and retrieves tokens
- [ ] AuthManager login flow returns tokens and user
- [ ] AuthManager refresh flow updates tokens on 401
- [ ] APIClient injects Bearer header correctly

**Gate 1 — Phase 1 Complete When**:
- [ ] `xcodebuild build` succeeds with zero errors
- [ ] `xcodebuild test` passes all unit tests
- [ ] App launches in Simulator
- [ ] Can register a new user (against real or local API)
- [ ] Can login with existing user
- [ ] After login, sees placeholder main screen
- [ ] Tokens stored in Keychain (verify via Keychain Access or test)
- [ ] Logout clears Keychain and returns to LoginView

---

### Phase 2: Core Sync

**Goal**: Offline-first data layer — app syncs with server, works offline, shows sync status.

**Depends on**: Phase 1 complete (auth works, APIClient ready)

**Deliverables**:
1. Implement `LocalStore.swift` (SwiftData ModelContainer setup)
2. Implement `NetworkMonitor.swift` (NWPathMonitor wrapper)
3. Add `isDirty` and `lastSyncedAt` fields to all models (local-only, not sent to API)
4. Implement `SyncEngine.swift` (@MainActor @Observable class with push/pull/reconcile)
5. Wire sync triggers (app foreground, network restored, timer, manual)
6. Implement `SyncStatusIndicator.swift` component (idle/syncing/error/offline)
7. Implement `OfflineBanner.swift` component

**Tests Required**:
- [ ] SyncEngine.pushAll() sends dirty docs to correct endpoints
- [ ] SyncEngine.pullAll() upserts server docs into SwiftData
- [ ] SyncEngine.reconcileAll() deletes local orphans not in pull response
- [ ] Dirty flag set on local create/update/delete
- [ ] Dirty flag cleared after successful sync
- [ ] NetworkMonitor correctly detects online/offline transitions
- [ ] Sync triggers on app foreground
- [ ] Sync triggers when network restored
- [ ] Mock API tests for push/pull responses

**Gate 2 — Phase 2 Complete When**:
- [ ] `xcodebuild test` passes all sync tests
- [ ] Create a wishlist locally → shows in SwiftData immediately
- [ ] Trigger sync → wishlist appears on server (verify via API or PWA)
- [ ] Create wishlist in PWA → sync in iOS → appears locally
- [ ] Delete wishlist in PWA → sync in iOS → removed locally (reconcile works)
- [ ] Turn off network → app still shows cached data
- [ ] OfflineBanner appears when offline
- [ ] SyncStatusIndicator shows correct state
- [ ] Turn network back on → sync triggers automatically

---

### Phase 3: Wishlists & Items

**Goal**: Full CRUD for wishlists and items — core user-facing functionality.

**Depends on**: Phase 2 complete (sync works, offline-first verified)

**Deliverables**:
1. Implement `WishlistsViewModel.swift`
2. Implement `WishlistsView.swift` (list with pull-to-refresh)
3. Implement `WishlistRow.swift` component
4. Implement `CreateEditWishlistSheet.swift` (name, description, icon picker, color picker)
5. Implement delete wishlist with confirmation
6. Implement `WishlistDetailViewModel.swift` (also handles add-item logic)
7. Implement `WishlistDetailView.swift` (items list with pull-to-refresh)
8. Implement `ItemCard.swift` component (image, title, price, status badge)
9. Implement `AddItemSheet.swift` (URL mode + manual mode, uses WishlistDetailViewModel)
10. Implement `EditItemSheet.swift` (item editing form)
11. Implement edit/delete item
12. Implement `IconMapper.swift` + `IconColorMapper.swift` (Material → SF Symbols)

**Tests Required**:
- [ ] Create wishlist → appears in list → syncs to server
- [ ] Edit wishlist → changes persist → sync
- [ ] Delete wishlist → removed from list → sync
- [ ] Create item by URL → status "pending" → sync → server resolves → pull updated item
- [ ] Create item manually → all fields saved → sync
- [ ] Edit item → changes persist → sync
- [ ] Delete item → removed → sync
- [ ] Pull-to-refresh triggers full sync
- [ ] Empty state shown when no wishlists/items
- [ ] Loading state shown during operations

**Gate 3 — Phase 3 Complete When**:
- [ ] `xcodebuild test` passes all CRUD tests
- [ ] Maestro flow: create wishlist → add item by URL → verify resolution
- [ ] Maestro flow: create wishlist → add item manually → edit → delete
- [ ] Visual diff: WishlistsView matches PWA (acceptable platform differences)
- [ ] Visual diff: WishlistDetailView matches PWA
- [ ] All operations work offline (queued for sync)
- [ ] PWA regression tests still pass (`pwa-unit` agent)

---

### Phase 4: Sharing & Marks

**Goal**: Share wishlists, accept shared links, mark items (surprise mode).

**Depends on**: Phase 3 complete (wishlists/items CRUD works)

**Deliverables**:
1. Implement `ShareSheet.swift` (create view/mark links, copy, iOS share, revoke)
2. Configure deep link handling in Info.plist
3. Implement `.onOpenURL` handler for `/s/{token}` (in `WishWithMeApp.swift`)
4. Implement `SharedWishlistViewModel.swift` (two modes: shareToken and wishlistId)
5. Implement `SharedWishlistView.swift`
6. Implement `SharedItemCard.swift` (with mark button)
7. Implement mark/unmark logic (create/delete Mark docs)
8. Implement surprise mode filtering (hide marks from wishlist owner)
9. Implement `SharedBookmarksView.swift` (dedicated tab for bookmarked wishlists)
10. Implement `BookmarkRow.swift` component
11. Implement `ShareViewModel.swift` (share link CRUD)

**Tests Required**:
- [ ] Create share link → copy to clipboard → link format correct
- [ ] Revoke share link → link no longer works
- [ ] Open share link → grant-access called → wishlist accessible
- [ ] Mark item → Mark doc created with correct access array (excludes owner)
- [ ] Owner views own wishlist → marks NOT visible (surprise mode)
- [ ] Non-owner views wishlist → marks visible
- [ ] Unmark item → Mark doc deleted
- [ ] Bookmark created when accepting share
- [ ] Bookmarked wishlists appear in dedicated section

**Gate 4 — Phase 4 Complete When**:
- [ ] `xcodebuild test` passes all sharing/mark tests
- [ ] Maestro flow: create wishlist → share → open link in second account → mark item
- [ ] Maestro flow: verify owner cannot see marks
- [ ] Deep links work from Safari and other apps
- [ ] Visual diff: SharedWishlistView matches PWA
- [ ] Share via iOS share sheet works (Messages, WhatsApp, etc.)
- [ ] PWA regression tests still pass

---

### Phase 5: Profile & OAuth

**Goal**: User profile editing, OAuth login (Google/Yandex), account settings.

**Depends on**: Phase 4 complete (sharing works, app is feature-complete for core flows)

**Deliverables**:
1. Implement `ProfileViewModel.swift`
2. Implement `ProfileView.swift` (name, bio, avatar, birthday, locale, public URL slug)
3. Implement avatar photo picker (camera + library) + base64 encoding
4. Implement `SettingsView.swift` (language switch, connected accounts, logout)
5. Implement OAuth flow via `OAuthSessionHelper.swift` (wraps `ASWebAuthenticationSession`)
6. Implement `SocialLoginButtons.swift` (Google, Yandex — handles OAuth callback inline)
7. Implement `OAuthAPI.swift` (APIClient extension for OAuth endpoints)
8. Implement link/unlink OAuth providers (in `SettingsView`)

**Tests Required**:
- [ ] Edit profile name → syncs to server
- [ ] Upload avatar → base64 encoded → syncs
- [ ] Change locale → syncs → UI updates
- [ ] OAuth login with Google → tokens received → user logged in
- [ ] OAuth login with Yandex → tokens received → user logged in
- [ ] Link Google to existing account → provider connected
- [ ] Unlink provider → provider removed
- [ ] Logout → tokens cleared → redirected to login

**Gate 5 — Phase 5 Complete When**:
- [ ] `xcodebuild test` passes all profile/OAuth tests
- [ ] Maestro flow: edit profile → change avatar → verify sync
- [ ] Maestro flow: OAuth login with Google (requires test account)
- [ ] Visual diff: ProfileView matches PWA
- [ ] Visual diff: SettingsView matches PWA
- [ ] PWA regression tests still pass

---

### Phase 6: Polish

**Goal**: Production-ready app with full localization, accessibility, and performance.

**Depends on**: Phase 5 complete (all features implemented)

**Deliverables**:
1. Full localization pass (en + ru) — all user-facing strings in .xcstrings
2. Loading states for all async operations
3. Empty states for all lists (wishlists, items, bookmarks)
4. Error states with retry actions
5. Haptic feedback on key actions (create, delete, mark, sync complete)
6. App icon (all sizes)
7. Launch screen
8. Accessibility audit (VoiceOver labels, Dynamic Type, contrast)
9. Performance profiling (Instruments: Time Profiler, Allocations, Network)
10. Memory leak check
11. Final visual diff pass on all screens

**Tests Required**:
- [ ] All strings appear correctly in Russian
- [ ] VoiceOver can navigate all screens
- [ ] Dynamic Type scales correctly
- [ ] No memory leaks detected in Instruments
- [ ] App launches in < 2 seconds
- [ ] Sync completes in reasonable time with 100+ items

**Gate 6 — Phase 6 Complete When**:
- [ ] `xcodebuild test` passes all tests
- [ ] Full Maestro test suite passes
- [ ] All visual diffs approved
- [ ] Accessibility audit passes
- [ ] Performance benchmarks met
- [ ] App Store screenshots captured
- [ ] Ready for TestFlight submission

---

### Phase Tracking

Track current phase status in this section:

| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| 1. Foundation | Complete | — | 2026-02-04 | Auth, models, networking |
| 2. Core Sync | Complete | 2026-02-04 | 2026-02-05 | Push/pull/reconcile working |
| 3. Wishlists & Items | Complete | 2026-02-05 | 2026-02-08 | CRUD + sync + E2E verified |
| 4. Sharing & Marks | Complete | 2026-02-08 | 2026-02-09 | Share links, marks, bookmarks |
| 5. Profile & OAuth | Complete | 2026-02-09 | 2026-02-09 | Profile, settings, OAuth, tests |
| 6. Polish | Complete | 2026-02-09 | 2026-02-09 | i18n (en+ru), haptics, accessibility, app icon |

Update this table as phases are completed.

---

## Code Conventions

- **Swift style**: Swift API Design Guidelines
- **Naming**: `camelCase` for vars/funcs, `PascalCase` for types
- **Architecture**: MVVM with `@Observable` ViewModels
- **Concurrency**: async/await, @MainActor for shared mutable state (SyncEngine)
- **Error handling**: typed errors, `do/catch` with user-facing messages
- **No force unwraps**: Use `guard let` / `if let` everywhere
- **SwiftData**: `@Model` classes, `FetchDescriptor` in ViewModels (not `@Query` in views)
- **Views**: Small, composable, max ~100 lines per view file
- **Comments**: Document non-obvious business logic, especially sync rules

---

## Testing Strategy

### iOS Tests
- **Unit tests (XCTest)**: Models, SyncEngine, AuthManager, APIClient (with mock URLProtocol)
- **ViewModel tests**: Business logic with mocked stores
- **UI automation (Maestro)**: YAML flows in `.maestro/flows/` — login, create wishlist, add item, share
- **Minimum**: Every new feature must have XCTest + Maestro coverage before moving to next phase
- **Run unit**: `xcodebuild test -scheme WishWithMe -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Run Maestro**: `maestro test .maestro/flows/`

### PWA Regression Tests (run after iOS changes to confirm no backend/sync regressions)
- **Frontend unit**: `cd ~/wish-with-me-codex/services/frontend && npm test` (290 Vitest tests)
- **Core API**: `cd ~/wish-with-me-codex/services/core-api && pytest` (154 tests)
- **Item resolver**: `cd ~/wish-with-me-codex/services/item-resolver && pytest` (305 tests)
- **E2E**: Playwright tests in `services/frontend/e2e/`

### Current Test Coverage
Unit tests exist in `WishWithMeTests/` with 3 categories:
- `ModelTests/` — UserModelTests, WishlistModelTests (JSON encode/decode, CodingKeys)
- `ServiceTests/` — KeychainHelperTests, IDGeneratorTests
- `ViewModelTests/` — ProfileViewModelTests (slug validation, avatar detection, OAuth URL construction)

Maestro flows (21 flows in `.maestro/flows/`): login, create/delete wishlist, add items (URL + manual),
share, mark/unmark, verify owner can't see marks, profile editing, settings, logout.

### Cross-Platform Visual Comparison
- PWA screenshots via `scripts/pwa-screenshot.js` (Playwright, iPhone 16 viewport 390×844)
- Additional authenticated screenshot scripts: `scripts/pwa-screenshot-auth.js`, `scripts/pwa-screenshot-authenticated.js`
- iOS screenshots via `xcrun simctl io booted screenshot`
- ImageMagick comparison via `visual-diff` agent
- Output: `screenshots/diff/` with side-by-side montages and RMSE metrics

---

## Commands

```bash
# Generate Xcode project from project.yml (run after adding/removing files)
xcodegen generate

# Build
xcodebuild -scheme WishWithMe -destination 'platform=iOS Simulator,name=iPhone 16' build

# Unit tests
xcodebuild test -scheme WishWithMe -destination 'platform=iOS Simulator,name=iPhone 16'

# Maestro UI tests
maestro test .maestro/flows/

# PWA screenshot capture (for visual diff)
node scripts/pwa-screenshot.js <page>   # pages: login, wishlists, wishlist-detail, profile, settings, shared

# iOS screenshot capture
xcrun simctl io booted screenshot screenshots/ios/<page>.png

# PWA regression tests
cd ~/wish-with-me-codex/services/frontend && npm test
cd ~/wish-with-me-codex/services/core-api && pytest
cd ~/wish-with-me-codex/services/item-resolver && pytest

# Verify all tools installed
bash files/check-tools.sh

# Clean
xcodebuild clean -scheme WishWithMe

# List simulators
xcrun simctl list devices available

# Open in Xcode
open WishWithMe.xcodeproj
```

---

## Supporting Infrastructure

### App Entry Point (`WishWithMeApp.swift`)

The `@main` struct wires all dependencies and handles lifecycle events:

```swift
@main
struct WishWithMeApp: App {
    @State private var authManager = AuthManager()
    @State private var networkMonitor = NetworkMonitor()
    @State private var syncEngine: SyncEngine?           // nil until auth loads
    @State private var pendingShareToken: String?        // deferred deep link
    @AppStorage("appLocale") private var appLocale: String = "en"
    private let localStore = LocalStore.shared
    @Environment(\.scenePhase) var scenePhase
}
```

**Startup sequence** (in `.task {}` modifier on root view):
1. `#if DEBUG`: Check for `-clearKeychain` launch argument (for Maestro tests)
   → clears Keychain + `localStore.clearAllData()`
2. `await authManager.loadStoredAuth()` — validates stored token with server
3. Sync `appLocale` from `authManager.currentUser?.locale` if available
4. Create `SyncEngine(apiClient: .shared, modelContainer: localStore.modelContainer, networkMonitor: networkMonitor)`
5. If authenticated: `await engine.fullSync()` then `engine.startPeriodicSync()`

**Environment injection** (on root view):
```swift
ContentView(syncEngine: syncEngine, pendingShareToken: $pendingShareToken)
    .id(appLocale)                           // Force view refresh on locale change
    .environment(authManager)                 // @Environment(AuthManager.self)
    .environment(networkMonitor)              // @Environment(NetworkMonitor.self)
    .environment(\.locale, Locale(identifier: appLocale))  // System locale override
    .modelContainer(localStore.modelContainer)  // @Environment(\.modelContext)
```

**Lifecycle observers** (`.onChange` modifiers):

| Trigger | Condition | Action |
|---------|-----------|--------|
| `scenePhase → .active` | `isAuthenticated` | `syncEngine?.triggerSync()` |
| `networkMonitor.isConnected → true` | `isAuthenticated` | `syncEngine?.triggerSync()` |
| `authManager.isAuthenticated → true` | — | `syncEngine?.fullSync()` + `startPeriodicSync()` |
| `authManager.isAuthenticated → false` | — | `syncEngine?.stopSync()` |

**Deep link handling** (`.onOpenURL`):
```swift
private func handleDeepLink(_ url: URL) {
    // Custom scheme: wishwithme://s/{token} → host="s", path="/{token}"
    // Universal link: https://wishwith.me/s/{token} → path="/s/{token}"
    // Extracts token → sets pendingShareToken
}
```

The `pendingShareToken` is consumed by `ContentView` which waits for `isAuthenticated`
before presenting `SharedWishlistView` as a sheet.

### ContentView (Auth Gate + Deep Link Consumer)

```swift
struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    let syncEngine: SyncEngine?
    @Binding var pendingShareToken: String?

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner(isOffline: !networkMonitor.isConnected)
            Group {
                if authManager.isAuthenticated {
                    MainTabView(syncEngine: syncEngine)
                } else {
                    LoginView(viewModel: AuthViewModel(authManager: authManager))
                }
            }
        }
        .sheet(isPresented: $showSharedWishlist) {
            // SharedWishlistView presented when activeShareToken is set
        }
    }

    // Deep link consumption: waits for auth, then presents shared wishlist
    private func consumePendingToken(_ token: String?) {
        guard let token = token, authManager.isAuthenticated else { return }
        activeShareToken = token
        pendingShareToken = nil      // Clear the binding
        showSharedWishlist = true
    }
}
```

### XcodeGen Project Definition (`project.yml`)

The Xcode project is generated from `project.yml` using XcodeGen. Run `xcodegen generate`
after adding or removing files.

```yaml
name: WishWithMe
options:
  bundleIdPrefix: me.wishwith
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.10"
    TARGETED_DEVICE_FAMILY: "1"    # iPhone only
    INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait

targets:
  WishWithMe:
    type: application
    platform: iOS
    sources:
      - path: WishWithMe
        excludes: ["**/.DS_Store"]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: me.wishwith.app
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_STYLE: Automatic
    info:
      path: WishWithMe/Resources/Info.plist
      properties:
        CFBundleURLTypes:
          - CFBundleURLName: "me.wishwith.app"
            CFBundleURLSchemes: [wishwithme]     # custom URL scheme for deep links/OAuth
        NSAppTransportSecurity:
          NSAllowsArbitraryLoads: false
          NSExceptionDomains:
            localhost:
              NSExceptionAllowsInsecureHTTPLoads: true   # for local dev
    entitlements:
      path: WishWithMe/Resources/WishWithMe.entitlements
      properties:
        com.apple.security.application-groups: [group.me.wishwith.app]
        keychain-access-groups: [$(AppIdentifierPrefix)me.wishwith.app]

  WishWithMeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: WishWithMeTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: me.wishwith.app.tests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/WishWithMe.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WishWithMe"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: WishWithMe

schemes:
  WishWithMe:
    build:
      targets:
        WishWithMe: all
        WishWithMeTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets: [WishWithMeTests]
    profile:
      config: Release
    archive:
      config: Release
```

### LocalStore (SwiftData ModelContainer)

```swift
@MainActor
final class LocalStore {
    static let shared = LocalStore()
    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            User.self, Wishlist.self, Item.self,
            Mark.self, Share.self, Bookmark.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed — delete old SQLite store and recreate
            let storePath = config.url.path()
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: storePath + suffix)
            }
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    func clearAllData() {
        let context = ModelContext(modelContainer)
        try? context.delete(model: User.self)
        try? context.delete(model: Wishlist.self)
        try? context.delete(model: Item.self)
        try? context.delete(model: Mark.self)
        try? context.delete(model: Share.self)
        try? context.delete(model: Bookmark.self)
        try? context.save()
    }
}
```

**Key points:**
- Singleton (`static let shared`), `@MainActor`
- Schema includes all 6 model types
- On schema migration failure: deletes SQLite files and recreates (loses local data, but data syncs back from server)
- `clearAllData()` is called on logout to wipe local state
- SyncEngine gets its `ModelContext` via `modelContainer.mainContext` (not creating a new context)

### NetworkMonitor

```swift
@Observable
final class NetworkMonitor {
    var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
```

**Key points:**
- `@Observable` (not `@MainActor`) — updates dispatched to main queue manually
- Injected into views via `@Environment(NetworkMonitor.self)`
- `isConnected` drives `OfflineBanner` visibility and `SyncEngine.fullSync()` guard
- SyncEngine checks `networkMonitor.isConnected` at the start of `fullSync()`

### AnyCodable (Type-Erased JSON)

The sync layer uses `AnyCodable` to handle generic CouchDB documents without knowing
their types at the push/pull boundary.

```swift
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    // Decode: tries Bool → Int → Double → String → [AnyCodable] → [String: AnyCodable]
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil()                             { value = NSNull() }
        else if let bool = try? container.decode(Bool.self)  { value = bool }
        else if let int = try? container.decode(Int.self)    { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map(\.value) }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues(\.value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "...") }
    }

    // Encode: handles NSNumber/CFBoolean edge case
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        // CRITICAL: NSNumber(1) and Bool(true) are the same in Foundation.
        // Use CFBooleanGetTypeID to distinguish actual booleans from numeric NSNumbers.
        if let number = value as? NSNumber, CFBooleanGetTypeID() != CFGetTypeID(number) {
            // It's a real number, not a boolean
            if number.doubleValue == Double(number.intValue) {
                try container.encode(number.intValue)
            } else {
                try container.encode(number.doubleValue)
            }
            return
        }

        switch value {
        case is NSNull:          try container.encodeNil()
        case let bool as Bool:   try container.encode(bool)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]: try container.encode(dict.mapValues(AnyCodable.init))
        default: throw EncodingError.invalidValue(value, ...)
        }
    }
}
```

**Why this matters**: Without the `CFBooleanGetTypeID` check, `NSNumber(1)` would encode as
`true` instead of `1`, corrupting quantity fields and other numeric data during sync push.

### KeychainHelper

```swift
enum KeychainHelper {
    enum KeychainError: Error {
        case duplicateItem, unknown(OSStatus), notFound, invalidData
    }

    // All methods use kSecClassGenericPassword with service = AppConfig.keychainService
    static func save(key: String, value: String) throws    // SecItemAdd, on duplicate → update()
    static func read(key: String) throws -> String?        // SecItemCopyMatching → String
    static func delete(key: String) throws                 // SecItemDelete (no error on notFound)
    private static func update(key: String, value: String) throws  // SecItemUpdate
}
```

**Key behaviors:**
- `save()` calls `SecItemAdd` first; if `errSecDuplicateItem`, falls through to `update()` (upsert pattern)
- `read()` returns `nil` on `errSecItemNotFound` (not an error), throws on other failures
- `delete()` silently succeeds on `errSecItemNotFound` (idempotent)
- All queries use `kSecAttrService: AppConfig.keychainService` and `kSecAttrAccount: key`

### HapticManager

```swift
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium)
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    static func selection()
}
```

Used for: create wishlist (`.success`), delete (`.warning`), mark item (`.medium`), sync complete (`.light`).

### Colors

```swift
extension Color {
    static let brandPrimary = Color(hex: "4F46E5")   // Indigo-600
    static let brandAccent = Color(hex: "8B5CF6")    // Violet-500

    init(hex: String)  // Supports 3, 6, or 8 character hex strings
}
```

### OAuthSessionHelper

```swift
@MainActor
final class OAuthSessionHelper: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthSessionHelper()
    static let callbackScheme = "wishwithme"
    static let callbackURL = "wishwithme://auth/callback"

    // Opens ASWebAuthenticationSession, returns callback URL via withCheckedThrowingContinuation
    func openSession(url: URL) async throws -> URL?
}

enum OAuthSessionError: Error, LocalizedError {
    case failedToStart      // session.start() returned false
    case cancelled          // user dismissed browser (errorDescription = nil)
    case sessionError(Error) // ASWebAuthenticationSession error
}
```

**Key behaviors:**
- Cancels any existing session before starting a new one
- `prefersEphemeralWebBrowserSession = false` (preserves login cookies)
- `presentationAnchor` finds key window via `UIApplication.shared.connectedScenes`
- Returns `nil` if session has no callback URL; throws `.cancelled` on user dismiss

### ScrollOffsetTracker

```swift
struct ScrollOffsetTracker: UIViewRepresentable {
    @Binding var isScrolled: Bool
    var threshold: CGFloat = 3    // pixels of scroll before isScrolled = true
}
```

A `UIViewRepresentable` that walks the view hierarchy to find its parent `UIScrollView`,
then observes `contentOffset` via KVO. Used by `FloatingTabBar` to collapse middle tabs
when the user scrolls list content.

---

## APIClient Extension Methods

### OAuthAPI (`OAuthAPI.swift`)

```swift
extension APIClient {
    func getOAuthProviders() async throws -> [String]
    func getConnectedAccounts() async throws -> ConnectedAccountsResponse
    func initiateOAuthLink(provider: String) async throws -> OAuthLinkInitiateResponse
    func unlinkOAuthProvider(provider: String) async throws    // requestVoid
    func getOAuthAuthorizeURL(provider: String) -> URL?        // synchronous, no network call
}
```

`getOAuthAuthorizeURL()` builds the URL locally:
`{apiBaseURL}/api/v1/oauth/{provider}/authorize?callback_url=wishwithme://auth/callback`

### ShareAPI (`ShareAPI.swift`)

```swift
extension APIClient {
    func createShareLink(wishlistId: String, linkType: String) async throws -> CreateShareResponse
    func revokeShareLink(wishlistId: String, shareId: String) async throws  // requestVoid DELETE
    func grantAccess(token: String) async throws -> GrantAccessResponse
}
```

---

## ViewModel Implementations

All ViewModels follow the same pattern: `@MainActor @Observable final class` with stored `ModelContext`.

### AuthViewModel

```swift
@MainActor @Observable final class AuthViewModel {
    var email = "", password = "", name = "", confirmPassword = ""
    var isLoading = false, errorMessage: String?, isLoginMode = true

    init(authManager: AuthManager)

    func login() async       // Validates non-empty email+password, calls authManager.login()
    func register() async    // Validates all fields + password match + min 8 chars, calls authManager.register()
    func clearError()
    func toggleMode()        // Toggles isLoginMode, clears error
}
```

### WishlistsViewModel

```swift
@MainActor @Observable final class WishlistsViewModel {
    var wishlists: [Wishlist] = []
    var bookmarks: [Bookmark] = []
    var itemCounts: [String: Int] = [:]
    var isLoading = false, errorMessage: String?

    init(modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager)

    func loadWishlists()     // Fetches own wishlists (ownerId == userId, !softDeleted), then refreshItemCounts + loadBookmarks
    func loadBookmarks()     // Fetches bookmarks (userId == userId, !softDeleted), sorted by lastAccessedAt desc
    func refreshItemCounts() // For each wishlist, fetchCount of non-deleted items
    func itemCount(for wishlist: Wishlist) -> Int
    func itemCount(for bookmark: Bookmark) -> Int

    func createWishlist(name:, description:, icon:, iconColor:)  // Insert + save + loadWishlists + triggerSync
    func updateWishlist(_:, name:, description:, icon:, iconColor:)
    func deleteWishlist(_:)  // Soft-delete + cascade soft-delete items
    func deleteBookmark(_:)  // Soft-delete bookmark

    func refresh() async     // fullSync + loadWishlists
}
```

### WishlistDetailViewModel

```swift
@MainActor @Observable final class WishlistDetailViewModel {
    var wishlist: Wishlist?, items: [Item] = [], marks: [Mark] = []
    var isLoading = false, errorMessage: String?
    var isOwner: Bool { wishlist?.ownerId == userId }

    init(wishlistId: String, modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager)

    func loadData()          // Fetches wishlist + items + marks (marks EMPTY if isOwner — surprise mode)

    // Item CRUD (all follow 4-step write pattern + post .itemsDidChange notification)
    func createItemByURL(url:)        // status = "pending", title = hostname
    func createItemManually(title:, description:, price:, currency:, quantity:, sourceUrl:, imageBase64:)  // status = "resolved"
    func updateItem(_:, title:, description:, price:, currency:, quantity:, sourceUrl:, imageBase64:)
    func deleteItem(_:)

    // Wishlist CRUD
    func updateWishlist(name:, description:, icon:, iconColor:)
    func deleteWishlist()    // Soft-delete + cascade items

    // Mark helpers
    func totalMarked(for item: Item) -> Int
    func isFullyMarked(_ item: Item) -> Bool

    func refresh() async
}
```

**Item access arrays**: New items inherit `wishlist.access` (or `[userId]` fallback).

### SharedWishlistViewModel

```swift
@MainActor @Observable final class SharedWishlistViewModel {
    var wishlist: Wishlist?, items: [Item] = [], marks: [Mark] = [], bookmark: Bookmark?
    var isLoading = false, errorMessage: String?, grantSuccess = false
    var permissions: [String] = []

    init(modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager, wishlistId: String? = nil)

    // Two entry points:
    func grantAccessAndSync(token:) async  // POST grant-access → fullSync → loadData
    func loadFromBookmark(wishlistId:)     // Direct SwiftData load (no API call)

    func loadData()          // Fetches wishlist + items + marks + bookmark (always loads marks — not owner's wishlist)

    // Mark/Unmark
    func markItem(_:)        // Creates Mark with access = wishlist.access.filter { $0 != ownerId }
    func unmarkItem(_:)      // Soft-deletes the user's mark

    // Helpers
    func myMarkForItem(_:) -> Mark?
    func totalMarked(for:) -> Int
    func isFullyMarked(_:) -> Bool
    func canMark(_:) -> Bool           // No existing mark + not fully marked
    var canMarkItems: Bool             // permissions.contains("mark") || permissions.isEmpty
}
```

### ProfileViewModel

```swift
@MainActor @Observable final class ProfileViewModel {
    var name = "", bio = "", publicUrlSlug = "", birthday = "", email = ""
    var avatarBase64: String?
    var isSaving = false, errorMessage: String?, successMessage: String?

    var slugError: String?   // Validates: only lowercase letters, numbers, hyphens
    var canSave: Bool        // !name.isEmpty && slugError == nil && !isSaving

    init(modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager)

    func loadProfile()       // Reads User from SwiftData; falls back to authManager.currentUser
    func saveProfile()       // Updates User in SwiftData + mirrors to authManager.currentUser
    func updateAvatar(_:)    // Updates avatar in SwiftData + authManager.currentUser
}
```

**Key detail**: `saveProfile()` also updates `authManager.currentUser` fields in memory
(name, bio, publicUrlSlug, birthday) so the tab bar and other views reflect changes immediately.

### ShareViewModel

```swift
@MainActor @Observable final class ShareViewModel {
    var shares: [Share] = []
    var isCreating = false, errorMessage: String?

    init(modelContext: ModelContext, syncEngine: SyncEngine?, wishlistId: String)

    func loadShares()              // FetchDescriptor: wishlistId match, !softDeleted, !revoked
    func createShareLink(linkType:) async  // POST API → fullSync → loadShares
    func revokeShareLink(_:) async         // DELETE API → fullSync → loadShares
    func shareLinkURL(_:) -> String        // "https://wishwith.me/s/{token}"
}
```

**Note**: Share creation and revocation are **server-side operations** (not local-first).
The ViewModel calls the API directly, then syncs to get updated local state.

---

## Component Implementations

### MainTabView + FloatingTabBar

```swift
enum MainTab: Hashable { case home, ownWishlists, sharedWithMe, profile }

struct MainTabView: View {
    let syncEngine: SyncEngine?
    @State private var selectedTab: MainTab = .home
    @State private var isTabBarCollapsed: Bool = false
    // Uses Group + switch (NOT native TabView) with FloatingTabBar via .safeAreaInset(edge: .bottom)
}
```

**FloatingTabBar**: Custom capsule-shaped tab bar with 4 tabs.
- Home (house) and Profile (person) are **always visible**
- Wishlists (rectangle.stack) and Shared (person.2) **fade out on scroll** (`isCollapsed`)
- Collapse triggered by `ScrollOffsetTracker` (threshold: 3px)
- Spring animation: `response: 0.4, dampingFraction: 0.82`
- Background: `.ultraThinMaterial` capsule with shadow
- Selected state: `Color.brandPrimary` foreground + `systemGray5` background pill

### SyncStatusIndicator

```swift
struct SyncStatusIndicator: View {
    let state: SyncEngine.SyncState
    // .idle    → checkmark.circle.fill (green)
    // .syncing → ProgressView (small spinner)
    // .error   → exclamationmark.triangle.fill (orange)
    // .offline → wifi.slash (secondary)
    // Frame: 28×28, font size 20
}
```

### OfflineBanner

```swift
struct OfflineBanner: View {
    let isOffline: Bool
    // When offline: HStack with wifi.slash icon + "You are offline" text
    // Background: .ultraThinMaterial, padding 16h/10v, font .caption
}
```

### AvatarView

```swift
struct AvatarView: View {
    let name: String?, avatarBase64: String?, size: CGFloat  // default size: 32

    // Priority: base64 image → name initial (letter on brandPrimary gradient) → person.fill fallback
    // Clipped to Circle()
    // Filters out SVG placeholder avatars (checks for known base64 prefix)
    // Strips "data:image/...;base64," prefix before decoding
}
```

### SocialLoginButtons

```swift
struct SocialLoginButtons: View {
    // "or continue with" divider + two OAuth buttons (Google blue, Yandex red)
    // Each button: HStack with SF Symbol (g.circle.fill / y.circle.fill) + label
    // Rounded rectangle, color-tinted background, border
    // Calls startOAuth(provider:) → APIClient.getOAuthAuthorizeURL → OAuthSessionHelper → extract tokens
    // Error handling: "email_exists" → specific message, other errors → capitalized
}
```

---

## Environment Configuration

```swift
enum AppConfig {
    // Currently both point to production — change DEBUG to localhost for local dev
    #if DEBUG
    static let apiBaseURL = "https://api.wishwith.me"
    #else
    static let apiBaseURL = "https://api.wishwith.me"
    #endif

    static let requestTimeout: TimeInterval = 30
    static let keychainService = "me.wishwith.app"
    static let accessTokenKey = "access_token"
    static let refreshTokenKey = "refresh_token"
}
```

For local development, change the DEBUG `apiBaseURL` to `"http://localhost:8000"`
and run backend via Docker:
```bash
cd ~/wish-with-me-codex && docker-compose up -d
```

---

## Security

- Store tokens in Keychain, NEVER in UserDefaults
- Pin `https://api.wishwith.me` via App Transport Security
- No secrets in source code
- Validate all server responses
- Clear Keychain on logout
- OAuth state parameter validation

---

## Reference: PWA Source Locations

When implementing any feature, consult the PWA source:

| iOS Component | PWA Source |
|---|---|
| Data models | `services/frontend/src/services/pouchdb/types.ts` |
| Sync logic | `services/frontend/src/services/pouchdb/index.ts` |
| Auth store | `services/frontend/src/stores/auth.ts` |
| Wishlist store | `services/frontend/src/stores/wishlist.ts` |
| Item store | `services/frontend/src/stores/item.ts` |
| All pages | `services/frontend/src/pages/` |
| All components | `services/frontend/src/components/` |
| i18n strings | `services/frontend/src/i18n/en/` and `ru/` |
| API schemas | `services/core-api/app/schemas/` |
| Sync endpoints | `services/core-api/app/routers/sync_couchdb.py` |
| Auth endpoints | `services/core-api/app/routers/auth_couchdb.py` |
| Share endpoints | `services/core-api/app/routers/share.py` |

---

## Agent Instructions

### Subagent System

This project uses a multi-agent orchestration system defined in `files/AGENTS.md`
and `.claude/agents/`. **Read `files/AGENTS.md` before starting any feature work.**

Eight specialized subagents handle different concerns:

| Agent | Role | Tools |
|-------|------|-------|
| `pwa-reader` | Extract feature specs from PWA source | Read-only |
| `ios-arch` | Review iOS codebase compatibility | Read-only |
| `ios-impl` | Write Swift/SwiftUI production code | Read/Write/Bash |
| `ios-test` | Write XCTest + Maestro flows, run tests | Read/Write/Bash |
| `qa-verify` | Full build + all tests gate (GO/NO-GO) | Read/Bash |
| `visual-diff` | Cross-platform screenshot comparison | Read/Write/Bash |
| `pwa-e2e` | Playwright E2E tests for PWA baseline | Read/Write/Bash |
| `pwa-unit` | Run existing PWA test suites (749 tests) | Read/Bash |

iOS agents live in `~/wish-with-me-iphone/.claude/agents/`.
PWA agents live in `~/wish-with-me-codex/.claude/agents/`.

### Feature Workflow (Mandatory for Every Feature)

```
STEP 1: RESEARCH (parallel)
  ├── pwa-reader     → extract PWA feature spec
  └── ios-arch       → check iOS codebase compatibility

STEP 2: IMPLEMENT (sequential, needs Step 1)
  └── ios-impl       → write Swift code

STEP 3: TEST (sequential, needs Step 2)
  └── ios-test       → write + run XCTest and Maestro flows

STEP 4: VERIFY (parallel, needs Step 3)
  ├── qa-verify      → full build + all test suites
  └── visual-diff    → compare iOS vs PWA screenshots
```

Main agent orchestrates all steps — subagents cannot spawn other subagents.

### Testing Tools

| Tool | Target | What It Does |
|------|--------|-------------|
| `xcodebuild test` | iOS | Unit tests (XCTest) — run after every change |
| Maestro | iOS | YAML-based UI automation on Simulator (`.maestro/flows/`) |
| Playwright | PWA | Headless E2E tests (`services/frontend/e2e/`) |
| Vitest | PWA | 290 unit tests (existing) |
| pytest | PWA | core-api 154 + item-resolver 305 tests (existing) |
| ImageMagick | Both | Visual diff between iOS and PWA screenshots |

Run `bash files/check-tools.sh` to verify all tools are installed.

### Cross-Platform Visual Verification

After implementing each screen:
1. PWA screenshot: `node scripts/pwa-screenshot.js <page>` (Playwright, iPhone 16 viewport)
2. iOS screenshot: `xcrun simctl io booted screenshot screenshots/ios/<page>.png`
3. Compare: `visual-diff` agent runs ImageMagick diff, produces side-by-side montage
4. Expected OK differences: native nav bars, SF Symbols vs Material icons, system fonts, platform sheets

### Before Writing Any Code
1. Read this entire CLAUDE.md
2. Read `files/AGENTS.md` for orchestration patterns
3. Check the PWA source for the feature you're implementing
4. Plan the implementation (models → services → viewmodels → views)
5. Write tests alongside implementation

### Critical Rules
- NEVER skip sync logic — it must match PWA behavior exactly
- NEVER store tokens outside Keychain
- ALWAYS handle offline state gracefully
- ALWAYS run tests after changes (`xcodebuild test` + Maestro)
- ALWAYS use the subagent workflow for features (research → implement → test → verify)
- When uncertain about API behavior, read the core-api Python source
- Marks must be hidden from wishlist owner (surprise mode) — this is a core business rule
- After iOS implementation, run `pwa-unit` agent to confirm no PWA regressions

---

## Setup (One-Time)

### Prerequisites
- macOS with Xcode 15+ installed
- iOS 17+ Simulator (install via Xcode → Settings → Platforms)
- XcodeGen (`brew install xcodegen`) — generates `.xcodeproj` from `project.yml`
- Claude Code CLI
- Maestro (UI automation)
- Node.js 18+ with Playwright (for PWA screenshots and E2E)
- ImageMagick (for visual diff)
- xcpretty (optional, cleaner test output)

### Tool Installation

```bash
# XcodeGen (generates .xcodeproj from project.yml)
brew install xcodegen

# Claude Code CLI (native, no Node.js required)
curl -fsSL https://claude.ai/install.sh | bash
source ~/.zshrc

# Maestro (iOS UI automation)
brew install maestro

# Playwright (PWA E2E + screenshots)
cd ~/wish-with-me-codex/services/frontend
npm install -D @playwright/test
npx playwright install chromium

# ImageMagick (visual diff)
brew install imagemagick

# xcpretty (optional)
gem install xcpretty

# Verify everything
bash files/check-tools.sh
```

### Start Development
```bash
cd ~/wish-with-me-iphone
claude
```

Claude Code will read this CLAUDE.md automatically and understand the full project context.

### Creating the Xcode Project
Tell Claude Code:
> Create the Xcode project for WishWithMe following CLAUDE.md Phase 1

# Test Scenarios — Wish With Me iPhone App

## Phase 1-2: Foundation & Core Sync

### Scenario: Login and Authentication
1. Launch app fresh (clear state)
2. See login screen with "Wish With Me" title
3. Enter email and password
4. Tap "Log In"
5. See "Wishlists" screen (authenticated)
6. Tokens stored in Keychain

### Scenario: Logout
1. From Wishlists screen, tap "Log Out"
2. See login screen
3. Tokens cleared from Keychain

### Scenario: Registration
1. From login screen, navigate to registration
2. Enter name, email, password
3. Tap "Register"
4. See Wishlists screen (auto-logged in)

### Scenario: Sync Status Indicator
1. When online and idle: green checkmark
2. During sync: spinning indicator
3. When sync fails: warning triangle
4. When offline: offline indicator

---

## Phase 3: Wishlists & Items

### Test Account
- Email: `test-ios-app@wishwith.me`
- Password: `TestPass123`
- User ID: `user:4130d57e-5e7d-41c9-a3ef-1a041732092f`
- Simulator: iPhone 17 Pro (AC3D5BBD-941D-4345-A0C5-C40BCDC8B5C8, iOS 26.2)

### Maestro Flows (in execution order)
| Flow | File | Description |
|------|------|-------------|
| 01 | `01-login.yaml` | Login with test account (clears state first) |
| 02 | `02-create-wishlist.yaml` | Create "Birthday Gifts" wishlist |
| 03 | `03-logout.yaml` | Logout |
| 04 | `04-login-verify-persist.yaml` | Re-login, verify wishlist persists |
| 05 | `05-delete-wishlist.yaml` | Delete wishlist via swipe + confirm |
| 06 | `06-logout-login-verify-deleted.yaml` | Re-login, verify deletion persists |
| 07 | `07-add-item-by-url.yaml` | Add item by URL (ozon.ru product) |
| 08 | `08-verify-item-resolved.yaml` | Pull-to-refresh, verify item resolved |
| 09 | `09-logout-login-verify-item.yaml` | Re-login, verify URL item persists |
| 10 | `10-add-item-manually.yaml` | Add "Blue Sneakers" manually |
| 11 | `11-logout-login-verify-manual-item.yaml` | Re-login, verify manual item persists |

### Step-by-Step E2E Test Plan

**Step 1-2: Login**
- Launch app with clear state
- Enter credentials: `test-ios-app@wishwith.me` / `TestPass123`
- Tap "Log In"
- Verify "Wishlists" screen appears
- Maestro: `01-login.yaml`

**Step 3: Create Wishlist**
- From empty wishlists screen, tap "New Wishlist"
- Enter name: "Birthday Gifts"
- Tap "Create"
- Verify "Birthday Gifts" appears in list
- Maestro: `02-create-wishlist.yaml`

**Step 4: Logout**
- Tap "Log Out"
- Verify login screen appears
- Maestro: `03-logout.yaml`

**Step 5: Re-login, Verify Persistence**
- Login with same credentials
- Verify "Birthday Gifts" still in list (synced from server)
- Maestro: `04-login-verify-persist.yaml`

**Step 6: Delete Wishlist**
- Swipe left on "Birthday Gifts"
- Tap "Delete"
- Confirm deletion in alert
- Verify wishlist disappears, "No wishlists yet" shown
- Maestro: `05-delete-wishlist.yaml`

**Step 7: Verify Deletion Persists After Re-login**
- Logout, re-login
- Verify "Birthday Gifts" does NOT reappear
- Verify "No wishlists yet" shown
- Maestro: `06-logout-login-verify-deleted.yaml`

**Step 8: Create New Wishlist**
- Create "Birthday Gifts" again
- Maestro: `02-create-wishlist.yaml` (reused)

**Step 9: Add Item by URL**
- Navigate into "Birthday Gifts"
- Tap "+" to add item
- Enter URL: `https://www.ozon.ru/product/1632508757`
- Tap "Create"
- Verify item appears with title "www.ozon.ru" and "Resolving..." status
- Maestro: `07-add-item-by-url.yaml`

**Step 10: Verify Item Resolves**
- Wait 30 seconds for server item-resolver
- Pull-to-refresh to trigger sync
- Verify "Resolving..." disappears
- Verify title updated to resolved product name
- Maestro: `08-verify-item-resolved.yaml`

**Step 11: Verify URL Item Persists After Re-login**
- Logout, re-login
- Navigate into "Birthday Gifts"
- Verify item is present (not "No items yet")
- Verify not showing "Resolving..."
- Maestro: `09-logout-login-verify-item.yaml`

**Step 12a: Add Item Manually**
- Tap "+" to add item
- Switch to "Manual" mode
- Enter: Title="Blue Sneakers", Description="Size 42 EU", Price=5999
- Tap "Create"
- Verify "Blue Sneakers" appears
- Maestro: `10-add-item-manually.yaml`

**Step 12b: Verify Manual Item Persists After Re-login**
- Logout, re-login
- Navigate into "Birthday Gifts"
- Verify "Blue Sneakers" is present
- Maestro: `11-logout-login-verify-manual-item.yaml`

### Bugs Found & Fixed During Phase 3

1. **`isDeleted` SwiftData naming conflict** — `PersistentModel` has a built-in `isDeleted` computed property. Our stored property shadowed it, preventing persistence. Fix: renamed to `softDeleted` across all 6 models + SyncEngine + ViewModels.

2. **SyncEngine nil in ViewModels** — SyncEngine is created asynchronously in `.task`. ViewModels captured it at init when still nil. Fix: made `syncEngine` `var` in ViewModels, update reference in `onAppear`/`onChange`.

3. **Dirty-doc protection during pull** — Server upsert would overwrite local pending changes. Fix: `guard !existing.isDirty else { return }` in all upsert cases.

4. **Dirty-doc protection during reconcile** — Reconcile would delete locally dirty docs as orphans. Fix: subtract dirty IDs from orphan set.

5. **`quantity` type mismatch** — Server returns `"quantity": true` (boolean) for resolved items. Fix: custom `init(from decoder:)` in `ItemDTO` handling both `Int` and `Bool`.

6. **Post-sync UI refresh** — SyncEngine uses separate ModelContext; Views didn't see updates. Fix: `onChange(of: syncEngine?.state)` reloads ViewModel data when sync completes.

---

## Phase 4: Sharing & Marks

### Test Accounts
- **Account A** (wishlist owner): `test-ios-app@wishwith.me` / `TestPass123` — User ID: `user:4130d57e-5e7d-41c9-a3ef-1a041732092f`
- **Account B** (first viewer/marker): `test-ios-b@wishwith.me` / `TestPass123` — User ID: `user:8e99a999-d2b8-48b1-b9cb-058a3e1e3229`
- **Account C** (second viewer/marker): `test-ios-c@wishwith.me` / `TestPass123` — User ID: `user:03d6c93e-fea3-4788-a8f9-c6ba2943f17f`

### Step-by-Step E2E Test Plan

**Step 1: Login as Account A**
- Login with Account A credentials
- Verify wishlists screen with existing "Birthday Gifts"

**Step 2: Create Share Link**
- Navigate into "Birthday Gifts"
- Open share menu
- Create a share link (type: "mark" — allows marking items)
- Copy share link to clipboard
- Verify link format: `https://wishwith.me/s/{token}`

**Step 3: Login as Account B**
- Logout from Account A
- Login with Account B credentials

**Step 4: Follow Share Link**
- Open share link (via deep link or URL handler)
- Grant access is called automatically
- See shared wishlist content (items from Account A's "Birthday Gifts")

**Step 5: Verify Shared Wishlist Content**
- Verify wishlist name, items visible
- Verify items show correct titles, prices, images

**Step 6: Verify Bookmarked Wishlist**
- Navigate to "Shared with me" tab/section
- Verify bookmarked wishlist appears with owner name and wishlist info

**Step 7: Mark Items as Bought**
- Open bookmarked wishlist
- Mark an item as "I'll get this"
- Verify mark appears (quantity badge or visual indicator)
- Mark is hidden from Account A (surprise mode)

**Step 8: Login as Account C**
- Logout from Account B
- Login with Account C credentials

**Step 9: Follow Same Share Link**
- Open same share link
- Grant access
- See shared wishlist and items

**Step 10: Verify Marks from Account B**
- See items marked by Account B shown as marked
- Account C cannot mark items already fully marked

**Step 11: Verify Mark Visibility (Surprise Mode)**
- Login as Account A (wishlist owner)
- Navigate to "Birthday Gifts"
- Verify marks are NOT visible (hidden from owner)

**Step 12: Login as Account B, Unmark Items**
- Login as Account B
- Open bookmarked wishlist
- Unmark previously marked items
- Verify marks removed

**Step 13: Login as Account C, Verify Unmarked**
- Login as Account C
- Open shared wishlist
- Verify items are now unmarked
- Account C can now mark them

**Step 14: Login as Account A, Revoke Share**
- Login as Account A
- Navigate to share management
- Revoke the share link
- Verify link is marked as revoked

**Step 15: Verify Revoked Link**
- Login as Account B or C
- Attempt to follow revoked link
- Verify access denied or appropriate error

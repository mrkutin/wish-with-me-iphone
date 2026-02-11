import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var name: String = ""
    var bio: String = ""
    var publicUrlSlug: String = ""
    var birthday: String = ""
    var avatarBase64: String?
    var email: String = ""

    var isSaving: Bool = false
    var errorMessage: String?
    var successMessage: String?

    var slugError: String? {
        if publicUrlSlug.isEmpty { return nil }
        let regex = /^[a-z0-9-]+$/
        if publicUrlSlug.wholeMatch(of: regex) == nil {
            return "Only lowercase letters, numbers, and hyphens"
        }
        return nil
    }

    var canSave: Bool {
        !name.isEmpty && slugError == nil && !isSaving
    }

    private let modelContext: ModelContext
    var syncEngine: SyncEngine?
    private let authManager: AuthManager

    init(modelContext: ModelContext, syncEngine: SyncEngine?, authManager: AuthManager) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.authManager = authManager
    }

    func loadProfile() {
        guard let userId = authManager.currentUser?.id else { return }

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.id == userId }
        )
        if let user = try? modelContext.fetch(descriptor).first {
            name = user.name
            bio = user.bio ?? ""
            publicUrlSlug = user.publicUrlSlug ?? ""
            birthday = user.birthday ?? ""
            avatarBase64 = user.avatarBase64
            email = user.email
        } else if let currentUser = authManager.currentUser {
            name = currentUser.name
            bio = currentUser.bio ?? ""
            publicUrlSlug = currentUser.publicUrlSlug ?? ""
            birthday = currentUser.birthday ?? ""
            avatarBase64 = currentUser.avatarBase64
            email = currentUser.email
        }
    }

    func saveProfile() {
        guard let userId = authManager.currentUser?.id else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.id == userId }
        )

        guard let user = try? modelContext.fetch(descriptor).first else {
            errorMessage = "User not found"
            isSaving = false
            return
        }

        user.name = name
        user.bio = bio.isEmpty ? nil : bio
        user.publicUrlSlug = publicUrlSlug.isEmpty ? nil : publicUrlSlug
        user.birthday = birthday.isEmpty ? nil : birthday
        user.updatedAt = ISO8601DateFormatter().string(from: Date())
        user.isDirty = true

        do {
            try modelContext.save()
            authManager.currentUser?.name = name
            authManager.currentUser?.bio = bio.isEmpty ? nil : bio
            authManager.currentUser?.publicUrlSlug = publicUrlSlug.isEmpty ? nil : publicUrlSlug
            authManager.currentUser?.birthday = birthday.isEmpty ? nil : birthday
            successMessage = "Profile saved"
            syncEngine?.triggerSync()
        } catch {
            errorMessage = "Failed to save profile"
        }

        isSaving = false
    }

    func updateAvatar(_ base64: String?) {
        guard let userId = authManager.currentUser?.id else { return }

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { $0.id == userId }
        )

        guard let user = try? modelContext.fetch(descriptor).first else { return }

        user.avatarBase64 = base64
        user.updatedAt = ISO8601DateFormatter().string(from: Date())
        user.isDirty = true
        avatarBase64 = base64

        do {
            try modelContext.save()
            authManager.currentUser?.avatarBase64 = base64
            syncEngine?.triggerSync()
        } catch {
            errorMessage = "Failed to update avatar"
        }
    }
}

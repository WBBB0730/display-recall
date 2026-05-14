import Foundation

public enum ProfileManagerError: Error, Equatable, Sendable {
    case profileNotFound
    case invalidCommand
}

public struct ProfileManager: Sendable {
    public typealias CommandRunner = @Sendable ([String]) async throws -> DisplayplacerBackendRunResult

    public private(set) var document: ProfileStoreDocument

    public init(document: ProfileStoreDocument) {
        self.document = document
    }

    @discardableResult
    public mutating func saveCurrentLayout(
        _ layout: CurrentDisplayLayout,
        name: String? = nil,
        makeAutomaticDefault: Bool = false
    ) throws -> ProfileStoreDocument {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let profile = DisplayProfile(
            name: trimmedName.isEmpty ? layout.generatedProfileName : trimmedName,
            command: layout.command,
            displaySetupFingerprint: layout.displaySetupFingerprint,
            displaySummary: layout.displaySummary
        )
        document.profiles.append(profile)
        if makeAutomaticDefault {
            clearAutomaticDefault(for: layout.displaySetupFingerprint)
            document.automaticDefaultRules.append(
                AutomaticDefaultRule(
                    displaySetupFingerprint: layout.displaySetupFingerprint,
                    profileId: profile.id
                )
            )
        }
        return document
    }

    public mutating func rename(profileID: UUID, to name: String) throws {
        let index = try index(of: profileID)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        document.profiles[index].name = trimmed.isEmpty ? document.profiles[index].name : trimmed
        document.profiles[index].updatedAt = Date()
        document.profiles[index].updatedByAppVersion = AppConfiguration.version
    }

    public mutating func updateNotes(profileID: UUID, notes: String) throws {
        let index = try index(of: profileID)
        document.profiles[index].notes = notes
        document.profiles[index].updatedAt = Date()
        document.profiles[index].updatedByAppVersion = AppConfiguration.version
    }

    public mutating func updateCommand(profileID: UUID, command: String) throws {
        guard (try? DisplayCommandParser.parse(command)) != nil else {
            throw ProfileManagerError.invalidCommand
        }
        let index = try index(of: profileID)
        document.profiles[index].command = command
        document.profiles[index].updatedAt = Date()
        document.profiles[index].updatedByAppVersion = AppConfiguration.version
    }

    public mutating func setAutomaticDefault(
        profileID: UUID,
        for fingerprint: DisplaySetupFingerprint
    ) throws {
        _ = try index(of: profileID)
        clearAutomaticDefault(for: fingerprint)
        document.automaticDefaultRules.append(
            AutomaticDefaultRule(displaySetupFingerprint: fingerprint, profileId: profileID)
        )
    }

    public mutating func clearAutomaticDefault(for fingerprint: DisplaySetupFingerprint) {
        document.automaticDefaultRules.removeAll { $0.displaySetupFingerprint == fingerprint }
    }

    public mutating func rebind(
        profileID: UUID,
        to fingerprint: DisplaySetupFingerprint,
        displaySummary: String
    ) throws {
        let index = try index(of: profileID)
        document.profiles[index].displaySetupFingerprint = fingerprint
        document.profiles[index].displaySummary = displaySummary
        document.profiles[index].updatedAt = Date()
        document.profiles[index].updatedByAppVersion = AppConfiguration.version
    }

    public func apply(
        _ profile: DisplayProfile,
        run: CommandRunner
    ) async throws -> DisplayplacerBackendRunResult {
        try await run(DisplayCommandParser.displayplacerArguments(from: profile.command))
    }

    private func index(of profileID: UUID) throws -> Array<DisplayProfile>.Index {
        guard let index = document.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw ProfileManagerError.profileNotFound
        }
        return index
    }
}

public enum ProfileListFilter {
    public static func filter(_ profiles: [DisplayProfile], query: String) -> [DisplayProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return profiles
        }

        return profiles.filter { profile in
            profile.name.localizedCaseInsensitiveContains(trimmed)
                || profile.notes.localizedCaseInsensitiveContains(trimmed)
                || profile.displaySummary.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

public struct ProfileDeletionResult: Equatable, Sendable {
    public let profilesDocument: ProfileStoreDocument
    public let settings: AppSettings
    public let logEntry: ActivityLogEntry
    public let nextSelectedProfileID: UUID?
}

public enum ProfileDeletion {
    public static func delete(
        profileID: UUID,
        profilesDocument: ProfileStoreDocument,
        settings: AppSettings
    ) throws -> ProfileDeletionResult {
        guard let deletedProfile = profilesDocument.profiles.first(where: { $0.id == profileID }) else {
            throw ProfileManagerError.profileNotFound
        }

        let remainingProfiles = profilesDocument.profiles.filter { $0.id != profileID }
        let remainingRules = profilesDocument.automaticDefaultRules.filter { $0.profileId != profileID }
        var updatedSettings = settings
        updatedSettings.shortcutBindings.removeAll { $0.profileId == profileID }

        let updatedDocument = ProfileStoreDocument(
            schemaVersion: profilesDocument.schemaVersion,
            profiles: remainingProfiles,
            automaticDefaultRules: remainingRules
        )

        return ProfileDeletionResult(
            profilesDocument: updatedDocument,
            settings: updatedSettings,
            logEntry: ActivityLogEntry(
                type: .profileDeleted,
                trigger: .manual,
                profileSnapshot: ProfileSnapshot(id: deletedProfile.id, name: deletedProfile.name)
            ),
            nextSelectedProfileID: remainingProfiles.first?.id
        )
    }
}

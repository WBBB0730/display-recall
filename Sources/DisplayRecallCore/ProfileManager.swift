import Foundation

public enum ProfileManagerError: Error, Equatable, Sendable {
    case profileNotFound
    case displaySetupGroupNotFound
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
        makeAutomaticDefault: Bool = false,
        displaySetupGroupLanguage: LanguagePreference = .english
    ) throws -> ProfileStoreDocument {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let profile = DisplayProfile(
            name: trimmedName.isEmpty ? layout.generatedProfileName : trimmedName,
            command: layout.command,
            displaySetupFingerprint: layout.displaySetupFingerprint,
            displaySummary: layout.displaySummary
        )
        ensureDisplaySetupGroup(
            for: layout.displaySetupFingerprint,
            language: displaySetupGroupLanguage
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

    public mutating func renameDisplaySetupGroup(groupID: UUID, to name: String) throws {
        guard let index = document.displaySetupGroups.firstIndex(where: { $0.id == groupID }) else {
            throw ProfileManagerError.displaySetupGroupNotFound
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        document.displaySetupGroups[index].name = trimmed
        document.displaySetupGroups[index].updatedAt = Date()
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

    public mutating func setAutomaticApply(profileID: UUID, isEnabled: Bool) throws {
        let profile = try profile(with: profileID)
        if isEnabled {
            clearAutomaticDefault(for: profile.displaySetupFingerprint)
            document.automaticDefaultRules.append(
                AutomaticDefaultRule(
                    displaySetupFingerprint: profile.displaySetupFingerprint,
                    profileId: profileID
                )
            )
        } else {
            document.automaticDefaultRules.removeAll { rule in
                rule.displaySetupFingerprint == profile.displaySetupFingerprint
                    && rule.profileId == profileID
            }
        }
    }

    public func isAutomaticApplyEnabled(for profileID: UUID) -> Bool {
        guard let profile = document.profiles.first(where: { $0.id == profileID }) else {
            return false
        }
        return document.automaticDefaultRules.contains { rule in
            rule.displaySetupFingerprint == profile.displaySetupFingerprint
                && rule.profileId == profileID
        }
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

    private mutating func ensureDisplaySetupGroup(
        for fingerprint: DisplaySetupFingerprint,
        language: LanguagePreference
    ) {
        guard !document.displaySetupGroups.contains(where: { $0.fingerprint == fingerprint }) else {
            return
        }

        document.displaySetupGroups.append(
            DisplaySetupGroup(
                fingerprint: fingerprint,
                name: DisplaySetupGroupNameGenerator.firstAvailableDefaultName(
                    existingNames: document.displaySetupGroups.map(\.name),
                    language: language
                )
            )
        )
    }

    private func index(of profileID: UUID) throws -> Array<DisplayProfile>.Index {
        guard let index = document.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw ProfileManagerError.profileNotFound
        }
        return index
    }

    private func profile(with profileID: UUID) throws -> DisplayProfile {
        guard let profile = document.profiles.first(where: { $0.id == profileID }) else {
            throw ProfileManagerError.profileNotFound
        }
        return profile
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

public struct DisplaySetupGroupDeletionResult: Equatable, Sendable {
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
            automaticDefaultRules: remainingRules,
            displaySetupGroups: profilesDocument.displaySetupGroups
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

public enum DisplaySetupGroupDeletion {
    public static func delete(
        groupID: UUID,
        profilesDocument: ProfileStoreDocument,
        settings: AppSettings
    ) throws -> DisplaySetupGroupDeletionResult {
        guard let deletedGroup = profilesDocument.displaySetupGroups.first(where: { $0.id == groupID }) else {
            throw ProfileManagerError.displaySetupGroupNotFound
        }

        let deletedProfiles = profilesDocument.profiles.filter {
            $0.displaySetupFingerprint == deletedGroup.fingerprint
        }
        let deletedProfileIDs = Set(deletedProfiles.map(\.id))
        let remainingProfiles = profilesDocument.profiles.filter { !deletedProfileIDs.contains($0.id) }
        let remainingGroups = profilesDocument.displaySetupGroups.filter { $0.id != groupID }
        let remainingRules = profilesDocument.automaticDefaultRules.filter { rule in
            !deletedProfileIDs.contains(rule.profileId)
                && rule.displaySetupFingerprint != deletedGroup.fingerprint
        }
        var updatedSettings = settings
        updatedSettings.shortcutBindings.removeAll { deletedProfileIDs.contains($0.profileId) }

        let updatedDocument = ProfileStoreDocument(
            schemaVersion: profilesDocument.schemaVersion,
            profiles: remainingProfiles,
            automaticDefaultRules: remainingRules,
            displaySetupGroups: remainingGroups
        )
        let deletedProfileList = deletedProfiles
            .map { "\($0.name) \($0.id.uuidString)" }
            .joined(separator: "\n")

        return DisplaySetupGroupDeletionResult(
            profilesDocument: updatedDocument,
            settings: updatedSettings,
            logEntry: ActivityLogEntry(
                type: .displaySetupGroupDeleted,
                trigger: .manual,
                metadata: [
                    "displaySetupGroupID": deletedGroup.id.uuidString,
                    "displaySetupGroupName": deletedGroup.name,
                    "displaySetupFingerprint": deletedGroup.fingerprint.rawValue,
                    "deletedProfileCount": String(deletedProfiles.count),
                    "deletedProfiles": deletedProfileList
                ]
            ),
            nextSelectedProfileID: remainingProfiles.first?.id
        )
    }
}

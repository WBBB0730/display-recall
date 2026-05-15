import Foundation

public struct ProfileBackupDocument: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appVersion: String
    public var exportedAt: Date
    public var profiles: [DisplayProfile]
    public var automaticDefaultRules: [AutomaticDefaultRule]
    public var displaySetupGroups: [DisplaySetupGroup]
    public var settings: AppSettings?

    public init(
        schemaVersion: Int = currentSchemaVersion,
        appVersion: String = AppConfiguration.version,
        exportedAt: Date = Date(),
        profiles: [DisplayProfile] = [],
        automaticDefaultRules: [AutomaticDefaultRule] = [],
        displaySetupGroups: [DisplaySetupGroup] = [],
        settings: AppSettings? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.profiles = profiles
        self.automaticDefaultRules = automaticDefaultRules
        self.displaySetupGroups = displaySetupGroups
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appVersion
        case exportedAt
        case profiles
        case automaticDefaultRules
        case displaySetupGroups
        case settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        profiles = try container.decode([DisplayProfile].self, forKey: .profiles)
        automaticDefaultRules = try container.decode([AutomaticDefaultRule].self, forKey: .automaticDefaultRules)
        displaySetupGroups = try container.decodeIfPresent(
            [DisplaySetupGroup].self,
            forKey: .displaySetupGroups
        ) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings)
    }
}

public enum ProfileExportSelection: Equatable, Sendable {
    case all
    case single(UUID)
    case multiple([UUID])
}

public enum ImportConflictStrategy: Equatable, Sendable {
    case keepBoth
    case replaceExisting
    case skipConflict
}

public enum ProfileImportExportError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedFutureSchema(version: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFutureSchema(version):
            "Unsupported backup schema version \(version). Please update Display Recall before importing this backup."
        }
    }
}

public struct ImportProfileConflict: Equatable, Sendable {
    public let importedName: String
    public let existingProfileID: UUID
    public let importedProfileID: UUID
}

public struct ImportMatchingStatus: Equatable, Sendable {
    public let profileID: UUID
    public let profileName: String
    public let matchesCurrentDisplaySetup: Bool
}

public struct ProfileImportPreview: Equatable, Sendable {
    public let profileCount: Int
    public let profileNames: [String]
    public let conflicts: [ImportProfileConflict]
    public let matchingStatuses: [ImportMatchingStatus]
}

public struct ProfileExportPreview: Equatable, Sendable {
    public let profileCount: Int
    public let profileNames: [String]
}

public enum ProfileExporter {
    public static func preview(
        document: ProfileStoreDocument,
        selection: ProfileExportSelection
    ) -> ProfileExportPreview {
        let profiles = selectedProfiles(in: document, selection: selection)

        return ProfileExportPreview(
            profileCount: profiles.count,
            profileNames: profiles.map(\.name)
        )
    }

    public static func export(
        document: ProfileStoreDocument,
        settings: AppSettings?,
        selection: ProfileExportSelection
    ) -> ProfileBackupDocument {
        let selectedProfiles = selectedProfiles(in: document, selection: selection)
        let selectedIDs = Set(selectedProfiles.map(\.id))
        let selectedFingerprints = Set(selectedProfiles.map(\.displaySetupFingerprint))
        let selectedRules = document.automaticDefaultRules.filter { selectedIDs.contains($0.profileId) }
        let selectedGroups = document.displaySetupGroups.filter {
            selectedFingerprints.contains($0.fingerprint)
        }

        return ProfileBackupDocument(
            profiles: selectedProfiles,
            automaticDefaultRules: selectedRules,
            displaySetupGroups: selectedGroups,
            settings: settings
        )
    }

    private static func selectedProfileIDs(
        in document: ProfileStoreDocument,
        selection: ProfileExportSelection
    ) -> Set<UUID> {
        switch selection {
        case .all:
            Set(document.profiles.map(\.id))
        case let .single(id):
            [id]
        case let .multiple(ids):
            Set(ids)
        }
    }

    private static func selectedProfiles(
        in document: ProfileStoreDocument,
        selection: ProfileExportSelection
    ) -> [DisplayProfile] {
        let selectedIDs = selectedProfileIDs(in: document, selection: selection)
        return document.profiles.filter { selectedIDs.contains($0.id) }
    }
}

public enum ProfileImporter {
    public static func preview(
        backup: ProfileBackupDocument,
        currentDocument: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint?
    ) throws -> ProfileImportPreview {
        try validateSchema(backup)
        return ProfileImportPreview(
            profileCount: backup.profiles.count,
            profileNames: backup.profiles.map(\.name),
            conflicts: conflicts(for: backup.profiles, in: currentDocument),
            matchingStatuses: backup.profiles.map { profile in
                ImportMatchingStatus(
                    profileID: profile.id,
                    profileName: profile.name,
                    matchesCurrentDisplaySetup: profile.displaySetupFingerprint == currentFingerprint
                )
            }
        )
    }

    public static func importProfiles(
        from backup: ProfileBackupDocument,
        into currentDocument: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint?,
        conflictStrategy: ImportConflictStrategy,
        importAsNew: Bool = true
    ) throws -> ProfileStoreDocument {
        try validateSchema(backup)

        var profiles = currentDocument.profiles
        var automaticRules = currentDocument.automaticDefaultRules
        var displaySetupGroups = currentDocument.displaySetupGroups
        var importedIDMap: [UUID: UUID] = [:]

        for importedProfile in backup.profiles {
            let conflictIndex = profiles.firstIndex { $0.name == importedProfile.name }
            let matchesCurrentSetup = importedProfile.displaySetupFingerprint == currentFingerprint

            switch (conflictIndex, conflictStrategy) {
            case (.some, .skipConflict):
                continue

            case let (.some(index), .replaceExisting):
                let localID = profiles[index].id
                profiles[index] = copy(
                    importedProfile,
                    id: localID,
                    name: importedProfile.name,
                    importedNeedsFirstApplyConfirmation: !matchesCurrentSetup
                )
                importedIDMap[importedProfile.id] = localID

            case (.some, .keepBoth), (.none, _):
                let localID = importAsNew ? UUID() : importedProfile.id
                let localName = conflictIndex == nil
                    ? importedProfile.name
                    : uniqueName(for: importedProfile.name, existingNames: Set(profiles.map(\.name)))
                profiles.append(copy(
                    importedProfile,
                    id: localID,
                    name: localName,
                    importedNeedsFirstApplyConfirmation: !matchesCurrentSetup
                ))
                importedIDMap[importedProfile.id] = localID
            }
        }

        let currentImportedRules = backup.automaticDefaultRules.compactMap { rule -> AutomaticDefaultRule? in
            guard let localID = importedIDMap[rule.profileId],
                  let profile = profiles.first(where: { $0.id == localID }),
                  profile.displaySetupFingerprint == currentFingerprint,
                  !profile.importedNeedsFirstApplyConfirmation else {
                return nil
            }
            return AutomaticDefaultRule(
                displaySetupFingerprint: profile.displaySetupFingerprint,
                profileId: localID
            )
        }
        automaticRules.append(contentsOf: currentImportedRules)
        mergeDisplaySetupGroups(
            &displaySetupGroups,
            importedGroups: backup.displaySetupGroups,
            importedProfiles: profiles.filter { profile in
                importedIDMap.values.contains(profile.id)
            }
        )

        return ProfileStoreDocument(
            schemaVersion: currentDocument.schemaVersion,
            profiles: profiles,
            automaticDefaultRules: automaticRules,
            displaySetupGroups: displaySetupGroups
        )
    }

    private static func validateSchema(_ backup: ProfileBackupDocument) throws {
        guard backup.schemaVersion <= ProfileBackupDocument.currentSchemaVersion else {
            throw ProfileImportExportError.unsupportedFutureSchema(version: backup.schemaVersion)
        }
    }

    private static func conflicts(
        for importedProfiles: [DisplayProfile],
        in currentDocument: ProfileStoreDocument
    ) -> [ImportProfileConflict] {
        importedProfiles.compactMap { imported in
            guard let existing = currentDocument.profiles.first(where: { $0.name == imported.name }) else {
                return nil
            }
            return ImportProfileConflict(
                importedName: imported.name,
                existingProfileID: existing.id,
                importedProfileID: imported.id
            )
        }
    }

    private static func uniqueName(for baseName: String, existingNames: Set<String>) -> String {
        var suffix = 2
        var candidate = "\(baseName) \(suffix)"
        while existingNames.contains(candidate) {
            suffix += 1
            candidate = "\(baseName) \(suffix)"
        }
        return candidate
    }

    private static func mergeDisplaySetupGroups(
        _ groups: inout [DisplaySetupGroup],
        importedGroups: [DisplaySetupGroup],
        importedProfiles: [DisplayProfile]
    ) {
        var knownFingerprints = Set(groups.map(\.fingerprint))
        var knownNames = groups.map(\.name)

        for group in importedGroups where !knownFingerprints.contains(group.fingerprint) {
            groups.append(group)
            knownFingerprints.insert(group.fingerprint)
            knownNames.append(group.name)
        }

        for profile in importedProfiles where !knownFingerprints.contains(profile.displaySetupFingerprint) {
            let name = DisplaySetupGroupNameGenerator.firstAvailableDefaultName(
                existingNames: knownNames,
                language: .english
            )
            groups.append(
                DisplaySetupGroup(
                    fingerprint: profile.displaySetupFingerprint,
                    name: name,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            )
            knownFingerprints.insert(profile.displaySetupFingerprint)
            knownNames.append(name)
        }
    }

    private static func copy(
        _ profile: DisplayProfile,
        id: UUID,
        name: String,
        importedNeedsFirstApplyConfirmation: Bool
    ) -> DisplayProfile {
        DisplayProfile(
            id: id,
            schemaVersion: profile.schemaVersion,
            name: name,
            notes: profile.notes,
            command: profile.command,
            displaySetupFingerprint: profile.displaySetupFingerprint,
            displaySummary: profile.displaySummary,
            backendVersion: profile.backendVersion,
            createdByAppVersion: profile.createdByAppVersion,
            updatedByAppVersion: AppConfiguration.version,
            isCommandEdited: profile.isCommandEdited,
            importedNeedsFirstApplyConfirmation: importedNeedsFirstApplyConfirmation,
            createdAt: profile.createdAt,
            updatedAt: Date()
        )
    }
}

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
    public mutating func saveCurrentLayout(_ layout: CurrentDisplayLayout) throws -> ProfileStoreDocument {
        let profile = DisplayProfile(
            name: layout.generatedProfileName,
            command: layout.command,
            displaySetupFingerprint: layout.displaySetupFingerprint,
            displaySummary: layout.displaySummary
        )
        document.profiles.append(profile)
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
        try await run([profile.command])
    }

    private func index(of profileID: UUID) throws -> Array<DisplayProfile>.Index {
        guard let index = document.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw ProfileManagerError.profileNotFound
        }
        return index
    }
}

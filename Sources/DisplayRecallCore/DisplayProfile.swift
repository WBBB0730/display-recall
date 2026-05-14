import Foundation

public struct DisplaySetupFingerprint: Equatable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct DisplayProfile: Equatable, Identifiable, Sendable, Codable {
    public let id: UUID
    public var schemaVersion: Int
    public var name: String
    public var notes: String
    public var command: String
    public var displaySetupFingerprint: DisplaySetupFingerprint
    public var displaySummary: String
    public var backendVersion: String
    public var createdByAppVersion: String
    public var updatedByAppVersion: String
    public var isCommandEdited: Bool
    public var importedNeedsFirstApplyConfirmation: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        name: String,
        notes: String = "",
        command: String,
        displaySetupFingerprint: DisplaySetupFingerprint,
        displaySummary: String = "",
        backendVersion: String = DisplayplacerBackend.bundledMetadata.version,
        createdByAppVersion: String = AppConfiguration.version,
        updatedByAppVersion: String = AppConfiguration.version,
        isCommandEdited: Bool = false,
        importedNeedsFirstApplyConfirmation: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.notes = notes
        self.command = command
        self.displaySetupFingerprint = displaySetupFingerprint
        self.displaySummary = displaySummary
        self.backendVersion = backendVersion
        self.createdByAppVersion = createdByAppVersion
        self.updatedByAppVersion = updatedByAppVersion
        self.isCommandEdited = isCommandEdited
        self.importedNeedsFirstApplyConfirmation = importedNeedsFirstApplyConfirmation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AutomaticDefaultRule: Equatable, Sendable, Codable {
    public let displaySetupFingerprint: DisplaySetupFingerprint
    public let profileId: UUID

    public init(displaySetupFingerprint: DisplaySetupFingerprint, profileId: UUID) {
        self.displaySetupFingerprint = displaySetupFingerprint
        self.profileId = profileId
    }
}

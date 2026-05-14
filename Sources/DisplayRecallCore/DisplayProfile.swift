import Foundation

public struct DisplaySetupFingerprint: Equatable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct DisplayProfile: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var command: String
    public var displaySetupFingerprint: DisplaySetupFingerprint
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        displaySetupFingerprint: DisplaySetupFingerprint,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.displaySetupFingerprint = displaySetupFingerprint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AutomaticDefaultRule: Equatable, Sendable {
    public let displaySetupFingerprint: DisplaySetupFingerprint
    public let profileId: UUID
}

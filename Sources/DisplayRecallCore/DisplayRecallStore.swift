import Foundation

public struct AppSettings: Equatable, Sendable, Codable {
    public var setupCompleted: Bool
    public var showDockIcon: Bool
    public var launchAtLogin: Bool
    public var automaticApplyEnabled: Bool
    public var automaticApplyCountdownSeconds: Int
    public var language: LanguagePreference
    public var backendSelection: BackendSelection
    public var shortcutBindings: [ShortcutBinding]

    public init(
        setupCompleted: Bool = false,
        showDockIcon: Bool = false,
        launchAtLogin: Bool = false,
        automaticApplyEnabled: Bool = true,
        automaticApplyCountdownSeconds: Int = 5,
        language: LanguagePreference = .system,
        backendSelection: BackendSelection = BackendSelection(),
        shortcutBindings: [ShortcutBinding] = []
    ) {
        self.setupCompleted = setupCompleted
        self.showDockIcon = showDockIcon
        self.launchAtLogin = launchAtLogin
        self.automaticApplyEnabled = automaticApplyEnabled
        self.automaticApplyCountdownSeconds = automaticApplyCountdownSeconds
        self.language = language
        self.backendSelection = backendSelection
        self.shortcutBindings = shortcutBindings
    }
}

public struct ProfileStoreDocument: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var profiles: [DisplayProfile]
    public var automaticDefaultRules: [AutomaticDefaultRule]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        profiles: [DisplayProfile] = [],
        automaticDefaultRules: [AutomaticDefaultRule] = []
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.automaticDefaultRules = automaticDefaultRules
    }
}

public struct SettingsStoreDocument: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var settings: AppSettings

    public init(schemaVersion: Int = currentSchemaVersion, settings: AppSettings = AppSettings()) {
        self.schemaVersion = schemaVersion
        self.settings = settings
    }
}

public enum DisplayRecallStoreError: Error, Equatable, Sendable {
    case unsupportedFutureSchema(version: Int)
}

public struct DisplayRecallMigrations {
    public static func migrateProfiles(_ document: ProfileStoreDocument) throws -> ProfileStoreDocument {
        guard document.schemaVersion <= ProfileStoreDocument.currentSchemaVersion else {
            throw DisplayRecallStoreError.unsupportedFutureSchema(version: document.schemaVersion)
        }
        return document
    }

    public static func migrateSettings(_ document: SettingsStoreDocument) throws -> SettingsStoreDocument {
        guard document.schemaVersion <= SettingsStoreDocument.currentSchemaVersion else {
            throw DisplayRecallStoreError.unsupportedFutureSchema(version: document.schemaVersion)
        }
        return document
    }

    public static func migrateActivityLog(_ document: ActivityLogStoreDocument) throws -> ActivityLogStoreDocument {
        guard document.schemaVersion <= ActivityLogStoreDocument.currentSchemaVersion else {
            throw DisplayRecallStoreError.unsupportedFutureSchema(version: document.schemaVersion)
        }
        return ActivityLogStoreDocument(schemaVersion: document.schemaVersion, entries: document.entries)
    }
}

public struct DisplayRecallStore: Sendable {
    public let applicationSupportDirectory: URL
    public let profilesURL: URL
    public let settingsURL: URL
    public let activityLogURL: URL

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.profilesURL = applicationSupportDirectory.appendingPathComponent("profiles.json")
        self.settingsURL = applicationSupportDirectory.appendingPathComponent("settings.json")
        self.activityLogURL = applicationSupportDirectory.appendingPathComponent("activity-log.json")
    }

    public static func live() throws -> DisplayRecallStore {
        try DisplayRecallStore(applicationSupportDirectory: defaultApplicationSupportDirectory())
    }

    public static func defaultApplicationSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(AppConfiguration.displayName, isDirectory: true)
    }

    public func loadProfiles() throws -> ProfileStoreDocument {
        guard FileManager.default.fileExists(atPath: profilesURL.path) else {
            return ProfileStoreDocument()
        }

        let data = try Data(contentsOf: profilesURL)
        try rejectFutureSchema(in: data, currentVersion: ProfileStoreDocument.currentSchemaVersion)
        let document = try decoder.decode(ProfileStoreDocument.self, from: data)
        return try DisplayRecallMigrations.migrateProfiles(document)
    }

    public func loadSettings() throws -> SettingsStoreDocument {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return SettingsStoreDocument()
        }

        let data = try Data(contentsOf: settingsURL)
        try rejectFutureSchema(in: data, currentVersion: SettingsStoreDocument.currentSchemaVersion)
        let document = try decoder.decode(SettingsStoreDocument.self, from: data)
        return try DisplayRecallMigrations.migrateSettings(document)
    }

    public func loadActivityLog() throws -> ActivityLogStoreDocument {
        guard FileManager.default.fileExists(atPath: activityLogURL.path) else {
            return ActivityLogStoreDocument()
        }

        let data = try Data(contentsOf: activityLogURL)
        try rejectFutureSchema(in: data, currentVersion: ActivityLogStoreDocument.currentSchemaVersion)
        let document = try decoder.decode(ActivityLogStoreDocument.self, from: data)
        return try DisplayRecallMigrations.migrateActivityLog(document)
    }

    public func save(_ document: ProfileStoreDocument) throws {
        try createDirectoryIfNeeded()
        let data = try encoder.encode(document)
        try data.write(to: profilesURL, options: .atomic)
    }

    public func save(_ document: SettingsStoreDocument) throws {
        try createDirectoryIfNeeded()
        let data = try encoder.encode(document)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func save(_ document: ActivityLogStoreDocument) throws {
        try createDirectoryIfNeeded()
        let retainedDocument = ActivityLogStoreDocument(
            schemaVersion: document.schemaVersion,
            entries: document.entries
        )
        let data = try encoder.encode(retainedDocument)
        try data.write(to: activityLogURL, options: .atomic)
    }

    private func createDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    private func rejectFutureSchema(in data: Data, currentVersion: Int) throws {
        let envelope = try decoder.decode(SchemaEnvelope.self, from: data)
        guard envelope.schemaVersion <= currentVersion else {
            throw DisplayRecallStoreError.unsupportedFutureSchema(version: envelope.schemaVersion)
        }
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }
}

private struct SchemaEnvelope: Decodable {
    let schemaVersion: Int
}

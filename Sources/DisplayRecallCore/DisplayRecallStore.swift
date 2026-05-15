import Foundation

public struct AppSettings: Equatable, Sendable, Codable {
    public var setupCompleted: Bool
    public var dockIconVisibility: DockIconVisibilityPreference
    public var launchAtLogin: Bool
    public var automaticApplyEnabled: Bool
    public var automaticApplyCountdownSeconds: Int
    public var language: LanguagePreference
    public var backendSelection: BackendSelection
    public var shortcutBindings: [ShortcutBinding]

    public var showDockIcon: Bool {
        get {
            dockIconVisibility == .alwaysShow
        }
        set {
            dockIconVisibility = newValue ? .alwaysShow : .automatic
        }
    }

    public init(
        setupCompleted: Bool = false,
        showDockIcon: Bool? = nil,
        dockIconVisibility: DockIconVisibilityPreference = DockIconVisibilityPreference.defaultValue,
        launchAtLogin: Bool = false,
        automaticApplyEnabled: Bool = true,
        automaticApplyCountdownSeconds: Int = 5,
        language: LanguagePreference = .system,
        backendSelection: BackendSelection = BackendSelection(),
        shortcutBindings: [ShortcutBinding] = []
    ) {
        self.setupCompleted = setupCompleted
        self.dockIconVisibility = showDockIcon.map { $0 ? .alwaysShow : .automatic } ?? dockIconVisibility
        self.launchAtLogin = launchAtLogin
        self.automaticApplyEnabled = automaticApplyEnabled
        self.automaticApplyCountdownSeconds = automaticApplyCountdownSeconds
        self.language = language
        self.backendSelection = backendSelection
        self.shortcutBindings = shortcutBindings
    }

    private enum CodingKeys: String, CodingKey {
        case setupCompleted
        case showDockIcon
        case dockIconVisibility
        case launchAtLogin
        case automaticApplyEnabled
        case automaticApplyCountdownSeconds
        case language
        case backendSelection
        case shortcutBindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted) ?? false
        if let preference = try container.decodeIfPresent(
            DockIconVisibilityPreference.self,
            forKey: .dockIconVisibility
        ) {
            dockIconVisibility = preference
        } else if let legacyShowDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showDockIcon) {
            dockIconVisibility = legacyShowDockIcon ? .alwaysShow : .automatic
        } else {
            dockIconVisibility = DockIconVisibilityPreference.defaultValue
        }
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        automaticApplyEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticApplyEnabled) ?? true
        automaticApplyCountdownSeconds = try container.decodeIfPresent(
            Int.self,
            forKey: .automaticApplyCountdownSeconds
        ) ?? 5
        language = try container.decodeIfPresent(LanguagePreference.self, forKey: .language) ?? .system
        backendSelection = try container.decodeIfPresent(
            BackendSelection.self,
            forKey: .backendSelection
        ) ?? BackendSelection()
        shortcutBindings = try container.decodeIfPresent(
            [ShortcutBinding].self,
            forKey: .shortcutBindings
        ) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(setupCompleted, forKey: .setupCompleted)
        try container.encode(dockIconVisibility, forKey: .dockIconVisibility)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(automaticApplyEnabled, forKey: .automaticApplyEnabled)
        try container.encode(automaticApplyCountdownSeconds, forKey: .automaticApplyCountdownSeconds)
        try container.encode(language, forKey: .language)
        try container.encode(backendSelection, forKey: .backendSelection)
        try container.encode(shortcutBindings, forKey: .shortcutBindings)
    }
}

public struct ProfileStoreDocument: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var profiles: [DisplayProfile]
    public var automaticDefaultRules: [AutomaticDefaultRule]
    public var displaySetupGroups: [DisplaySetupGroup]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        profiles: [DisplayProfile] = [],
        automaticDefaultRules: [AutomaticDefaultRule] = [],
        displaySetupGroups: [DisplaySetupGroup] = []
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.automaticDefaultRules = automaticDefaultRules
        self.displaySetupGroups = displaySetupGroups
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profiles
        case automaticDefaultRules
        case displaySetupGroups
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        profiles = try container.decode([DisplayProfile].self, forKey: .profiles)
        automaticDefaultRules = try container.decode([AutomaticDefaultRule].self, forKey: .automaticDefaultRules)
        displaySetupGroups = try container.decodeIfPresent(
            [DisplaySetupGroup].self,
            forKey: .displaySetupGroups
        ) ?? []
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
        var migrated = ProfileStoreDocument(
            schemaVersion: ProfileStoreDocument.currentSchemaVersion,
            profiles: document.profiles,
            automaticDefaultRules: document.automaticDefaultRules,
            displaySetupGroups: document.displaySetupGroups
        )
        addMissingDisplaySetupGroups(to: &migrated)
        return migrated
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

private extension DisplayRecallMigrations {
    static func addMissingDisplaySetupGroups(to document: inout ProfileStoreDocument) {
        var existingFingerprints = Set(document.displaySetupGroups.map(\.fingerprint))
        var existingNames = document.displaySetupGroups.map(\.name)

        for profile in document.profiles where !existingFingerprints.contains(profile.displaySetupFingerprint) {
            let name = DisplaySetupGroupNameGenerator.firstAvailableDefaultName(
                existingNames: existingNames,
                language: .english
            )
            document.displaySetupGroups.append(
                DisplaySetupGroup(
                    fingerprint: profile.displaySetupFingerprint,
                    name: name,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            )
            existingFingerprints.insert(profile.displaySetupFingerprint)
            existingNames.append(name)
        }
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

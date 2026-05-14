import XCTest
@testable import DisplayRecallCore

final class DisplayRecallStoreTests: XCTestCase {
    func testProfilesSettingsAndDefaultRulesPersistAcrossStoreInstances() throws {
        let directory = try temporaryDirectory()
        let store = DisplayRecallStore(applicationSupportDirectory: directory)
        let profile = DisplayProfile.fixture(name: "Home Desk")
        let settings = AppSettings(setupCompleted: true, showDockIcon: true)
        let rule = AutomaticDefaultRule(
            displaySetupFingerprint: profile.displaySetupFingerprint,
            profileId: profile.id
        )

        try store.save(
            ProfileStoreDocument(
                profiles: [profile],
                automaticDefaultRules: [rule]
            )
        )
        try store.save(SettingsStoreDocument(settings: settings))

        let reloadedStore = DisplayRecallStore(applicationSupportDirectory: directory)
        let profilesDocument = try reloadedStore.loadProfiles()
        let settingsDocument = try reloadedStore.loadSettings()

        XCTAssertEqual(profilesDocument.schemaVersion, 1)
        XCTAssertEqual(profilesDocument.profiles, [profile])
        XCTAssertEqual(profilesDocument.automaticDefaultRules, [rule])
        XCTAssertEqual(settingsDocument.schemaVersion, 1)
        XCTAssertEqual(settingsDocument.settings, settings)
    }

    func testProfileStoresMetadataNeededForFutureMigrations() throws {
        let profile = DisplayProfile.fixture(name: "Office")

        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.backendVersion, "1.4.0")
        XCTAssertEqual(profile.createdByAppVersion, "0.1.0")
        XCTAssertEqual(profile.updatedByAppVersion, "0.1.0")
        XCTAssertFalse(profile.displaySummary.isEmpty)
    }

    func testUnknownFutureSchemaVersionIsRejected() throws {
        let directory = try temporaryDirectory()
        let store = DisplayRecallStore(applicationSupportDirectory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let futureJSON = #"{"schemaVersion":999,"profiles":[],"automaticDefaultRules":[]}"#
        try futureJSON.write(to: store.profilesURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try store.loadProfiles()) { error in
            XCTAssertEqual(error as? DisplayRecallStoreError, .unsupportedFutureSchema(version: 999))
        }
    }

    func testStoreUsesPerUserApplicationSupportDirectoryByDefault() throws {
        let url = try DisplayRecallStore.defaultApplicationSupportDirectory()

        XCTAssertTrue(url.path.contains("Application Support"))
        XCTAssertEqual(url.lastPathComponent, "Display Recall")
    }

    func testMigrationInfrastructureAcceptsCurrentVersionWithoutChangingData() throws {
        let profile = DisplayProfile.fixture(name: "Desk")
        let document = ProfileStoreDocument(profiles: [profile], automaticDefaultRules: [])

        let migrated = try DisplayRecallMigrations.migrateProfiles(document)

        XCTAssertEqual(migrated, document)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DisplayRecallStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private extension DisplayProfile {
    static func fixture(name: String) -> DisplayProfile {
        DisplayProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            schemaVersion: 1,
            name: name,
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0""#,
            displaySetupFingerprint: DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1"),
            displaySummary: "27 inch external screen",
            backendVersion: "1.4.0",
            createdByAppVersion: "0.1.0",
            updatedByAppVersion: "0.1.0",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
    }
}

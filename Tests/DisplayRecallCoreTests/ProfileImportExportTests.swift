import XCTest
@testable import DisplayRecallCore

final class ProfileImportExportTests: XCTestCase {
    func testExportsAllProfilesAndSettingsWithoutLogsOrRestorePoints() throws {
        let home = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let office = DisplayProfile.fixture(id: Self.officeID, name: "Office")
        let document = ProfileStoreDocument(
            profiles: [home, office],
            automaticDefaultRules: [
                AutomaticDefaultRule(displaySetupFingerprint: home.displaySetupFingerprint, profileId: home.id)
            ]
        )
        let settings = AppSettings(setupCompleted: true, automaticApplyCountdownSeconds: 5)

        let backup = ProfileExporter.export(document: document, settings: settings, selection: .all)
        let data = try JSONEncoder().encode(backup)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(backup.profiles.map(\.name), ["Home", "Office"])
        XCTAssertEqual(backup.settings, settings)
        XCTAssertEqual(backup.automaticDefaultRules.count, 1)
        XCTAssertFalse(json.contains("activity-log"))
        XCTAssertFalse(json.contains("restore"))
    }

    func testExportsSelectedSingleAndMultipleProfiles() {
        let home = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let office = DisplayProfile.fixture(id: Self.officeID, name: "Office")
        let travel = DisplayProfile.fixture(id: Self.travelID, name: "Travel")
        let document = ProfileStoreDocument(profiles: [home, office, travel])

        let single = ProfileExporter.export(document: document, settings: nil, selection: .single(office.id))
        let multiple = ProfileExporter.export(
            document: document,
            settings: nil,
            selection: .multiple([travel.id, home.id])
        )

        XCTAssertEqual(single.profiles.map(\.name), ["Office"])
        XCTAssertEqual(multiple.profiles.map(\.name), ["Home", "Travel"])
    }

    func testImportPreviewShowsCountNamesConflictsAndMatchingStatus() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let importedHome = DisplayProfile.fixture(id: Self.officeID, name: "Home")
        let importedTravel = DisplayProfile.fixture(id: Self.travelID, name: "Travel", fingerprint: "MISSING|builtIn:false|count:1")
        let backup = ProfileBackupDocument(profiles: [importedHome, importedTravel])

        let preview = try ProfileImporter.preview(
            backup: backup,
            currentDocument: ProfileStoreDocument(profiles: [local]),
            currentFingerprint: local.displaySetupFingerprint
        )

        XCTAssertEqual(preview.profileCount, 2)
        XCTAssertEqual(preview.profileNames, ["Home", "Travel"])
        XCTAssertEqual(preview.conflicts.map(\.importedName), ["Home"])
        XCTAssertEqual(preview.matchingStatuses.map(\.matchesCurrentDisplaySetup), [true, false])
    }

    func testImportConflictStrategiesKeepBothReplaceOrSkip() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let imported = DisplayProfile.fixture(id: Self.officeID, name: "Home")
        let backup = ProfileBackupDocument(profiles: [imported])
        let current = ProfileStoreDocument(profiles: [local])

        let keepBoth = try ProfileImporter.importProfiles(
            from: backup,
            into: current,
            currentFingerprint: local.displaySetupFingerprint,
            conflictStrategy: .keepBoth
        )
        let replace = try ProfileImporter.importProfiles(
            from: backup,
            into: current,
            currentFingerprint: local.displaySetupFingerprint,
            conflictStrategy: .replaceExisting
        )
        let skip = try ProfileImporter.importProfiles(
            from: backup,
            into: current,
            currentFingerprint: local.displaySetupFingerprint,
            conflictStrategy: .skipConflict
        )

        XCTAssertEqual(keepBoth.profiles.map(\.name), ["Home", "Home 2"])
        XCTAssertNotEqual(keepBoth.profiles[1].id, imported.id)
        XCTAssertEqual(replace.profiles.map(\.id), [local.id])
        XCTAssertEqual(replace.profiles[0].name, "Home")
        XCTAssertEqual(skip.profiles, [local])
    }

    func testImportedNonMatchingProfilesAreMarkedAndNotAutomaticDefaults() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let imported = DisplayProfile.fixture(id: Self.officeID, name: "Travel", fingerprint: "MISSING|builtIn:false|count:1")
        let backup = ProfileBackupDocument(
            profiles: [imported],
            automaticDefaultRules: [
                AutomaticDefaultRule(displaySetupFingerprint: imported.displaySetupFingerprint, profileId: imported.id)
            ]
        )

        let result = try ProfileImporter.importProfiles(
            from: backup,
            into: ProfileStoreDocument(profiles: [local]),
            currentFingerprint: local.displaySetupFingerprint,
            conflictStrategy: .keepBoth
        )

        XCTAssertTrue(result.profiles[1].importedNeedsFirstApplyConfirmation)
        XCTAssertTrue(result.automaticDefaultRules.isEmpty)
    }

    func testFutureUnsupportedBackupSchemaIsRejectedClearly() throws {
        let backup = ProfileBackupDocument(schemaVersion: 999, profiles: [])

        XCTAssertThrowsError(try ProfileImporter.preview(
            backup: backup,
            currentDocument: ProfileStoreDocument(),
            currentFingerprint: nil
        )) { error in
            XCTAssertEqual(error as? ProfileImportExportError, .unsupportedFutureSchema(version: 999))
            XCTAssertTrue(error.localizedDescription.contains("Unsupported backup schema"))
        }
    }

    private static let homeID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let officeID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private static let travelID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
}

private extension DisplayProfile {
    static func fixture(id: UUID, name: String, fingerprint: String = "AAA|builtIn:false|count:1") -> DisplayProfile {
        DisplayProfile(
            id: id,
            name: name,
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: DisplaySetupFingerprint(rawValue: fingerprint),
            displaySummary: "27 inch external screen"
        )
    }
}

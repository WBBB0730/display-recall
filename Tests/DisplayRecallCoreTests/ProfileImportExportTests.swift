import XCTest
@testable import DisplayRecallCore

final class ProfileImportExportTests: XCTestCase {
    func testExportsAllProfilesAndSettingsWithoutLogsOrRestorePoints() throws {
        let home = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let office = DisplayProfile.fixture(id: Self.officeID, name: "Office", fingerprint: "OFFICE|builtIn:false|count:2")
        let homeGroup = DisplaySetupGroup(
            id: Self.homeGroupID,
            fingerprint: home.displaySetupFingerprint,
            name: "Desk"
        )
        let document = ProfileStoreDocument(
            profiles: [home, office],
            automaticDefaultRules: [
                AutomaticDefaultRule(displaySetupFingerprint: home.displaySetupFingerprint, profileId: home.id)
            ],
            displaySetupGroups: [homeGroup]
        )
        let settings = AppSettings(setupCompleted: true, automaticApplyCountdownSeconds: 5)

        let backup = ProfileExporter.export(document: document, settings: settings, selection: .all)
        let data = try JSONEncoder().encode(backup)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(backup.profiles.map(\.name), ["Home", "Office"])
        XCTAssertEqual(backup.settings, settings)
        XCTAssertEqual(backup.automaticDefaultRules.count, 1)
        XCTAssertEqual(backup.displaySetupGroups, [homeGroup])
        XCTAssertFalse(json.contains("activity-log"))
        XCTAssertFalse(json.contains("restore"))
    }

    func testExportsSelectedSingleAndMultipleProfilesWithSameBackupFormat() {
        let home = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let office = DisplayProfile.fixture(id: Self.officeID, name: "Office", fingerprint: "OFFICE|builtIn:false|count:2")
        let travel = DisplayProfile.fixture(id: Self.travelID, name: "Travel")
        let officeGroup = DisplaySetupGroup(
            id: Self.officeGroupID,
            fingerprint: office.displaySetupFingerprint,
            name: "Office displays"
        )
        let document = ProfileStoreDocument(
            profiles: [home, office, travel],
            displaySetupGroups: [officeGroup]
        )

        let single = ProfileExporter.export(document: document, settings: nil, selection: .single(office.id))
        let multiple = ProfileExporter.export(
            document: document,
            settings: nil,
            selection: .multiple([travel.id, home.id])
        )

        XCTAssertEqual(single.profiles.map(\.name), ["Office"])
        XCTAssertEqual(single.displaySetupGroups, [officeGroup])
        XCTAssertEqual(multiple.profiles.map(\.name), ["Home", "Travel"])
        XCTAssertTrue(multiple.displaySetupGroups.isEmpty)
        XCTAssertEqual(single.schemaVersion, multiple.schemaVersion)
    }

    func testImportSupportsLegacyBackupDocumentsAndPreservesHiddenFields() throws {
        let rawCommand = #"displayplacer "id:AAA res:1280x720 enabled:true origin:(0,0) degree:0""#
        let json = """
        {
          "schemaVersion": 1,
          "appVersion": "0.1.1",
          "exportedAt": "2026-05-15T00:00:00Z",
          "profiles": [
            {
              "schemaVersion": 1,
              "id": "\(Self.homeID.uuidString)",
              "name": "Home",
              "notes": "Hidden note",
              "command": "\(rawCommand.replacingOccurrences(of: "\"", with: "\\\""))",
              "displaySetupFingerprint": {
                "rawValue": "AAA|builtIn:false|count:1"
              },
              "displaySummary": "Hidden summary",
              "backendVersion": "1.4.0",
              "createdByAppVersion": "0.1.1",
              "updatedByAppVersion": "0.1.1",
              "isCommandEdited": true,
              "importedNeedsFirstApplyConfirmation": false,
              "createdAt": "2026-05-15T00:00:00Z",
              "updatedAt": "2026-05-15T00:00:00Z"
            }
          ],
          "automaticDefaultRules": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(ProfileBackupDocument.self, from: Data(json.utf8))

        let result = try ProfileImporter.importProfiles(
            from: backup,
            into: ProfileStoreDocument(),
            currentFingerprint: DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1"),
            conflictStrategy: .keepBoth,
            importAsNew: false
        )

        XCTAssertTrue(backup.displaySetupGroups.isEmpty)
        XCTAssertEqual(result.profiles[0].notes, "Hidden note")
        XCTAssertEqual(result.profiles[0].command, rawCommand)
        XCTAssertTrue(result.profiles[0].isCommandEdited)
        XCTAssertEqual(result.displaySetupGroups.map(\.fingerprint), [result.profiles[0].displaySetupFingerprint])
    }

    func testImportMergesExportedDisplaySetupGroups() throws {
        let localFingerprint = DisplaySetupFingerprint(rawValue: "LOCAL|builtIn:true|count:1")
        let importedFingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let localGroup = DisplaySetupGroup(id: Self.homeGroupID, fingerprint: localFingerprint, name: "Laptop")
        let importedGroup = DisplaySetupGroup(id: Self.officeGroupID, fingerprint: importedFingerprint, name: "Office")
        let importedProfile = DisplayProfile.fixture(id: Self.officeID, name: "Office", fingerprint: importedFingerprint.rawValue)
        let backup = ProfileBackupDocument(
            profiles: [importedProfile],
            displaySetupGroups: [importedGroup]
        )

        let result = try ProfileImporter.importProfiles(
            from: backup,
            into: ProfileStoreDocument(displaySetupGroups: [localGroup]),
            currentFingerprint: importedFingerprint,
            conflictStrategy: .keepBoth,
            importAsNew: false
        )

        XCTAssertEqual(result.displaySetupGroups, [localGroup, importedGroup])
    }

    func testExportPreviewShowsCountAndNamesForSelectedProfiles() {
        let home = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let office = DisplayProfile.fixture(id: Self.officeID, name: "Office")
        let travel = DisplayProfile.fixture(id: Self.travelID, name: "Travel")
        let document = ProfileStoreDocument(profiles: [home, office, travel])

        let preview = ProfileExporter.preview(
            document: document,
            selection: .multiple([travel.id, home.id])
        )

        XCTAssertEqual(preview.profileCount, 2)
        XCTAssertEqual(preview.profileNames, ["Home", "Travel"])
    }

    func testImportPreviewTreatsSameNameDifferentUUIDProfilesAsNonConflicting() throws {
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
        XCTAssertTrue(preview.conflicts.isEmpty)
        XCTAssertEqual(preview.matchingStatuses.map(\.matchesCurrentDisplaySetup), [true, false])
    }

    func testImportPreviewConfirmationSummaryOnlyIncludesCountsNeededForConfirmation() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let importedHome = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let importedTravel = DisplayProfile.fixture(id: Self.travelID, name: "Travel", fingerprint: "MISSING|builtIn:false|count:1")
        let backup = ProfileBackupDocument(profiles: [importedHome, importedTravel])

        let preview = try ProfileImporter.preview(
            backup: backup,
            currentDocument: ProfileStoreDocument(profiles: [local]),
            currentFingerprint: local.displaySetupFingerprint
        )
        let summary = ImportPreviewConfirmationSummary(preview: preview)

        XCTAssertEqual(summary.profileCount, 2)
        XCTAssertEqual(summary.conflictCount, 1)
        XCTAssertTrue(summary.showsConflictStrategy)
    }

    func testImportPreviewConfirmationSummaryHidesConflictStrategyWhenNoConflictsExist() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let imported = DisplayProfile.fixture(id: Self.officeID, name: "Office")
        let backup = ProfileBackupDocument(profiles: [imported])

        let preview = try ProfileImporter.preview(
            backup: backup,
            currentDocument: ProfileStoreDocument(profiles: [local]),
            currentFingerprint: local.displaySetupFingerprint
        )
        let summary = ImportPreviewConfirmationSummary(preview: preview)

        XCTAssertEqual(summary.profileCount, 1)
        XCTAssertEqual(summary.conflictCount, 0)
        XCTAssertFalse(summary.showsConflictStrategy)
    }

    func testImportConflictStrategiesUseUUIDAndKeepNamesUnchanged() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let imported = DisplayProfile.fixture(id: Self.homeID, name: "Home")
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

        XCTAssertEqual(keepBoth.profiles.map(\.name), ["Home", "Home"])
        XCTAssertEqual(keepBoth.profiles[0].id, local.id)
        XCTAssertNotEqual(keepBoth.profiles[1].id, imported.id)
        XCTAssertEqual(replace.profiles.map(\.id), [imported.id])
        XCTAssertEqual(replace.profiles[0].name, "Home")
        XCTAssertEqual(skip.profiles, [local])
    }

    func testSkipConflictOnlySkipsProfilesWithDuplicateUUIDs() throws {
        let local = DisplayProfile.fixture(id: Self.homeID, name: "Home")
        let duplicate = DisplayProfile.fixture(id: Self.homeID, name: "Home imported")
        let newProfile = DisplayProfile.fixture(id: Self.officeID, name: "Home")
        let backup = ProfileBackupDocument(profiles: [duplicate, newProfile])

        let result = try ProfileImporter.importProfiles(
            from: backup,
            into: ProfileStoreDocument(profiles: [local]),
            currentFingerprint: local.displaySetupFingerprint,
            conflictStrategy: .skipConflict
        )

        XCTAssertEqual(result.profiles.map(\.id), [local.id, newProfile.id])
        XCTAssertEqual(result.profiles.map(\.name), ["Home", "Home"])
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
    private static let homeGroupID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    private static let officeGroupID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
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

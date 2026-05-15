import XCTest
@testable import DisplayRecallCore

final class ProfileManagementTests: XCTestCase {
    func testSaveCurrentLayoutCreatesProfileWithGeneratedNameAndSummary() throws {
        var manager = ProfileManager(document: ProfileStoreDocument())
        let layout = try CurrentDisplayLayoutParser.parse(Self.displayListOutput)

        let updated = try manager.saveCurrentLayout(layout)

        XCTAssertEqual(updated.profiles.count, 1)
        XCTAssertEqual(updated.profiles[0].name, "27 inch external screen")
        XCTAssertEqual(updated.profiles[0].command, layout.command)
        XCTAssertEqual(updated.profiles[0].displaySummary, layout.displaySummary)
    }

    func testSaveCurrentLayoutCanUseEditedNameAndMakeAutomaticDefault() throws {
        var manager = ProfileManager(document: ProfileStoreDocument())
        let layout = try CurrentDisplayLayoutParser.parse(Self.displayListOutput)

        let updated = try manager.saveCurrentLayout(
            layout,
            name: "配置 1",
            makeAutomaticDefault: true
        )

        XCTAssertEqual(updated.profiles[0].name, "配置 1")
        XCTAssertEqual(updated.automaticDefaultRules.first?.profileId, updated.profiles[0].id)
        XCTAssertEqual(updated.automaticDefaultRules.first?.displaySetupFingerprint, layout.displaySetupFingerprint)
    }

    func testSaveCurrentLayoutLazilyCreatesDisplaySetupGroup() throws {
        var manager = ProfileManager(document: ProfileStoreDocument())
        let layout = try CurrentDisplayLayoutParser.parse(Self.displayListOutput)

        let updated = try manager.saveCurrentLayout(
            layout,
            name: "配置 1",
            displaySetupGroupLanguage: .simplifiedChinese
        )

        XCTAssertEqual(updated.profiles.count, 1)
        XCTAssertEqual(updated.displaySetupGroups.count, 1)
        XCTAssertEqual(updated.displaySetupGroups[0].fingerprint, layout.displaySetupFingerprint)
        XCTAssertEqual(updated.displaySetupGroups[0].name, "显示器组合 1")
    }

    func testSaveCurrentLayoutReusesExistingDisplaySetupGroup() throws {
        let layout = try CurrentDisplayLayoutParser.parse(Self.displayListOutput)
        let existingGroup = DisplaySetupGroup(
            fingerprint: layout.displaySetupFingerprint,
            name: "Office"
        )
        var manager = ProfileManager(document: ProfileStoreDocument(displaySetupGroups: [existingGroup]))

        let updated = try manager.saveCurrentLayout(layout, name: "Desk")

        XCTAssertEqual(updated.profiles.count, 1)
        XCTAssertEqual(updated.displaySetupGroups, [existingGroup])
    }

    func testRenameNotesAndAdvancedCommandValidation() throws {
        let profile = DisplayProfile.fixture()
        var manager = ProfileManager(document: ProfileStoreDocument(profiles: [profile]))

        try manager.rename(profileID: profile.id, to: "Office")
        try manager.updateNotes(profileID: profile.id, notes: "Standing desk")
        try manager.updateCommand(
            profileID: profile.id,
            command: #"displayplacer "id:BBB res:1280x720 enabled:true origin:(0,0) degree:0""#
        )

        let updated = manager.document.profiles[0]
        XCTAssertEqual(updated.name, "Office")
        XCTAssertEqual(updated.notes, "Standing desk")
        XCTAssertEqual(updated.command, #"displayplacer "id:BBB res:1280x720 enabled:true origin:(0,0) degree:0""#)
        XCTAssertThrowsError(try manager.updateCommand(profileID: profile.id, command: "not a command"))
    }

    func testDefaultRuleCanBeMarkedUnmarkedAndProfileCanBeRebound() throws {
        let profile = DisplayProfile.fixture()
        let newFingerprint = DisplaySetupFingerprint(rawValue: "BBB|builtIn:false|count:1")
        var manager = ProfileManager(document: ProfileStoreDocument(profiles: [profile]))

        try manager.setAutomaticDefault(profileID: profile.id, for: newFingerprint)
        XCTAssertEqual(manager.document.automaticDefaultRules.first?.profileId, profile.id)
        XCTAssertEqual(manager.document.automaticDefaultRules.first?.displaySetupFingerprint, newFingerprint)

        try manager.rebind(profileID: profile.id, to: newFingerprint, displaySummary: "Office display")
        XCTAssertEqual(manager.document.profiles[0].displaySetupFingerprint, newFingerprint)
        XCTAssertEqual(manager.document.profiles[0].displaySummary, "Office display")

        manager.clearAutomaticDefault(for: newFingerprint)
        XCTAssertTrue(manager.document.automaticDefaultRules.isEmpty)
    }

    func testAutomaticApplySwitchAllowsOneProfilePerDisplaySetupGroup() throws {
        let fingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let otherFingerprint = DisplaySetupFingerprint(rawValue: "BBB|builtIn:true|count:1")
        let first = DisplayProfile.fixture(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "First",
            fingerprint: fingerprint
        )
        let second = DisplayProfile.fixture(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Second",
            fingerprint: fingerprint
        )
        let other = DisplayProfile.fixture(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Other",
            fingerprint: otherFingerprint
        )
        var manager = ProfileManager(document: ProfileStoreDocument(profiles: [first, second, other]))

        try manager.setAutomaticApply(profileID: first.id, isEnabled: true)
        try manager.setAutomaticApply(profileID: second.id, isEnabled: true)
        try manager.setAutomaticApply(profileID: other.id, isEnabled: true)

        XCTAssertEqual(manager.document.automaticDefaultRules.map(\.profileId), [second.id, other.id])
        XCTAssertTrue(manager.isAutomaticApplyEnabled(for: second.id))
        XCTAssertTrue(manager.isAutomaticApplyEnabled(for: other.id))
        XCTAssertFalse(manager.isAutomaticApplyEnabled(for: first.id))

        try manager.setAutomaticApply(profileID: second.id, isEnabled: false)

        XCTAssertEqual(manager.document.automaticDefaultRules.map(\.profileId), [other.id])
    }

    func testApplyProfileRunsParsedDisplayplacerArgumentsThroughBackendRunner() async throws {
        let profile = DisplayProfile.fixture(
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0" "id:BBB res:1280x720 enabled:true origin:(1920,0) degree:90""#
        )
        let manager = ProfileManager(document: ProfileStoreDocument(profiles: [profile]))

        let result = try await manager.apply(profile) { arguments in
            XCTAssertEqual(arguments, [
                "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0",
                "id:BBB res:1280x720 enabled:true origin:(1920,0) degree:90"
            ])
            return DisplayplacerBackendRunResult(
                stdout: "ok",
                stderr: "",
                exitCode: 0,
                backendPath: "/bin/displayplacer",
                backendArchitecture: .appleSilicon,
                backendVersion: "1.4.0",
                backendSource: .bundled
            )
        }

        XCTAssertEqual(result.stdout, "ok")
    }

    func testSearchProfilesMatchesNameNotesAndDisplaySummary() {
        let home = DisplayProfile.fixture(name: "Home", notes: "Standing desk", summary: "27 inch external screen")
        let travel = DisplayProfile.fixture(name: "Travel", notes: "Hotel", summary: "Built-in display")

        XCTAssertEqual(ProfileListFilter.filter([home, travel], query: "hotel").map(\.name), ["Travel"])
        XCTAssertEqual(ProfileListFilter.filter([home, travel], query: "27 inch").map(\.name), ["Home"])
        XCTAssertEqual(ProfileListFilter.filter([home, travel], query: "").map(\.name), ["Home", "Travel"])
    }

    func testDeleteProfileCleansDefaultRulesShortcutsAndCreatesLogEntry() throws {
        let profile = DisplayProfile.fixture()
        let other = DisplayProfile.fixture(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Other"
        )
        let deletion = try ProfileDeletion.delete(
            profileID: profile.id,
            profilesDocument: ProfileStoreDocument(
                profiles: [profile, other],
                automaticDefaultRules: [
                    AutomaticDefaultRule(
                        displaySetupFingerprint: profile.displaySetupFingerprint,
                        profileId: profile.id
                    )
                ]
            ),
            settings: AppSettings(shortcutBindings: [
                ShortcutBinding(profileId: profile.id, keyEquivalent: "⌘⇧1"),
                ShortcutBinding(profileId: other.id, keyEquivalent: "⌘⇧2")
            ])
        )

        XCTAssertEqual(deletion.profilesDocument.profiles, [other])
        XCTAssertTrue(deletion.profilesDocument.automaticDefaultRules.isEmpty)
        XCTAssertEqual(deletion.settings.shortcutBindings.map(\.profileId), [other.id])
        XCTAssertEqual(deletion.logEntry.type, .profileDeleted)
        XCTAssertEqual(deletion.nextSelectedProfileID, other.id)
    }

    private static let displayListOutput = """
    Persistent screen id: AAA
    Type: 27 inch external screen
    Resolution: 1920x1080
    Hertz: 60
    Scaling: on
    Origin: (0,0) - main display
    Rotation: 0
    Enabled: true

    displayplacer "id:AAA res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0"
    """
}

private extension DisplayProfile {
    static func fixture(
        id: UUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: String = "Home",
        notes: String = "",
        command: String = #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
        summary: String = "27 inch external screen",
        fingerprint: DisplaySetupFingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
    ) -> DisplayProfile {
        DisplayProfile(
            id: id,
            name: name,
            notes: notes,
            command: command,
            displaySetupFingerprint: fingerprint,
            displaySummary: summary
        )
    }
}

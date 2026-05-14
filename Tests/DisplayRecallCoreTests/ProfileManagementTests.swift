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

    func testApplyProfileRunsRawCommandThroughBackendRunner() async throws {
        let profile = DisplayProfile.fixture()
        let manager = ProfileManager(document: ProfileStoreDocument(profiles: [profile]))

        let result = try await manager.apply(profile) { arguments in
            XCTAssertEqual(arguments, [profile.command])
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
    static func fixture() -> DisplayProfile {
        DisplayProfile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Home",
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1"),
            displaySummary: "27 inch external screen"
        )
    }
}

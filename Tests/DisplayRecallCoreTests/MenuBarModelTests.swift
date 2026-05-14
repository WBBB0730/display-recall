import XCTest
@testable import DisplayRecallCore

final class MenuBarModelTests: XCTestCase {
    func testMenuModelPrioritizesMatchingProfilesAndMarksDefault() {
        let fingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let matching = DisplayProfile.fixture(name: "Home", fingerprint: fingerprint)
        let other = DisplayProfile.fixture(name: "Office", fingerprint: DisplaySetupFingerprint(rawValue: "BBB|builtIn:false|count:1"))
        let document = ProfileStoreDocument(
            profiles: [other, matching],
            automaticDefaultRules: [
                AutomaticDefaultRule(displaySetupFingerprint: fingerprint, profileId: matching.id)
            ]
        )

        let model = MenuBarModel.build(
            document: document,
            currentFingerprint: fingerprint,
            automationStatus: .enabled
        )

        XCTAssertEqual(model.matchingProfiles.map(\.profile.id), [matching.id])
        XCTAssertEqual(model.otherProfiles.map(\.profile.id), [other.id])
        XCTAssertTrue(model.matchingProfiles[0].isAutomaticDefault)
        XCTAssertEqual(model.statusTitle, "Automation On")
    }

    func testMenuIconStatesCoverRequiredStatuses() {
        XCTAssertEqual(MenuBarIconState.normal.systemImage, "display.2")
        XCTAssertEqual(MenuBarIconState.paused.systemImage, "pause.circle")
        XCTAssertEqual(MenuBarIconState.pending.systemImage, "timer")
        XCTAssertEqual(MenuBarIconState.error.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(MenuBarIconState.setupRequired.systemImage, "wrench.and.screwdriver")
    }

    func testNonMatchingMenuProfileIsHighRiskCandidate() {
        let fingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let other = DisplayProfile.fixture(name: "Office", fingerprint: DisplaySetupFingerprint(rawValue: "BBB|builtIn:false|count:1"))

        let item = MenuBarProfileItem(profile: other, currentFingerprint: fingerprint, isAutomaticDefault: false)

        XCTAssertFalse(item.matchesCurrentDisplaySetup)
        XCTAssertTrue(item.requiresHighRiskApply)
    }
}

private extension DisplayProfile {
    static func fixture(name: String, fingerprint: DisplaySetupFingerprint) -> DisplayProfile {
        DisplayProfile(
            name: name,
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: fingerprint,
            displaySummary: name
        )
    }
}

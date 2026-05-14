import XCTest
@testable import DisplayRecallCore

final class RiskAndRestoreTests: XCTestCase {
    func testRiskClassifierMarksRequiredHighRiskConditions() throws {
        let currentIDs = Set(["AAA"])
        let safe = DisplayProfile.fixture(command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#)
        let missing = DisplayProfile.fixture(command: #"displayplacer "id:BBB res:1920x1080 enabled:true origin:(0,0) degree:0""#)
        let disabled = DisplayProfile.fixture(command: #"displayplacer "id:AAA res:1920x1080 enabled:false origin:(0,0) degree:0""#)
        var edited = safe
        edited.isCommandEdited = true
        var imported = safe
        imported.importedNeedsFirstApplyConfirmation = true

        XCTAssertEqual(RiskClassifier.classify(profile: safe, currentFingerprint: safe.displaySetupFingerprint, currentDisplayIDs: currentIDs), .normal)
        XCTAssertTrue(RiskClassifier.classify(profile: missing, currentFingerprint: missing.displaySetupFingerprint, currentDisplayIDs: currentIDs).isHighRisk)
        XCTAssertTrue(RiskClassifier.classify(profile: disabled, currentFingerprint: disabled.displaySetupFingerprint, currentDisplayIDs: currentIDs).isHighRisk)
        XCTAssertTrue(RiskClassifier.classify(profile: edited, currentFingerprint: edited.displaySetupFingerprint, currentDisplayIDs: currentIDs).isHighRisk)
        XCTAssertTrue(RiskClassifier.classify(profile: imported, currentFingerprint: imported.displaySetupFingerprint, currentDisplayIDs: currentIDs).isHighRisk)
    }

    func testRestorePointCapturesLatestLayoutAndSupportsUndoRestore() {
        let before = RestorePoint(command: "before", capturedAt: Date(timeIntervalSince1970: 1))
        let after = RestorePoint(command: "after", capturedAt: Date(timeIntervalSince1970: 2))
        var manager = RestorePointManager()

        manager.capture(before)
        XCTAssertEqual(manager.latest, before)

        manager.prepareUndoForRestore(currentLayout: after)
        XCTAssertEqual(manager.latest, after)
    }

    func testApplyPlannerCreatesRestorePointAndKeepRestorePromptOnlyForHighRiskSuccess() {
        let profile = DisplayProfile.fixture(command: #"displayplacer "id:AAA res:1920x1080 enabled:false origin:(0,0) degree:0""#)
        let plan = ProfileApplyPlanner.plan(
            profile: profile,
            risk: .high([.disablesDisplay]),
            currentLayoutCommand: "restore"
        )

        XCTAssertEqual(plan.restorePoint?.command, "restore")
        XCTAssertTrue(plan.requiresConfirmation)
        XCTAssertEqual(plan.keepRestorePromptSeconds, 15)

        let normalPlan = ProfileApplyPlanner.plan(
            profile: profile,
            risk: .normal,
            currentLayoutCommand: "restore"
        )
        XCTAssertFalse(normalPlan.requiresConfirmation)
        XCTAssertNil(normalPlan.keepRestorePromptSeconds)
    }

    func testFailureFeedbackIncludesManualRecoveryActionsAndStopsAutomaticFlow() {
        let feedback = ProfileApplyFailureFeedback(
            profileName: "Home",
            stderr: "boom",
            wasAutomatic: true
        )

        XCTAssertEqual(feedback.actions, [.restorePreviousLayout, .copyLog, .editProfile])
        XCTAssertTrue(feedback.shouldStopAutomaticFlow)
    }
}

private extension DisplayProfile {
    static func fixture(command: String) -> DisplayProfile {
        DisplayProfile(
            name: "Profile",
            command: command,
            displaySetupFingerprint: DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        )
    }
}

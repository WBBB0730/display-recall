import XCTest
@testable import DisplayRecallCore

final class AutomaticApplyCoordinatorTests: XCTestCase {
    func testDisplayChangeSchedulesFiveSecondPendingApplyWhenDefaultMatches() {
        let profile = DisplayProfile.fixture(name: "Home")
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 5)

        let state = coordinator.handleDisplayChange(
            document: ProfileStoreDocument(
                profiles: [profile],
                automaticDefaultRules: [
                    AutomaticDefaultRule(displaySetupFingerprint: profile.displaySetupFingerprint, profileId: profile.id)
                ]
            ),
            currentFingerprint: profile.displaySetupFingerprint,
            automationStatus: .enabled
        )

        XCTAssertEqual(state, .pending(profile: profile, remainingSeconds: 5, trigger: .displayChange))
    }

    func testZeroSecondDisplayChangeIsReadyToApplyImmediatelyWhenDefaultMatches() {
        let profile = DisplayProfile.fixture(name: "Home")
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 0)

        let state = coordinator.handleDisplayChange(
            document: ProfileStoreDocument(
                profiles: [profile],
                automaticDefaultRules: [
                    AutomaticDefaultRule(displaySetupFingerprint: profile.displaySetupFingerprint, profileId: profile.id)
                ]
            ),
            currentFingerprint: profile.displaySetupFingerprint,
            automationStatus: .enabled
        )

        XCTAssertEqual(state, .readyToApply(profile: profile, trigger: .displayChange))
    }

    func testDisplayChangeDoesNotScheduleWhenFingerprintDidNotChange() {
        let profile = DisplayProfile.fixture(name: "Home")
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 5)

        let state = coordinator.handleDisplayChange(
            document: ProfileStoreDocument(
                profiles: [profile],
                automaticDefaultRules: [
                    AutomaticDefaultRule(displaySetupFingerprint: profile.displaySetupFingerprint, profileId: profile.id)
                ]
            ),
            previousFingerprint: profile.displaySetupFingerprint,
            currentFingerprint: profile.displaySetupFingerprint,
            automationStatus: .enabled
        )

        XCTAssertEqual(state, .idle)
    }

    func testPendingPanelPresentationHasOnlyApplyNowAndStop() throws {
        let profile = DisplayProfile.fixture(name: "Home")
        let presentation = try PendingApplyPanelPresentation(
            state: .pending(profile: profile, remainingSeconds: 5, trigger: .displayChange)
        )

        XCTAssertEqual(presentation.profileName, "Home")
        XCTAssertEqual(presentation.remainingSeconds, 5)
        XCTAssertEqual(presentation.triggerTitle, "Display changed")
        XCTAssertEqual(presentation.actions, [.applyNow, .stop])
        XCTAssertFalse(presentation.actions.contains(.pause))
    }

    func testNoDefaultDoesNotGuessWhenMultipleProfilesMatch() {
        let first = DisplayProfile.fixture(name: "Work")
        let second = DisplayProfile.fixture(name: "Meeting")
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 5)

        let state = coordinator.handleDisplayChange(
            document: ProfileStoreDocument(profiles: [first, second], automaticDefaultRules: []),
            currentFingerprint: first.displaySetupFingerprint,
            automationStatus: .enabled
        )

        XCTAssertEqual(state, .needsChoice(matchingProfiles: [first, second]))
    }

    func testPausedAutomationIgnoresAutomaticTriggersButManualApplyCancelsPending() {
        let profile = DisplayProfile.fixture(name: "Home")
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 5)

        let pausedState = coordinator.handleDisplayChange(
            document: ProfileStoreDocument(profiles: [profile], automaticDefaultRules: []),
            currentFingerprint: profile.displaySetupFingerprint,
            automationStatus: .paused
        )
        XCTAssertEqual(pausedState, .idle)

        coordinator.state = .pending(profile: profile, remainingSeconds: 5, trigger: .displayChange)
        coordinator.cancelForManualApply()
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testCountdownCompletionRereadsFingerprintBeforeChoosingProfile() async throws {
        let old = DisplayProfile.fixture(name: "Old", fingerprint: DisplaySetupFingerprint(rawValue: "OLD|builtIn:false|count:1"))
        let fresh = DisplayProfile.fixture(name: "Fresh", fingerprint: DisplaySetupFingerprint(rawValue: "NEW|builtIn:false|count:1"))
        var coordinator = AutomaticApplyCoordinator(countdownSeconds: 5)
        coordinator.state = .pending(profile: old, remainingSeconds: 0, trigger: .startup)

        let selected = try await coordinator.completeCountdown(
            document: ProfileStoreDocument(
                profiles: [old, fresh],
                automaticDefaultRules: [
                    AutomaticDefaultRule(displaySetupFingerprint: fresh.displaySetupFingerprint, profileId: fresh.id)
                ]
            ),
            rereadFingerprint: { fresh.displaySetupFingerprint }
        )

        XCTAssertEqual(selected, fresh)
    }

    func testStartupUsesConfiguredStabilityDelay() {
        XCTAssertEqual(AutomaticApplyCoordinator.startupStabilitySeconds, 10)
    }
}

private extension DisplayProfile {
    static func fixture(
        name: String,
        fingerprint: DisplaySetupFingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
    ) -> DisplayProfile {
        DisplayProfile(
            name: name,
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: fingerprint,
            displaySummary: name
        )
    }
}

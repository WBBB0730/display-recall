import Foundation

public enum AutomaticApplyTrigger: Equatable, Sendable {
    case displayChange
    case startup
}

public enum AutomaticApplyState: Equatable, Sendable {
    case idle
    case pending(profile: DisplayProfile, remainingSeconds: Int, trigger: AutomaticApplyTrigger)
    case needsChoice(matchingProfiles: [DisplayProfile])
}

public struct AutomaticApplyCoordinator: Sendable {
    public static let startupStabilitySeconds = 10

    public var state: AutomaticApplyState = .idle
    public let countdownSeconds: Int

    public init(countdownSeconds: Int = 5) {
        self.countdownSeconds = countdownSeconds
    }

    @discardableResult
    public mutating func handleDisplayChange(
        document: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint,
        automationStatus: AutomationStatus
    ) -> AutomaticApplyState {
        schedule(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus,
            trigger: .displayChange
        )
    }

    @discardableResult
    public mutating func handleStartup(
        document: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint,
        automationStatus: AutomationStatus
    ) -> AutomaticApplyState {
        schedule(
            document: document,
            currentFingerprint: currentFingerprint,
            automationStatus: automationStatus,
            trigger: .startup
        )
    }

    public mutating func cancelForManualApply() {
        state = .idle
    }

    public mutating func stopPendingApply() {
        state = .idle
    }

    public mutating func pauseAutomation() {
        state = .idle
    }

    public mutating func completeCountdown(
        document: ProfileStoreDocument,
        rereadFingerprint: @Sendable () async throws -> DisplaySetupFingerprint
    ) async throws -> DisplayProfile? {
        guard case .pending = state else {
            return nil
        }

        let freshFingerprint = try await rereadFingerprint()
        state = .idle
        return automaticDefaultProfile(in: document, for: freshFingerprint)
    }

    @discardableResult
    private mutating func schedule(
        document: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint,
        automationStatus: AutomationStatus,
        trigger: AutomaticApplyTrigger
    ) -> AutomaticApplyState {
        guard automationStatus == .enabled else {
            state = .idle
            return state
        }

        let matchingProfiles = document.profiles.filter {
            $0.displaySetupFingerprint == currentFingerprint
        }

        if let defaultProfile = automaticDefaultProfile(in: document, for: currentFingerprint) {
            state = .pending(
                profile: defaultProfile,
                remainingSeconds: countdownSeconds,
                trigger: trigger
            )
        } else if matchingProfiles.count > 1 {
            state = .needsChoice(matchingProfiles: matchingProfiles)
        } else {
            state = .idle
        }

        return state
    }

    private func automaticDefaultProfile(
        in document: ProfileStoreDocument,
        for fingerprint: DisplaySetupFingerprint
    ) -> DisplayProfile? {
        guard let rule = document.automaticDefaultRules.first(where: {
            $0.displaySetupFingerprint == fingerprint
        }) else {
            return nil
        }

        return document.profiles.first { $0.id == rule.profileId }
    }
}

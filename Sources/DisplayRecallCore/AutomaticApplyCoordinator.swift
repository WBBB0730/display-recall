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

public enum PendingApplyPanelAction: Equatable, Sendable {
    case applyNow
    case stop
    case pause
}

public enum PendingApplyPanelError: Error, Equatable, Sendable {
    case notPending
}

public struct PendingApplyPanelPresentation: Equatable, Sendable {
    public let profileName: String
    public let remainingSeconds: Int
    public let triggerTitle: String
    public let actions: [PendingApplyPanelAction]

    public init(state: AutomaticApplyState) throws {
        guard case let .pending(profile, remainingSeconds, trigger) = state else {
            throw PendingApplyPanelError.notPending
        }

        self.profileName = profile.name
        self.remainingSeconds = remainingSeconds
        self.triggerTitle = switch trigger {
        case .displayChange:
            "Display changed"
        case .startup:
            "Startup"
        }
        self.actions = [.applyNow, .stop]
    }
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
        previousFingerprint: DisplaySetupFingerprint? = nil,
        currentFingerprint: DisplaySetupFingerprint,
        automationStatus: AutomationStatus
    ) -> AutomaticApplyState {
        if previousFingerprint == currentFingerprint {
            state = .idle
            return state
        }

        return schedule(
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

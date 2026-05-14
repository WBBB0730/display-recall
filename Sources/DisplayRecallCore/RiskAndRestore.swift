import Foundation

public enum ProfileApplyRiskReason: Equatable, Sendable {
    case editedCommand
    case importedFirstApply
    case nonMatchingDisplaySetup
    case missingDisplayIDs([String])
    case disablesDisplay
    case mirroredDisplay
    case invalidCommand
}

public enum ProfileApplyRisk: Equatable, Sendable {
    case normal
    case high([ProfileApplyRiskReason])

    public var isHighRisk: Bool {
        if case .high = self { return true }
        return false
    }
}

public enum RiskClassifier {
    public static func classify(
        profile: DisplayProfile,
        currentFingerprint: DisplaySetupFingerprint,
        currentDisplayIDs: Set<String>
    ) -> ProfileApplyRisk {
        var reasons: [ProfileApplyRiskReason] = []

        if profile.isCommandEdited {
            reasons.append(.editedCommand)
        }

        if profile.importedNeedsFirstApplyConfirmation {
            reasons.append(.importedFirstApply)
        }

        if profile.displaySetupFingerprint != currentFingerprint {
            reasons.append(.nonMatchingDisplaySetup)
        }

        guard let layout = try? DisplayCommandParser.parse(profile.command) else {
            return .high(reasons + [.invalidCommand])
        }

        let targetIDs = Set(layout.targets.flatMap(\.displayIDs))
        let missingIDs = targetIDs.subtracting(currentDisplayIDs).sorted()
        if !missingIDs.isEmpty {
            reasons.append(.missingDisplayIDs(missingIDs))
        }

        if layout.containsDisabledDisplay {
            reasons.append(.disablesDisplay)
        }

        if layout.targets.contains(where: \.isMirrored) {
            reasons.append(.mirroredDisplay)
        }

        return reasons.isEmpty ? .normal : .high(reasons)
    }
}

public struct RestorePoint: Equatable, Sendable, Codable {
    public let command: String
    public let capturedAt: Date

    public init(command: String, capturedAt: Date = Date()) {
        self.command = command
        self.capturedAt = capturedAt
    }
}

public struct RestorePointManager: Equatable, Sendable {
    public private(set) var latest: RestorePoint?

    public init(latest: RestorePoint? = nil) {
        self.latest = latest
    }

    public mutating func capture(_ restorePoint: RestorePoint) {
        latest = restorePoint
    }

    public mutating func prepareUndoForRestore(currentLayout: RestorePoint) {
        latest = currentLayout
    }
}

public struct ProfileApplyPlan: Equatable, Sendable {
    public let profile: DisplayProfile
    public let risk: ProfileApplyRisk
    public let restorePoint: RestorePoint?
    public let requiresConfirmation: Bool
    public let keepRestorePromptSeconds: Int?
}

public enum ProfileApplyPlanner {
    public static func plan(
        profile: DisplayProfile,
        risk: ProfileApplyRisk,
        currentLayoutCommand: String?
    ) -> ProfileApplyPlan {
        ProfileApplyPlan(
            profile: profile,
            risk: risk,
            restorePoint: currentLayoutCommand.map { RestorePoint(command: $0) },
            requiresConfirmation: risk.isHighRisk,
            keepRestorePromptSeconds: risk.isHighRisk ? 15 : nil
        )
    }
}

public enum ProfileApplyFailureAction: Equatable, Sendable {
    case restorePreviousLayout
    case copyLog
    case editProfile
}

public struct ProfileApplyFailureFeedback: Equatable, Sendable {
    public let profileName: String
    public let stderr: String
    public let wasAutomatic: Bool

    public init(profileName: String, stderr: String, wasAutomatic: Bool) {
        self.profileName = profileName
        self.stderr = stderr
        self.wasAutomatic = wasAutomatic
    }

    public var actions: [ProfileApplyFailureAction] {
        [.restorePreviousLayout, .copyLog, .editProfile]
    }

    public var shouldStopAutomaticFlow: Bool {
        wasAutomatic
    }
}

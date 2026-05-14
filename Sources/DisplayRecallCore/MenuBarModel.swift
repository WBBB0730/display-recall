import Foundation

public enum AutomationStatus: Equatable, Sendable {
    case enabled
    case paused

    public var title: String {
        switch self {
        case .enabled:
            "Automation On"
        case .paused:
            "Automation Paused"
        }
    }
}

public enum MenuBarIconState: Equatable, Sendable {
    case normal
    case paused
    case pending
    case error
    case setupRequired

    public var systemImage: String {
        switch self {
        case .normal:
            "display.2"
        case .paused:
            "pause.circle"
        case .pending:
            "timer"
        case .error:
            "exclamationmark.triangle"
        case .setupRequired:
            "wrench.and.screwdriver"
        }
    }
}

public struct MenuBarProfileItem: Equatable, Identifiable, Sendable {
    public var id: UUID { profile.id }
    public let profile: DisplayProfile
    public let currentFingerprint: DisplaySetupFingerprint?
    public let isAutomaticDefault: Bool

    public init(
        profile: DisplayProfile,
        currentFingerprint: DisplaySetupFingerprint?,
        isAutomaticDefault: Bool
    ) {
        self.profile = profile
        self.currentFingerprint = currentFingerprint
        self.isAutomaticDefault = isAutomaticDefault
    }

    public var matchesCurrentDisplaySetup: Bool {
        profile.displaySetupFingerprint == currentFingerprint
    }

    public var requiresHighRiskApply: Bool {
        !matchesCurrentDisplaySetup
    }
}

public struct MenuBarModel: Equatable, Sendable {
    public let statusTitle: String
    public let iconState: MenuBarIconState
    public let matchingProfiles: [MenuBarProfileItem]
    public let otherProfiles: [MenuBarProfileItem]

    public static func build(
        document: ProfileStoreDocument,
        currentFingerprint: DisplaySetupFingerprint?,
        automationStatus: AutomationStatus
    ) -> MenuBarModel {
        let items = document.profiles.map { profile in
            MenuBarProfileItem(
                profile: profile,
                currentFingerprint: currentFingerprint,
                isAutomaticDefault: document.automaticDefaultRules.contains {
                    $0.profileId == profile.id && $0.displaySetupFingerprint == profile.displaySetupFingerprint
                }
            )
        }

        return MenuBarModel(
            statusTitle: automationStatus.title,
            iconState: automationStatus == .paused ? .paused : .normal,
            matchingProfiles: items.filter(\.matchesCurrentDisplaySetup),
            otherProfiles: items.filter { !$0.matchesCurrentDisplaySetup }
        )
    }
}

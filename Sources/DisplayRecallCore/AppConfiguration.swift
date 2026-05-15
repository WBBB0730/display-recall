import Foundation

public enum AppConfiguration {
    public static let displayName = "Display Recall"
    public static let bundleIdentifier = "dev.wbbb.display-recall"
    public static let version = "0.1.0"
    public static let buildNumber = "1"
    public static let minimumSupportedMacOS = OperatingSystemVersion(
        majorVersion: 13,
        minorVersion: 0,
        patchVersion: 0
    )
    public static let runsAsMenuBarUtility = true
    public static let supportsDockIconVisibilityPreference = true
}

public enum AppMenuAction: String, CaseIterable, Equatable {
    case openDisplayRecall
    case openSettings
    case quit

    public var title: String {
        switch self {
        case .openDisplayRecall:
            "Open Display Recall"
        case .openSettings:
            "Settings"
        case .quit:
            "Quit Display Recall"
        }
    }

    public var targetSection: MainWindowSection? {
        switch self {
        case .openDisplayRecall:
            .profiles
        case .openSettings:
            .settings
        case .quit:
            nil
        }
    }
}

public enum AppWindow: String, CaseIterable, Equatable {
    case main

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .main:
            AppConfiguration.displayName
        }
    }
}

public enum MainWindowSection: String, CaseIterable, Equatable, Identifiable, Sendable {
    case profiles
    case activityLog
    case settings
    case about

    public static let `default` = MainWindowSection.profiles

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .profiles:
            "Profiles"
        case .activityLog:
            "Log"
        case .settings:
            "Settings"
        case .about:
            "About"
        }
    }

    public var systemImage: String {
        switch self {
        case .profiles:
            "display.2"
        case .activityLog:
            "list.bullet.rectangle"
        case .settings:
            "gearshape"
        case .about:
            "info.circle"
        }
    }
}

public enum DockIconPreference: String, Equatable, Sendable {
    case hidden
    case visible

    public static let defaultValue = DockIconPreference.hidden
    public static let userDefaultsKey = "showDockIcon"
}

public enum SetupPreference {
    public static let completedUserDefaultsKey = "setupCompleted"
}

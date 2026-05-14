import Foundation

public enum AppConfiguration {
    public static let displayName = "Display Recall"
    public static let bundleIdentifier = "dev.wbbb.display-recall"
    public static let minimumSupportedMacOS = OperatingSystemVersion(
        majorVersion: 13,
        minorVersion: 0,
        patchVersion: 0
    )
    public static let runsAsMenuBarUtility = true
    public static let supportsDockIconVisibilityPreference = true
}

public enum AppMenuAction: String, CaseIterable, Equatable {
    case openProfiles
    case openSettings
    case quit

    public var title: String {
        switch self {
        case .openProfiles:
            "Open Profiles"
        case .openSettings:
            "Settings"
        case .quit:
            "Quit Display Recall"
        }
    }
}

public enum AppWindow: String, CaseIterable, Equatable {
    case profiles

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .profiles:
            "Profiles"
        }
    }
}

public enum DockIconPreference: String, Equatable, Sendable {
    case hidden
    case visible

    public static let defaultValue = DockIconPreference.hidden
    public static let userDefaultsKey = "showDockIcon"
}

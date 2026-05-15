public struct AppBundleManifest: Equatable, Sendable {
    public let bundleName: String
    public let executableName: String
    public let bundleIdentifier: String
    public let iconFileName: String
    public let minimumSystemVersion: String
    public let localizations: [String]
    public let allowsMixedLocalizations: Bool
    public let launchesAsUIElement: Bool

    public static let `default` = AppBundleManifest(
        bundleName: AppConfiguration.displayName,
        executableName: "DisplayRecall",
        bundleIdentifier: AppConfiguration.bundleIdentifier,
        iconFileName: "AppIcon.icns",
        minimumSystemVersion: "13.0",
        localizations: ["en", "zh-Hans"],
        allowsMixedLocalizations: true,
        launchesAsUIElement: true
    )
}

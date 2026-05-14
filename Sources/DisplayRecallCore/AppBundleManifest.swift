public struct AppBundleManifest: Equatable, Sendable {
    public let bundleName: String
    public let executableName: String
    public let bundleIdentifier: String
    public let minimumSystemVersion: String

    public static let `default` = AppBundleManifest(
        bundleName: AppConfiguration.displayName,
        executableName: "DisplayRecall",
        bundleIdentifier: AppConfiguration.bundleIdentifier,
        minimumSystemVersion: "13.0"
    )
}

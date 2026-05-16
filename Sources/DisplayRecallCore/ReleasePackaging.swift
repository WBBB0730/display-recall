import Foundation

public enum DistributionChannel: String, Equatable, Sendable, Codable {
    case githubReleases
}

public enum SparkleUpdateChannel: String, Equatable, Sendable, Codable {
    case stable
}

public struct SparkleUpdatePolicy: Equatable, Sendable, Codable {
    public let channel: SparkleUpdateChannel
    public let feedURL: URL
    public let manualUpdateChecksEnabled: Bool
    public let automaticChecksAreUserOptional: Bool
    public let allowsSilentForcedInstallation: Bool
    public let requiresEdDSAUpdateSignatures: Bool

    public init(
        channel: SparkleUpdateChannel,
        feedURL: URL,
        manualUpdateChecksEnabled: Bool,
        automaticChecksAreUserOptional: Bool,
        allowsSilentForcedInstallation: Bool,
        requiresEdDSAUpdateSignatures: Bool
    ) {
        self.channel = channel
        self.feedURL = feedURL
        self.manualUpdateChecksEnabled = manualUpdateChecksEnabled
        self.automaticChecksAreUserOptional = automaticChecksAreUserOptional
        self.allowsSilentForcedInstallation = allowsSilentForcedInstallation
        self.requiresEdDSAUpdateSignatures = requiresEdDSAUpdateSignatures
    }

    public var infoPlistEntries: [String: String] {
        [
            "SUEnableAutomaticChecks": automaticChecksAreUserOptional ? "false" : "true",
            "SUFeedURL": feedURL.absoluteString,
            "SUPublicEDKey": "$(SPARKLE_PUBLIC_ED_KEY)"
        ]
    }
}

public struct ReleaseConfiguration: Equatable, Sendable {
    public let architectures: [DisplayplacerBackendArchitecture]
    public let requiresDeveloperIDSigning: Bool
    public let requiresNotarization: Bool
    public let distributionChannel: DistributionChannel
    public let artifactExtension: String
    public let backendManifest: [DisplayplacerBackendAsset]
    public let sparklePolicy: SparkleUpdatePolicy

    public init(
        architectures: [DisplayplacerBackendArchitecture],
        requiresDeveloperIDSigning: Bool,
        requiresNotarization: Bool,
        distributionChannel: DistributionChannel,
        artifactExtension: String,
        backendManifest: [DisplayplacerBackendAsset],
        sparklePolicy: SparkleUpdatePolicy
    ) {
        self.architectures = architectures
        self.requiresDeveloperIDSigning = requiresDeveloperIDSigning
        self.requiresNotarization = requiresNotarization
        self.distributionChannel = distributionChannel
        self.artifactExtension = artifactExtension
        self.backendManifest = backendManifest
        self.sparklePolicy = sparklePolicy
    }

    public static func production() -> ReleaseConfiguration {
        ReleaseConfiguration(
            architectures: [.appleSilicon, .intel],
            requiresDeveloperIDSigning: true,
            requiresNotarization: true,
            distributionChannel: .githubReleases,
            artifactExtension: "dmg",
            backendManifest: [
                DisplayplacerBackend.bundledMetadata.appleSiliconAsset,
                DisplayplacerBackend.bundledMetadata.intelAsset
            ],
            sparklePolicy: SparkleUpdatePolicy(
                channel: .stable,
                feedURL: URL(string: "https://github.com/wbbb/display-recall/releases/latest/download/appcast.xml")!,
                manualUpdateChecksEnabled: true,
                automaticChecksAreUserOptional: true,
                allowsSilentForcedInstallation: false,
                requiresEdDSAUpdateSignatures: true
            )
        )
    }
}

public struct AboutMetadata: Equatable, Sendable {
    public let appName: String
    public let version: String
    public let build: String

    public init(appName: String, version: String, build: String) {
        self.appName = appName
        self.version = version
        self.build = build
    }

    public static func current(build: String = AppConfiguration.buildNumber) -> AboutMetadata {
        AboutMetadata(
            appName: AppConfiguration.displayName,
            version: AppConfiguration.version,
            build: build
        )
    }

    public var displayString: String {
        "\(appName) \(version) (\(build))"
    }
}

public enum ReleaseReadinessStep: Equatable, Sendable {
    case buildUniversal2
    case signWithDeveloperID
    case notarize
    case packageGitHubReleaseArtifact
    case signSparkleUpdate
    case generateSparkleAppcast
    case publishGitHubReleaseArtifact
}

public struct ReleaseReadinessChecklist: Equatable, Sendable {
    public let requiresMacAppStoreReceipt: Bool
    public let steps: [ReleaseReadinessStep]

    public init(requiresMacAppStoreReceipt: Bool, steps: [ReleaseReadinessStep]) {
        self.requiresMacAppStoreReceipt = requiresMacAppStoreReceipt
        self.steps = steps
    }

    public static func production() -> ReleaseReadinessChecklist {
        ReleaseReadinessChecklist(
            requiresMacAppStoreReceipt: false,
            steps: [
                .buildUniversal2,
                .signWithDeveloperID,
                .notarize,
                .packageGitHubReleaseArtifact,
                .signSparkleUpdate,
                .generateSparkleAppcast,
                .publishGitHubReleaseArtifact
            ]
        )
    }
}

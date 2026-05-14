import Foundation

public enum ModificationStatus: String, Equatable, Sendable, Codable {
    case unmodifiedBinary
    case sourceDependency

    public var title: String {
        switch self {
        case .unmodifiedBinary:
            "Unmodified official release binaries"
        case .sourceDependency:
            "Source dependency"
        }
    }
}

public struct ThirdPartyAcknowledgement: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let name: String
    public let version: String
    public let projectURL: URL
    public let licenseName: String
    public let modificationStatus: ModificationStatus

    public init(
        id: String,
        name: String,
        version: String,
        projectURL: URL,
        licenseName: String,
        modificationStatus: ModificationStatus
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.projectURL = projectURL
        self.licenseName = licenseName
        self.modificationStatus = modificationStatus
    }
}

public struct AcknowledgementsCatalog: Equatable, Sendable, Codable {
    public let independenceNotice: String
    public let items: [ThirdPartyAcknowledgement]

    public init(independenceNotice: String, items: [ThirdPartyAcknowledgement]) {
        self.independenceNotice = independenceNotice
        self.items = items
    }

    public static func current() -> AcknowledgementsCatalog {
        AcknowledgementsCatalog(
            independenceNotice: "Display Recall is an independent companion for displayplacer. It is not an official displayplacer app.",
            items: [
                ThirdPartyAcknowledgement(
                    id: "displayplacer",
                    name: "displayplacer",
                    version: DisplayplacerBackend.bundledMetadata.version,
                    projectURL: URL(string: "https://github.com/jakehilborn/displayplacer")!,
                    licenseName: "MIT",
                    modificationStatus: .unmodifiedBinary
                ),
                ThirdPartyAcknowledgement(
                    id: "sparkle",
                    name: "Sparkle",
                    version: "2",
                    projectURL: URL(string: "https://sparkle-project.org")!,
                    licenseName: "MIT",
                    modificationStatus: .sourceDependency
                )
            ]
        )
    }
}

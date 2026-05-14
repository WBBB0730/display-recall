import Foundation

public enum DisplayParsingError: Error, Equatable, Sendable {
    case missingDisplayplacerCommand
}

public struct DisplaySetup: Equatable, Sendable {
    public let displays: [ParsedDisplay]
    public let fingerprint: DisplaySetupFingerprint
    public let currentCommand: String?

    public var hasBuiltInDisplay: Bool {
        displays.contains(where: \.isBuiltIn)
    }

    public var enabledDisplayCount: Int {
        displays.filter(\.enabled).count
    }

    public var summary: String {
        let countText = displays.count == 1 ? "1 display" : "\(displays.count) displays"
        let displayText = displays
            .map { display in
                let shortID = String(display.persistentID.suffix(6))
                return "\(display.type) \(shortID) \(display.resolution ?? "unknown")"
            }
            .joined(separator: " + ")
        return "\(countText): \(displayText)"
    }
}

public struct ParsedDisplay: Equatable, Sendable {
    public var persistentID: String
    public var contextualID: String?
    public var serialID: String?
    public var type: String
    public var resolution: String?
    public var hertz: Int?
    public var scaling: String?
    public var origin: String?
    public var rotation: Int?
    public var enabled: Bool
    public var isPrimary: Bool

    public var isBuiltIn: Bool {
        type.localizedCaseInsensitiveContains("built-in")
    }
}

public struct ParsedDisplayLayout: Equatable, Sendable {
    public let command: String
    public let targets: [ParsedDisplayTarget]
    public let fingerprint: DisplaySetupFingerprint

    public var containsDisabledDisplay: Bool {
        targets.contains { $0.enabled == false }
    }
}

public struct ParsedDisplayTarget: Equatable, Sendable {
    public var displayIDs: [String]
    public var resolution: String?
    public var enabled: Bool?
    public var scaling: String?
    public var origin: String?
    public var degree: Int?

    public var isMirrored: Bool {
        displayIDs.count > 1
    }
}

public enum DisplayListParser {
    public static func parse(_ output: String) throws -> DisplaySetup {
        let displays = output
            .components(separatedBy: "\n\n")
            .compactMap(parseDisplayBlock)

        let ids = displays
            .filter(\.enabled)
            .map(\.persistentID)
            .sorted()
        let fingerprint = DisplaySetupFingerprint(
            rawValue: "\(ids.joined(separator: "+"))|builtIn:\(displays.contains(where: \.isBuiltIn))|count:\(ids.count)"
        )

        return DisplaySetup(
            displays: displays,
            fingerprint: fingerprint,
            currentCommand: output
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .last { $0.hasPrefix("displayplacer ") }
        )
    }

    private static func parseDisplayBlock(_ block: String) -> ParsedDisplay? {
        let fields = Dictionary(
            uniqueKeysWithValues: block
                .split(separator: "\n")
                .compactMap { line -> (String, String)? in
                    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return nil }
                    return (
                        parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                        parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
        )

        guard let persistentID = fields["Persistent screen id"] else {
            return nil
        }

        let originText = fields["Origin"]
        return ParsedDisplay(
            persistentID: persistentID,
            contextualID: fields["Contextual screen id"],
            serialID: fields["Serial screen id"],
            type: fields["Type"] ?? "Unknown display",
            resolution: fields["Resolution"],
            hertz: fields["Hertz"].flatMap(Int.init),
            scaling: fields["Scaling"],
            origin: originText?.components(separatedBy: " - ").first,
            rotation: fields["Rotation"].flatMap(Int.init),
            enabled: fields["Enabled"].map { $0 == "true" } ?? true,
            isPrimary: originText?.contains("main display") ?? false
        )
    }
}

public enum DisplayCommandParser {
    public static func parse(_ command: String) throws -> ParsedDisplayLayout {
        guard command.hasPrefix("displayplacer ") else {
            throw DisplayParsingError.missingDisplayplacerCommand
        }

        let targets = command
            .components(separatedBy: "\"")
            .filter { $0.hasPrefix("id:") }
            .map(parseTarget)

        if targets.isEmpty {
            throw DisplayParsingError.missingDisplayplacerCommand
        }

        let ids = targets
            .flatMap(\.displayIDs)
            .sorted()

        return ParsedDisplayLayout(
            command: command,
            targets: targets,
            fingerprint: DisplaySetupFingerprint(
                rawValue: "\(ids.joined(separator: "+"))|builtIn:false|count:\(ids.count)"
            )
        )
    }

    private static func parseTarget(_ segment: String) -> ParsedDisplayTarget {
        let fields = Dictionary(
            uniqueKeysWithValues: segment
                .split(separator: " ")
                .compactMap { token -> (String, String)? in
                    let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return nil }
                    return (parts[0], parts[1])
                }
        )

        let displayIDs = fields["id"]?
            .split(separator: "+")
            .map(String.init) ?? []

        return ParsedDisplayTarget(
            displayIDs: displayIDs,
            resolution: fields["res"],
            enabled: fields["enabled"].map { $0 == "true" },
            scaling: fields["scaling"],
            origin: fields["origin"],
            degree: fields["degree"].flatMap(Int.init)
        )
    }
}

public enum ProfileRecognizer {
    public static func recognizeCurrentProfile(
        in profiles: [DisplayProfile],
        currentSetup: DisplaySetup
    ) -> DisplayProfile? {
        guard let currentCommand = currentSetup.currentCommand,
              let currentLayout = try? DisplayCommandParser.parse(currentCommand) else {
            return nil
        }

        return profiles.first { profile in
            guard let profileLayout = try? DisplayCommandParser.parse(profile.command) else {
                return false
            }
            return profileLayout.targets.normalizedForComparison == currentLayout.targets.normalizedForComparison
        }
    }
}

private extension Array where Element == ParsedDisplayTarget {
    var normalizedForComparison: [ParsedDisplayTarget] {
        map { target in
            ParsedDisplayTarget(
                displayIDs: target.displayIDs.sorted(),
                resolution: target.resolution,
                enabled: target.enabled,
                scaling: target.scaling,
                origin: target.origin,
                degree: target.degree
            )
        }
        .sorted { $0.displayIDs.joined(separator: "+") < $1.displayIDs.joined(separator: "+") }
    }
}

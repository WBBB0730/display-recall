import Foundation

public enum FirstRunSetupState: Equatable, Sendable {
    case idle
    case verifying
    case ready(CurrentDisplayLayout)
    case failed(DisplayplacerBackendError)
    case completed(DisplayProfile)
}

public struct CurrentDisplayLayout: Equatable, Sendable {
    public let command: String
    public let generatedProfileName: String
    public let displaySetupFingerprint: DisplaySetupFingerprint
}

public struct FirstProfileCompletion: Equatable, Sendable {
    public let profile: DisplayProfile
    public let automaticDefaultRule: AutomaticDefaultRule?
}

public struct FirstRunSetupService: Sendable {
    public typealias RunList = @Sendable () async throws -> DisplayplacerBackendRunResult

    private let runList: RunList

    public init(runList: @escaping RunList) {
        self.runList = runList
    }

    public static func live() throws -> FirstRunSetupService {
        let runner = try DisplayplacerBackend.bundledRunner()
        return FirstRunSetupService {
            try await runner.verifyList()
        }
    }

    public func verifyBackendAndReadCurrentLayout() async -> FirstRunSetupState {
        do {
            let result = try await runList()
            let layout = try CurrentDisplayLayoutParser.parse(result.stdout)
            return .ready(layout)
        } catch let error as DisplayplacerBackendError {
            return .failed(error)
        } catch {
            return .failed(
                DisplayplacerBackendError(
                    kind: .launchFailed,
                    backendPath: "displayplacer",
                    backendVersion: DisplayplacerBackend.bundledMetadata.version,
                    backendSource: .bundled,
                    stderr: error.localizedDescription
                )
            )
        }
    }

    public func createFirstProfile(
        from layout: CurrentDisplayLayout,
        editedName: String,
        makeAutomaticDefault: Bool
    ) -> FirstProfileCompletion {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = DisplayProfile(
            name: trimmedName.isEmpty ? layout.generatedProfileName : trimmedName,
            command: layout.command,
            displaySetupFingerprint: layout.displaySetupFingerprint
        )

        let rule = makeAutomaticDefault
            ? AutomaticDefaultRule(
                displaySetupFingerprint: layout.displaySetupFingerprint,
                profileId: profile.id
            )
            : nil

        return FirstProfileCompletion(profile: profile, automaticDefaultRule: rule)
    }
}

public enum CurrentDisplayLayoutParser {
    public static func parse(_ output: String) throws -> CurrentDisplayLayout {
        let command = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .last { $0.hasPrefix("displayplacer ") }?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let command else {
            throw DisplayplacerBackendError(
                kind: .nonZeroExit,
                backendPath: "displayplacer",
                backendVersion: DisplayplacerBackend.bundledMetadata.version,
                backendSource: .bundled,
                stderr: "Could not find current layout command in displayplacer list output."
            )
        }

        let ids = parsePersistentIDs(from: command)
        let types = parseDisplayTypes(from: output)
        let hasBuiltInDisplay = types.contains { $0.localizedCaseInsensitiveContains("built-in") }
        let displayCount = ids.count

        return CurrentDisplayLayout(
            command: command,
            generatedProfileName: generatedName(from: types, fallbackCount: displayCount),
            displaySetupFingerprint: DisplaySetupFingerprint(
                rawValue: "\(ids.sorted().joined(separator: "+"))|builtIn:\(hasBuiltInDisplay)|count:\(displayCount)"
            )
        )
    }

    private static func parsePersistentIDs(from command: String) -> [String] {
        command
            .components(separatedBy: "\"")
            .filter { $0.hasPrefix("id:") }
            .compactMap { segment in
                segment
                    .split(separator: " ")
                    .first?
                    .dropFirst(3)
            }
            .flatMap { idGroup in
                idGroup.split(separator: "+").map(String.init)
            }
    }

    private static func parseDisplayTypes(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map(String.init)
            .compactMap { line in
                guard line.hasPrefix("Type: ") else { return nil }
                return String(line.dropFirst("Type: ".count))
            }
    }

    private static func generatedName(from types: [String], fallbackCount: Int) -> String {
        let names = types.map { type in
            if type.localizedCaseInsensitiveContains("built-in") {
                return "Built-in display"
            }
            return type
        }

        if names.isEmpty {
            return fallbackCount == 1 ? "1 Display" : "\(fallbackCount) Displays"
        }

        return names.joined(separator: " + ")
    }
}

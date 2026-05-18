#!/usr/bin/env swift

import Foundation

struct ReleaseVersion: Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let beta: Int?

    var description: String {
        if let beta {
            "\(major).\(minor).\(patch)-beta.\(beta)"
        } else {
            "\(major).\(minor).\(patch)"
        }
    }

    var tagName: String {
        "v\(description)"
    }

    var stableBase: ReleaseVersion {
        ReleaseVersion(major: major, minor: minor, patch: patch, beta: nil)
    }

    static func parse(_ value: String) -> ReleaseVersion? {
        let pattern = #"^([0-9]+)\.([0-9]+)\.([0-9]+)(?:-beta\.([0-9]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range), match.range == range else {
            return nil
        }

        func int(at index: Int) -> Int? {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else {
                return nil
            }
            return Int(value[swiftRange])
        }

        guard let major = int(at: 1), let minor = int(at: 2), let patch = int(at: 3) else {
            return nil
        }

        return ReleaseVersion(major: major, minor: minor, patch: patch, beta: int(at: 4))
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.beta, rhs.beta) {
        case (.none, .none):
            return false
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case let (.some(lhsBeta), .some(rhsBeta)):
            return lhsBeta < rhsBeta
        }
    }

    func nextMajor() -> ReleaseVersion {
        ReleaseVersion(major: major + 1, minor: 0, patch: 0, beta: nil)
    }

    func nextMinor() -> ReleaseVersion {
        ReleaseVersion(major: major, minor: minor + 1, patch: 0, beta: nil)
    }

    func nextPatch() -> ReleaseVersion {
        ReleaseVersion(major: major, minor: minor, patch: patch + 1, beta: nil)
    }

    func nextBeta() -> ReleaseVersion {
        if let beta {
            ReleaseVersion(major: major, minor: minor, patch: patch, beta: beta + 1)
        } else {
            ReleaseVersion(major: major, minor: minor, patch: patch + 1, beta: 1)
        }
    }
}

struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

struct BumpOptions {
    var release: String?
    var yes = false
    var dryRun = false
    var commit: Bool?
    var tag: Bool?
    var noGitCheck = false
    var selfTest = false
}

enum BumpError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case invalidVersion(String)
    case commandFailed(String)
    case cancelled
    case missingCurrentVersion
    case tagRequiresCommit

    var description: String {
        switch self {
        case let .invalidArgument(argument):
            "Unknown argument: \(argument)"
        case let .invalidVersion(version):
            "Invalid version: \(version). Expected X.Y.Z or X.Y.Z-beta.N."
        case let .commandFailed(message):
            message
        case .cancelled:
            "Cancelled."
        case .missingCurrentVersion:
            "Could not find AppConfiguration.version."
        case .tagRequiresCommit:
            "Creating a tag requires creating the release commit in the same run."
        }
    }
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL

func run(_ launchPath: String, _ arguments: [String], input: String? = nil) throws -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.currentDirectoryURL = repositoryRoot

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    if let input {
        let stdin = Pipe()
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
    } else {
        try process.run()
    }

    process.waitUntilExit()

    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

    return CommandResult(
        status: process.terminationStatus,
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? ""
    )
}

func runGit(_ arguments: [String]) throws -> String {
    let result = try run("/usr/bin/env", ["git"] + arguments)
    guard result.status == 0 else {
        throw BumpError.commandFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return result.stdout
}

func parseOptions(_ arguments: [String]) throws -> BumpOptions {
    var options = BumpOptions()

    for argument in arguments.dropFirst() {
        switch argument {
        case "--yes", "-y":
            options.yes = true
        case "--dry-run":
            options.dryRun = true
        case "--commit":
            options.commit = true
        case "--no-commit":
            options.commit = false
        case "--tag":
            options.tag = true
        case "--no-tag":
            options.tag = false
        case "--no-git-check":
            options.noGitCheck = true
        case "--self-test":
            options.selfTest = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            if argument.hasPrefix("-") {
                throw BumpError.invalidArgument(argument)
            }
            if options.release == nil {
                options.release = argument
            } else {
                throw BumpError.invalidArgument(argument)
            }
        }
    }

    return options
}

func printUsage() {
    print("""
    Usage:
      scripts/bump-version.swift [major|minor|patch|beta|prerelease|X.Y.Z[-beta.N]] [options]

    Options:
      --commit          Create a release commit.
      --tag             Create the matching v-prefixed git tag.
      --yes, -y         Skip confirmation prompts.
      --dry-run         Preview changes without writing files.
      --no-git-check    Allow tracked changes before bumping.

    Tag formats:
      Stable: vX.Y.Z
      Beta:   vX.Y.Z-beta.N
    """)
}

func currentVersion() throws -> ReleaseVersion {
    let path = repositoryRoot.appendingPathComponent("Sources/DisplayRecallCore/AppConfiguration.swift")
    let contents = try String(contentsOf: path, encoding: .utf8)
    let pattern = #"public static let version = "([^"]+)""#
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
    guard
        let match = regex.firstMatch(in: contents, range: range),
        let versionRange = Range(match.range(at: 1), in: contents)
    else {
        throw BumpError.missingCurrentVersion
    }

    let version = String(contents[versionRange])
    guard let parsed = ReleaseVersion.parse(version) else {
        throw BumpError.invalidVersion(version)
    }
    return parsed
}

func candidates(from version: ReleaseVersion) -> [(label: String, version: ReleaseVersion)] {
    var values: [(String, ReleaseVersion)] = []

    if version.beta != nil {
        values.append(("stable", version.stableBase))
    }

    values.append(("patch", version.nextPatch()))
    values.append(("minor", version.nextMinor()))
    values.append(("major", version.nextMajor()))
    values.append(("beta", version.nextBeta()))

    return values
}

func resolveTargetVersion(current: ReleaseVersion, release: String?) throws -> ReleaseVersion {
    guard let release else {
        return try promptForTargetVersion(current: current)
    }

    switch release {
    case "major":
        return current.nextMajor()
    case "minor":
        return current.nextMinor()
    case "patch":
        return current.nextPatch()
    case "beta", "prerelease":
        return current.nextBeta()
    default:
        guard let explicit = ReleaseVersion.parse(release) else {
            throw BumpError.invalidVersion(release)
        }
        return explicit
    }
}

func promptForTargetVersion(current: ReleaseVersion) throws -> ReleaseVersion {
    let values = candidates(from: current)

    print("Current version: \(current)")
    print("Select next version:")
    for (index, candidate) in values.enumerated() {
        print("  \(index + 1)) \(candidate.label.padding(toLength: 7, withPad: " ", startingAt: 0)) \(candidate.version)")
    }
    print("  \(values.count + 1)) custom")
    print("Choice [1]: ", terminator: "")

    let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedIndex = input?.isEmpty == false ? Int(input ?? "") : 1

    if selectedIndex == values.count + 1 {
        print("Version: ", terminator: "")
        guard let custom = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), let version = ReleaseVersion.parse(custom) else {
            throw BumpError.invalidVersion("custom")
        }
        return version
    }

    guard let selectedIndex, selectedIndex >= 1, selectedIndex <= values.count else {
        throw BumpError.invalidArgument(input ?? "")
    }

    return values[selectedIndex - 1].version
}

func confirm(_ message: String, defaultValue: Bool = false) -> Bool {
    let suffix = defaultValue ? "[Y/n]" : "[y/N]"
    print("\(message) \(suffix): ", terminator: "")
    let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if input?.isEmpty ?? true {
        return defaultValue
    }

    return input == "y" || input == "yes"
}

func ensureCleanTrackedWorktree(options: BumpOptions) throws {
    guard !options.noGitCheck else {
        return
    }

    let status = try runGit(["status", "--porcelain", "--untracked-files=no"])
    guard status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw BumpError.commandFailed("Tracked changes exist. Commit or stash them first, or pass --no-git-check.")
    }
}

func filesContaining(_ version: ReleaseVersion) throws -> [String] {
    let result = try run("/usr/bin/env", ["git", "grep", "-l", "--fixed-strings", version.description])
    guard result.status == 0 || result.status == 1 else {
        throw BumpError.commandFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return result.stdout
        .split(separator: "\n")
        .map(String.init)
        .filter { !$0.isEmpty }
}

func updateFiles(files: [String], from current: ReleaseVersion, to target: ReleaseVersion, dryRun: Bool) throws {
    for file in files {
        let url = repositoryRoot.appendingPathComponent(file)
        let oldContents = try String(contentsOf: url, encoding: .utf8)
        let newContents = oldContents.replacingOccurrences(of: current.description, with: target.description)

        if !dryRun {
            try newContents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

func tagExists(_ tagName: String) throws -> Bool {
    let result = try run("/usr/bin/env", ["git", "rev-parse", "-q", "--verify", "refs/tags/\(tagName)"])
    return result.status == 0
}

func performGitOperations(target: ReleaseVersion, files: [String], commit: Bool, tag: Bool, dryRun: Bool) throws {
    guard commit || tag else {
        return
    }

    if tag && !commit {
        throw BumpError.tagRequiresCommit
    }

    if try tagExists(target.tagName) {
        throw BumpError.commandFailed("Tag already exists: \(target.tagName)")
    }

    let message = "chore: 发布 \(target.tagName)"

    if dryRun {
        print("Would commit: \(message)")
        if tag {
            print("Would tag: \(target.tagName)")
        }
        return
    }

    _ = try runGit(["add", "--"] + files)
    _ = try runGit(["commit", "-m", message])

    if tag {
        _ = try runGit(["tag", target.tagName])
    }
}

func runSelfTest() throws {
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw BumpError.commandFailed("Self-test failed: \(message)")
        }
    }

    let stable = ReleaseVersion.parse("1.2.3")
    let beta = ReleaseVersion.parse("1.2.3-beta.1")

    try expect(stable?.description == "1.2.3", "stable parse")
    try expect(stable?.tagName == "v1.2.3", "stable tag")
    try expect(stable?.nextBeta().description == "1.2.4-beta.1", "stable to beta")
    try expect(beta?.description == "1.2.3-beta.1", "beta parse")
    try expect(beta?.tagName == "v1.2.3-beta.1", "beta tag")
    try expect(beta?.nextBeta().description == "1.2.3-beta.2", "beta increment")
    try expect(beta?.stableBase.description == "1.2.3", "beta to stable")
    try expect(ReleaseVersion.parse("v1.2.3") == nil, "no v prefix in app version")

    print("Self-test passed.")
}

func main() throws {
    let options = try parseOptions(CommandLine.arguments)

    if options.selfTest {
        try runSelfTest()
        return
    }

    let current = try currentVersion()
    let target = try resolveTargetVersion(current: current, release: options.release)

    if target == current {
        throw BumpError.commandFailed("Target version is already current: \(current)")
    }

    try ensureCleanTrackedWorktree(options: options)

    let files = try filesContaining(current)
    guard !files.isEmpty else {
        throw BumpError.commandFailed("No tracked files contain \(current).")
    }

    print("Bump: \(current) -> \(target)")
    print("Tag:  \(target.tagName)")
    print("Files:")
    for file in files {
        print("  - \(file)")
    }

    if !options.yes && !confirm("Continue?") {
        throw BumpError.cancelled
    }

    var shouldCommit = options.commit ?? false
    var shouldTag = options.tag ?? false

    if options.release == nil && options.commit == nil {
        shouldCommit = confirm("Create release commit?")
    }

    if options.release == nil && options.tag == nil {
        shouldTag = confirm("Create git tag?", defaultValue: shouldCommit)
        if shouldTag {
            shouldCommit = true
        }
    }

    try updateFiles(files: files, from: current, to: target, dryRun: options.dryRun)
    try performGitOperations(target: target, files: files, commit: shouldCommit, tag: shouldTag, dryRun: options.dryRun)

    if options.dryRun {
        print("Dry run complete.")
    } else {
        print("Updated to \(target).")
        if shouldTag {
            print("Created tag \(target.tagName).")
        }
    }
}

do {
    try main()
} catch let error as BumpError {
    fputs("\(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}

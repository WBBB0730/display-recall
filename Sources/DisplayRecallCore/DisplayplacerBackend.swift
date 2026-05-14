import Foundation

public enum DisplayplacerBackendArchitecture: String, Equatable, Sendable {
    case appleSilicon = "arm64"
    case intel = "x86_64"

    public static var current: DisplayplacerBackendArchitecture {
        #if arch(arm64)
        .appleSilicon
        #else
        .intel
        #endif
    }
}

public enum DisplayplacerBackendSource: Equatable, Sendable, Codable {
    case bundled
    case system(path: String)
    case custom(path: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case path
    }

    private enum Kind: String, Codable {
        case bundled
        case system
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .bundled:
            self = .bundled
        case .system:
            self = .system(path: try container.decode(String.self, forKey: .path))
        case .custom:
            self = .custom(path: try container.decode(String.self, forKey: .path))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bundled:
            try container.encode(Kind.bundled, forKey: .kind)
        case let .system(path):
            try container.encode(Kind.system, forKey: .kind)
            try container.encode(path, forKey: .path)
        case let .custom(path):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(path, forKey: .path)
        }
    }
}

public struct DisplayplacerBackendAsset: Equatable, Sendable {
    public let architecture: DisplayplacerBackendArchitecture
    public let fileName: String
    public let sha256: String

    public init(architecture: DisplayplacerBackendArchitecture, fileName: String, sha256: String) {
        self.architecture = architecture
        self.fileName = fileName
        self.sha256 = sha256
    }
}

public struct DisplayplacerBackendMetadata: Equatable, Sendable {
    public let version: String
    public let source: DisplayplacerBackendSource
    public let appleSiliconAsset: DisplayplacerBackendAsset
    public let intelAsset: DisplayplacerBackendAsset

    public init(
        version: String,
        source: DisplayplacerBackendSource,
        appleSiliconAsset: DisplayplacerBackendAsset,
        intelAsset: DisplayplacerBackendAsset
    ) {
        self.version = version
        self.source = source
        self.appleSiliconAsset = appleSiliconAsset
        self.intelAsset = intelAsset
    }

    public func asset(for architecture: DisplayplacerBackendArchitecture) -> DisplayplacerBackendAsset {
        switch architecture {
        case .appleSilicon:
            appleSiliconAsset
        case .intel:
            intelAsset
        }
    }
}

public enum DisplayplacerBackend {
    public static let bundledMetadata = DisplayplacerBackendMetadata(
        version: "1.4.0",
        source: .bundled,
        appleSiliconAsset: DisplayplacerBackendAsset(
            architecture: .appleSilicon,
            fileName: "displayplacer-apple-v140",
            sha256: "0572c3d2918e47c7e0b9d7723907864e2ea2b53b9d3b02379769fffcf44f7ea0"
        ),
        intelAsset: DisplayplacerBackendAsset(
            architecture: .intel,
            fileName: "displayplacer-intel-v140",
            sha256: "13ec0351ed7849b22e945974f1d4ac91eca30b38b09ec962c497feb8297eac2b"
        )
    )

    public static func bundledExecutableURL(
        for architecture: DisplayplacerBackendArchitecture = .current,
        bundle: Bundle? = nil
    ) -> URL? {
        let asset = bundledMetadata.asset(for: architecture)
        let resourceBundle = bundle ?? .module
        return resourceBundle.url(
            forResource: asset.fileName,
            withExtension: nil,
            subdirectory: "Backends"
        )
    }

    public static func bundledRunner(
        for architecture: DisplayplacerBackendArchitecture = .current
    ) throws -> DisplayplacerBackendRunner {
        guard let executableURL = bundledExecutableURL(for: architecture) else {
            throw DisplayplacerBackendError(
                kind: .executableMissing,
                backendPath: "Backends/\(bundledMetadata.asset(for: architecture).fileName)",
                backendVersion: bundledMetadata.version,
                backendSource: bundledMetadata.source,
                stderr: "Bundled displayplacer backend is missing."
            )
        }

        return DisplayplacerBackendRunner(
            executableURL: executableURL,
            metadata: bundledMetadata,
            architecture: architecture
        )
    }
}

public struct DisplayplacerBackendRunResult: Equatable, Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let backendPath: String
    public let backendArchitecture: DisplayplacerBackendArchitecture
    public let backendVersion: String
    public let backendSource: DisplayplacerBackendSource

    public init(
        stdout: String,
        stderr: String,
        exitCode: Int32,
        backendPath: String,
        backendArchitecture: DisplayplacerBackendArchitecture,
        backendVersion: String,
        backendSource: DisplayplacerBackendSource
    ) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.backendPath = backendPath
        self.backendArchitecture = backendArchitecture
        self.backendVersion = backendVersion
        self.backendSource = backendSource
    }
}

public struct DisplayplacerBackendError: Error, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case executableMissing
        case launchFailed
        case nonZeroExit
    }

    public let kind: Kind
    public let backendPath: String
    public let backendVersion: String
    public let backendSource: DisplayplacerBackendSource
    public let stderr: String

    public init(
        kind: Kind,
        backendPath: String,
        backendVersion: String,
        backendSource: DisplayplacerBackendSource,
        stderr: String
    ) {
        self.kind = kind
        self.backendPath = backendPath
        self.backendVersion = backendVersion
        self.backendSource = backendSource
        self.stderr = stderr
    }

    public var recoveryActionTitle: String {
        "Retry"
    }
}

public struct DisplayplacerBackendRunner: Sendable {
    public let executableURL: URL
    public let metadata: DisplayplacerBackendMetadata
    public let architecture: DisplayplacerBackendArchitecture

    public init(
        executableURL: URL,
        metadata: DisplayplacerBackendMetadata,
        architecture: DisplayplacerBackendArchitecture
    ) {
        self.executableURL = executableURL
        self.metadata = metadata
        self.architecture = architecture
    }

    public func verifyList() async throws -> DisplayplacerBackendRunResult {
        let result = try await run(arguments: ["list"])
        guard result.exitCode == 0 else {
            throw DisplayplacerBackendError(
                kind: .nonZeroExit,
                backendPath: result.backendPath,
                backendVersion: result.backendVersion,
                backendSource: result.backendSource,
                stderr: result.stderr
            )
        }
        return result
    }

    public func run(arguments: [String]) async throws -> DisplayplacerBackendRunResult {
        let path = executableURL.path
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw DisplayplacerBackendError(
                kind: .executableMissing,
                backendPath: path,
                backendVersion: metadata.version,
                backendSource: metadata.source,
                stderr: "Backend executable is missing or is not executable."
            )
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw DisplayplacerBackendError(
                kind: .launchFailed,
                backendPath: path,
                backendVersion: metadata.version,
                backendSource: metadata.source,
                stderr: error.localizedDescription
            )
        }

        process.waitUntilExit()

        return DisplayplacerBackendRunResult(
            stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            exitCode: process.terminationStatus,
            backendPath: path,
            backendArchitecture: architecture,
            backendVersion: metadata.version,
            backendSource: metadata.source
        )
    }
}

import XCTest
@testable import DisplayRecallCore

final class DisplayplacerBackendTests: XCTestCase {
    func testBundledBackendMetadataIsFixedToDisplayplacerVersion140() {
        let metadata = DisplayplacerBackend.bundledMetadata

        XCTAssertEqual(metadata.version, "1.4.0")
        XCTAssertEqual(metadata.source, .bundled)
        XCTAssertEqual(metadata.appleSiliconAsset.fileName, "displayplacer-apple-v140")
        XCTAssertEqual(metadata.appleSiliconAsset.sha256, "0572c3d2918e47c7e0b9d7723907864e2ea2b53b9d3b02379769fffcf44f7ea0")
        XCTAssertEqual(metadata.intelAsset.fileName, "displayplacer-intel-v140")
        XCTAssertEqual(metadata.intelAsset.sha256, "13ec0351ed7849b22e945974f1d4ac91eca30b38b09ec962c497feb8297eac2b")
    }

    func testBackendArchitectureSelectsAssetForMachineArchitecture() {
        XCTAssertEqual(
            DisplayplacerBackend.bundledMetadata.asset(for: .appleSilicon).fileName,
            "displayplacer-apple-v140"
        )
        XCTAssertEqual(
            DisplayplacerBackend.bundledMetadata.asset(for: .intel).fileName,
            "displayplacer-intel-v140"
        )
    }

    func testRunnerCapturesOutputExitCodePathAndArchitecture() async throws {
        let runner = DisplayplacerBackendRunner(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            metadata: .fixture(version: "test", source: .custom(path: "/bin/echo")),
            architecture: .appleSilicon
        )

        let result = try await runner.run(arguments: ["list"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "list\n")
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.backendPath, "/bin/echo")
        XCTAssertEqual(result.backendArchitecture, .appleSilicon)
        XCTAssertEqual(result.backendVersion, "test")
        XCTAssertEqual(result.backendSource, .custom(path: "/bin/echo"))
    }

    func testVerificationFailureProducesStructuredError() async {
        let runner = DisplayplacerBackendRunner(
            executableURL: URL(fileURLWithPath: "/path/that/does/not/exist"),
            metadata: .fixture(version: "test", source: .bundled),
            architecture: .intel
        )

        do {
            _ = try await runner.verifyList()
            XCTFail("Expected backend verification to fail.")
        } catch let error as DisplayplacerBackendError {
            XCTAssertEqual(error.kind, .executableMissing)
            XCTAssertEqual(error.backendPath, "/path/that/does/not/exist")
            XCTAssertEqual(error.backendVersion, "test")
            XCTAssertEqual(error.backendSource, .bundled)
        } catch {
            XCTFail("Expected DisplayplacerBackendError, got \(error).")
        }
    }

    func testBundledBackendCanRunDisplayplacerList() async throws {
        let runner = try DisplayplacerBackend.bundledRunner()

        let result = try await runner.verifyList()

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.backendVersion, "1.4.0")
        XCTAssertEqual(result.backendSource, .bundled)
        XCTAssertTrue(result.stdout.contains("Persistent screen id:"))
    }
}

private extension DisplayplacerBackendMetadata {
    static func fixture(version: String, source: DisplayplacerBackendSource) -> DisplayplacerBackendMetadata {
        DisplayplacerBackendMetadata(
            version: version,
            source: source,
            appleSiliconAsset: DisplayplacerBackendAsset(
                architecture: .appleSilicon,
                fileName: "displayplacer-apple-test",
                sha256: "apple"
            ),
            intelAsset: DisplayplacerBackendAsset(
                architecture: .intel,
                fileName: "displayplacer-intel-test",
                sha256: "intel"
            )
        )
    }
}

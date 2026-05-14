import XCTest
@testable import DisplayRecallCore

final class FirstRunSetupTests: XCTestCase {
    func testSuccessfulSetupVerificationCapturesCurrentLayoutCommandAndGeneratedName() async {
        let service = FirstRunSetupService(
            runList: {
                DisplayplacerBackendRunResult.fixture(stdout: Self.twoDisplayListOutput)
            }
        )

        let state = await service.verifyBackendAndReadCurrentLayout()

        guard case let .ready(layout) = state else {
            return XCTFail("Expected setup to be ready.")
        }

        XCTAssertEqual(
            layout.command,
            #"displayplacer "id:AAA res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0" "id:BBB res:1080x1920 enabled:true scaling:on origin:(1920,0) degree:90""#
        )
        XCTAssertEqual(layout.generatedProfileName, "27 inch external screen + Built-in display")
        XCTAssertEqual(layout.displaySetupFingerprint.rawValue, "AAA+BBB|builtIn:true|count:2")
    }

    func testFailedSetupVerificationReturnsRetryableFailureState() async {
        let service = FirstRunSetupService(
            runList: {
                throw DisplayplacerBackendError(
                    kind: .executableMissing,
                    backendPath: "/missing/displayplacer",
                    backendVersion: "1.4.0",
                    backendSource: .bundled,
                    stderr: "missing"
                )
            }
        )

        let state = await service.verifyBackendAndReadCurrentLayout()

        guard case let .failed(error) = state else {
            return XCTFail("Expected setup to fail.")
        }

        XCTAssertEqual(error.kind, .executableMissing)
        XCTAssertEqual(error.backendPath, "/missing/displayplacer")
        XCTAssertEqual(error.recoveryActionTitle, "Retry")
    }

    func testCreatingFirstProfileUsesEditableNameAndDefaultOnAutomationRule() async throws {
        let service = FirstRunSetupService(
            runList: {
                DisplayplacerBackendRunResult.fixture(stdout: Self.twoDisplayListOutput)
            }
        )

        guard case let .ready(layout) = await service.verifyBackendAndReadCurrentLayout() else {
            return XCTFail("Expected setup to be ready.")
        }

        let completion = service.createFirstProfile(
            from: layout,
            editedName: "Home Desk",
            makeAutomaticDefault: true
        )

        XCTAssertEqual(completion.profile.name, "Home Desk")
        XCTAssertEqual(completion.profile.command, layout.command)
        XCTAssertEqual(completion.profile.displaySetupFingerprint, layout.displaySetupFingerprint)
        XCTAssertEqual(completion.automaticDefaultRule?.profileId, completion.profile.id)
        XCTAssertEqual(completion.automaticDefaultRule?.displaySetupFingerprint, layout.displaySetupFingerprint)
    }

    private static let twoDisplayListOutput = """
    Persistent screen id: AAA
    Type: 27 inch external screen
    Enabled: true

    Persistent screen id: BBB
    Type: built-in screen
    Enabled: true

    Execute the command below to set your screens to the current arrangement.

    displayplacer "id:AAA res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0" "id:BBB res:1080x1920 enabled:true scaling:on origin:(1920,0) degree:90"
    """
}

private extension DisplayplacerBackendRunResult {
    static func fixture(stdout: String) -> DisplayplacerBackendRunResult {
        DisplayplacerBackendRunResult(
            stdout: stdout,
            stderr: "",
            exitCode: 0,
            backendPath: "/fixture/displayplacer",
            backendArchitecture: .appleSilicon,
            backendVersion: "1.4.0",
            backendSource: .bundled
        )
    }
}

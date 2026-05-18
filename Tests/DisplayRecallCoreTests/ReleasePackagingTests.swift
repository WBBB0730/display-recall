import XCTest
@testable import DisplayRecallCore

final class ReleasePackagingTests: XCTestCase {
    func testReleaseConfigurationUsesUniversalUnsignedGitHubDMGArtifact() {
        let configuration = ReleaseConfiguration.production()

        XCTAssertEqual(configuration.architectures, [.appleSilicon, .intel])
        XCTAssertFalse(configuration.requiresDeveloperIDSigning)
        XCTAssertFalse(configuration.requiresNotarization)
        XCTAssertEqual(configuration.distributionChannel, .githubReleases)
        XCTAssertEqual(configuration.artifactExtension, "dmg")
    }

    func testReleaseIncludesBundledBackendsForSupportedArchitectures() {
        let manifest = ReleaseConfiguration.production().backendManifest

        XCTAssertEqual(manifest.map(\.architecture), [.appleSilicon, .intel])
        XCTAssertTrue(manifest.allSatisfy { !$0.sha256.isEmpty })
    }

    func testSparklePolicyUsesStableManualChecksAndNoForcedSilentInstall() {
        let policy = ReleaseConfiguration.production().sparklePolicy

        XCTAssertEqual(policy.channel, .stable)
        XCTAssertTrue(policy.manualUpdateChecksEnabled)
        XCTAssertTrue(policy.automaticChecksAreUserOptional)
        XCTAssertFalse(policy.allowsSilentForcedInstallation)
        XCTAssertTrue(policy.requiresEdDSAUpdateSignatures)
        XCTAssertTrue(policy.infoPlistEntries.keys.contains("SUFeedURL"))
    }

    func testAboutMetadataExposesVersionAndBuildNumber() {
        let about = AboutMetadata.current()

        XCTAssertEqual(about.version, "0.1.0")
        XCTAssertEqual(about.build, "1")
        XCTAssertEqual(about.displayString, "Display Recall 0.1.0 (1)")
    }

    func testReleaseChecklistRejectsMacAppStoreAssumptions() {
        let checklist = ReleaseReadinessChecklist.production()

        XCTAssertFalse(checklist.requiresMacAppStoreReceipt)
        XCTAssertFalse(checklist.steps.contains(.signSparkleUpdate))
        XCTAssertTrue(checklist.steps.contains(.generateSparkleAppcast))
        XCTAssertTrue(checklist.steps.contains(.publishGitHubReleaseArtifact))
    }
}

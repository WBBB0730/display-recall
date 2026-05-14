import XCTest
@testable import DisplayRecallCore

final class OpenSourceReadinessTests: XCTestCase {
    func testAcknowledgementsCatalogIncludesBundledDependenciesAndIndependenceNotice() {
        let catalog = AcknowledgementsCatalog.current()

        XCTAssertTrue(catalog.independenceNotice.contains("independent companion"))
        XCTAssertTrue(catalog.independenceNotice.contains("displayplacer"))
        XCTAssertTrue(catalog.items.contains { acknowledgement in
            acknowledgement.name == "displayplacer"
                && acknowledgement.version == "1.4.0"
                && acknowledgement.licenseName == "MIT"
                && acknowledgement.modificationStatus == .unmodifiedBinary
        })
        XCTAssertTrue(catalog.items.contains { acknowledgement in
            acknowledgement.name == "Sparkle"
                && acknowledgement.licenseName == "MIT"
        })
    }

    func testRepositoryIncludesMITLicenseForDisplayRecall() throws {
        let license = try readRepositoryFile("LICENSE")

        XCTAssertTrue(license.contains("MIT License"))
        XCTAssertTrue(license.contains("Display Recall contributors"))
        XCTAssertTrue(license.contains("Permission is hereby granted"))
    }

    func testThirdPartyNoticesCoverDisplayplacerAndSparkle() throws {
        let notices = try readRepositoryFile("THIRD_PARTY_NOTICES.md")

        XCTAssertTrue(notices.contains("displayplacer"))
        XCTAssertTrue(notices.contains("Jake Hilborn"))
        XCTAssertTrue(notices.contains("Version: 1.4.0"))
        XCTAssertTrue(notices.contains("Modification status: unmodified official release binaries"))
        XCTAssertTrue(notices.contains("Sparkle"))
        XCTAssertTrue(notices.contains("MIT License"))
    }

    func testReleaseDocumentationExplainsBundledBackendAndFallback() throws {
        let releaseGuide = try readRepositoryFile("docs/release.md")

        XCTAssertTrue(releaseGuide.contains("bundled displayplacer backend"))
        XCTAssertTrue(releaseGuide.contains("advanced fallback"))
        XCTAssertTrue(releaseGuide.contains("Developer ID"))
        XCTAssertTrue(releaseGuide.contains("notarization"))
    }

    private func readRepositoryFile(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

import XCTest
@testable import DisplayRecallCore

final class ProfileGroupingTests: XCTestCase {
    func testProjectionShowsCurrentGroupExpandedAndHidesNonCurrentEmptyGroups() {
        let currentFingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let otherFingerprint = DisplaySetupFingerprint(rawValue: "BBB|builtIn:true|count:1")
        let emptyFingerprint = DisplaySetupFingerprint(rawValue: "CCC|builtIn:false|count:2")
        let currentGroup = DisplaySetupGroup.fixture(name: "Office", fingerprint: currentFingerprint)
        let otherGroup = DisplaySetupGroup.fixture(name: "Travel", fingerprint: otherFingerprint)
        let emptyGroup = DisplaySetupGroup.fixture(name: "Projector", fingerprint: emptyFingerprint)
        let currentProfile = DisplayProfile.fixture(name: "Standing Desk", fingerprint: currentFingerprint)
        let otherProfile = DisplayProfile.fixture(name: "Laptop", fingerprint: otherFingerprint)
        let document = ProfileStoreDocument(
            profiles: [currentProfile, otherProfile],
            displaySetupGroups: [currentGroup, otherGroup, emptyGroup]
        )

        let sections = ProfileGroupingProjection.sections(
            document: document,
            currentFingerprint: currentFingerprint
        )

        XCTAssertEqual(sections.map(\.group.name), ["Office", "Travel"])
        XCTAssertEqual(sections.map { $0.profiles.map(\.name) }, [["Standing Desk"], ["Laptop"]])
        XCTAssertEqual(sections.map(\.isCurrent), [true, false])
        XCTAssertEqual(sections.map(\.isExpandedByDefault), [true, false])
    }

    func testProjectionShowsEphemeralCurrentGroupWhenCurrentFingerprintHasNoStoredGroup() {
        let currentFingerprint = DisplaySetupFingerprint(rawValue: "AAA|builtIn:false|count:1")
        let historicalFingerprint = DisplaySetupFingerprint(rawValue: "BBB|builtIn:true|count:1")
        let historicalGroup = DisplaySetupGroup.fixture(name: "Travel", fingerprint: historicalFingerprint)
        let historicalProfile = DisplayProfile.fixture(name: "Laptop", fingerprint: historicalFingerprint)
        let document = ProfileStoreDocument(
            profiles: [historicalProfile],
            displaySetupGroups: [historicalGroup]
        )

        let sections = ProfileGroupingProjection.sections(
            document: document,
            currentFingerprint: currentFingerprint,
            currentGroupName: "显示器组合 1"
        )

        XCTAssertEqual(sections.map(\.group.name), ["显示器组合 1", "Travel"])
        XCTAssertEqual(sections.map { $0.profiles.map(\.name) }, [[], ["Laptop"]])
        XCTAssertEqual(sections.map(\.isCurrent), [true, false])
        XCTAssertEqual(sections.map(\.isExpandedByDefault), [true, false])
    }
}

private extension DisplaySetupGroup {
    static func fixture(name: String, fingerprint: DisplaySetupFingerprint) -> DisplaySetupGroup {
        DisplaySetupGroup(
            id: UUID(),
            fingerprint: fingerprint,
            name: name,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
    }
}

private extension DisplayProfile {
    static func fixture(
        name: String,
        fingerprint: DisplaySetupFingerprint
    ) -> DisplayProfile {
        DisplayProfile(
            id: UUID(),
            name: name,
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: fingerprint,
            displaySummary: "Hidden summary"
        )
    }
}

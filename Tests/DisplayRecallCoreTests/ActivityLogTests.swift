import XCTest
@testable import DisplayRecallCore

final class ActivityLogTests: XCTestCase {
    func testActivityLogRecordsStructuredEventsAndRendersLocalizedTitles() {
        let entry = ActivityLogEntry(
            type: .profileApplied,
            trigger: .manual,
            profileSnapshot: ProfileSnapshot(id: UUID(), name: "Home"),
            backend: BackendSnapshot(path: "/bin/displayplacer", version: "1.4.0", source: .bundled),
            command: "displayplacer list",
            stdout: "ok",
            stderr: "",
            exitCode: 0,
            metadata: ["fingerprint": "AAA"]
        )

        XCTAssertEqual(entry.type, .profileApplied)
        XCTAssertEqual(ActivityLogRenderer.title(for: entry, language: .english), "Profile Applied")
        XCTAssertEqual(ActivityLogRenderer.title(for: entry, language: .simplifiedChinese), "已应用配置")
        XCTAssertTrue(ActivityLogRenderer.details(for: entry).contains("/bin/displayplacer"))
        XCTAssertTrue(ActivityLogRenderer.details(for: entry).contains("displayplacer list"))
    }

    func testRetentionKeepsMostRecentEntries() {
        let entries = (0..<600).map { index in
            ActivityLogEntry(type: .displaySetChanged, timestamp: Date(timeIntervalSince1970: TimeInterval(index)))
        }

        let retained = ActivityLogRetention.apply(entries, maxEntries: 500)

        XCTAssertEqual(retained.count, 500)
        XCTAssertEqual(retained.first?.timestamp, Date(timeIntervalSince1970: 100))
    }

    func testAllEventTypesHaveLocalizedTitlesAndSummaries() {
        for type in ActivityLogEventType.allCases {
            let entry = ActivityLogEntry(type: type)

            XCTAssertNotEqual(ActivityLogRenderer.title(for: entry, language: .english), type.rawValue)
            XCTAssertNotEqual(ActivityLogRenderer.title(for: entry, language: .simplifiedChinese), type.rawValue)
            XCTAssertFalse(ActivityLogRenderer.summary(for: entry, language: .english).isEmpty)
            XCTAssertFalse(ActivityLogRenderer.summary(for: entry, language: .simplifiedChinese).isEmpty)
        }
    }

    func testDisplaySetupGroupDeletedSummaryIncludesGroupNameAndProfileCount() {
        let entry = ActivityLogEntry(
            type: .displaySetupGroupDeleted,
            metadata: [
                "displaySetupGroupName": "Office",
                "deletedProfileCount": "3"
            ]
        )

        XCTAssertEqual(
            ActivityLogRenderer.summary(for: entry, language: .english),
            "Display setup group deleted: Office (3 configurations)"
        )
        XCTAssertEqual(
            ActivityLogRenderer.summary(for: entry, language: .simplifiedChinese),
            "已删除显示器组合：Office（3 个配置）"
        )
    }

    func testActivityLogQueryFiltersEntriesInReverseChronologicalOrder() {
        let oldApply = ActivityLogEntry(
            type: .profileApplied,
            timestamp: Date(timeIntervalSince1970: 100),
            exitCode: 0
        )
        let recentAutomation = ActivityLogEntry(
            type: .displaySetChanged,
            timestamp: Date(timeIntervalSince1970: 300)
        )
        let recentError = ActivityLogEntry(
            type: .profileApplyFailed,
            timestamp: Date(timeIntervalSince1970: 200),
            stderr: "failed",
            exitCode: 1
        )
        let entries = [oldApply, recentAutomation, recentError]

        XCTAssertEqual(ActivityLogQuery.entries(entries, filter: .all).map(\.id), [
            recentAutomation.id,
            recentError.id,
            oldApply.id
        ])
        XCTAssertEqual(ActivityLogQuery.entries(entries, filter: .applies).map(\.id), [
            recentError.id,
            oldApply.id
        ])
        XCTAssertEqual(ActivityLogQuery.entries(entries, filter: .automation).map(\.id), [
            recentAutomation.id
        ])
        XCTAssertEqual(ActivityLogQuery.entries(entries, filter: .errors).map(\.id), [
            recentError.id
        ])
    }

    func testDiagnosticExportIsSeparateFromBackupAndContainsLogsBackendAndErrors() throws {
        let entry = ActivityLogEntry(type: .profileApplyFailed, stderr: "boom")
        let export = DiagnosticExporter.export(
            logs: [entry],
            backend: BackendSnapshot(path: "/bin/displayplacer", version: "1.4.0", source: .bundled),
            recentErrors: ["boom"]
        )

        XCTAssertTrue(export.summary.contains("Display Recall Diagnostics"))
        XCTAssertTrue(export.json.contains("profileApplyFailed"))
        XCTAssertTrue(export.json.contains("1.4.0"))
        XCTAssertFalse(export.json.contains("profiles.json"))
    }

    func testActivityLogPersistsSeparatelyWithRetentionAndCopyableDetails() throws {
        let store = DisplayRecallStore(applicationSupportDirectory: temporaryDirectory())
        let entries = (0..<505).map { index in
            ActivityLogEntry(
                type: .backendVerification,
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                backend: BackendSnapshot(path: "/bin/displayplacer", version: "1.4.0", source: .bundled),
                command: "displayplacer list",
                stdout: "ok-\(index)"
            )
        }

        try store.save(ActivityLogStoreDocument(entries: entries))
        let loaded = try store.loadActivityLog()

        XCTAssertEqual(loaded.entries.count, 500)
        XCTAssertEqual(loaded.entries.first?.stdout, "ok-5")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.profilesURL.path))
        XCTAssertTrue(ActivityLogRenderer.copyableDiagnostics(for: loaded.entries[0]).contains("displayplacer list"))
    }

    func testRecorderAppendsEntriesThroughStore() throws {
        let store = DisplayRecallStore(applicationSupportDirectory: temporaryDirectory())
        let recorder = ActivityLogRecorder(store: store)

        try recorder.record(ActivityLogEntry(type: .displaySetChanged, metadata: ["reason": "test"]))
        try recorder.record(ActivityLogEntry(type: .matchingDecision, metadata: ["result": "matched"]))

        let loaded = try store.loadActivityLog()
        XCTAssertEqual(loaded.entries.map(\.type), [.displaySetChanged, .matchingDecision])
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DisplayRecallTests-\(UUID().uuidString)", isDirectory: true)
    }
}

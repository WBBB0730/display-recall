import Foundation

public enum ActivityLogEventType: String, CaseIterable, Equatable, Sendable, Codable {
    case displaySetChanged
    case matchingDecision
    case pendingCountdown
    case cancellation
    case profileApplied
    case profileApplyFailed
    case hotkeyApplied
    case automaticApplied
    case restored
    case importExport
    case backendVerification
    case profileDeleted
    case displaySetupGroupDeleted
}

public enum ActivityTrigger: String, Equatable, Sendable, Codable {
    case manual
    case automatic
    case hotkey
    case startup
}

public struct ProfileSnapshot: Equatable, Sendable, Codable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct BackendSnapshot: Equatable, Sendable, Codable {
    public let path: String
    public let version: String
    public let source: DisplayplacerBackendSource

    public init(path: String, version: String, source: DisplayplacerBackendSource) {
        self.path = path
        self.version = version
        self.source = source
    }
}

public struct ActivityLogEntry: Equatable, Identifiable, Sendable, Codable {
    public let id: UUID
    public let type: ActivityLogEventType
    public let timestamp: Date
    public let trigger: ActivityTrigger?
    public let profileSnapshot: ProfileSnapshot?
    public let backend: BackendSnapshot?
    public let command: String?
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: ActivityLogEventType,
        timestamp: Date = Date(),
        trigger: ActivityTrigger? = nil,
        profileSnapshot: ProfileSnapshot? = nil,
        backend: BackendSnapshot? = nil,
        command: String? = nil,
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.trigger = trigger
        self.profileSnapshot = profileSnapshot
        self.backend = backend
        self.command = command
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.metadata = metadata
    }
}

public struct ActivityLogStoreDocument: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var entries: [ActivityLogEntry]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        entries: [ActivityLogEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.entries = ActivityLogRetention.apply(entries)
    }
}

public enum ActivityLogFilter: String, CaseIterable, Equatable, Sendable {
    case all
    case applies
    case automation
    case errors
}

public enum ActivityLogQuery {
    public static func entries(
        _ entries: [ActivityLogEntry],
        filter: ActivityLogFilter
    ) -> [ActivityLogEntry] {
        entries
            .filter { entry in
                switch filter {
                case .all:
                    true
                case .applies:
                    entry.type == .profileApplied
                        || entry.type == .profileApplyFailed
                        || entry.type == .hotkeyApplied
                        || entry.type == .automaticApplied
                case .automation:
                    entry.type == .displaySetChanged
                        || entry.type == .matchingDecision
                        || entry.type == .pendingCountdown
                        || entry.type == .cancellation
                        || entry.type == .automaticApplied
                case .errors:
                    entry.type == .profileApplyFailed
                        || !entry.stderr.isEmpty
                        || entry.exitCode.map { $0 != 0 } == true
                }
            }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

public enum ActivityLogRenderer {
    public static func title(for entry: ActivityLogEntry, language: LanguagePreference) -> String {
        localizedText(for: entry.type, language: language).title
    }

    public static func summary(for entry: ActivityLogEntry, language: LanguagePreference) -> String {
        if entry.type == .displaySetupGroupDeleted,
           let groupName = entry.metadata["displaySetupGroupName"],
           let count = entry.metadata["deletedProfileCount"] {
            switch language.resolved() {
            case .simplifiedChinese:
                return "已删除显示器组合：\(groupName)（\(count) 个配置）"
            case .english, .system:
                let noun = count == "1" ? "configuration" : "configurations"
                return "Display setup group deleted: \(groupName) (\(count) \(noun))"
            }
        }

        let base = localizedText(for: entry.type, language: language).summary
        guard let profileName = entry.profileSnapshot?.name else {
            return base
        }
        return "\(base): \(profileName)"
    }

    public static func details(for entry: ActivityLogEntry) -> String {
        [
            entry.backend?.path,
            entry.backend?.version,
            entry.command,
            entry.stdout,
            entry.stderr,
            entry.exitCode.map(String.init),
            entry.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n")
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    public static func copyableDiagnostics(for entry: ActivityLogEntry) -> String {
        [
            "type=\(entry.type.rawValue)",
            "timestamp=\(entry.timestamp.timeIntervalSince1970)",
            entry.trigger.map { "trigger=\($0.rawValue)" },
            entry.profileSnapshot.map { "profile=\($0.name) \($0.id.uuidString)" },
            details(for: entry)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

private func localizedText(
    for type: ActivityLogEventType,
    language: LanguagePreference
) -> (title: String, summary: String) {
    switch language {
    case .simplifiedChinese:
        switch type {
        case .displaySetChanged:
            ("显示器组合已变化", "检测到显示器组合发生变化")
        case .matchingDecision:
            ("匹配决策", "记录本次配置匹配结果")
        case .pendingCountdown:
            ("等待自动应用", "自动应用倒计时已开始")
        case .cancellation:
            ("已取消操作", "用户或系统取消了待执行操作")
        case .profileApplied:
            ("已应用配置", "配置已成功应用")
        case .profileApplyFailed:
            ("应用配置失败", "配置应用失败")
        case .hotkeyApplied:
            ("快捷键应用配置", "通过快捷键应用了配置")
        case .automaticApplied:
            ("自动应用配置", "通过自动化应用了配置")
        case .restored:
            ("已恢复布局", "恢复点已应用")
        case .importExport:
            ("导入或导出", "配置导入或导出已完成")
        case .backendVerification:
            ("后端验证", "displayplacer 后端验证已完成")
        case .profileDeleted:
            ("已删除配置", "配置已删除")
        case .displaySetupGroupDeleted:
            ("已删除显示器组合", "显示器组合已删除")
        }

    case .system, .english:
        switch type {
        case .displaySetChanged:
            ("Display Setup Changed", "The display setup changed")
        case .matchingDecision:
            ("Matching Decision", "A profile matching decision was recorded")
        case .pendingCountdown:
            ("Pending Countdown", "Automatic apply countdown started")
        case .cancellation:
            ("Cancellation", "A pending operation was cancelled")
        case .profileApplied:
            ("Profile Applied", "The profile was applied")
        case .profileApplyFailed:
            ("Profile Apply Failed", "The profile failed to apply")
        case .hotkeyApplied:
            ("Hotkey Applied", "A profile was applied from a hotkey")
        case .automaticApplied:
            ("Automatic Apply", "A profile was applied automatically")
        case .restored:
            ("Layout Restored", "A restore point was applied")
        case .importExport:
            ("Import or Export", "Profile import or export completed")
        case .backendVerification:
            ("Backend Verification", "The displayplacer backend was verified")
        case .profileDeleted:
            ("Profile Deleted", "The profile was deleted")
        case .displaySetupGroupDeleted:
            ("Display Setup Group Deleted", "The display setup group was deleted")
        }
    }
}

public enum ActivityLogRetention {
    public static func apply(_ entries: [ActivityLogEntry], maxEntries: Int = 500) -> [ActivityLogEntry] {
        Array(entries.sorted { $0.timestamp < $1.timestamp }.suffix(maxEntries))
    }
}

public struct ActivityLogRecorder: Sendable {
    public let store: DisplayRecallStore

    public init(store: DisplayRecallStore) {
        self.store = store
    }

    public func record(_ entry: ActivityLogEntry) throws {
        var document = try store.loadActivityLog()
        document.entries.append(entry)
        try store.save(document)
    }
}

public struct DiagnosticExport: Equatable, Sendable {
    public let summary: String
    public let json: String
}

public enum DiagnosticExporter {
    public static func export(
        logs: [ActivityLogEntry],
        backend: BackendSnapshot,
        recentErrors: [String]
    ) -> DiagnosticExport {
        let payload = DiagnosticPayload(logs: logs, backend: backend, recentErrors: recentErrors)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return DiagnosticExport(
            summary: "Display Recall Diagnostics\nLogs: \(logs.count)\nBackend: \(backend.version)",
            json: json
        )
    }
}

private struct DiagnosticPayload: Encodable {
    let logs: [ActivityLogEntry]
    let backend: BackendSnapshot
    let recentErrors: [String]
}

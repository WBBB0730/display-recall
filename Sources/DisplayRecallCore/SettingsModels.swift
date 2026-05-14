import Foundation

public enum LanguagePreference: String, CaseIterable, Equatable, Sendable, Codable {
    case system
    case english
    case simplifiedChinese

    public var title: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }
}

public struct BackendSelection: Equatable, Sendable, Codable {
    public var source: DisplayplacerBackendSource
    public var customPath: String?

    public init(source: DisplayplacerBackendSource = .bundled, customPath: String? = nil) {
        self.source = source
        self.customPath = customPath
    }
}

public enum ProfileNameGenerator {
    public static func generatedName(types: [String], language: LanguagePreference) -> String {
        let names = types.map { type in
            if type.localizedCaseInsensitiveContains("built-in") {
                return language == .simplifiedChinese ? "内置显示器" : "Built-in display"
            }
            return type
        }
        return names.isEmpty ? (language == .simplifiedChinese ? "显示器" : "Display") : names.joined(separator: " + ")
    }
}

public struct ShortcutBinding: Equatable, Sendable, Codable {
    public let profileId: UUID
    public var keyEquivalent: String?

    public init(profileId: UUID, keyEquivalent: String? = nil) {
        self.profileId = profileId
        self.keyEquivalent = keyEquivalent
    }
}

public enum ShortcutBindingError: Error, Equatable, Sendable {
    case duplicateShortcut(String)
}

public enum CommonShortcutWarning: Equatable, Sendable {
    case spotlight
    case appSwitcher
}

public enum ShortcutBindingValidator {
    public static func validate(_ bindings: [ShortcutBinding]) throws {
        var seen = Set<String>()
        for binding in bindings {
            guard let keyEquivalent = binding.keyEquivalent, !keyEquivalent.isEmpty else {
                continue
            }
            guard seen.insert(keyEquivalent).inserted else {
                throw ShortcutBindingError.duplicateShortcut(keyEquivalent)
            }
        }
    }

    public static func commonSystemShortcutWarnings(for keyEquivalent: String) -> [CommonShortcutWarning] {
        switch keyEquivalent {
        case "⌘Space":
            [.spotlight]
        case "⌘Tab":
            [.appSwitcher]
        default:
            []
        }
    }
}

public enum ShortcutPermissionPolicy {
    public static func requiresPermissionPrompt(bindings: [ShortcutBinding]) -> Bool {
        bindings.contains { binding in
            guard let keyEquivalent = binding.keyEquivalent else {
                return false
            }
            return !keyEquivalent.isEmpty
        }
    }
}

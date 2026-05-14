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

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> LanguagePreference {
        switch self {
        case .english, .simplifiedChinese:
            self
        case .system:
            preferredLanguages.contains { language in
                language.lowercased().hasPrefix("zh-hans")
                    || language.lowercased().hasPrefix("zh_cn")
                    || language.lowercased().hasPrefix("zh-cn")
            } ? .simplifiedChinese : .english
        }
    }
}

public enum AppLocalizationKey: String, CaseIterable, Equatable, Sendable {
    case about
    case acknowledgements
    case activityLog
    case advancedCommand
    case apply
    case applyNow
    case appearance
    case architecture
    case automaticApply
    case automaticDefault
    case automaticDefaultForSetup
    case automation
    case backend
    case backendReady
    case backendVerificationFailed
    case checkForUpdates
    case clearDefault
    case copyDetails
    case copyDiagnosticExport
    case createProfile
    case customBackendPath
    case currentDisplaySetup
    case displayRecall
    case displayRecallSetupDescription
    case displaySetup
    case export
    case exportSelected
    case fingerprint
    case importProfiles
    case language
    case launchAtLogin
    case noMatchingProfiles
    case name
    case noProfileSelected
    case noProfileSelectedDescription
    case noRecentActivity
    case openActivityLog
    case notes
    case openDisplayRecall
    case openProfiles
    case openProject
    case otherProfiles
    case profile
    case profileName
    case profiles
    case quitDisplayRecall
    case rebindToCurrentDisplays
    case refresh
    case recentActivityDescription
    case saveCommand
    case saveCurrentLayout
    case settings
    case setDefault
    case shortcuts
    case shortcutsDescription
    case showDockIcon
    case source
    case status
    case stop
    case summary
    case updates
    case updateChecksDescription
    case version
    case welcomeToDisplayRecall
}

public enum AppLocalization {
    public static func text(_ key: AppLocalizationKey, language: LanguagePreference) -> String {
        let resolved = language.resolved()
        return catalog[resolved]?[key] ?? catalog[.english]?[key] ?? key.rawValue
    }

    public static func pendingApplyTitle(
        profileName: String,
        remainingSeconds: Int,
        language: LanguagePreference
    ) -> String {
        switch language.resolved() {
        case .simplifiedChinese:
            "将在 \(remainingSeconds) 秒后应用 \(profileName)"
        case .english, .system:
            "Applying \(profileName) in \(remainingSeconds)s"
        }
    }

    public static func hasTranslations(for language: LanguagePreference) -> Bool {
        guard let strings = catalog[language.resolved()] else {
            return false
        }
        return AppLocalizationKey.allCases.allSatisfy { strings[$0]?.isEmpty == false }
    }

    private static let catalog: [LanguagePreference: [AppLocalizationKey: String]] = [
        .english: [
            .about: "About",
            .acknowledgements: "Acknowledgements",
            .activityLog: "Activity Log",
            .advancedCommand: "Advanced Command",
            .apply: "Apply",
            .applyNow: "Apply Now",
            .appearance: "Appearance",
            .architecture: "Architecture",
            .automaticApply: "Automatic Apply",
            .automaticDefault: "Automatic default",
            .automaticDefaultForSetup: "Automatic default for this setup",
            .automation: "Automation",
            .backend: "Backend",
            .backendReady: "displayplacer is ready",
            .backendVerificationFailed: "displayplacer verification failed",
            .checkForUpdates: "Check for Updates",
            .clearDefault: "Clear Default",
            .copyDetails: "Copy Details",
            .copyDiagnosticExport: "Copy Diagnostic Export",
            .createProfile: "Create Profile",
            .customBackendPath: "Custom backend path",
            .currentDisplaySetup: "Current Display Setup",
            .displayRecall: "Display Recall",
            .displayRecallSetupDescription: "Display Recall will verify its bundled displayplacer backend, then save your current display layout as the first profile.",
            .displaySetup: "Display Setup",
            .export: "Export",
            .exportSelected: "Export Selected",
            .fingerprint: "Fingerprint",
            .importProfiles: "Import",
            .language: "Language",
            .launchAtLogin: "Launch at Login",
            .noMatchingProfiles: "No matching profiles",
            .name: "Name",
            .noProfileSelected: "No Profile Selected",
            .noProfileSelectedDescription: "Save your current display layout or select a profile.",
            .noRecentActivity: "No recent activity",
            .openActivityLog: "Open Activity Log",
            .notes: "Notes",
            .openDisplayRecall: "Open Display Recall",
            .openProfiles: "Open Profiles",
            .openProject: "Open Project",
            .otherProfiles: "Other Profiles",
            .profile: "Profile",
            .profileName: "Profile name",
            .profiles: "Profiles",
            .quitDisplayRecall: "Quit Display Recall",
            .rebindToCurrentDisplays: "Rebind to Current Displays",
            .refresh: "Refresh",
            .recentActivityDescription: "Recent automation, apply, import, and diagnostic events.",
            .saveCommand: "Save Command",
            .saveCurrentLayout: "Save Current Layout",
            .settings: "Settings",
            .setDefault: "Set Default",
            .shortcuts: "Shortcuts",
            .shortcutsDescription: "Shortcuts are optional. Permission is requested only after a shortcut is configured.",
            .showDockIcon: "Show Dock icon",
            .source: "Source",
            .status: "Status",
            .stop: "Stop",
            .summary: "Summary",
            .updates: "Updates",
            .updateChecksDescription: "Automatic update checks are optional and never install silently.",
            .version: "Version",
            .welcomeToDisplayRecall: "Welcome to Display Recall"
        ],
        .simplifiedChinese: [
            .about: "关于",
            .acknowledgements: "致谢",
            .activityLog: "活动日志",
            .advancedCommand: "高级命令",
            .apply: "应用",
            .applyNow: "立即应用",
            .appearance: "外观",
            .architecture: "架构",
            .automaticApply: "自动应用",
            .automaticDefault: "自动默认",
            .automaticDefaultForSetup: "此显示器组合的自动默认",
            .automation: "自动化",
            .backend: "后端",
            .backendReady: "displayplacer 已就绪",
            .backendVerificationFailed: "displayplacer 验证失败",
            .checkForUpdates: "检查更新",
            .clearDefault: "清除默认",
            .copyDetails: "复制详情",
            .copyDiagnosticExport: "复制诊断导出",
            .createProfile: "创建配置",
            .customBackendPath: "自定义后端路径",
            .currentDisplaySetup: "当前显示器组合",
            .displayRecall: "Display Recall",
            .displayRecallSetupDescription: "Display Recall 会验证内置 displayplacer 后端，然后把当前显示器布局保存为第一个配置。",
            .displaySetup: "显示器组合",
            .export: "导出",
            .exportSelected: "导出所选",
            .fingerprint: "指纹",
            .importProfiles: "导入",
            .language: "语言",
            .launchAtLogin: "登录时启动",
            .noMatchingProfiles: "没有匹配的配置",
            .name: "名称",
            .noProfileSelected: "未选择配置",
            .noProfileSelectedDescription: "保存当前显示器布局，或选择一个配置。",
            .noRecentActivity: "暂无最近活动",
            .openActivityLog: "打开活动日志",
            .notes: "备注",
            .openDisplayRecall: "打开 Display Recall",
            .openProfiles: "打开配置",
            .openProject: "打开项目",
            .otherProfiles: "其他配置",
            .profile: "配置",
            .profileName: "配置名称",
            .profiles: "配置",
            .quitDisplayRecall: "退出 Display Recall",
            .rebindToCurrentDisplays: "重新绑定到当前显示器",
            .refresh: "刷新",
            .recentActivityDescription: "最近的自动化、应用、导入和诊断事件。",
            .saveCommand: "保存命令",
            .saveCurrentLayout: "保存当前布局",
            .settings: "设置",
            .setDefault: "设为默认",
            .shortcuts: "快捷键",
            .shortcutsDescription: "快捷键是可选的。只有配置快捷键后才会请求权限。",
            .showDockIcon: "显示 Dock 图标",
            .source: "来源",
            .status: "状态",
            .stop: "停止",
            .summary: "摘要",
            .updates: "更新",
            .updateChecksDescription: "自动检查更新是可选项，并且不会静默强制安装。",
            .version: "版本",
            .welcomeToDisplayRecall: "欢迎使用 Display Recall"
        ]
    ]
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

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
    case advancedBackend
    case advancedCommand
    case allActivity
    case apply
    case applyConfiguration
    case applyEvents
    case applyNow
    case appearance
    case architecture
    case automaticApply
    case automaticApplyConfiguration
    case automaticDefault
    case automaticDefaultForSetup
    case automation
    case automationEvents
    case backend
    case backendReady
    case backendVerificationFailed
    case allProfiles
    case cancel
    case checkForUpdates
    case chooseExportScope
    case clearDefault
    case conflicts
    case copyDetails
    case copyDiagnosticExport
    case copyEntry
    case createProfile
    case currentProfile
    case customBackendPath
    case currentDisplaySetup
    case dangerZone
    case deleteProfile
    case differentSetup
    case diagnostics
    case displayRecall
    case displayRecallSetupDescription
    case displaySetup
    case export
    case exportProfiles
    case exportScope
    case exportSelected
    case errorEvents
    case fingerprint
    case general
    case importProfiles
    case importConflictStrategy
    case importPreview
    case keepBoth
    case language
    case launchAtLogin
    case highRisk
    case matchingCurrentSetup
    case matchesCurrentSetup
    case needsRebind
    case noMatchingProfiles
    case name
    case noEntrySelected
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
    case profileCount
    case profileName
    case profiles
    case quitDisplayRecall
    case rebindToCurrentDisplays
    case refresh
    case replaceExisting
    case recentActivityDescription
    case save
    case saveCommand
    case saveCurrentProfile
    case saveCurrentLayout
    case searchProfiles
    case selectedProfiles
    case settings
    case setDefault
    case shortcuts
    case shortcutsDescription
    case showDockIcon
    case skipConflicts
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
            .activityLog: "Log",
            .advancedBackend: "Advanced Backend",
            .advancedCommand: "Advanced Command",
            .allActivity: "All",
            .apply: "Apply",
            .applyConfiguration: "Apply Configuration",
            .applyEvents: "Applies",
            .applyNow: "Apply Now",
            .appearance: "Appearance",
            .architecture: "Architecture",
            .automaticApply: "Automatic Apply",
            .automaticApplyConfiguration: "Automatic Apply Configuration",
            .automaticDefault: "Automatic default",
            .automaticDefaultForSetup: "Automatic default for this setup",
            .automation: "Automation",
            .automationEvents: "Automation",
            .backend: "Backend",
            .backendReady: "displayplacer is ready",
            .backendVerificationFailed: "displayplacer verification failed",
            .allProfiles: "All profiles",
            .cancel: "Cancel",
            .checkForUpdates: "Check for Updates",
            .chooseExportScope: "Choose what to include before saving the backup file.",
            .clearDefault: "Clear Default",
            .conflicts: "Conflicts",
            .copyDetails: "Copy Details",
            .copyDiagnosticExport: "Copy Diagnostic Export",
            .copyEntry: "Copy Entry",
            .createProfile: "Create Profile",
            .currentProfile: "Current profile",
            .customBackendPath: "Custom backend path",
            .currentDisplaySetup: "Current Display Setup",
            .dangerZone: "Danger Zone",
            .deleteProfile: "Delete Profile",
            .differentSetup: "Different setup",
            .diagnostics: "Diagnostics",
            .displayRecall: "Display Recall",
            .displayRecallSetupDescription: "Display Recall will verify its bundled displayplacer backend, then save your current display layout as the first profile.",
            .displaySetup: "Display Setup",
            .export: "Export",
            .exportProfiles: "Export Profiles",
            .exportScope: "Export scope",
            .exportSelected: "Export Selected",
            .errorEvents: "Errors",
            .fingerprint: "Fingerprint",
            .general: "General",
            .importProfiles: "Import",
            .importConflictStrategy: "Conflict strategy",
            .importPreview: "Import Preview",
            .keepBoth: "Keep Both",
            .language: "Language",
            .launchAtLogin: "Launch at Login",
            .highRisk: "High risk",
            .matchingCurrentSetup: "Matching current setup",
            .matchesCurrentSetup: "Matches current setup",
            .needsRebind: "Needs rebind",
            .noMatchingProfiles: "No matching profiles",
            .name: "Name",
            .noEntrySelected: "No Entry Selected",
            .noProfileSelected: "No Profile Selected",
            .noProfileSelectedDescription: "Save your current display layout or select a profile.",
            .noRecentActivity: "No recent activity",
            .openActivityLog: "Open Log",
            .notes: "Notes",
            .openDisplayRecall: "Open Panel",
            .openProfiles: "Open Profiles",
            .openProject: "Open Project",
            .otherProfiles: "Other Profiles",
            .profile: "Profile",
            .profileCount: "Profile count",
            .profileName: "Profile name",
            .profiles: "Profiles",
            .quitDisplayRecall: "Quit",
            .rebindToCurrentDisplays: "Rebind to Current Displays",
            .refresh: "Refresh",
            .replaceExisting: "Replace Existing",
            .recentActivityDescription: "Recent automation, apply, import, and diagnostic events.",
            .save: "Save",
            .saveCommand: "Save Command",
            .saveCurrentProfile: "Save Current Profile",
            .saveCurrentLayout: "Save Current Layout",
            .searchProfiles: "Search profiles",
            .selectedProfiles: "Selected profiles",
            .settings: "Settings",
            .setDefault: "Set Default",
            .shortcuts: "Shortcuts",
            .shortcutsDescription: "Shortcuts are optional. Permission is requested only after a shortcut is configured.",
            .showDockIcon: "Show Dock icon",
            .skipConflicts: "Skip Conflicts",
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
            .activityLog: "日志",
            .advancedBackend: "高级后端",
            .advancedCommand: "高级命令",
            .allActivity: "全部",
            .apply: "应用",
            .applyConfiguration: "应用配置",
            .applyEvents: "应用",
            .applyNow: "立即应用",
            .appearance: "外观",
            .architecture: "架构",
            .automaticApply: "自动应用",
            .automaticApplyConfiguration: "自动应用配置",
            .automaticDefault: "自动默认",
            .automaticDefaultForSetup: "此显示器组合的自动默认",
            .automation: "自动化",
            .automationEvents: "自动化",
            .backend: "后端",
            .backendReady: "displayplacer 已就绪",
            .backendVerificationFailed: "displayplacer 验证失败",
            .allProfiles: "所有配置",
            .cancel: "取消",
            .checkForUpdates: "检查更新",
            .chooseExportScope: "先选择要包含的配置，再保存备份文件。",
            .clearDefault: "清除默认",
            .conflicts: "冲突",
            .copyDetails: "复制详情",
            .copyDiagnosticExport: "复制诊断导出",
            .copyEntry: "复制条目",
            .createProfile: "创建配置",
            .currentProfile: "当前配置",
            .customBackendPath: "自定义后端路径",
            .currentDisplaySetup: "当前显示器组合",
            .dangerZone: "危险区域",
            .deleteProfile: "删除配置",
            .differentSetup: "不同组合",
            .diagnostics: "诊断",
            .displayRecall: "Display Recall",
            .displayRecallSetupDescription: "Display Recall 会验证内置 displayplacer 后端，然后把当前显示器布局保存为第一个配置。",
            .displaySetup: "显示器组合",
            .export: "导出",
            .exportProfiles: "导出配置",
            .exportScope: "导出范围",
            .exportSelected: "导出所选",
            .errorEvents: "错误",
            .fingerprint: "指纹",
            .general: "通用",
            .importProfiles: "导入",
            .importConflictStrategy: "冲突策略",
            .importPreview: "导入预览",
            .keepBoth: "保留两者",
            .language: "语言",
            .launchAtLogin: "登录时启动",
            .highRisk: "高风险",
            .matchingCurrentSetup: "匹配当前组合",
            .matchesCurrentSetup: "匹配当前组合",
            .needsRebind: "需要重新绑定",
            .noMatchingProfiles: "没有匹配的配置",
            .name: "名称",
            .noEntrySelected: "未选择条目",
            .noProfileSelected: "未选择配置",
            .noProfileSelectedDescription: "保存当前显示器布局，或选择一个配置。",
            .noRecentActivity: "暂无最近活动",
            .openActivityLog: "打开日志",
            .notes: "备注",
            .openDisplayRecall: "打开面板",
            .openProfiles: "打开配置",
            .openProject: "打开项目",
            .otherProfiles: "其他配置",
            .profile: "配置",
            .profileCount: "配置数量",
            .profileName: "配置名称",
            .profiles: "配置",
            .quitDisplayRecall: "退出",
            .rebindToCurrentDisplays: "重新绑定到当前显示器",
            .refresh: "刷新",
            .replaceExisting: "替换现有",
            .recentActivityDescription: "最近的自动化、应用、导入和诊断事件。",
            .save: "保存",
            .saveCommand: "保存命令",
            .saveCurrentProfile: "保存当前配置",
            .saveCurrentLayout: "保存当前布局",
            .searchProfiles: "搜索配置",
            .selectedProfiles: "所选配置",
            .settings: "设置",
            .setDefault: "设为默认",
            .shortcuts: "快捷键",
            .shortcutsDescription: "快捷键是可选的。只有配置快捷键后才会请求权限。",
            .showDockIcon: "显示 Dock 图标",
            .skipConflicts: "跳过冲突",
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

    public static func defaultName(index: Int, language: LanguagePreference) -> String {
        let number = max(1, index)
        return language.resolved() == .simplifiedChinese ? "配置 \(number)" : "Profile \(number)"
    }

    public static func firstAvailableDefaultName(
        existingNames: [String],
        language: LanguagePreference
    ) -> String {
        let existing = Set(existingNames)
        var index = 1
        while existing.contains(defaultName(index: index, language: language)) {
            index += 1
        }
        return defaultName(index: index, language: language)
    }
}

public enum DisplaySetupGroupNameGenerator {
    public static func defaultName(index: Int, language: LanguagePreference) -> String {
        let number = max(1, index)
        return language.resolved() == .simplifiedChinese ? "显示器组合 \(number)" : "Display Set \(number)"
    }

    public static func localizedDefaultNameIfNeeded(_ name: String, language: LanguagePreference) -> String {
        guard let index = defaultNameIndex(in: name) else {
            return name
        }
        return defaultName(index: index, language: language)
    }

    public static func firstAvailableDefaultName(
        existingNames: [String],
        language: LanguagePreference
    ) -> String {
        let existing = Set(existingNames)
        var index = 1
        while existing.contains(defaultName(index: index, language: language)) {
            index += 1
        }
        return defaultName(index: index, language: language)
    }

    private static func defaultNameIndex(in name: String) -> Int? {
        for prefix in ["Display Set ", "显示器组合 "] where name.hasPrefix(prefix) {
            let suffix = name.dropFirst(prefix.count)
            if let index = Int(suffix), index > 0 {
                return index
            }
        }
        return nil
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

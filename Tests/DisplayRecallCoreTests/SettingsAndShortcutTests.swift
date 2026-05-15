import XCTest
@testable import DisplayRecallCore

final class SettingsAndShortcutTests: XCTestCase {
    func testDefaultSettingsMatchMVPDefaults() {
        let settings = AppSettings()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.automaticApplyEnabled)
        XCTAssertEqual(settings.automaticApplyCountdownSeconds, 5)
        XCTAssertEqual(settings.dockIconVisibility, .automatic)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.backendSelection.source, .bundled)
    }

    func testAutomaticApplyCountdownPolicyAllowsZeroAndCapsAtThirtySeconds() {
        XCTAssertEqual(AutomaticApplyCountdownPolicy.defaultSeconds, 5)
        XCTAssertEqual(AutomaticApplyCountdownPolicy.normalized(-1), 0)
        XCTAssertEqual(AutomaticApplyCountdownPolicy.normalized(0), 0)
        XCTAssertEqual(AutomaticApplyCountdownPolicy.normalized(30), 30)
        XCTAssertEqual(AutomaticApplyCountdownPolicy.normalized(31), 30)
    }

    func testLegacyShowDockIconSettingMigratesToVisibilityPreference() throws {
        let visibleJSON = #"{"showDockIcon":true}"#.data(using: .utf8)!
        let hiddenJSON = #"{"showDockIcon":false}"#.data(using: .utf8)!

        XCTAssertEqual(
            try JSONDecoder().decode(AppSettings.self, from: visibleJSON).dockIconVisibility,
            .alwaysShow
        )
        XCTAssertEqual(
            try JSONDecoder().decode(AppSettings.self, from: hiddenJSON).dockIconVisibility,
            .automatic
        )
    }

    func testLanguageChoicesAndGeneratedNamesDoNotMutateExistingProfiles() {
        XCTAssertEqual(LanguagePreference.allCases.map(\.title), ["System", "English", "简体中文"])

        let profile = DisplayProfile(
            name: "Built-in display",
            command: #"displayplacer "id:AAA res:1920x1080 enabled:true origin:(0,0) degree:0""#,
            displaySetupFingerprint: DisplaySetupFingerprint(rawValue: "AAA|builtIn:true|count:1")
        )

        XCTAssertEqual(ProfileNameGenerator.generatedName(types: ["built-in screen"], language: .simplifiedChinese), "内置显示器")
        XCTAssertEqual(ProfileNameGenerator.defaultName(index: 1, language: .english), "Profile 1")
        XCTAssertEqual(ProfileNameGenerator.defaultName(index: 1, language: .simplifiedChinese), "配置 1")
        XCTAssertEqual(DisplaySetupGroupNameGenerator.defaultName(index: 1, language: .english), "Display Set 1")
        XCTAssertEqual(DisplaySetupGroupNameGenerator.defaultName(index: 1, language: .simplifiedChinese), "显示器组合 1")
        XCTAssertEqual(
            DisplaySetupGroupNameGenerator.localizedDefaultNameIfNeeded("Display Set 2", language: .simplifiedChinese),
            "显示器组合 2"
        )
        XCTAssertEqual(
            DisplaySetupGroupNameGenerator.localizedDefaultNameIfNeeded("Office", language: .simplifiedChinese),
            "Office"
        )
        XCTAssertEqual(
            ProfileNameGenerator.firstAvailableDefaultName(existingNames: ["配置 5"], language: .simplifiedChinese),
            "配置 1"
        )
        XCTAssertEqual(
            ProfileNameGenerator.firstAvailableDefaultName(existingNames: ["配置 1", "配置 3"], language: .simplifiedChinese),
            "配置 2"
        )
        XCTAssertEqual(
            DisplaySetupGroupNameGenerator.firstAvailableDefaultName(
                existingNames: ["显示器组合 1", "显示器组合 3"],
                language: .simplifiedChinese
            ),
            "显示器组合 2"
        )
        XCTAssertEqual(profile.name, "Built-in display")
    }

    func testLocalizationCatalogCoversEnglishChineseAndPreservesTechnicalDetails() {
        XCTAssertEqual(AppLocalization.text(.settings, language: .english), "Settings")
        XCTAssertEqual(AppLocalization.text(.settings, language: .simplifiedChinese), "设置")
        XCTAssertEqual(AppLocalization.text(.applyNow, language: .simplifiedChinese), "立即应用")
        XCTAssertEqual(
            AppLocalization.pendingApplyTitle(profileName: "displayplacer id:AAA", remainingSeconds: 5, language: .simplifiedChinese),
            "将在 5 秒后应用 displayplacer id:AAA"
        )
        XCTAssertTrue(AppLocalization.hasTranslations(for: .english))
        XCTAssertTrue(AppLocalization.hasTranslations(for: .simplifiedChinese))
    }

    func testSystemLanguageResolutionUsesPreferredLanguagesWithoutRequiringLiveMonitoring() {
        XCTAssertEqual(
            LanguagePreference.system.resolved(preferredLanguages: ["zh-Hans-US", "en-US"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            LanguagePreference.system.resolved(preferredLanguages: ["fr-FR", "en-US"]),
            .english
        )
        XCTAssertEqual(LanguagePreference.english.resolved(preferredLanguages: ["zh-Hans"]), .english)
    }

    func testShortcutBindingsDefaultEmptyAndDetectConflicts() {
        let first = ShortcutBinding(profileId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        let second = ShortcutBinding(
            profileId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            keyEquivalent: "⌘⇧1",
            keyCode: 18,
            modifierFlags: 1
        )
        let duplicate = ShortcutBinding(
            profileId: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            keyEquivalent: "⌘⇧1",
            keyCode: 18,
            modifierFlags: 1
        )

        XCTAssertNil(first.keyEquivalent)
        XCTAssertNil(first.keyCode)
        XCTAssertNil(first.modifierFlags)
        XCTAssertThrowsError(try ShortcutBindingValidator.validate([second, duplicate]))
    }

    func testShortcutPermissionIsOnlyNeededWhenAShortcutIsConfigured() {
        XCTAssertFalse(ShortcutPermissionPolicy.requiresPermissionPrompt(bindings: [
            ShortcutBinding(profileId: UUID())
        ]))
        XCTAssertTrue(ShortcutPermissionPolicy.requiresPermissionPrompt(bindings: [
            ShortcutBinding(profileId: UUID(), keyEquivalent: "⌘⇧1")
        ]))
    }

    func testShortcutBindingUpdatesCanClearModifyOrReplaceConflicts() throws {
        let first = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let second = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let commandShiftOne = ShortcutBinding(
            profileId: first,
            keyEquivalent: "⌘⇧1",
            keyCode: 18,
            modifierFlags: 1
        )

        let conflict = ShortcutBindingEditor.conflict(
            for: commandShiftOne.shortcut!,
            profileId: second,
            in: [commandShiftOne]
        )
        XCTAssertEqual(conflict?.profileId, first)

        var replaced = ShortcutBindingEditor.replace(
            commandShiftOne.shortcut!,
            for: second,
            in: [commandShiftOne]
        )
        XCTAssertEqual(replaced, [
            ShortcutBinding(profileId: second, keyEquivalent: "⌘⇧1", keyCode: 18, modifierFlags: 1)
        ])

        replaced = ShortcutBindingEditor.clear(profileId: second, in: replaced)
        XCTAssertTrue(replaced.isEmpty)
    }
}

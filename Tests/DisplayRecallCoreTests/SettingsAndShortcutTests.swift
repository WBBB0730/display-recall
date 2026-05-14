import XCTest
@testable import DisplayRecallCore

final class SettingsAndShortcutTests: XCTestCase {
    func testDefaultSettingsMatchMVPDefaults() {
        let settings = AppSettings()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.automaticApplyEnabled)
        XCTAssertEqual(settings.automaticApplyCountdownSeconds, 5)
        XCTAssertEqual(settings.language, .system)
        XCTAssertEqual(settings.backendSelection.source, .bundled)
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
            keyEquivalent: "⌘⇧1"
        )
        let duplicate = ShortcutBinding(
            profileId: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            keyEquivalent: "⌘⇧1"
        )

        XCTAssertNil(first.keyEquivalent)
        XCTAssertThrowsError(try ShortcutBindingValidator.validate([second, duplicate]))
        XCTAssertTrue(ShortcutBindingValidator.commonSystemShortcutWarnings(for: "⌘Space").contains(.spotlight))
    }

    func testShortcutPermissionIsOnlyNeededWhenAShortcutIsConfigured() {
        XCTAssertFalse(ShortcutPermissionPolicy.requiresPermissionPrompt(bindings: [
            ShortcutBinding(profileId: UUID())
        ]))
        XCTAssertTrue(ShortcutPermissionPolicy.requiresPermissionPrompt(bindings: [
            ShortcutBinding(profileId: UUID(), keyEquivalent: "⌘⇧1")
        ]))
    }
}

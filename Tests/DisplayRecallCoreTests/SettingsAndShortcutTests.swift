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
        XCTAssertEqual(profile.name, "Built-in display")
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

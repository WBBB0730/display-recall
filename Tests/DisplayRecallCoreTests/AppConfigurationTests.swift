import XCTest
@testable import DisplayRecallCore

final class AppConfigurationTests: XCTestCase {
    func testAppContractMatchesDisplayRecallMVP() {
        XCTAssertEqual(AppConfiguration.displayName, "Display Recall")
        XCTAssertEqual(AppConfiguration.bundleIdentifier, "dev.wbbb.display-recall")
        XCTAssertEqual(AppConfiguration.minimumSupportedMacOS.majorVersion, 13)
        XCTAssertTrue(AppConfiguration.runsAsMenuBarUtility)
        XCTAssertTrue(AppConfiguration.supportsDockIconVisibilityPreference)
    }

    func testMenuBarActionsExposeRequiredEntryPoints() {
        XCTAssertEqual(
            AppMenuAction.allCases.map(\.title),
            [
                "Open Display Recall",
                "Settings",
                "Quit Display Recall"
            ]
        )
    }

    func testWindowIdentifiersExposeSingleMainWindowEntryPoint() {
        XCTAssertEqual(AppWindow.main.id, "main")
        XCTAssertEqual(AppWindow.main.title, "Display Recall")
    }

    func testMainWindowSectionsExposeRequiredDestinationsAndDefault() {
        XCTAssertEqual(
            MainWindowSection.allCases.map(\.title),
            ["Profiles", "Log", "Settings", "About"]
        )
        XCTAssertEqual(MainWindowSection.default, .profiles)
        XCTAssertEqual(AppMenuAction.openDisplayRecall.targetSection, .profiles)
        XCTAssertEqual(AppMenuAction.openSettings.targetSection, .settings)
    }

    func testDockIconPreferenceHasAHiddenDefaultAndSettingsKey() {
        XCTAssertEqual(DockIconPreference.defaultValue, .hidden)
        XCTAssertEqual(DockIconPreference.userDefaultsKey, "showDockIcon")
    }

    func testAppBundleManifestSupportsLaunchingAsDisplayRecall() {
        let manifest = AppBundleManifest.default

        XCTAssertEqual(manifest.bundleName, "Display Recall")
        XCTAssertEqual(manifest.executableName, "DisplayRecall")
        XCTAssertEqual(manifest.bundleIdentifier, "dev.wbbb.display-recall")
        XCTAssertEqual(manifest.minimumSystemVersion, "13.0")
        XCTAssertEqual(manifest.localizations, ["en", "zh-Hans"])
        XCTAssertTrue(manifest.allowsMixedLocalizations)
    }
}

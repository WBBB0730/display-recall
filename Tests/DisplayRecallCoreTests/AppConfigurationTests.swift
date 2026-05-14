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
                "Open Profiles",
                "Settings",
                "Quit Display Recall"
            ]
        )
    }

    func testWindowIdentifiersExposeProfilesEntryPoint() {
        XCTAssertEqual(AppWindow.profiles.id, "profiles")
        XCTAssertEqual(AppWindow.profiles.title, "Profiles")
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
    }
}

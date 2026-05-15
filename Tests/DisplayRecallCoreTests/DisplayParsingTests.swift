import XCTest
@testable import DisplayRecallCore

final class DisplayParsingTests: XCTestCase {
    func testDisplayListParserBuildsFingerprintAndAuxiliaryMetadata() throws {
        let setup = try DisplayListParser.parse(Self.displayListOutput)

        XCTAssertEqual(setup.displays.count, 2)
        XCTAssertEqual(setup.fingerprint.rawValue, "AAA+BBB|builtIn:true|count:2")
        XCTAssertEqual(setup.displays[0].persistentID, "AAA")
        XCTAssertEqual(setup.displays[0].contextualID, "1")
        XCTAssertEqual(setup.displays[0].serialID, "s123")
        XCTAssertEqual(setup.displays[0].type, "27 inch external screen")
        XCTAssertEqual(setup.displays[0].resolution, "1920x1080")
        XCTAssertEqual(setup.displays[0].hertz, 60)
        XCTAssertEqual(setup.displays[0].scaling, "on")
        XCTAssertEqual(setup.displays[0].origin, "(0,0)")
        XCTAssertTrue(setup.displays[0].isPrimary)
        XCTAssertEqual(setup.displays[1].rotation, 90)
        XCTAssertTrue(setup.hasBuiltInDisplay)
        XCTAssertEqual(setup.enabledDisplayCount, 2)
        XCTAssertTrue(setup.summary.contains("2 displays"))
        XCTAssertTrue(setup.summary.contains("AAA"))
    }

    func testProfileCommandParserRecognizesMirroringAndEnabledSignals() throws {
        let command = #"displayplacer "id:AAA+BBB res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0" "id:CCC res:1280x720 enabled:false scaling:off origin:(1920,0) degree:0""#

        let layout = try DisplayCommandParser.parse(command)

        XCTAssertEqual(layout.targets.count, 2)
        XCTAssertEqual(layout.targets[0].displayIDs, ["AAA", "BBB"])
        XCTAssertTrue(layout.targets[0].isMirrored)
        XCTAssertEqual(layout.targets[0].enabled, true)
        XCTAssertEqual(layout.targets[1].displayIDs, ["CCC"])
        XCTAssertEqual(layout.targets[1].enabled, false)
        XCTAssertTrue(layout.containsDisabledDisplay)
        XCTAssertEqual(layout.fingerprint.rawValue, "AAA+BBB+CCC|builtIn:false|count:3")
    }

    func testMalformedProfileCommandThrowsParserError() {
        XCTAssertThrowsError(try DisplayCommandParser.parse("not displayplacer")) { error in
            XCTAssertEqual(error as? DisplayParsingError, .missingDisplayplacerCommand)
        }
    }

    private static let displayListOutput = """
    Persistent screen id: AAA
    Contextual screen id: 1
    Serial screen id: s123
    Type: 27 inch external screen
    Resolution: 1920x1080
    Hertz: 60
    Scaling: on
    Origin: (0,0) - main display
    Rotation: 0
    Enabled: true

    Persistent screen id: BBB
    Contextual screen id: 2
    Serial screen id: s456
    Type: built-in screen
    Resolution: 1080x1920
    Hertz: 60
    Scaling: on
    Origin: (1920,0)
    Rotation: 90
    Enabled: true

    displayplacer "id:AAA res:1920x1080 enabled:true scaling:on origin:(0,0) degree:0" "id:BBB res:1080x1920 enabled:true scaling:on origin:(1920,0) degree:90"
    """
}

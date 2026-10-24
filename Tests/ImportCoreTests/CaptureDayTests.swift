import XCTest
@testable import ImportCore

final class CaptureDayTests: XCTestCase {
    func testParsesExifDate() {
        let day = CaptureDay(dateString: "2026:10:24 14:03:11")
        XCTAssertEqual(day?.yearFolderName, "2026")
        XCTAssertEqual(day?.dateFolderName, "2026-10-24")
    }

    func testParsesIsoDateWithTimeZoneUsingWrittenLocalDate() {
        // Filmed 00:30 Norwegian time: must stay on the 24th, not move to the 23rd in UTC.
        let day = CaptureDay(dateString: "2026-10-24T00:30:12+02:00")
        XCTAssertEqual(day?.dateFolderName, "2026-10-24")
    }

    func testRejectsEmptyAndZeroDates() {
        XCTAssertNil(CaptureDay(dateString: ""))
        XCTAssertNil(CaptureDay(dateString: "0000:00:00 00:00:00"))
        XCTAssertNil(CaptureDay(dateString: "    :  :     :  :  "))
    }

    func testRejectsImpossibleDates() {
        XCTAssertNil(CaptureDay(year: 2026, month: 2, day: 30))
        XCTAssertNil(CaptureDay(year: 2026, month: 13, day: 1))
    }

    func testRejectsImplausibleYears() {
        XCTAssertNil(CaptureDay(year: 1980, month: 1, day: 1), "Camera clock reset to an old default")
        XCTAssertNil(CaptureDay(year: 2099, month: 1, day: 1))
    }

    func testDateConvertedToGivenTimeZone() throws {
        // 2026-10-23 22:30 UTC is 2026-10-24 00:30 in Oslo (UTC+2 in October).
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 23
        components.hour = 22; components.minute = 30
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = try XCTUnwrap(utc.date(from: components))

        let oslo = CaptureDay(date: date, timeZone: TimeZone(identifier: "Europe/Oslo")!)
        XCTAssertEqual(oslo?.dateFolderName, "2026-10-24")
    }

    func testSonyXMLParsing() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NonRealTimeMeta>
          <CreationDate value="2025-12-31T23:59:58+01:00"/>
        </NonRealTimeMeta>
        """
        XCTAssertEqual(SystemCaptureDateReader.parseSonyXML(xml)?.dateFolderName, "2025-12-31")
        XCTAssertNil(SystemCaptureDateReader.parseSonyXML("<NonRealTimeMeta/>"))
    }
}

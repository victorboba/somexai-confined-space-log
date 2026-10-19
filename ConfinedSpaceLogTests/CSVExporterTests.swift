import XCTest
@testable import ConfinedSpaceLog

final class CSVExporterTests: XCTestCase {
    func testQuotesAndEscapesFields() {
        XCTAssertEqual(CSVExporter.quote(#"say "hi""#), #""say ""hi""""#)
    }

    func testFormatsWholeNumbersWithoutDecimals() {
        XCTAssertEqual(CSVExporter.formatted(3), "3")
        XCTAssertEqual(CSVExporter.formatted(2.5), "2.5")
    }

    func testFormattedOptionalIsBlankForNil() {
        XCTAssertEqual(CSVExporter.formattedOptional(nil), "")
        XCTAssertEqual(CSVExporter.formattedOptional(21), "21")
    }

    @MainActor
    private func permit(number: String = "CSE-2026-001") -> Permit {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Test tank", location: "Yard")
        let permit = Permit(space: space, from: Date(timeIntervalSince1970: 0), hours: 2)
        permit.permitNumber = number
        permit.purpose = "Inspect, notes with a comma"
        permit.attendantName = "A. Attendant"
        return permit
    }

    @MainActor
    func testPermitCSVHasHeaderAndOneLinePerPermit() {
        let one = permit(number: "CSE-2026-001")
        let two = permit(number: "CSE-2026-002")
        let csv = CSVExporter.csv(for: [one, two])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3, "one header line plus one line per permit")
        XCTAssertEqual(String(lines[0]), CSVExporter.permitHeader)
        XCTAssertTrue(csv.contains("CSE-2026-001"))
        XCTAssertTrue(csv.contains(#""Inspect, notes with a comma""#))
    }

    @MainActor
    func testPermitCSVIsEmptyBodyWithJustAHeaderWhenThereAreNoPermits() {
        let csv = CSVExporter.csv(for: [])
        XCTAssertEqual(csv, CSVExporter.permitHeader + "\n")
    }

    @MainActor
    func testReadingsCSVHasOneRowPerReadingAcrossPermits() {
        let permit = permit()
        let first = GasReading(takenAt: Date(timeIntervalSince1970: 0), kind: .preEntry, testedBy: "D. W.")
        first.oxygenPercent = 20.9; first.lelPercent = 0; first.coPPM = 0; first.h2sPPM = 0
        first.permit = permit
        let second = GasReading(takenAt: Date(timeIntervalSince1970: 600), kind: .periodic, testedBy: "D. W.")
        second.oxygenPercent = 20.8
        second.permit = permit
        permit.readings = [first, second]

        let csv = CSVExporter.csvForReadings([permit])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[0]), CSVExporter.readingHeader)
        XCTAssertTrue(csv.contains(#""20.8""#))
    }

    @MainActor
    func testAReadingWithNoValueForAGasLeavesThatFieldBlankNotZero() {
        let permit = permit()
        let reading = GasReading(takenAt: .now, kind: .preEntry)
        reading.oxygenPercent = 20.9
        reading.permit = permit
        permit.readings = [reading]
        let csv = CSVExporter.csvForReadings([permit])
        let fields = csv.split(separator: "\n")[1].split(separator: ",", omittingEmptySubsequences: false)
        // permit_number,space_id,taken_at,kind,oxygen_percent,lel_percent,co_ppm,h2s_ppm,...
        XCTAssertEqual(fields[5], "\"\"", "lel_percent should be blank, not \"0\"")
    }
}

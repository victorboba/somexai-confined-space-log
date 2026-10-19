import XCTest
import PDFKit
@testable import ConfinedSpaceLog

/// The PDF is the document a supervisor posts at the manway and files afterwards, so these tests
/// check that the pieces the standard asks a permit to carry actually made it onto the page.
///
/// Rule 7: `PDFDocument` collapses whitespace when it extracts text, and draws made with
/// independent `.draw(in:)` calls can still come back with runs of internal whitespace
/// normalised differently than the source string. So every assertion here normalises with the
/// same regex before comparing, and never asserts that a label and a value sit adjacent in the
/// extracted string — only that each piece is present somewhere on the page.
final class PDFExporterTests: XCTestCase {
    @MainActor
    private func fullPermit(status: Status = .open) -> Permit {
        let space = ConfinedSpace(spaceID: "TK-104", name: "Process water tank", location: "Building 3")
        let permit = Permit(space: space, from: Date(timeIntervalSince1970: 1_700_000_000), hours: 4)
        permit.permitNumber = "CSE-2026-042"
        permit.purpose = "Quarterly interior inspection"
        permit.attendantName = "D. Whitfield"
        permit.supervisorName = "R. Castellanos"
        permit.hazards = [.oxygenDeficient, .engulfment]
        permit.isolationMeasures = "Inlet valve V-12 locked and tagged"
        permit.ventilation = "Forced-air blower, continuous"
        permit.oxygenMinPercent = 19.5
        permit.oxygenMaxPercent = 23.5

        let reading = GasReading(takenAt: permit.authorisedFrom, kind: .preEntry, testedBy: "D. Whitfield")
        reading.oxygenPercent = 20.9
        reading.instrument = "RKI GX-2012"
        permit.readings = [reading]

        let entrant = Entrant(name: "J. Okafor", company: "Facilities")
        entrant.timeIn = permit.authorisedFrom.addingTimeInterval(600)
        permit.entrants = [entrant]

        switch status {
        case .draft:
            break
        case .open:
            permit.supervisorSignature = Data([0, 1, 2])
            permit.issuedAt = permit.authorisedFrom
        case .closed:
            permit.supervisorSignature = Data([0, 1, 2])
            permit.issuedAt = permit.authorisedFrom
            entrant.timeOut = permit.authorisedFrom.addingTimeInterval(3600)
            permit.closedAt = permit.authorisedFrom.addingTimeInterval(3700)
            permit.closedBy = "R. Castellanos"
            permit.closeSignature = Data([0, 1, 2])
            permit.outcome = .completed
        }
        return permit
    }

    enum Status { case draft, open, closed }

    private func text(of url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            XCTFail("Could not open the exported PDF")
            return ""
        }
        var full = ""
        for index in 0..<document.pageCount {
            full += document.page(at: index)?.string ?? ""
            full += " "
        }
        return full.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    @MainActor
    func testTheDocumentCarriesTheCoreIdentificationOfTheEntry() throws {
        let url = try PDFExporter.export(fullPermit())
        let content = try text(of: url)
        XCTAssertTrue(content.contains("CSE-2026-042"))
        XCTAssertTrue(content.contains("TK-104"))
        XCTAssertTrue(content.contains("Process water tank"))
        XCTAssertTrue(content.contains("Quarterly interior inspection"))
        XCTAssertTrue(content.contains("D. Whitfield"))
        XCTAssertTrue(content.contains("R. Castellanos"))
    }

    @MainActor
    func testHazardsIsolationAndVentilationAllAppear() throws {
        let content = try text(of: try PDFExporter.export(fullPermit()))
        XCTAssertTrue(content.contains("Oxygen deficient atmosphere"))
        XCTAssertTrue(content.contains("Engulfment by liquid or solid"))
        XCTAssertTrue(content.contains("Inlet valve V-12 locked and tagged"))
        XCTAssertTrue(content.contains("Forced-air blower, continuous"))
    }

    @MainActor
    func testAcceptableConditionsPrintAsTheUsersOwnRecordedRangeNeverAsPassFail() throws {
        let content = try text(of: try PDFExporter.export(fullPermit()))
        XCTAssertTrue(content.contains("19.5"))
        XCTAssertTrue(content.contains("23.5"))
        XCTAssertFalse(content.localizedCaseInsensitiveContains("pass"))
        XCTAssertFalse(content.localizedCaseInsensitiveContains("safe to enter"))
    }

    @MainActor
    func testTheAtmosphericTestAndTheEntrantBothAppear() throws {
        let content = try text(of: try PDFExporter.export(fullPermit()))
        XCTAssertTrue(content.contains("RKI GX-2012"))
        XCTAssertTrue(content.contains("J. Okafor"))
        XCTAssertTrue(content.contains("Facilities"))
    }

    @MainActor
    func testADraftWithNoTestsStillExportsWithoutCrashing() throws {
        let permit = Permit(from: .now, hours: 1)
        let url = try PDFExporter.export(permit)
        let content = try text(of: url)
        XCTAssertTrue(content.contains("No test recorded"))
        XCTAssertTrue(content.contains("No entrants named"))
    }

    @MainActor
    func testAClosedPermitPrintsItsCancellationAndRetentionDate() throws {
        let permit = fullPermit(status: .closed)
        let content = try text(of: try PDFExporter.export(permit))
        XCTAssertTrue(content.contains("Work completed"))
        guard let retainUntil = permit.retainUntil else { return XCTFail("closed permit should have a retention date") }
        let dateText = retainUntil.formatted(date: .abbreviated, time: .omitted)
        XCTAssertTrue(content.contains(dateText))
    }

    @MainActor
    func testEveryExportCarriesTheNoSafetyDeterminationDisclaimer() throws {
        let content = try text(of: try PDFExporter.export(fullPermit()))
        XCTAssertTrue(content.contains("makes no safety determination"))
        XCTAssertTrue(content.contains("does not authorise any entry"))
    }
}

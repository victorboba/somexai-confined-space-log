import Foundation
import SwiftData
import UIKit

#if DEBUG
/// Debug-only sample data for screenshots and manual testing: one space register with three
/// spaces, and permits at each stage of the lifecycle so a screenshot or a manual pass can see
/// the board, the roster and the archive without typing anything in first.
/// Launch with `-sampleData` to insert it on first run, or use Settings → Debug → Insert sample data.
enum SampleData {
    static func insert(into context: ModelContext) {
        let tank = ConfinedSpace(spaceID: "TK-104", name: "Process water tank", location: "Building 3, north yard")
        tank.kind = .tank
        tank.knownHazards = [.oxygenDeficient, .residues, .engulfment]
        tank.isolationPoints = "Inlet valve V-12 locked and tagged. Agitator breaker CB-4 locked out."
        tank.oxygenMinPercent = 19.5
        tank.oxygenMaxPercent = 23.5
        tank.lelMaxPercent = 10
        tank.coMaxPPM = 25
        tank.h2sMaxPPM = 10

        let vault = ConfinedSpace(spaceID: "MH-88", name: "Lift station wet well", location: "Lift station 4")
        vault.kind = .sewer
        vault.knownHazards = [.oxygenDeficient, .toxic, .biological, .engulfment]
        vault.isolationPoints = "Pump breaker locked out. Upstream gate closed."
        vault.oxygenMinPercent = 19.5
        vault.oxygenMaxPercent = 23.5
        vault.lelMaxPercent = 10
        vault.h2sMaxPPM = 10

        let silo = ConfinedSpace(spaceID: "SL-02", name: "Grain silo 2", location: "Elevator row B")
        silo.kind = .silo
        silo.knownHazards = [.engulfment, .oxygenDeficient]
        silo.isolationPoints = "Auger breaker locked and tagged."

        [tank, vault, silo].forEach(context.insert)

        // A cancelled permit, well inside its retention year, with a full readings and roster
        // history — this is what the Archive tab shows.
        let closed = Permit(space: tank, from: Date().addingTimeInterval(-6 * 86400), hours: 4)
        closed.permitNumber = "CSE-2026-001"
        closed.purpose = "Quarterly interior inspection"
        closed.attendantName = "D. Whitfield"
        closed.supervisorName = "R. Castellanos"
        closed.supervisorSignature = signatureStub()
        closed.issuedAt = closed.authorisedFrom
        closed.ventilation = "Forced-air blower, continuous, exhausting through the top manway."
        closed.rescueServices = "Local fire department non-entry rescue, dialled 911 on the attendant's radio."
        closed.communicationProcedure = "Two-way radio between attendant and entrants; hand signal for silence."
        closed.retestIntervalMinutes = 30
        closed.closedAt = closed.authorisedFrom.addingTimeInterval(3.5 * 3600)
        closed.closedBy = "R. Castellanos"
        closed.closeSignature = signatureStub()
        closed.outcome = .completed
        context.insert(closed)

        let preEntry = GasReading(takenAt: closed.authorisedFrom, kind: .preEntry, testedBy: "D. Whitfield")
        preEntry.oxygenPercent = 20.9; preEntry.lelPercent = 0; preEntry.coPPM = 0; preEntry.h2sPPM = 0
        preEntry.instrument = "RKI GX-2012 #4471"
        preEntry.permit = closed
        context.insert(preEntry)

        let midEntry = GasReading(takenAt: closed.authorisedFrom.addingTimeInterval(1.5 * 3600), kind: .periodic, testedBy: "D. Whitfield")
        midEntry.oxygenPercent = 20.8; midEntry.lelPercent = 0; midEntry.coPPM = 1; midEntry.h2sPPM = 0
        midEntry.instrument = "RKI GX-2012 #4471"
        midEntry.permit = closed
        context.insert(midEntry)

        let entrant1 = Entrant(name: "J. Okafor", company: "Facilities")
        entrant1.timeIn = closed.authorisedFrom.addingTimeInterval(15 * 60)
        entrant1.timeOut = closed.authorisedFrom.addingTimeInterval(3 * 3600)
        entrant1.permit = closed
        context.insert(entrant1)

        // An open permit, mid-entry, with one entrant still inside — this is what the board and
        // the widget summarise.
        let open = Permit(space: vault, from: Date().addingTimeInterval(-40 * 60), hours: 3)
        open.permitNumber = "CSE-2026-002"
        open.purpose = "Clear pump intake blockage"
        open.attendantName = "M. Silva"
        open.supervisorName = "R. Castellanos"
        open.supervisorSignature = signatureStub()
        open.issuedAt = open.authorisedFrom
        open.ventilation = "Portable blower running at the manway."
        open.rescueServices = "On-site retrieval line and tripod; fire department on standby."
        open.communicationProcedure = "Voice contact, line of sight to the manway."
        open.retestIntervalMinutes = 20
        context.insert(open)

        let openPreEntry = GasReading(takenAt: open.authorisedFrom, kind: .preEntry, testedBy: "M. Silva")
        openPreEntry.oxygenPercent = 20.7; openPreEntry.lelPercent = 0; openPreEntry.coPPM = 2; openPreEntry.h2sPPM = 0
        openPreEntry.instrument = "Industrial Scientific MX6 #118"
        openPreEntry.permit = open
        context.insert(openPreEntry)

        let entrant2 = Entrant(name: "A. Reyes", company: "Mechanical")
        entrant2.timeIn = open.authorisedFrom.addingTimeInterval(10 * 60)
        entrant2.permit = open
        context.insert(entrant2)

        // A draft, waiting to be issued.
        let draft = Permit(space: silo, from: Date().addingTimeInterval(3600), hours: 2)
        draft.permitNumber = "CSE-2026-003"
        draft.purpose = "Inspect discharge gate"
        context.insert(draft)
    }

    /// A tiny placeholder PNG so sample records show a signature without drawing one.
    private static func signatureStub() -> Data? {
        let size = CGSize(width: 200, height: 60)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).pngData { ctx in
            UIColor.label.setStroke()
            let path = UIBezierPath()
            path.lineWidth = 2.5
            path.move(to: CGPoint(x: 12, y: 40))
            path.addCurve(to: CGPoint(x: 90, y: 15), controlPoint1: CGPoint(x: 35, y: 5), controlPoint2: CGPoint(x: 60, y: 55))
            path.addCurve(to: CGPoint(x: 188, y: 30), controlPoint1: CGPoint(x: 120, y: -10), controlPoint2: CGPoint(x: 160, y: 55))
            path.stroke()
        }
    }
}
#endif

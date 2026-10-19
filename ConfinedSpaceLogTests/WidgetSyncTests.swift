import Testing
import Foundation
@testable import ConfinedSpaceLog

/// `WidgetSnapshot.make` is the pure function behind both the widget and the "who is inside"
/// Shortcut, so it is tested without a widget extension or an App Group in sight.
@MainActor
struct WidgetSyncTests {
    @Test func anEmptyPermitListIsAllZeroes() {
        let snapshot = WidgetSnapshot.make(from: [])
        #expect(snapshot.openPermits == 0)
        #expect(snapshot.peopleInside == 0)
        #expect(snapshot.draftPermits == 0)
        #expect(snapshot.insideSummary == nil)
    }

    @Test func countsSplitCorrectlyAcrossStatuses() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let draft = Permit(from: now, hours: 1)
        let open = Permit(from: now, hours: 4); open.issuedAt = now
        let entrant = Entrant(name: "A. Reyes"); entrant.timeIn = now
        open.entrants = [entrant]
        let closed = Permit(from: now, hours: 1); closed.issuedAt = now; closed.closedAt = now

        let snapshot = WidgetSnapshot.make(from: [draft, open, closed], asOf: now)
        #expect(snapshot.openPermits == 1)
        #expect(snapshot.draftPermits == 1)
        #expect(snapshot.peopleInside == 1)
        #expect(snapshot.insideSummary == "A. Reyes")
    }

    @Test func expiredOpenPermitsAreCountedSeparately() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expired = Permit(from: now.addingTimeInterval(-7200), hours: 1)
        expired.issuedAt = now.addingTimeInterval(-7200)
        let snapshot = WidgetSnapshot.make(from: [expired], asOf: now)
        #expect(snapshot.expiredOpenPermits == 1)
    }

    @Test func nextExpiryPicksTheSoonestOpenPermit() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let soon = Permit(from: now, hours: 1); soon.issuedAt = now; soon.permitNumber = "soon"
        let later = Permit(from: now, hours: 5); later.issuedAt = now; later.permitNumber = "later"
        let snapshot = WidgetSnapshot.make(from: [soon, later], asOf: now)
        #expect(snapshot.nextExpiry == soon.authorisedTo)
    }

    @Test func spokenSummaryReadsBackNaturally() {
        var snapshot = WidgetSnapshot()
        #expect(snapshot.spokenSummary == "No permits are open.")
        snapshot.openPermits = 1
        snapshot.peopleInside = 0
        #expect(snapshot.spokenSummary == "1 permit is open. Nobody is signed in.")
        snapshot.peopleInside = 2
        snapshot.insideSummary = "A. Reyes, J. Okafor"
        #expect(snapshot.spokenSummary == "1 permit is open. 2 people are inside: A. Reyes, J. Okafor.")
    }
}

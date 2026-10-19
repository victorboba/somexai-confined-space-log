import Testing
import Foundation
@testable import ConfinedSpaceLog

@MainActor
struct SpaceTests {
    @Test func titleCombinesTheIDAndTheName() {
        let space = ConfinedSpace(spaceID: "TK-104", name: "Process water tank")
        #expect(space.title == "TK-104 — Process water tank")
    }

    @Test func titleFallsBackToWhicheverHalfIsPresent() {
        #expect(ConfinedSpace(spaceID: "TK-104", name: "").title == "TK-104")
        #expect(ConfinedSpace(spaceID: "", name: "Process water tank").title == "Process water tank")
        #expect(ConfinedSpace(spaceID: "", name: "").title == "Unnamed space")
    }

    @Test func hasAcceptableConditionsIsFalseUntilOneIsRecorded() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank")
        #expect(!space.hasAcceptableConditions)
        space.h2sMaxPPM = 10
        #expect(space.hasAcceptableConditions)
    }

    @Test func openPermitsFiltersToOnlyOpenOnes() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank")
        let draft = Permit(space: space, from: .now, hours: 1)
        let open = Permit(space: space, from: .now, hours: 1); open.issuedAt = .now
        let closed = Permit(space: space, from: .now, hours: 1); closed.issuedAt = .now; closed.closedAt = .now
        space.permits = [draft, open, closed]
        #expect(space.openPermits.count == 1)
        #expect(space.openPermits.first === open)
    }

    @Test func knownHazardsRoundTripsThroughTheRawStorage() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank")
        space.knownHazards = [.oxygenDeficient, .engulfment]
        #expect(Set(space.knownHazards) == [.oxygenDeficient, .engulfment])
        #expect(space.knownHazardsRaw.count == 2)
    }
}

@MainActor
struct EntrantTests {
    @Test func anEntrantWhoHasNotSignedInIsNotInside() {
        #expect(!Entrant(name: "A. Reyes").isInside)
        #expect(!Entrant(name: "A. Reyes").hasEntered)
    }

    @Test func signingInMakesThemInsideAndEntered() {
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = .now
        #expect(entrant.isInside)
        #expect(entrant.hasEntered)
    }

    @Test func signingOutEndsInsideButKeepsEntered() {
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = .now
        entrant.timeOut = .now
        #expect(!entrant.isInside)
        #expect(entrant.hasEntered)
    }

    @Test func timeInsideIsNilBeforeEverEntering() {
        #expect(Entrant(name: "A. Reyes").timeInside() == nil)
    }

    @Test func timeInsideMeasuresToNowWhileStillIn() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = now.addingTimeInterval(-600)
        #expect(entrant.timeInside(asOf: now) == 600)
    }

    @Test func timeInsideMeasuresBetweenInAndOutOnceSignedOut() {
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = Date(timeIntervalSince1970: 0)
        entrant.timeOut = Date(timeIntervalSince1970: 900)
        #expect(entrant.timeInside(asOf: .distantFuture) == 900)
    }

    @Test func durationTextDropsTheHourWhenThereIsNone() {
        #expect(Entrant.durationText(600) == "10 min")
    }

    @Test func durationTextIncludesTheHourWhenThereIsOne() {
        #expect(Entrant.durationText(3600 + 900) == "1 hr 15 min")
    }

    @Test func displayNameFallsBackWhenBlank() {
        #expect(Entrant(name: "  ").displayName == "Unnamed entrant")
        #expect(Entrant(name: "A. Reyes").displayName == "A. Reyes")
    }
}

/// "Who is in the space right now" is the question a permit exists to answer, so the sort that
/// puts entrants inside first and named-but-not-yet-entered ones last is worth locking down.
@MainActor
struct EntrantOrderingTests {
    @Test func sortedEntrantsPutsThoseInsideFirst() {
        let permit = Permit(from: .now, hours: 2)
        let outside = Entrant(name: "Outside")
        outside.timeIn = Date(timeIntervalSince1970: 0)
        outside.timeOut = Date(timeIntervalSince1970: 100)
        let inside = Entrant(name: "Inside")
        inside.timeIn = Date(timeIntervalSince1970: 200)
        permit.entrants = [outside, inside]

        #expect(permit.sortedEntrants.first?.displayName == "Inside")
        #expect(permit.entrantsInside.map(\.displayName) == ["Inside"])
        #expect(permit.insideCount == 1)
    }
}

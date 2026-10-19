import Testing
import Foundation
@testable import ConfinedSpaceLog

/// The permit's four states, and the standard's own preconditions for moving between them.
@MainActor
struct PermitLifecycleTests {
    private func draftPermit() -> Permit {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Test tank", location: "Yard")
        return Permit(space: space, from: Date(timeIntervalSince1970: 1_000_000), hours: 4)
    }

    @Test func aBrandNewPermitIsADraft() {
        #expect(draftPermit().status == .draft)
    }

    @Test func issuingSetsStatusToOpen() {
        let permit = draftPermit()
        permit.issuedAt = .now
        #expect(permit.status == .open)
    }

    @Test func cancellingSetsStatusToClosedRegardlessOfIssuedAt() {
        let permit = draftPermit()
        permit.issuedAt = .now
        permit.closedAt = .now
        #expect(permit.status == .closed)
    }

    @Test func aDraftListsEveryMissingPrecondition() {
        let permit = draftPermit()
        let blockers = permit.issueBlockers
        #expect(blockers.count == 5, "purpose, window already valid, attendant, supervisor, signature, and a test — window defaults valid so 5 remain")
        #expect(!permit.canIssue)
    }

    @Test func aFullyFilledDraftCanBeIssued() {
        let permit = draftPermit()
        permit.purpose = "Inspection"
        permit.attendantName = "A. Attendant"
        permit.supervisorName = "S. Supervisor"
        permit.supervisorSignature = Data([0, 1, 2])
        let reading = GasReading(kind: .preEntry)
        reading.oxygenPercent = 20.9
        permit.readings = [reading]
        #expect(permit.issueBlockers.isEmpty)
        #expect(permit.canIssue)
    }

    @Test func aWindowThatEndsBeforeItStartsBlocksIssuing() {
        let permit = draftPermit()
        permit.authorisedTo = permit.authorisedFrom.addingTimeInterval(-1)
        #expect(permit.issueBlockers.contains { $0.contains("end after it starts") })
    }

    @Test func anUnassignedSpaceBlocksIssuing() {
        let permit = Permit(from: Date(timeIntervalSince1970: 0), hours: 2)
        #expect(permit.issueBlockers.contains { $0.contains("Choose the space") })
    }

    @Test func closingIsBlockedWhileSomeoneIsStillInside() {
        let permit = draftPermit()
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = .now
        permit.entrants = [entrant]
        #expect(permit.closeBlockers.contains { $0.contains("still signed in") })
    }

    @Test func closingIsBlockedWithoutASupervisorNameOrSignature() {
        let permit = draftPermit()
        #expect(permit.closeBlockers.contains { $0.contains("Name the entry supervisor") })
        permit.closedBy = "S. Supervisor"
        #expect(permit.closeBlockers.contains { $0.contains("sign to cancel") })
    }

    @Test func closingIsUnblockedOnceEveryoneIsOutAndItIsSigned() {
        let permit = draftPermit()
        let entrant = Entrant(name: "A. Reyes")
        entrant.timeIn = permit.authorisedFrom
        entrant.timeOut = permit.authorisedFrom.addingTimeInterval(600)
        permit.entrants = [entrant]
        permit.closedBy = "S. Supervisor"
        permit.closeSignature = Data([0])
        #expect(permit.closeBlockers.isEmpty)
    }
}

/// Adopting a space copies its fields forward onto a draft, and never touches an issued permit.
@MainActor
struct PermitAdoptionTests {
    @Test func adoptingASpaceCopiesItsHazardsAndConditionsOntoADraft() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank", location: "Yard")
        space.knownHazards = [.oxygenDeficient, .engulfment]
        space.isolationPoints = "Valve V-1 locked"
        space.oxygenMinPercent = 19.5
        space.lelMaxPercent = 10

        let permit = Permit(from: .now, hours: 2)
        permit.adopt(space)

        #expect(permit.space === space)
        #expect(permit.hazards.contains(.oxygenDeficient))
        #expect(permit.isolationMeasures == "Valve V-1 locked")
        #expect(permit.oxygenMinPercent == 19.5)
        #expect(permit.lelMaxPercent == 10)
    }

    @Test func adoptingDoesNothingOnceThePermitIsIssued() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank", location: "Yard")
        let other = ConfinedSpace(spaceID: "TK-2", name: "Other tank", location: "Yard")
        let permit = Permit(space: space, from: .now, hours: 2)
        permit.issuedAt = .now

        permit.adopt(other)

        #expect(permit.space === space, "an issued permit keeps the space it was issued with")
    }

    @Test func choosingNoSpaceClearsTheSnapshotOnADraft() {
        let space = ConfinedSpace(spaceID: "TK-1", name: "Tank", location: "Yard")
        let permit = Permit(space: space, from: .now, hours: 2)
        permit.adopt(nil)
        #expect(permit.space == nil)
        #expect(permit.spaceTitle == "Unassigned space")
    }
}

/// The expiry clock and the one-year retention clock — the two "how long" numbers the board and
/// the archive show, tested at their boundaries because that is where an off-by-one hides.
@MainActor
struct PermitClockTests {
    @Test func aPermitWithTimeLeftIsNotExpired() {
        let permit = Permit(from: .now, hours: 4)
        permit.issuedAt = .now
        #expect(!permit.isExpired())
        #expect(permit.timeRemaining() > 0)
    }

    @Test func aPermitExactlyAtItsEndIsExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now.addingTimeInterval(-3600), hours: 1)
        permit.issuedAt = now.addingTimeInterval(-3600)
        #expect(permit.isExpired(asOf: now))
    }

    @Test func aDraftIsNeverExpiredEvenPastItsWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now.addingTimeInterval(-7200), hours: 1)
        #expect(!permit.isExpired(asOf: now))
    }

    @Test func remainingTextNeverShowsANegativeNumber() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now.addingTimeInterval(-7200), hours: 1)
        permit.issuedAt = now.addingTimeInterval(-7200)
        let text = permit.remainingText(asOf: now)
        #expect(!text.contains("-"))
        #expect(text.contains("over"))
    }

    @Test func aPermitJustClosedHasTheFullYearRemaining() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now, hours: 1)
        permit.closedAt = now
        #expect(permit.retentionDaysRemaining(asOf: now) == 365)
        #expect(!permit.isPastRetention(asOf: now))
    }

    @Test func aPermitClosedOverAYearAgoIsPastRetention() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now, hours: 1)
        permit.closedAt = now.addingTimeInterval(-400 * 86400)
        #expect(permit.isPastRetention(asOf: now))
        #expect(permit.retentionDaysRemaining(asOf: now)! < 0)
    }

    @Test func aDraftOrOpenPermitHasNoRetentionDate() {
        let permit = Permit(from: .now, hours: 1)
        #expect(permit.retainUntil == nil)
        #expect(permit.retentionSummary() == nil)
    }

    @Test func retestOverdueOnlyAppliesToOpenPermitsWithAnIntervalAndAReading() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let permit = Permit(from: now.addingTimeInterval(-3600), hours: 4)
        permit.issuedAt = now.addingTimeInterval(-3600)
        permit.retestIntervalMinutes = 30
        #expect(!permit.isRetestOverdue(asOf: now), "no reading recorded yet, so nothing is overdue")

        let reading = GasReading(takenAt: now.addingTimeInterval(-1800), kind: .preEntry)
        permit.readings = [reading]
        #expect(permit.isRetestOverdue(asOf: now))
    }

    @Test func noRetestIntervalMeansNoRetestClock() {
        let permit = Permit(from: .now, hours: 1)
        permit.issuedAt = .now
        let reading = GasReading(takenAt: .now, kind: .preEntry)
        permit.readings = [reading]
        #expect(permit.nextRetestDue() == nil)
        #expect(!permit.isRetestOverdue())
    }
}

/// The reading-versus-range comparison the standard leaves entirely to the entry supervisor.
@MainActor
struct AcceptableConditionsTests {
    @Test func aRangeWithBothEndsDescribesAsBetween() {
        let range = AcceptableRange(minimum: 19.5, maximum: 23.5)
        #expect(range.describe(unit: "%") == "19.5 to 23.5%")
    }

    @Test func aMaximumOnlyRangeDescribesAsAtMost() {
        let range = AcceptableRange(minimum: nil, maximum: 10)
        #expect(range.describe(unit: "%") == "at most 10%")
    }

    @Test func noRangeAtAllDescribesAsNotRecorded() {
        #expect(AcceptableRange(minimum: nil, maximum: nil).describe(unit: "ppm") == "not recorded")
    }

    @Test func aReadingWithNoValueForAGasIsReportedAsNotMeasured() {
        let permit = Permit(from: .now, hours: 1)
        permit.oxygenMinPercent = 19.5
        let reading = GasReading(kind: .preEntry)
        #expect(permit.check(.oxygen, in: reading) == .notMeasured)
    }

    @Test func aMeasuredGasWithNoRecordedRangeIsReportedAsNoRange() {
        let permit = Permit(from: .now, hours: 1)
        let reading = GasReading(kind: .preEntry)
        reading.coPPM = 12
        #expect(permit.check(.carbonMonoxide, in: reading) == .noRangeRecorded)
    }

    @Test func aReadingInsideTheRecordedRangeIsWithinRange() {
        let permit = Permit(from: .now, hours: 1)
        permit.oxygenMinPercent = 19.5
        permit.oxygenMaxPercent = 23.5
        let reading = GasReading(kind: .preEntry)
        reading.oxygenPercent = 20.9
        #expect(permit.check(.oxygen, in: reading) == .withinRecordedRange)
    }

    @Test func aReadingOutsideTheRecordedRangeIsOutsideRange() {
        let permit = Permit(from: .now, hours: 1)
        permit.oxygenMinPercent = 19.5
        let reading = GasReading(kind: .preEntry)
        reading.oxygenPercent = 18.0
        #expect(permit.check(.oxygen, in: reading) == .outsideRecordedRange)
    }

    @Test func theGasListDropsToTheStandardFourUntilAFifthIsNamed() {
        let permit = Permit(from: .now, hours: 1)
        #expect(permit.gases == Gas.standard)
        permit.otherGasName = "Chlorine"
        #expect(permit.gases == Gas.allCases)
    }
}

/// The permit number suggester: a convenience, tested because a duplicate number on two printed
/// permits is exactly the kind of paperwork mistake this app exists to prevent.
@MainActor
struct PermitNumberingTests {
    @Test func theFirstPermitOfTheYearIsNumberOne() {
        // Built from local components on purpose: midnight UTC on 1 January is still 31 December
        // in any western timezone, and the permit number takes its year from the user's own
        // calendar, as a number printed on a paper permit should.
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        #expect(Permit.suggestedNumber(after: [], asOf: now) == "CSE-2026-001")
    }

    @Test func itContinuesTheHighestExistingNumberForTheYear() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        let p1 = Permit(from: .now, hours: 1); p1.permitNumber = "CSE-2026-001"
        let p2 = Permit(from: .now, hours: 1); p2.permitNumber = "CSE-2026-007"
        #expect(Permit.suggestedNumber(after: [p1, p2], asOf: now) == "CSE-2026-008")
    }

    @Test func itIgnoresNumbersFromOtherYearsOrOtherFormats() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        let old = Permit(from: .now, hours: 1); old.permitNumber = "CSE-2025-099"
        let custom = Permit(from: .now, hours: 1); custom.permitNumber = "A-1"
        #expect(Permit.suggestedNumber(after: [old, custom], asOf: now) == "CSE-2026-001")
    }
}

import Foundation
import SwiftData

/// One written entry permit, and the lifecycle 29 CFR 1910.146 puts it through.
///
/// The permit is not a checklist. It is a document with four states, and the whole app is
/// built on them:
///
/// - **Drafted** — the entry supervisor fills in the space, the purpose, the hazards, the
///   isolation and the ventilation. Nobody may enter.
/// - **Tested** — atmospheric readings are taken *before* entry and again through it.
///   1910.146(f)(10) asks for the results *and* when they were taken, so every reading is
///   timestamped and the times print on the record.
/// - **Open** — the supervisor signs to authorise entry, entrants sign in and out by name and
///   time, and an attendant is named for the duration. At any moment the permit can answer
///   "who is in the space right now", which is the question an attendant exists to answer.
/// - **Cancelled** — the supervisor signs to cancel it. 1910.146(e)(6) then requires the
///   cancelled permit to be retained at least one year and reviewed, so the archive runs a
///   retention clock on every closed permit.
///
/// **The app never decides whether conditions are acceptable.** The acceptable entry conditions
/// are the user's own, copied from the space they recorded them on. A reading is shown against
/// that range and labelled as the user's own criterion. No default thresholds ship with the app.
@Model
final class Permit {
    var id: UUID = UUID()
    var permitNumber: String = ""
    var purpose: String = ""

    /// Nullify on the space side, so a cancelled permit outlives its space being deleted.
    var space: ConfinedSpace? = nil
    /// The identification, copied at draft time. A retained record has to stand on its own.
    var spaceTitleSnapshot: String = ""
    var spaceLocationSnapshot: String = ""

    // MARK: The authorised window — 1910.146(f)(3)
    var authorisedFrom: Date = Date()
    var authorisedTo: Date = Date()

    // MARK: The people — (f)(4), (f)(5), (f)(6)
    var attendantName: String = ""
    var supervisorName: String = ""
    @Attribute(.externalStorage) var supervisorSignature: Data? = nil
    /// Set the moment the supervisor signs to issue. Nil means the permit is still a draft.
    var issuedAt: Date? = nil

    // MARK: The hazards and the controls — (f)(7), (f)(8)
    var hazardsRaw: [String] = []
    var otherHazards: String = ""
    var isolationMeasures: String = ""
    var ventilation: String = ""

    // MARK: Acceptable entry conditions — (f)(9). The user's own, never the app's.
    var oxygenMinPercent: Double? = nil
    var oxygenMaxPercent: Double? = nil
    var lelMaxPercent: Double? = nil
    var coMaxPPM: Double? = nil
    var h2sMaxPPM: Double? = nil
    var otherGasName: String = ""
    var otherGasUnit: String = ""
    var otherGasMax: Double? = nil
    /// How often the site's own program says to retest during the entry. Zero means the user
    /// has not set one, and the app then shows no retest clock rather than inventing an interval.
    var retestIntervalMinutes: Int = 0

    // MARK: The rest of the permit — (f)(11) to (f)(15)
    var rescueServices: String = ""
    var communicationProcedure: String = ""
    var equipment: String = ""
    var additionalPermits: String = ""
    var otherInformation: String = ""

    // MARK: Cancellation — (e)(5), (e)(6)
    var closedAt: Date? = nil
    var closedBy: String = ""
    @Attribute(.externalStorage) var closeSignature: Data? = nil
    var outcomeRaw: String = PermitOutcome.completed.rawValue
    var closeNotes: String = ""

    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \GasReading.permit)
    var readings: [GasReading]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Entrant.permit)
    var entrants: [Entrant]? = nil

    init(space: ConfinedSpace? = nil, from: Date = .now, hours: Double = 8) {
        self.id = UUID()
        self.createdAt = .now
        self.authorisedFrom = from
        self.authorisedTo = from.addingTimeInterval(hours * 3600)
        self.space = space
        if let space {
            self.spaceTitleSnapshot = space.title
            self.spaceLocationSnapshot = space.location
            self.hazardsRaw = space.knownHazardsRaw
            self.otherHazards = space.otherHazards
            self.isolationMeasures = space.isolationPoints
            self.oxygenMinPercent = space.oxygenMinPercent
            self.oxygenMaxPercent = space.oxygenMaxPercent
            self.lelMaxPercent = space.lelMaxPercent
            self.coMaxPPM = space.coMaxPPM
            self.h2sMaxPPM = space.h2sMaxPPM
            self.otherGasName = space.otherGasName
            self.otherGasUnit = space.otherGasUnit
            self.otherGasMax = space.otherGasMax
        }
    }

    /// Copy the space's identification and everything a permit inherits from it. Called when
    /// the space is chosen or changed on a draft, so the permit is never half from one space
    /// and half from another. A permit that has already been issued keeps what it was issued
    /// with — the record is the record.
    func adopt(_ newSpace: ConfinedSpace?) {
        guard status == .draft else { return }
        space = newSpace
        guard let newSpace else {
            spaceTitleSnapshot = ""
            spaceLocationSnapshot = ""
            return
        }
        spaceTitleSnapshot = newSpace.title
        spaceLocationSnapshot = newSpace.location
        hazardsRaw = newSpace.knownHazardsRaw
        otherHazards = newSpace.otherHazards
        isolationMeasures = newSpace.isolationPoints
        oxygenMinPercent = newSpace.oxygenMinPercent
        oxygenMaxPercent = newSpace.oxygenMaxPercent
        lelMaxPercent = newSpace.lelMaxPercent
        coMaxPPM = newSpace.coMaxPPM
        h2sMaxPPM = newSpace.h2sMaxPPM
        otherGasName = newSpace.otherGasName
        otherGasUnit = newSpace.otherGasUnit
        otherGasMax = newSpace.otherGasMax
    }

    // MARK: - Lifecycle

    var status: PermitStatus {
        if closedAt != nil { return .closed }
        return issuedAt == nil ? .draft : .open
    }

    var outcome: PermitOutcome {
        get { PermitOutcome(rawValue: outcomeRaw) ?? .completed }
        set { outcomeRaw = newValue.rawValue }
    }

    var hazards: [SpaceHazard] {
        get { hazardsRaw.compactMap(SpaceHazard.init(rawValue:)) }
        set { hazardsRaw = newValue.map(\.rawValue) }
    }

    var spaceTitle: String {
        if let space { return space.title }
        return spaceTitleSnapshot.isEmpty ? "Unassigned space" : spaceTitleSnapshot
    }

    var spaceLocation: String {
        space?.location.isEmpty == false ? space!.location : spaceLocationSnapshot
    }

    /// What the board and the archive sort on: when it mattered, not when it was typed.
    var sortDate: Date { issuedAt ?? authorisedFrom }

    var reference: String {
        permitNumber.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Permit \(id.uuidString.prefix(4))" : permitNumber
    }

    // MARK: - The expiry clock

    var duration: TimeInterval { max(0, authorisedTo.timeIntervalSince(authorisedFrom)) }

    func timeRemaining(asOf now: Date = .now) -> TimeInterval {
        authorisedTo.timeIntervalSince(now)
    }

    /// Open, and past the end of the window the supervisor authorised. The permit does not
    /// close itself: the standard makes cancellation an act of the entry supervisor, so this
    /// is a state the board shouts about rather than a state the app resolves.
    func isExpired(asOf now: Date = .now) -> Bool {
        status == .open && timeRemaining(asOf: now) <= 0
    }

    // MARK: - Who is in the space right now

    var sortedEntrants: [Entrant] {
        (entrants ?? []).sorted { lhs, rhs in
            if lhs.isInside != rhs.isInside { return lhs.isInside }
            return (lhs.timeIn ?? lhs.createdAt) < (rhs.timeIn ?? rhs.createdAt)
        }
    }

    var entrantsInside: [Entrant] { sortedEntrants.filter(\.isInside) }
    var insideCount: Int { entrantsInside.count }

    // MARK: - Atmospheric testing

    var sortedReadings: [GasReading] {
        (readings ?? []).sorted { $0.takenAt > $1.takenAt }
    }

    var latestReading: GasReading? { sortedReadings.first }

    var preEntryReading: GasReading? {
        sortedReadings.last { $0.kind == .preEntry } ?? sortedReadings.last
    }

    /// When the next test is due, if the user recorded an interval of their own.
    func nextRetestDue(asOf _: Date = .now) -> Date? {
        guard retestIntervalMinutes > 0, let last = latestReading else { return nil }
        return last.takenAt.addingTimeInterval(Double(retestIntervalMinutes) * 60)
    }

    func isRetestOverdue(asOf now: Date = .now) -> Bool {
        guard status == .open, let due = nextRetestDue(asOf: now) else { return false }
        // Inclusive: at the moment the interval elapses the retest should already have happened, so
        // "exactly due" counts as overdue. On a permit-required space the conservative reading is
        // the only defensible one.
        return now >= due
    }

    /// Whether any acceptable entry condition was recorded on this permit at all.
    var hasAcceptableConditions: Bool {
        oxygenMinPercent != nil || oxygenMaxPercent != nil || lelMaxPercent != nil
            || coMaxPPM != nil || h2sMaxPPM != nil || otherGasMax != nil
    }

    /// The user's own recorded range for one gas, or nil where they recorded none.
    func acceptableRange(for gas: Gas) -> AcceptableRange? {
        switch gas {
        case .oxygen:
            guard oxygenMinPercent != nil || oxygenMaxPercent != nil else { return nil }
            return AcceptableRange(minimum: oxygenMinPercent, maximum: oxygenMaxPercent)
        case .lel:
            guard let maximum = lelMaxPercent else { return nil }
            return AcceptableRange(minimum: nil, maximum: maximum)
        case .carbonMonoxide:
            guard let maximum = coMaxPPM else { return nil }
            return AcceptableRange(minimum: nil, maximum: maximum)
        case .hydrogenSulphide:
            guard let maximum = h2sMaxPPM else { return nil }
            return AcceptableRange(minimum: nil, maximum: maximum)
        case .other:
            guard let maximum = otherGasMax else { return nil }
            return AcceptableRange(minimum: nil, maximum: maximum)
        }
    }

    /// A reading measured against the range **the user themselves recorded**. This is a
    /// comparison, not a verdict: the app has no opinion about whether a number is safe, and
    /// every place this is shown says whose criterion it is.
    func check(_ gas: Gas, in reading: GasReading) -> RangeCheck {
        guard let value = reading.value(for: gas) else { return .notMeasured }
        guard let range = acceptableRange(for: gas) else { return .noRangeRecorded }
        return range.contains(value) ? .withinRecordedRange : .outsideRecordedRange
    }

    /// The gases this permit actually asks about: the four a four-gas meter reads, plus the
    /// site's own fifth if they named one.
    var gases: [Gas] {
        otherGasName.trimmingCharacters(in: .whitespaces).isEmpty ? Gas.standard : Gas.allCases
    }

    func label(for gas: Gas) -> String {
        gas == .other ? (otherGasName.isEmpty ? "Other gas" : otherGasName) : gas.name
    }

    func unit(for gas: Gas) -> String {
        gas == .other ? (otherGasUnit.isEmpty ? "" : otherGasUnit) : gas.unit
    }

    // MARK: - What has to be true before a permit can be issued

    /// The standard's own preconditions, applied literally: a permit names its space, its
    /// purpose, its window, its attendant and its supervisor, it carries the supervisor's
    /// signature, and the atmosphere is tested **before** entry is authorised.
    ///
    /// None of these is a judgement about whether the readings are acceptable. That call stays
    /// with the entry supervisor, exactly as 1910.146 leaves it.
    var issueBlockers: [String] {
        var blockers: [String] = []
        if spaceTitle == "Unassigned space" { blockers.append("Choose the space being entered.") }
        if purpose.trimmingCharacters(in: .whitespaces).isEmpty {
            blockers.append("Say what the entry is for.")
        }
        if authorisedTo <= authorisedFrom {
            blockers.append("The authorised window has to end after it starts.")
        }
        if attendantName.trimmingCharacters(in: .whitespaces).isEmpty {
            blockers.append("Name the attendant who will be outside the space.")
        }
        if supervisorName.trimmingCharacters(in: .whitespaces).isEmpty {
            blockers.append("Name the entry supervisor.")
        }
        if supervisorSignature == nil {
            blockers.append("The entry supervisor has to sign to issue the permit.")
        }
        if sortedReadings.isEmpty {
            blockers.append("Record an atmospheric test taken before entry.")
        }
        return blockers
    }

    var canIssue: Bool { status == .draft && issueBlockers.isEmpty }

    /// A permit cannot be cancelled with somebody still logged inside — the roster is the
    /// attendant's own account of who has come out.
    var closeBlockers: [String] {
        var blockers: [String] = []
        if insideCount > 0 {
            blockers.append("\(insideCount) \(insideCount == 1 ? "entrant is" : "entrants are") still signed in. Sign everyone out first.")
        }
        if closedBy.trimmingCharacters(in: .whitespaces).isEmpty {
            blockers.append("Name the entry supervisor cancelling the permit.")
        }
        if closeSignature == nil {
            blockers.append("The entry supervisor has to sign to cancel the permit.")
        }
        return blockers
    }

    // MARK: - Retention — 1910.146(e)(6)

    static let retentionDays = 365

    /// The date the one-year retention period runs to. Only a cancelled permit has one.
    var retainUntil: Date? {
        guard let closedAt else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.retentionDays, to: closedAt)
    }

    func retentionDaysRemaining(asOf now: Date = .now) -> Int? {
        guard let retainUntil else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                       to: calendar.startOfDay(for: retainUntil)).day
    }

    /// What the archive row says under the date.
    func retentionSummary(asOf now: Date = .now) -> String? {
        guard let days = retentionDaysRemaining(asOf: now), let until = retainUntil else { return nil }
        let date = until.formatted(date: .abbreviated, time: .omitted)
        if days < 0 { return "One-year retention ended \(date)" }
        if days == 0 { return "Retention ends today" }
        if days < 60 { return "Retain \(days) more \(days == 1 ? "day" : "days"), to \(date)" }
        return "Retain until \(date)"
    }

    func isPastRetention(asOf now: Date = .now) -> Bool {
        (retentionDaysRemaining(asOf: now) ?? 1) < 0
    }
}

// MARK: - The vocabulary

enum PermitStatus: String, CaseIterable, Identifiable, Sendable {
    case draft, open, closed

    var id: String { rawValue }

    var name: String {
        switch self {
        case .draft: return "Draft"
        case .open: return "Open"
        case .closed: return "Cancelled"
        }
    }

    var boardHeading: String {
        switch self {
        case .draft: return "Drafts"
        case .open: return "Open permits"
        case .closed: return "Cancelled"
        }
    }

    var symbol: String {
        switch self {
        case .draft: return "doc.text"
        case .open: return "person.2.badge.gearshape"
        case .closed: return "archivebox"
        }
    }

    var detail: String {
        switch self {
        case .draft:
            return "Not issued. Nobody may enter on a draft. The entry supervisor signs to issue it."
        case .open:
            return "Issued and in force for the authorised window. Entrants sign in and out; the attendant stays outside."
        case .closed:
            return "Cancelled by the entry supervisor. It is now a retained record."
        }
    }
}

/// Why the permit was cancelled. The standard requires problems encountered during entry to be
/// noted on the cancelled permit so the annual review has something to review.
enum PermitOutcome: String, CaseIterable, Identifiable, Sendable {
    case completed, spaceEvacuated, conditionsChanged, workNotStarted, windowExpired

    var id: String { rawValue }

    var name: String {
        switch self {
        case .completed: return "Work completed"
        case .spaceEvacuated: return "Space evacuated"
        case .conditionsChanged: return "Conditions changed"
        case .workNotStarted: return "Work never started"
        case .windowExpired: return "Authorised time ran out"
        }
    }

    /// The two that 1910.146(e)(6) most wants written down and reviewed.
    var isProblem: Bool { self == .spaceEvacuated || self == .conditionsChanged }
}

struct AcceptableRange: Equatable, Sendable {
    var minimum: Double?
    var maximum: Double?

    func contains(_ value: Double) -> Bool {
        if let minimum, value < minimum { return false }
        if let maximum, value > maximum { return false }
        return true
    }

    func describe(unit: String) -> String {
        // "%" sits hard against its number, every other unit takes a space: "23.5%" but "50 ppm".
        let suffix = unit.isEmpty ? "" : (unit == "%" ? unit : " \(unit)")
        switch (minimum, maximum) {
        case let (.some(low), .some(high)):
            return "\(Gas.format(low)) to \(Gas.format(high))\(suffix)"
        case let (.some(low), .none):
            return "at least \(Gas.format(low))\(suffix)"
        case let (.none, .some(high)):
            return "at most \(Gas.format(high))\(suffix)"
        case (.none, .none):
            return "not recorded"
        }
    }
}

/// What a reading is, next to the range the user recorded. Deliberately never "safe" or "pass".
enum RangeCheck: Equatable, Sendable {
    case notMeasured
    case noRangeRecorded
    case withinRecordedRange
    case outsideRecordedRange

    var name: String {
        switch self {
        case .notMeasured: return "Not measured"
        case .noRangeRecorded: return "No range recorded"
        case .withinRecordedRange: return "Within your recorded range"
        case .outsideRecordedRange: return "Outside your recorded range"
        }
    }

    var short: String {
        switch self {
        case .notMeasured: return "—"
        case .noRangeRecorded: return "no range"
        case .withinRecordedRange: return "in range"
        case .outsideRecordedRange: return "out of range"
        }
    }
}

import Foundation
import SwiftData

/// One atmospheric test, at one moment, by one person.
///
/// 29 CFR 1910.146(f)(10) asks a permit to carry "the results of initial and periodic tests ...
/// accompanied by the names or initials of the testers and by an indication of when the tests
/// were performed". So the time and the tester are stored beside the numbers, and the list is
/// ordered by time rather than by entry order — a retest entered late still lands where it
/// happened.
///
/// Every value is optional. A meter that does not read hydrogen sulphide leaves the field empty,
/// and an empty field prints as "not measured" rather than as zero. Zero is a reading.
@Model
final class GasReading {
    var id: UUID = UUID()
    var takenAt: Date = Date()
    var testedBy: String = ""
    var kindRaw: String = ReadingKind.preEntry.rawValue
    /// Which meter, and whether it was bump tested. Not required by the rule; asked for by
    /// every insurer and client safety department that has ever looked at one of these.
    var instrument: String = ""

    var oxygenPercent: Double? = nil
    var lelPercent: Double? = nil
    var coPPM: Double? = nil
    var h2sPPM: Double? = nil
    var otherValue: Double? = nil

    var notes: String = ""
    var createdAt: Date = Date()
    var permit: Permit? = nil

    init(takenAt: Date = .now, kind: ReadingKind = .preEntry, testedBy: String = "") {
        self.id = UUID()
        self.takenAt = takenAt
        self.kindRaw = kind.rawValue
        self.testedBy = testedBy
        self.createdAt = .now
    }

    var kind: ReadingKind {
        get { ReadingKind(rawValue: kindRaw) ?? .periodic }
        set { kindRaw = newValue.rawValue }
    }

    func value(for gas: Gas) -> Double? {
        switch gas {
        case .oxygen: return oxygenPercent
        case .lel: return lelPercent
        case .carbonMonoxide: return coPPM
        case .hydrogenSulphide: return h2sPPM
        case .other: return otherValue
        }
    }

    func setValue(_ value: Double?, for gas: Gas) {
        switch gas {
        case .oxygen: oxygenPercent = value
        case .lel: lelPercent = value
        case .carbonMonoxide: coPPM = value
        case .hydrogenSulphide: h2sPPM = value
        case .other: otherValue = value
        }
    }

    /// A reading with no numbers on it is not a test. Used to stop an empty row being saved.
    var hasAnyValue: Bool {
        Gas.allCases.contains { value(for: $0) != nil }
    }

    /// How long ago, in the words the board uses.
    func age(asOf now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(takenAt))
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr \(minutes % 60) min ago" }
        return "\(hours / 24) days ago"
    }
}

/// When in the entry a test was taken. The standard distinguishes the test that authorises
/// entry from the ones taken while people are inside, and so does the record.
enum ReadingKind: String, CaseIterable, Identifiable, Sendable {
    case preEntry, afterVentilation, periodic, afterInterruption, onExit

    var id: String { rawValue }

    var name: String {
        switch self {
        case .preEntry: return "Before entry"
        case .afterVentilation: return "After ventilation"
        case .periodic: return "During entry"
        case .afterInterruption: return "After a break in work"
        case .onExit: return "On leaving"
        }
    }

    var symbol: String {
        switch self {
        case .preEntry: return "arrow.down.to.line"
        case .afterVentilation: return "wind"
        case .periodic: return "clock.arrow.circlepath"
        case .afterInterruption: return "arrow.uturn.down"
        case .onExit: return "arrow.up.to.line"
        }
    }
}

/// The four gases a four-gas meter reads, plus the one a site adds for itself.
///
/// There are deliberately **no default limits here**. The order is the order the numbers appear
/// on every meter display in the field, which is the order somebody transcribing them expects.
enum Gas: String, CaseIterable, Identifiable, Sendable {
    case oxygen, lel, carbonMonoxide, hydrogenSulphide, other

    var id: String { rawValue }

    static var standard: [Gas] { [.oxygen, .lel, .carbonMonoxide, .hydrogenSulphide] }

    var name: String {
        switch self {
        case .oxygen: return "Oxygen"
        case .lel: return "Flammable (LEL)"
        case .carbonMonoxide: return "Carbon monoxide"
        case .hydrogenSulphide: return "Hydrogen sulphide"
        case .other: return "Other gas"
        }
    }

    /// The short form used in table headers, where the column is narrow.
    var abbreviation: String {
        switch self {
        case .oxygen: return "O2"
        case .lel: return "LEL"
        case .carbonMonoxide: return "CO"
        case .hydrogenSulphide: return "H2S"
        case .other: return "Other"
        }
    }

    var unit: String {
        switch self {
        case .oxygen, .lel: return "%"
        case .carbonMonoxide, .hydrogenSulphide: return "ppm"
        case .other: return ""
        }
    }

    /// Numbers print the way a meter shows them: 20.9, not 20.900000.
    static func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1_000_000 { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    func formatted(_ value: Double?, unit customUnit: String? = nil) -> String {
        guard let value else { return "—" }
        let suffix = customUnit ?? unit
        return suffix.isEmpty ? Gas.format(value) : "\(Gas.format(value)) \(suffix)"
    }
}

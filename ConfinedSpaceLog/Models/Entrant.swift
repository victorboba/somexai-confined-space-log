import Foundation
import SwiftData

/// One authorised entrant on one permit, with the times they went in and came out.
///
/// 1910.146(f)(4) asks the permit to identify the authorised entrants, and (i)(3) makes the
/// attendant keep "an accurate count of authorized entrants in the permit space" and know who
/// is in there. A name on a list does not do that; a name with a time in and a time out does.
@Model
final class Entrant {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
    var timeIn: Date? = nil
    var timeOut: Date? = nil
    var notes: String = ""
    var createdAt: Date = Date()
    var permit: Permit? = nil

    init(name: String = "", company: String = "") {
        self.id = UUID()
        self.name = name
        self.company = company
        self.createdAt = .now
    }

    /// Signed in and not yet signed out. This is the answer to "who is in the space right now".
    var isInside: Bool { timeIn != nil && timeOut == nil }

    var hasEntered: Bool { timeIn != nil }

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Unnamed entrant" : name
    }

    /// How long this entrant has been in, or was in. Nil before they ever entered.
    func timeInside(asOf now: Date = .now) -> TimeInterval? {
        guard let timeIn else { return nil }
        return (timeOut ?? now).timeIntervalSince(timeIn)
    }

    /// "1 hr 42 min", the way an attendant reads a board.
    static func durationText(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 { return "\(minutes) min" }
        return "\(hours) hr \(minutes) min"
    }

    func status(asOf now: Date = .now) -> String {
        guard let timeIn else { return "Not entered" }
        let clock = timeIn.formatted(date: .omitted, time: .shortened)
        guard let timeOut else {
            return "In since \(clock) · \(Entrant.durationText(timeInside(asOf: now) ?? 0))"
        }
        return "\(clock) to \(timeOut.formatted(date: .omitted, time: .shortened)) · \(Entrant.durationText(timeInside(asOf: now) ?? 0))"
    }
}

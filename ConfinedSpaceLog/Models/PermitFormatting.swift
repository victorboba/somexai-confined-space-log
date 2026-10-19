import Foundation

/// How the board talks about time. Kept out of the views so the wording can be tested: an
/// expiry clock that reads "-0 min" or "0 hr 0 min left" at the wrong moment is the kind of
/// thing nobody notices until it is in front of an inspector.
extension Permit {
    /// "2 hr 14 min left", "18 min left", "1 hr 3 min over". Never an ellipsis, never a
    /// negative number with a minus sign in front of it.
    func remainingText(asOf now: Date = .now) -> String {
        let remaining = timeRemaining(asOf: now)
        if remaining <= 0 { return "\(Entrant.durationText(-remaining)) over" }
        return "\(Entrant.durationText(remaining)) left"
    }

    /// The window, written the way a permit writes it: one date, two times, unless it spans days.
    func windowText() -> String {
        let calendar = Calendar.current
        let from = authorisedFrom.formatted(date: .abbreviated, time: .shortened)
        if calendar.isDate(authorisedFrom, inSameDayAs: authorisedTo) {
            return "\(from) to \(authorisedTo.formatted(date: .omitted, time: .shortened))"
        }
        return "\(from) to \(authorisedTo.formatted(date: .abbreviated, time: .shortened))"
    }

    /// The line under the retest chip: when the next test is due, or why there is no clock.
    func retestText(asOf now: Date = .now) -> String {
        guard retestIntervalMinutes > 0 else { return "No retest interval recorded" }
        guard let due = nextRetestDue(asOf: now) else { return "No test recorded yet" }
        let delta = due.timeIntervalSince(now)
        if delta <= 0 { return "Retest overdue by \(Entrant.durationText(-delta))" }
        return "Retest due in \(Entrant.durationText(delta))"
    }

    /// A one-line account of the permit for a row, a widget or a CSV cell.
    func summaryLine(asOf now: Date = .now) -> String {
        switch status {
        case .draft:
            return issueBlockers.isEmpty ? "Ready to issue" : "\(issueBlockers.count) thing\(issueBlockers.count == 1 ? "" : "s") still to do"
        case .open:
            let clock = remainingText(asOf: now)
            return insideCount == 0 ? "\(clock) · nobody inside"
                                    : "\(clock) · \(insideCount) inside"
        case .closed:
            return outcome.name
        }
    }
}

extension Permit {
    /// The next permit number in the site's running sequence: CSE-2026-007. Entirely a
    /// convenience — the user can type anything, and does, because most sites have their own
    /// numbering already printed on a pad of paper permits.
    static func suggestedNumber(after existing: [Permit], asOf now: Date = .now) -> String {
        let year = Calendar.current.component(.year, from: now)
        let prefix = "CSE-\(year)-"
        let used = existing.compactMap { permit -> Int? in
            guard permit.permitNumber.hasPrefix(prefix) else { return nil }
            return Int(permit.permitNumber.dropFirst(prefix.count))
        }
        return prefix + String(format: "%03d", (used.max() ?? 0) + 1)
    }
}

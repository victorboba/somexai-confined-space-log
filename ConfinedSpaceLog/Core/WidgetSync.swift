import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the board summary from the current permits and reloads timelines.
    static func update(with permits: [Permit], asOf now: Date = .now) {
        WidgetSnapshot.make(from: permits, asOf: now).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WidgetSnapshot {
    /// Pure, so the tests can check the numbers without a widget or an App Group.
    static func make(from permits: [Permit], asOf now: Date = .now) -> WidgetSnapshot {
        let open = permits.filter { $0.status == .open }
        let inside = open.flatMap(\.entrantsInside)
        let soonest = open.min { $0.authorisedTo < $1.authorisedTo }

        var snapshot = WidgetSnapshot()
        snapshot.openPermits = open.count
        snapshot.peopleInside = inside.count
        snapshot.draftPermits = permits.filter { $0.status == .draft }.count
        snapshot.expiredOpenPermits = open.filter { $0.isExpired(asOf: now) }.count
        snapshot.nextExpiryLabel = soonest?.spaceTitle
        snapshot.nextExpiry = soonest?.authorisedTo
        snapshot.insideSummary = inside.isEmpty
            ? nil
            : inside.prefix(6).map(\.displayName).joined(separator: ", ")
        snapshot.updatedAt = now
        return snapshot
    }
}

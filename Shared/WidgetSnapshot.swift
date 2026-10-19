import Foundation

/// A tiny summary the app writes to the shared App Group so the widget — and the "who is inside"
/// Shortcut — can answer without touching SwiftData.
///
/// The two numbers on it are the two an attendant or a supervisor actually wants on a home
/// screen: how many permits are open, and how many people are in a space right now.
struct WidgetSnapshot: Codable {
    var openPermits: Int = 0
    var peopleInside: Int = 0
    var draftPermits: Int = 0
    var expiredOpenPermits: Int = 0
    /// The open permit whose authorised window ends first, and when.
    var nextExpiryLabel: String? = nil
    var nextExpiry: Date? = nil
    /// "TK-104: A. Reyes, J. Okafor" — what the Shortcut reads back.
    var insideSummary: String? = nil
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    /// The sentence the Shortcut speaks and the widget's second line.
    var spokenSummary: String {
        if openPermits == 0 { return "No permits are open." }
        let permits = "\(openPermits) \(openPermits == 1 ? "permit is" : "permits are") open"
        if peopleInside == 0 { return "\(permits). Nobody is signed in." }
        let people = "\(peopleInside) \(peopleInside == 1 ? "person is" : "people are") inside"
        guard let insideSummary, !insideSummary.isEmpty else { return "\(permits). \(people)." }
        return "\(permits). \(people): \(insideSummary)."
    }

    static let placeholder = WidgetSnapshot(openPermits: 2, peopleInside: 3, draftPermits: 1,
                                            expiredOpenPermits: 0,
                                            nextExpiryLabel: "TK-104",
                                            nextExpiry: Date().addingTimeInterval(2 * 3600 + 840),
                                            insideSummary: "A. Reyes, J. Okafor, M. Silva")
}

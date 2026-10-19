import AppIntents
import Foundation

/// "Draft a permit in Confined Space Log" from Siri, Spotlight or the Shortcuts app.
/// Opens the app straight onto a new permit.
struct LogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Draft an Entry Permit"
    static var description = IntentDescription("Opens the app ready to draft a new entry permit.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openNewPermit"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

/// "Who is in the space?" — answered out loud, without opening the app.
///
/// This is the question an attendant exists to answer, so it is worth being able to ask it from
/// a locked phone. It reads the same App Group snapshot the widget does; nothing leaves the
/// device and no space is unlocked or authorised by asking.
struct WhoIsInsideIntent: AppIntent {
    static var title: LocalizedStringResource = "Who Is In The Space"
    static var description = IntentDescription("Reads back how many permits are open and who is signed in right now.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let summary = WidgetSnapshot.load().spokenSummary
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

struct ConfinedSpaceLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogEntryIntent(),
            phrases: ["Draft a permit in \(.applicationName)", "New entry permit in \(.applicationName)"],
            shortTitle: "Draft Permit",
            systemImageName: "doc.badge.plus"
        )
        AppShortcut(
            intent: WhoIsInsideIntent(),
            phrases: ["Who is inside in \(.applicationName)", "Check \(.applicationName)"],
            shortTitle: "Who Is Inside",
            systemImageName: "person.2.wave.2"
        )
    }
}

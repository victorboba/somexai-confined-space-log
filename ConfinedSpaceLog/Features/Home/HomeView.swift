import SwiftUI
import SwiftData

/// The app is three places, not one list: the **board** of what is open right now, the
/// **register** of spaces that get entered again and again, and the **archive** of cancelled
/// permits running their one-year retention clock. Tabs, because those three are used at
/// different moments by different people and none of them is a drill-down of another.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var permits: [Permit]

    @State private var selection: Tab = .board
    @State private var newPermit: Permit?
    @State private var showingSettings = false

    enum Tab: Hashable { case board, spaces, archive }

    var body: some View {
        TabView(selection: $selection) {
            BoardView(newPermit: $newPermit, showingSettings: $showingSettings)
                .tabItem { Label("Board", systemImage: "rectangle.stack.badge.person.crop") }
                .tag(Tab.board)

            SpacesView()
                .tabItem { Label("Spaces", systemImage: "circle.dashed") }
                .tag(Tab.spaces)

            ArchiveView()
                .tabItem { Label("Archive", systemImage: "archivebox") }
                .tag(Tab.archive)
        }
        .sheet(item: $newPermit) { permit in
            PermitEditorView(permit: permit, isNew: true)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .onChange(of: permits.count, initial: true) { WidgetSync.update(with: permits) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetSync.update(with: permits)
            openNewPermitIfRequestedByShortcut()
        }
    }

    private func openNewPermitIfRequestedByShortcut() {
        let defaults = WidgetSnapshot.defaults
        guard defaults.bool(forKey: LogEntryIntent.pendingKey) else { return }
        defaults.removeObject(forKey: LogEntryIntent.pendingKey)
        selection = .board
        let permit = Permit()
        context.insert(permit)
        newPermit = permit
    }
}

import SwiftUI
import SwiftData

/// The operations board: what is open right now, how long it has left, and who is inside it.
///
/// This is not a list of past records — those live in the Archive. It is the screen an entry
/// supervisor or an attendant looks at while the work is happening, so the two things it puts
/// in the largest type are the expiry clock and the count of people in the space.
struct BoardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Permit.authorisedFrom, order: .reverse) private var permits: [Permit]
    @Query(sort: \ConfinedSpace.spaceID) private var spaces: [ConfinedSpace]

    @Binding var newPermit: Permit?
    @Binding var showingSettings: Bool

    @State private var openPermit: Permit?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var noSpaceYet = false

    private var openPermits: [Permit] { permits.filter { $0.status == .open } }
    private var drafts: [Permit] { permits.filter { $0.status == .draft } }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                board(asOf: context.date)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Board")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How do I use this app")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("Every permit (CSV)", systemImage: "tablecells") { export(.permits) }
                            .disabled(permits.isEmpty)
                        Button("Atmospheric tests (CSV)", systemImage: "aqi.medium") { export(.readings) }
                            .disabled(permits.isEmpty)
                        Divider()
                        Button("Settings", systemImage: "gear") { showingSettings = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")

                    Button { startPermit() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New permit")
                }
            }
            .navigationDestination(item: $openPermit) { PermitView(permit: $0) }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Add a space first", isPresented: $noSpaceYet) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A permit has to name the space being entered. Open the Spaces tab and add one; every permit for it is then pre-filled from what you put in.")
            }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil },
                                                         set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    @ViewBuilder
    private func board(asOf now: Date) -> some View {
        if permits.isEmpty {
            ContentUnavailableView {
                Label("Nothing is open", systemImage: "rectangle.stack.badge.person.crop")
            } description: {
                Text("A confined space entry needs a written permit before anybody goes in. Draft one here and it appears on this board with its clock running.")
            } actions: {
                Button("New permit") { startPermit() }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    LiveSummary(openPermits: openPermits, drafts: drafts.count, asOf: now)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    let expired = openPermits.filter { $0.isExpired(asOf: now) }
                    let running = openPermits.filter { !$0.isExpired(asOf: now) }

                    if !expired.isEmpty {
                        BoardSection(title: "Past its authorised time",
                                     footnote: "The permit does not cancel itself. Sign the entrants out and let the entry supervisor cancel it, or issue a new permit.",
                                     tint: .red) {
                            ForEach(expired) { permit in
                                card(permit, asOf: now)
                            }
                        }
                    }

                    if !running.isEmpty {
                        BoardSection(title: "Open", footnote: nil, tint: .accentColor) {
                            ForEach(running) { permit in
                                card(permit, asOf: now)
                            }
                        }
                    }

                    if !drafts.isEmpty {
                        BoardSection(title: "Drafts",
                                     footnote: "Nobody may enter on a draft. The entry supervisor signs to issue it.",
                                     tint: .secondary) {
                            ForEach(drafts) { permit in
                                card(permit, asOf: now)
                            }
                        }
                    }

                    if openPermits.isEmpty && drafts.isEmpty {
                        Text("No permit is open. Cancelled permits are in the Archive tab.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    Text(AppConfig.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func card(_ permit: Permit, asOf now: Date) -> some View {
        Button { openPermit = permit } label: {
            PermitCard(permit: permit, now: now)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .contextMenu {
            Button("Delete permit", systemImage: "trash", role: .destructive) {
                delete(permit)
            }
        }
    }

    private func startPermit() {
        guard !spaces.isEmpty else { noSpaceYet = true; return }
        let permit = Permit(space: spaces.count == 1 ? spaces[0] : nil)
        permit.permitNumber = Permit.suggestedNumber(after: permits)
        context.insert(permit)
        try? context.save()
        newPermit = permit
    }

    private func delete(_ permit: Permit) {
        context.delete(permit)
        try? context.save()
        WidgetSync.update(with: permits)
    }

    private enum ExportKind { case permits, readings }

    private func export(_ kind: ExportKind) {
        do {
            let url = kind == .permits
                ? try CSVExporter.export(permits)
                : try CSVExporter.exportReadings(permits)
            exportFile = ExportFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - The live band at the top

/// Two numbers, large: permits open and people in a space. Everything else on this screen is
/// detail underneath them.
private struct LiveSummary: View {
    let openPermits: [Permit]
    let drafts: Int
    let asOf: Date

    private var inside: Int { openPermits.reduce(0) { $0 + $1.insideCount } }
    private var names: [String] { openPermits.flatMap(\.entrantsInside).map(\.displayName) }
    private var expiringSoon: Permit? {
        openPermits.filter { !$0.isExpired(asOf: asOf) }
            .min { $0.authorisedTo < $1.authorisedTo }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                figure("\(openPermits.count)", openPermits.count == 1 ? "permit open" : "permits open")
                Divider().frame(height: 44)
                figure("\(inside)", inside == 1 ? "person inside" : "people inside",
                       tint: inside > 0 ? .accentColor : .secondary)
            }

            if !names.isEmpty {
                Wrap(spacing: 6, lineSpacing: 6) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.caption.weight(.medium))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
            }

            if let expiringSoon {
                Label("\(expiringSoon.spaceTitle) expires \(expiringSoon.authorisedTo.formatted(date: .omitted, time: .shortened))",
                      systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if drafts > 0 {
                Label("\(drafts) \(drafts == 1 ? "draft waiting" : "drafts waiting") to be issued",
                      systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func figure(_ value: String, _ caption: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct BoardSection<Content: View>: View {
    let title: String
    let footnote: String?
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal)
            content
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - One permit on the board

struct PermitCard: View {
    let permit: Permit
    let now: Date

    private var expired: Bool { permit.isExpired(asOf: now) }
    private var urgent: Bool {
        permit.status == .open && permit.timeRemaining(asOf: now) < 30 * 60
    }

    private var bar: Color {
        if expired { return .red }
        if permit.status == .draft { return .secondary }
        if urgent { return .orange }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(bar).frame(width: 6)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(permit.spaceTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(permit.reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                if !permit.purpose.isEmpty {
                    Text(permit.purpose)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if permit.status == .open {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(permit.remainingText(asOf: now))
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(expired ? Color.red : (urgent ? Color.orange : Color.primary))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(expired ? "past its authorised time" : "on the authorised window")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 1) {
                            Label("\(permit.insideCount)", systemImage: "person.2.fill")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(permit.insideCount > 0 ? Color.accentColor : Color.secondary)
                            Text("inside")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !permit.entrantsInside.isEmpty {
                        Wrap(spacing: 6, lineSpacing: 6) {
                            ForEach(permit.entrantsInside) { entrant in
                                Text(entrant.displayName)
                                    .font(.caption.weight(.medium))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        if let latest = permit.latestReading {
                            Label("Tested \(latest.age(asOf: now))", systemImage: "aqi.medium")
                        } else {
                            Label("No test recorded", systemImage: "aqi.medium")
                        }
                        if permit.isRetestOverdue(asOf: now) {
                            Label("Retest overdue", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if !permit.attendantName.isEmpty {
                        Label("Attendant \(permit.attendantName)", systemImage: "figure.stand")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(permit.summaryLine(asOf: now))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(permit.issueBlockers.isEmpty ? Color.green : Color.secondary)
                    Text(permit.windowText())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}

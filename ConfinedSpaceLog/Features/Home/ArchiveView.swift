import SwiftUI
import SwiftData

/// Cancelled permits — the retained record 29 CFR 1910.146(e)(6) requires be kept at least one
/// year and reviewed. Grouped by whether the year is still running, because "can I throw this
/// away yet" is the question this screen exists to answer.
struct ArchiveView: View {
    @Query(sort: \Permit.authorisedFrom, order: .reverse) private var permits: [Permit]
    @Environment(\.modelContext) private var context

    @State private var openPermit: Permit?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var closed: [Permit] { permits.filter { $0.status == .closed } }
    private var withinRetention: [Permit] { closed.filter { !$0.isPastRetention() } }
    private var pastRetention: [Permit] { closed.filter { $0.isPastRetention() } }

    var body: some View {
        NavigationStack {
            Group {
                if closed.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing cancelled yet", systemImage: "archivebox")
                    } description: {
                        Text("A permit lands here once the entry supervisor cancels it. It stays for at least one year, with the retention date shown on every row.")
                    }
                } else {
                    List {
                        if !withinRetention.isEmpty {
                            Section {
                                ForEach(withinRetention) { permit in
                                    row(permit)
                                }
                            } header: {
                                Text("Retain — within one year")
                            }
                        }
                        if !pastRetention.isEmpty {
                            Section {
                                ForEach(pastRetention) { permit in
                                    row(permit)
                                }
                            } header: {
                                Text("Past the one-year minimum")
                            } footer: {
                                Text("29 CFR 1910.146(e)(6) sets one year as the minimum, not a deadline to delete. Keep records as long as your own program requires.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export All (CSV)", systemImage: "square.and.arrow.up") { export() }
                        .disabled(closed.isEmpty)
                }
            }
            .navigationDestination(item: $openPermit) { PermitView(permit: $0) }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil },
                                                         set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private func row(_ permit: Permit) -> some View {
        Button { openPermit = permit } label: {
            ArchiveRow(permit: permit)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { delete(permit) }
        }
    }

    private func delete(_ permit: Permit) {
        context.delete(permit)
        try? context.save()
    }

    private func export() {
        do {
            exportFile = ExportFile(url: try CSVExporter.export(closed))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ArchiveRow: View {
    let permit: Permit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(permit.spaceTitle).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(permit.reference).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Text("\(permit.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "") · \(permit.outcome.name)")
                .font(.subheadline)
                .foregroundStyle(permit.outcome.isProblem ? Color.orange : Color.secondary)
            if let summary = permit.retentionSummary() {
                Label(summary, systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

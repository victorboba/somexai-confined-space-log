import SwiftUI
import SwiftData

/// Cancelling a permit: 1910.146(e)(5) makes this the entry supervisor's act, and (e)(6) turns
/// the result into a record that has to be kept at least a year. So this is its own screen with
/// its own signature, not a status flip on the board.
struct ClosePermitView: View {
    @Bindable var permit: Permit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query private var allPermits: [Permit]

    @State private var outcome: PermitOutcome
    @State private var closeNotes: String
    @State private var closedBy: String
    @State private var signature: Data?

    init(permit: Permit) {
        self.permit = permit
        _outcome = State(initialValue: permit.outcome)
        _closeNotes = State(initialValue: permit.closeNotes)
        _closedBy = State(initialValue: permit.closedBy.isEmpty ? permit.supervisorName : permit.closedBy)
        _signature = State(initialValue: permit.closeSignature)
    }

    private var blockers: [String] {
        var list: [String] = []
        if permit.insideCount > 0 {
            list.append("\(permit.insideCount) \(permit.insideCount == 1 ? "entrant is" : "entrants are") still signed in. Sign everyone out first.")
        }
        if closedBy.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append("Name the entry supervisor cancelling the permit.")
        }
        if signature == nil {
            list.append("The entry supervisor has to sign to cancel the permit.")
        }
        if outcome.isProblem && closeNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append("Say what happened — this outcome is one 1910.146(e)(6) asks the annual review to look at.")
        }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Cancelling ends the entry. The permit moves to Archive and has to be retained at least one year under 29 CFR 1910.146(e)(6).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Outcome") {
                    ChoiceChips(options: PermitOutcome.allCases, selection: $outcome, title: \.name,
                               tint: { $0.isProblem ? .orange : .accentColor })
                }

                if outcome.isProblem {
                    Section("What happened") {
                        TextField("Problems encountered during entry", text: $closeNotes, axis: .vertical)
                            .lineLimit(3...8)
                    }
                } else {
                    Section("Notes") {
                        TextField("Optional", text: $closeNotes, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }

                Section("Entry supervisor") {
                    TextField("Name", text: $closedBy)
                        .textContentType(.name)
                    SignaturePad(data: $signature, name: closedBy)
                        .padding(.vertical, 4)
                }

                if !blockers.isEmpty {
                    Section {
                        ForEach(blockers, id: \.self) { blocker in
                            Label(blocker, systemImage: "circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .navigationTitle("Cancel Permit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel Permit") { close() }
                        .disabled(!blockers.isEmpty)
                }
            }
        }
    }

    private func close() {
        permit.outcome = outcome
        permit.closeNotes = closeNotes
        permit.closedBy = closedBy
        permit.closeSignature = signature
        permit.closedAt = .now
        try? context.save()
        WidgetSync.update(with: allPermits)
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}

import SwiftUI
import SwiftData

/// One atmospheric test. Readings are taken before entry and repeatedly during it, so this sheet
/// has to be fast: pick when in the entry it was taken, type the numbers, done. The time is
/// stamped automatically to the moment the reading is opened, and can be moved back for a test
/// that was taken standing at the space and typed up a minute later.
struct ReadingEditorView: View {
    let permit: Permit
    @Bindable var reading: GasReading
    let isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPermits: [Permit]
    /// What the user has actually typed per gas, so an in-progress "20." is not reformatted away.
    @State private var rawText: [String: String] = [:]

    private var hasAnyValue: Bool {
        Gas.allCases.contains { reading.value(for: $0) != nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When in the entry") {
                    ChoiceChips(options: ReadingKind.allCases, selection: $reading.kind, title: \.name)
                }
                Section("Taken") {
                    DatePicker("Time", selection: $reading.takenAt)
                }
                Section {
                    ForEach(permit.gases) { gas in
                        gasField(gas)
                    }
                } header: {
                    Text("Readings")
                } footer: {
                    Text("Leave a gas blank if your meter did not read it. A blank reading and a zero reading are different — the app never assumes zero.")
                }
                Section("Who tested and with what") {
                    TextField("Tester's name or initials", text: $reading.testedBy)
                    TextField("Instrument, e.g. RKI GX-2012 #4471", text: $reading.instrument)
                }
                Section("Notes") {
                    TextField("Optional", text: $reading.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isNew ? "Record a Test" : "Edit Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { context.delete(reading) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!hasAnyValue)
                }
            }
        }
    }

    @ViewBuilder
    private func gasField(_ gas: Gas) -> some View {
        HStack {
            Text(permit.label(for: gas))
            Spacer()
            TextField("Not measured", text: textBinding(for: gas))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .accessibilityIdentifier("gasField.\(gas.rawValue)")
            if !permit.unit(for: gas).isEmpty {
                Text(permit.unit(for: gas)).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            }
        }
    }

    /// Text-backed rather than `TextField(value:format:)`, which only commits when the field loses
    /// focus. With a formatted binding, someone who types their only reading and goes straight for
    /// Save finds it still greyed out, because the model never saw the number — the value is not
    /// committed until they happen to tap somewhere else first. Parsing on each keystroke keeps the
    /// Save button honest about whether a reading exists.
    ///
    /// The raw text is kept per gas so a half-typed "20." survives the next keystroke; a blank field
    /// stores nil, because a blank reading and a zero reading mean different things on this record.
    private func textBinding(for gas: Gas) -> Binding<String> {
        Binding(
            get: {
                if let typed = rawText[gas.rawValue] { return typed }
                guard let value = reading.value(for: gas) else { return "" }
                return value.formatted(.number.precision(.fractionLength(0...2)))
            },
            set: { typed in
                rawText[gas.rawValue] = typed
                let cleaned = typed.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: ".")
                reading.setValue(cleaned.isEmpty ? nil : Double(cleaned), for: gas)
            }
        )
    }

    private func save() {
        if isNew {
            reading.permit = permit
            context.insert(reading)
        }
        try? context.save()
        WidgetSync.update(with: allPermits)
        dismiss()
    }
}

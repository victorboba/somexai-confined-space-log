import SwiftUI
import SwiftData

/// The space register: the same tank, vault or silo gets entered a dozen times a year, and
/// 1910.146(c) makes the employer identify its permit spaces before anybody goes near one. Add a
/// space once here and every permit for it starts pre-filled — the identification, the known
/// hazards, the isolation points and the acceptable entry conditions.
struct SpacesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ConfinedSpace.spaceID) private var spaces: [ConfinedSpace]

    @State private var newSpace: ConfinedSpace?

    var body: some View {
        NavigationStack {
            Group {
                if spaces.isEmpty {
                    ContentUnavailableView {
                        Label("No spaces yet", systemImage: "circle.dashed")
                    } description: {
                        Text("Add the tanks, vaults and vessels you enter. Each one carries its own hazards and acceptable entry conditions forward onto every permit for it.")
                    } actions: {
                        Button("Add a space") { startSpace() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(spaces) { space in
                            NavigationLink {
                                SpaceEditorView(space: space, isNew: false)
                            } label: {
                                SpaceRow(space: space)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Spaces")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { startSpace() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a space")
                }
            }
            .sheet(item: $newSpace) { space in
                NavigationStack { SpaceEditorView(space: space, isNew: true) }
            }
        }
    }

    private func startSpace() {
        let space = ConfinedSpace()
        context.insert(space)
        try? context.save()
        newSpace = space
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(spaces[index]) }
        try? context.save()
    }
}

private struct SpaceRow: View {
    let space: ConfinedSpace

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: space.kind.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(space.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                if !space.location.isEmpty {
                    Text(space.location).font(.subheadline).foregroundStyle(.secondary)
                }
                if !space.knownHazards.isEmpty {
                    Text(space.knownHazards.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    if !space.openPermits.isEmpty {
                        Label("\(space.openPermits.count) open", systemImage: "circle.fill")
                            .foregroundStyle(.tint)
                    }
                    Label(space.hasAcceptableConditions ? "Conditions recorded" : "No conditions recorded",
                          systemImage: space.hasAcceptableConditions ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(space.hasAcceptableConditions ? Color.secondary : Color.orange)
                }
                .font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Add or edit one space: its identification, its known hazards and isolation points, and the
/// site's own acceptable entry conditions. New properties default to "not recorded", never to a
/// number the app made up.
struct SpaceEditorView: View {
    @Bindable var space: ConfinedSpace
    var isNew: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Identification") {
                TextField("Space ID, e.g. TK-104", text: $space.spaceID)
                TextField("Name, e.g. Process water tank", text: $space.name)
                TextField("Location", text: $space.location)
                Picker("Kind", selection: $space.kind) {
                    ForEach(SpaceKind.allCases) { kind in
                        Text(kind.name).tag(kind)
                    }
                }
                Toggle("Classified as permit-required", isOn: $space.isPermitRequired)
            }

            Section("Known hazards") {
                SpaceHazardChips(selection: hazardSelection)
                TextField("Other hazards not listed", text: $space.otherHazards, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section {
                TextField("Lockout points, blanks, blinds, valves, breakers", text: $space.isolationPoints, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Isolation points")
            } footer: {
                Text("Copied onto every new permit for this space. Adjust on the permit if a specific entry differs.")
            }

            Section("Access notes") {
                TextField("Optional — how to find and open it", text: $space.accessNotes, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section("Acceptable entry conditions") {
                Text("Your own numbers, from your written confined space program. Left blank, a gas has no recorded criterion — that is different from zero.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                numberField("Oxygen minimum (%)", value: $space.oxygenMinPercent)
                numberField("Oxygen maximum (%)", value: $space.oxygenMaxPercent)
                numberField("Flammable maximum (% LEL)", value: $space.lelMaxPercent)
                numberField("Carbon monoxide maximum (ppm)", value: $space.coMaxPPM)
                numberField("Hydrogen sulphide maximum (ppm)", value: $space.h2sMaxPPM)
                TextField("A fifth gas name, if your program tests one", text: $space.otherGasName)
                if !space.otherGasName.trimmingCharacters(in: .whitespaces).isEmpty {
                    TextField("Unit, e.g. ppm", text: $space.otherGasUnit)
                    numberField("Maximum acceptable", value: $space.otherGasMax)
                }
            }

            Section("Photo") {
                PhotoField(data: $space.photoData, label: "photo of the manway or the lockout points")
            }

            Section("Notes") {
                TextField("Optional", text: $space.notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            if !isNew {
                Section {
                    Button("Delete This Space", role: .destructive) { deleteSpace() }
                } footer: {
                    Text("Any cancelled permit for this space stays in the Archive with its own copy of the identification.")
                }
            }
        }
        .navigationTitle(isNew ? "New Space" : "Edit Space")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
        }
    }

    private var hazardSelection: Binding<Set<SpaceHazard>> {
        Binding(get: { Set(space.knownHazards) }, set: { space.knownHazards = Array($0) })
    }

    @ViewBuilder
    private func numberField(_ label: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Not set", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
        }
    }

    private func save() {
        try? context.save()
        dismiss()
    }

    private func deleteSpace() {
        context.delete(space)
        try? context.save()
        dismiss()
    }
}

private struct SpaceHazardChips: View {
    @Binding var selection: Set<SpaceHazard>

    var body: some View {
        Wrap(spacing: 8, lineSpacing: 8) {
            ForEach(SpaceHazard.allCases) { hazard in
                let isSelected = selection.contains(hazard)
                Button {
                    if isSelected { selection.remove(hazard) } else { selection.insert(hazard) }
                } label: {
                    Text(hazard.name)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 30)
                        .background(isSelected ? Color.orange.opacity(0.18) : Color(.secondarySystemFill), in: Capsule())
                        .foregroundStyle(isSelected ? Color.orange : Color.primary)
                        .overlay(Capsule().strokeBorder(isSelected ? Color.orange.opacity(0.55) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

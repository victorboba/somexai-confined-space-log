import SwiftUI
import SwiftData

/// One permit, through its whole life.
///
/// The order of this screen is the order of the entry, not the order of the form: what state the
/// permit is in, who is in the space, what the meter said and when, then the written permit
/// itself, then the signature that issues or cancels it.
struct PermitView: View {
    @Bindable var permit: Permit

    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @Query private var allPermits: [Permit]

    @State private var editingDetails = false
    @State private var newReading: GasReading?
    @State private var editingReading: GasReading?
    @State private var addingEntrant = false
    @State private var entrantName = ""
    @State private var entrantCompany = ""
    @State private var closing = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            Form {
                statusSection(asOf: timeline.date)
                if permit.status == .draft { issueSection }
                if permit.status != .draft { rosterSection(asOf: timeline.date) }
                testsSection(asOf: timeline.date)
                if permit.status == .draft { rosterSection(asOf: timeline.date) }
                permitSection
                if permit.status == .open { closeSection }
                if permit.status == .closed { closedSection(asOf: timeline.date) }
                exportSection
                Section {
                    Text(AppConfig.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(permit.spaceTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit details") { editingDetails = true }
                    .disabled(permit.status == .closed)
            }
        }
        .sheet(isPresented: $editingDetails) { PermitEditorView(permit: permit, isNew: false) }
        .sheet(item: $newReading) { reading in
            ReadingEditorView(permit: permit, reading: reading, isNew: true)
        }
        .sheet(item: $editingReading) { reading in
            ReadingEditorView(permit: permit, reading: reading, isNew: false)
        }
        .sheet(isPresented: $closing) { ClosePermitView(permit: permit) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Add an entrant", isPresented: $addingEntrant) {
            TextField("Name", text: $entrantName)
            TextField("Company or crew", text: $entrantCompany)
            Button("Add") { addEntrant() }
            Button("Cancel", role: .cancel) { entrantName = ""; entrantCompany = "" }
        } message: {
            Text("Authorised entrants are named on the permit. Sign them in when they go through the opening.")
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil },
                                                     set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Status

    @ViewBuilder
    private func statusSection(asOf now: Date) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: permit.status.symbol)
                    Text(statusHeadline(asOf: now))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(statusTint(asOf: now))

                Text(permit.status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Permit number", value: permit.reference)
                    .font(.caption)
                LabeledContent("Authorised", value: permit.windowText())
                    .font(.caption)
                if !permit.spaceLocation.isEmpty {
                    LabeledContent("Location", value: permit.spaceLocation)
                        .font(.caption)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func statusHeadline(asOf now: Date) -> String {
        switch permit.status {
        case .draft: return "Draft — not issued"
        case .open:
            return permit.isExpired(asOf: now)
                ? "Open, \(permit.remainingText(asOf: now))"
                : "Open · \(permit.remainingText(asOf: now))"
        case .closed: return "Cancelled \(permit.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")"
        }
    }

    private func statusTint(asOf now: Date) -> Color {
        switch permit.status {
        case .draft: return .secondary
        case .open: return permit.isExpired(asOf: now) ? .red : .accentColor
        case .closed: return .primary
        }
    }

    // MARK: - Issuing

    private var issueSection: some View {
        Section {
            TextField("Entry supervisor", text: $permit.supervisorName)
                .textContentType(.name)
            SignaturePad(data: $permit.supervisorSignature, name: permit.supervisorName)
                .padding(.vertical, 4)

            if permit.issueBlockers.isEmpty {
                Button {
                    issue()
                } label: {
                    Label("Issue permit", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Before this permit can be issued")
                        .font(.subheadline.weight(.semibold))
                    ForEach(permit.issueBlockers, id: \.self) { blocker in
                        Label(blocker, systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Entry supervisor")
        } footer: {
            Text("29 CFR 1910.146(f)(6) asks the permit to carry the signature of the supervisor who authorised the entry. Sign with a finger; it prints on the record.")
        }
    }

    private func issue() {
        permit.issuedAt = .now
        try? context.save()
        WidgetSync.update(with: allPermits)
        ReviewPrompter.recordSuccess(request: requestReview)
    }

    // MARK: - Who is inside

    @ViewBuilder
    private func rosterSection(asOf now: Date) -> some View {
        Section {
            if permit.sortedEntrants.isEmpty {
                Text("No entrants named yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(permit.sortedEntrants) { entrant in
                EntrantRow(entrant: entrant, permit: permit, now: now) {
                    try? context.save()
                    WidgetSync.update(with: allPermits)
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(permit.sortedEntrants[index]) }
                try? context.save()
                WidgetSync.update(with: allPermits)
            }

            Button {
                addingEntrant = true
            } label: {
                Label("Add entrant", systemImage: "person.badge.plus")
            }
            .disabled(permit.status == .closed)
        } header: {
            HStack {
                Text("Who is inside")
                Spacer()
                Text("\(permit.insideCount) inside")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(permit.insideCount > 0 ? Color.accentColor : Color.secondary)
            }
        } footer: {
            Text("The attendant has to know who is in the space and how many. Sign each entrant in as they go through the opening and out as they come back.")
        }
    }

    private func addEntrant() {
        let entrant = Entrant(name: entrantName.trimmingCharacters(in: .whitespaces),
                              company: entrantCompany.trimmingCharacters(in: .whitespaces))
        entrant.permit = permit
        context.insert(entrant)
        try? context.save()
        entrantName = ""
        entrantCompany = ""
        WidgetSync.update(with: allPermits)
    }

    // MARK: - Atmospheric tests

    @ViewBuilder
    private func testsSection(asOf now: Date) -> some View {
        Section {
            if permit.sortedReadings.isEmpty {
                Text("No test recorded. A permit cannot be issued until the atmosphere has been tested.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(permit.sortedReadings) { reading in
                Button { editingReading = reading } label: {
                    ReadingRow(permit: permit, reading: reading, now: now)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { context.delete(permit.sortedReadings[index]) }
                try? context.save()
            }

            Button {
                let reading = GasReading(kind: permit.sortedReadings.isEmpty ? .preEntry : .periodic)
                newReading = reading
            } label: {
                Label("Record a test", systemImage: "plus.circle")
            }
            .disabled(permit.status == .closed)
        } header: {
            HStack {
                Text("Atmospheric tests")
                Spacer()
                if permit.status == .open {
                    Text(permit.retestText(asOf: now))
                        .font(.caption)
                        .foregroundStyle(permit.isRetestOverdue(asOf: now) ? Color.orange : Color.secondary)
                }
            }
        } footer: {
            Text("The permit has to carry the results of the initial and periodic tests and when they were taken. Readings are compared only against the acceptable entry conditions you recorded; the app makes no judgement of its own.")
        }
    }

    // MARK: - The written permit

    private var permitSection: some View {
        Section {
            detail("Purpose of entry", permit.purpose)
            if !permit.attendantName.isEmpty { detail("Attendant", permit.attendantName) }
            if !permit.supervisorName.isEmpty { detail("Entry supervisor", permit.supervisorName) }
            if !permit.hazards.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hazards of the space")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Wrap(spacing: 6, lineSpacing: 6) {
                        ForEach(permit.hazards) { hazard in
                            Text(hazard.name)
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Color.orange.opacity(0.16), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if !permit.otherHazards.isEmpty { detail("Other hazards", permit.otherHazards) }
            detail("Isolation", permit.isolationMeasures)
            detail("Ventilation", permit.ventilation)
            detail("Rescue and emergency services", permit.rescueServices)
            detail("Communication", permit.communicationProcedure)
            detail("Equipment", permit.equipment)
            detail("Additional permits", permit.additionalPermits)
            detail("Other information", permit.otherInformation)
            detail("Notes", permit.notes)

            NavigationLink {
                AcceptableConditionsView(permit: permit)
            } label: {
                LabeledContent("Acceptable entry conditions",
                               value: permit.hasAcceptableConditions ? "Recorded" : "None recorded")
            }

            if let data = permit.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        } header: {
            Text("The permit")
        }
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Cancelling

    private var closeSection: some View {
        Section {
            Button {
                closing = true
            } label: {
                Label("Cancel permit", systemImage: "xmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } footer: {
            Text("Cancelling ends the entry and turns the permit into a retained record. It has to be kept at least one year and reviewed.")
        }
    }

    @ViewBuilder
    private func closedSection(asOf now: Date) -> some View {
        Section {
            LabeledContent("Outcome", value: permit.outcome.name)
            if !permit.closeNotes.isEmpty { detail("Problems encountered", permit.closeNotes) }
            LabeledContent("Cancelled by", value: permit.closedBy.isEmpty ? "Not named" : permit.closedBy)
            if let signature = permit.closeSignature, let image = UIImage(data: signature) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 70)
            }
            if let summary = permit.retentionSummary(asOf: now) {
                Label(summary, systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(permit.isPastRetention(asOf: now) ? Color.secondary : Color.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Cancellation")
        } footer: {
            Text("29 CFR 1910.146(e)(6) requires the cancelled permit to be retained at least one year and reviewed.")
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            Button {
                do { exportFile = ExportFile(url: try PDFExporter.export(permit)) }
                catch { exportError = error.localizedDescription }
            } label: {
                Label("Entry permit (PDF)", systemImage: "doc.richtext")
            }
        } footer: {
            Text("The PDF is laid out to be posted at the space while the entry is under way and filed afterwards.")
        }
    }
}

// MARK: - Rows

private struct EntrantRow: View {
    @Bindable var entrant: Entrant
    let permit: Permit
    let now: Date
    let onChange: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entrant.displayName)
                    .font(.body.weight(entrant.isInside ? .semibold : .regular))
                if !entrant.company.isEmpty {
                    Text(entrant.company).font(.caption).foregroundStyle(.secondary)
                }
                Text(entrant.status(asOf: now))
                    .font(.caption)
                    .foregroundStyle(entrant.isInside ? Color.accentColor : Color.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            if permit.status != .closed {
                if entrant.isInside {
                    Button("Sign out") {
                        entrant.timeOut = .now
                        onChange()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                } else if entrant.hasEntered {
                    Button("Sign in again") {
                        entrant.timeIn = .now
                        entrant.timeOut = nil
                        onChange()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Sign in") {
                        entrant.timeIn = .now
                        onChange()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(permit.status == .draft)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ReadingRow: View {
    let permit: Permit
    let reading: GasReading
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(reading.kind.name, systemImage: reading.kind.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(reading.takenAt.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.monospacedDigit())
            }
            Wrap(spacing: 6, lineSpacing: 6) {
                ForEach(permit.gases) { gas in
                    GasChip(permit: permit, reading: reading, gas: gas)
                }
            }
            HStack(spacing: 8) {
                Text(reading.age(asOf: now))
                if !reading.testedBy.isEmpty { Text("· \(reading.testedBy)") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !reading.notes.isEmpty {
                Text(reading.notes).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct GasChip: View {
    let permit: Permit
    let reading: GasReading
    let gas: Gas

    private var check: RangeCheck { permit.check(gas, in: reading) }

    private var tint: Color {
        switch check {
        case .outsideRecordedRange: return .red
        case .withinRecordedRange: return .green
        default: return .secondary
        }
    }

    var body: some View {
        let value = reading.value(for: gas)
        HStack(spacing: 4) {
            Text(gas.abbreviation)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(gas.formatted(value, unit: permit.unit(for: gas)))
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(tint.opacity(value == nil ? 0.08 : 0.16), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(value == nil ? Color.secondary : tint)
        .accessibilityLabel("\(permit.label(for: gas)) \(gas.formatted(value, unit: permit.unit(for: gas))), \(check.name)")
    }
}

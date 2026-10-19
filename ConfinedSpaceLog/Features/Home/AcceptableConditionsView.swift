import SwiftUI

/// The acceptable entry conditions on one permit: the user's own numbers, copied from the space
/// when the permit was drafted and editable here up until the permit is cancelled.
///
/// **This screen never says "safe".** It records a range the entry supervisor wrote down from
/// their own site program. Every reading elsewhere in the app is compared to this range and
/// labelled "within your recorded range" or "outside your recorded range" — never "pass" or
/// "safe" — because the app has no basis to say either.
struct AcceptableConditionsView: View {
    @Bindable var permit: Permit
    @Environment(\.dismiss) private var dismiss

    private var editable: Bool { permit.status != .closed }

    var body: some View {
        Form {
            Section {
                Text("These are the acceptable entry conditions the entry supervisor recorded from your site's own written confined space program. \(AppConfig.appName) ships no default numbers and makes no judgement about whether a reading is safe — it only shows a reading next to the range recorded here, and says whose criterion it is.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Oxygen (%)") {
                numberField("Minimum acceptable", value: $permit.oxygenMinPercent)
                numberField("Maximum acceptable", value: $permit.oxygenMaxPercent)
            }
            Section("Flammable gas (% LEL)") {
                numberField("Maximum acceptable", value: $permit.lelMaxPercent)
            }
            Section("Carbon monoxide (ppm)") {
                numberField("Maximum acceptable", value: $permit.coMaxPPM)
            }
            Section("Hydrogen sulphide (ppm)") {
                numberField("Maximum acceptable", value: $permit.h2sMaxPPM)
            }
            Section("A fifth gas, if your program tests one") {
                TextField("Gas name, e.g. Chlorine", text: $permit.otherGasName)
                    .disabled(!editable)
                if !permit.otherGasName.trimmingCharacters(in: .whitespaces).isEmpty {
                    TextField("Unit, e.g. ppm", text: $permit.otherGasUnit)
                        .disabled(!editable)
                    numberField("Maximum acceptable", value: $permit.otherGasMax)
                }
            }
            Section {
                Stepper(value: $permit.retestIntervalMinutes, in: 0...240, step: 5) {
                    LabeledContent("Retest every", value: permit.retestIntervalMinutes == 0 ? "Not set" : "\(permit.retestIntervalMinutes) min")
                }
                .disabled(!editable)
            } footer: {
                Text("How often your program calls for a periodic test while the space is occupied. Leave at 0 to run without a retest reminder.")
            }
        }
        .navigationTitle("Acceptable Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    @ViewBuilder
    private func numberField(_ label: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Not set", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .disabled(!editable)
                .frame(maxWidth: 100)
        }
    }
}

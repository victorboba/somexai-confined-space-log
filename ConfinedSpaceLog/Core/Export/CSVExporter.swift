import Foundation

/// Two CSVs: one row per permit, and one row per atmospheric reading. The reading sheet is its
/// own export because it is what most people actually want to chart or hand to a safety
/// department — the times and the numbers, not the narrative fields.
enum CSVExporter {
    static let permitHeader = "permit_number,status,space_id,space_name,location,purpose,authorised_from,authorised_to,attendant,entry_supervisor,issued_at,closed_at,outcome,entrants_count,people_inside_at_export,isolation,ventilation,notes"

    static func csv(for permits: [Permit]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [permitHeader]
        for permit in permits.sorted(by: { $0.sortDate > $1.sortDate }) {
            let fields = [
                permit.reference,
                permit.status.name,
                permit.space?.spaceID ?? "",
                permit.spaceTitle,
                permit.spaceLocation,
                permit.purpose,
                formatter.string(from: permit.authorisedFrom),
                formatter.string(from: permit.authorisedTo),
                permit.attendantName,
                permit.supervisorName,
                permit.issuedAt.map(formatter.string(from:)) ?? "",
                permit.closedAt.map(formatter.string(from:)) ?? "",
                permit.status == .closed ? permit.outcome.name : "",
                String(permit.sortedEntrants.count),
                String(permit.insideCount),
                permit.isolationMeasures,
                permit.ventilation,
                permit.notes,
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static let readingHeader = "permit_number,space_id,taken_at,kind,oxygen_percent,lel_percent,co_ppm,h2s_ppm,other_gas_name,other_gas_value,instrument,tested_by,notes"

    static func csvForReadings(_ permits: [Permit]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [readingHeader]
        let allReadings = permits.flatMap { permit in permit.sortedReadings.map { (permit, $0) } }
            .sorted { $0.1.takenAt < $1.1.takenAt }
        for (permit, reading) in allReadings {
            let fields = [
                permit.reference,
                permit.space?.spaceID ?? "",
                formatter.string(from: reading.takenAt),
                reading.kind.name,
                formattedOptional(reading.oxygenPercent),
                formattedOptional(reading.lelPercent),
                formattedOptional(reading.coPPM),
                formattedOptional(reading.h2sPPM),
                permit.otherGasName,
                formattedOptional(reading.otherValue),
                reading.instrument,
                reading.testedBy,
                reading.notes,
            ]
            lines.append(fields.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Writes the permit CSV to a temporary file and returns its URL for the share sheet.
    static func export(_ permits: [Permit]) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "csv")
        try csv(for: permits).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Writes the atmospheric-readings CSV, stem suffixed `-readings` so it never collides with
    /// the permit export in a downloads folder.
    static func exportReadings(_ permits: [Permit]) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "csv", suffix: "-readings")
        try csvForReadings(permits).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    static func formattedOptional(_ value: Double?) -> String {
        guard let value else { return "" }
        return formatted(value)
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(extension ext: String, suffix: String = "") -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(stamp)\(suffix)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()

    static let report: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

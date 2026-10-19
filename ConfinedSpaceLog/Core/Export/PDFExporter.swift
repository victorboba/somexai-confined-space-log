import UIKit

/// Renders one permit as a document that reads like the paper form it replaces: postable at the
/// space while the entry is under way, filable once it is cancelled. This is the feature the
/// buyer is actually paying for, so every section on the real permit gets a section here —
/// including the acceptable entry conditions, always labelled as the user's own criterion, never
/// as a pass/fail the app decided.
enum PDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 44
    private static let contentWidth = page.width - margin * 2

    private static let titleFont = UIFont.boldSystemFont(ofSize: 18)
    private static let sectionFont = UIFont.boldSystemFont(ofSize: 11)
    private static let labelFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 10)
    private static let smallFont = UIFont.systemFont(ofSize: 8)
    private static let subtleGray = UIColor(white: 0.4, alpha: 1)
    private static let ruleGray = UIColor(white: 0.75, alpha: 1)

    static func export(_ permit: Permit, filename: String? = nil) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        var y: CGFloat = 0
        var pageNumber = 0

        try renderer.writePDF(to: url) { context in
            func startPage() {
                context.beginPage()
                pageNumber += 1
                y = margin
                draw("Confined Space Entry Permit", at: margin, y: y, font: titleFont)
                let stamp = "No. \(permit.reference) · \(permit.status.name) · Page \(pageNumber)"
                draw(stamp, at: margin, y: y + 22, font: smallFont, color: subtleGray)
                y += 40
                rule()
                y += 10
            }

            func rule() {
                context.cgContext.setStrokeColor(ruleGray.cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y))
                context.cgContext.strokePath()
            }

            func ensure(_ height: CGFloat) {
                if y + height > page.height - margin { startPage() }
            }

            func sectionHeading(_ text: String) {
                ensure(20)
                draw(text.uppercased(), at: margin, y: y, font: sectionFont)
                y += 16
            }

            var fieldRowMaxHeight: CGFloat = 0

            /// A label above its value, drawn as two separate calls — never one padded string —
            /// so a PDF-text assertion can find each piece without depending on a fixed layout.
            func field(_ label: String, _ value: String, width: CGFloat, x: CGFloat) {
                draw(label.uppercased(), at: x, y: y, font: labelFont, color: subtleGray)
                let text = value.isEmpty ? "—" : value
                let height = textHeight(text, font: bodyFont, width: width)
                draw(text, at: x, y: y + 10, font: bodyFont, width: width)
                fieldRowMaxHeight = max(fieldRowMaxHeight, 10 + height)
            }

            func fieldRow(_ items: [(String, String)], columns: Int = 2) {
                let colWidth = (contentWidth - CGFloat(columns - 1) * 16) / CGFloat(columns)
                fieldRowMaxHeight = 0
                for chunkStart in stride(from: 0, to: items.count, by: columns) {
                    let chunk = Array(items[chunkStart..<min(chunkStart + columns, items.count)])
                    fieldRowMaxHeight = 0
                    for (index, item) in chunk.enumerated() {
                        let x = margin + CGFloat(index) * (colWidth + 16)
                        field(item.0, item.1, width: colWidth, x: x)
                    }
                    y += fieldRowMaxHeight + 10
                }
            }

            func paragraph(_ label: String, _ value: String) {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let height = textHeight(value, font: bodyFont, width: contentWidth)
                ensure(20 + height)
                draw(label.uppercased(), at: margin, y: y, font: labelFont, color: subtleGray)
                draw(value, at: margin, y: y + 10, font: bodyFont, width: contentWidth)
                y += 14 + height
            }

            startPage()

            // MARK: Space and window
            fieldRow([
                ("Space", permit.spaceTitle),
                ("Location", permit.spaceLocation),
                ("Purpose of entry", permit.purpose),
                ("Authorised window", permit.windowText()),
                ("Attendant", permit.attendantName),
                ("Entry supervisor", permit.supervisorName),
            ])
            y += 6

            // MARK: Hazards
            if !permit.hazards.isEmpty || !permit.otherHazards.isEmpty {
                sectionHeading("Hazards of the space")
                let names = (permit.hazards.map(\.name) + (permit.otherHazards.isEmpty ? [] : [permit.otherHazards])).joined(separator: "; ")
                let height = textHeight(names, font: bodyFont, width: contentWidth)
                ensure(height + 6)
                draw(names, at: margin, y: y, font: bodyFont, width: contentWidth)
                y += height + 14
            }

            paragraph("Isolation of hazardous energy", permit.isolationMeasures)
            paragraph("Ventilation", permit.ventilation)
            paragraph("Rescue and emergency services", permit.rescueServices)
            paragraph("Communication procedure", permit.communicationProcedure)
            paragraph("Equipment provided", permit.equipment)
            paragraph("Additional permits in effect", permit.additionalPermits)
            paragraph("Other information", permit.otherInformation)
            paragraph("Notes", permit.notes)

            // MARK: Acceptable entry conditions
            sectionHeading("Acceptable entry conditions (recorded by the entry supervisor)")
            ensure(22)
            draw("These are the ranges the entry supervisor entered from their own written program. The app makes no determination that any reading is safe.",
                 at: margin, y: y, font: smallFont, color: subtleGray, width: contentWidth)
            y += 20
            if permit.hasAcceptableConditions {
                let rows = permit.gases.compactMap { gas -> (String, String)? in
                    guard let range = permit.acceptableRange(for: gas) else { return nil }
                    return (permit.label(for: gas), range.describe(unit: permit.unit(for: gas)))
                }
                fieldRow(rows.isEmpty ? [("Acceptable entry conditions", "None recorded")] : rows, columns: 3)
            } else {
                draw("None recorded.", at: margin, y: y, font: bodyFont)
                y += 18
            }
            y += 4

            // MARK: Atmospheric tests
            sectionHeading("Atmospheric test results")
            if permit.sortedReadings.isEmpty {
                ensure(18)
                draw("No test recorded.", at: margin, y: y, font: bodyFont)
                y += 18
            } else {
                let columns: [(name: String, x: CGFloat, width: CGFloat)] = [
                    ("Time", margin, 74),
                    ("Test", margin + 78, 78),
                    ("O2", margin + 160, 44),
                    ("LEL", margin + 208, 44),
                    ("CO", margin + 256, 44),
                    ("H2S", margin + 304, 44),
                    ("Other", margin + 352, 60),
                    ("Tester", margin + 416, contentWidth - 372),
                ]
                func header() {
                    ensure(30)
                    for c in columns { draw(c.name, at: c.x, y: y, font: labelFont, color: subtleGray) }
                    y += 12
                    rule()
                    y += 6
                }
                header()
                for reading in permit.sortedReadings.sorted(by: { $0.takenAt < $1.takenAt }) {
                    ensure(16)
                    let cells = [
                        reading.takenAt.formatted(date: .omitted, time: .shortened),
                        reading.kind.name,
                        permit.gases.contains(.oxygen) ? Gas.oxygen.formatted(reading.oxygenPercent) : "",
                        permit.gases.contains(.lel) ? Gas.lel.formatted(reading.lelPercent) : "",
                        permit.gases.contains(.carbonMonoxide) ? Gas.carbonMonoxide.formatted(reading.coPPM) : "",
                        permit.gases.contains(.hydrogenSulphide) ? Gas.hydrogenSulphide.formatted(reading.h2sPPM) : "",
                        permit.gases.contains(.other) ? Gas.other.formatted(reading.otherValue) : "",
                        reading.testedBy,
                    ]
                    for (column, text) in zip(columns, cells) {
                        draw(text, at: column.x, y: y, font: smallFont, width: column.width)
                    }
                    y += 14
                }

                // The permit has to say what the readings were taken with. An instrument that later
                // turns out to have been out of calibration puts every number in the table above in
                // question, so the record names it rather than leaving it to memory. Listed once
                // beneath the table because one meter usually covers the whole entry, and the table
                // has no room for a ninth column.
                let instruments = permit.sortedReadings
                    .map(\.instrument)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .reduce(into: [String]()) { unique, name in
                        if !unique.contains(name) { unique.append(name) }
                    }
                if !instruments.isEmpty {
                    ensure(20)
                    y += 4
                    draw("Tested with: " + instruments.joined(separator: ", "),
                         at: margin, y: y, font: smallFont, color: subtleGray)
                    y += 14
                }
            }
            y += 10

            // MARK: Entrant roster
            sectionHeading("Authorised entrants")
            if permit.sortedEntrants.isEmpty {
                ensure(18)
                draw("No entrants named.", at: margin, y: y, font: bodyFont)
                y += 18
            } else {
                let columns: [(name: String, x: CGFloat, width: CGFloat)] = [
                    ("Name", margin, 140),
                    ("Company / crew", margin + 144, 140),
                    ("Time in", margin + 288, 80),
                    ("Time out", margin + 372, 80),
                    ("Duration", margin + 456, contentWidth - 412),
                ]
                ensure(24)
                for c in columns { draw(c.name, at: c.x, y: y, font: labelFont, color: subtleGray) }
                y += 12
                rule()
                y += 6
                for entrant in permit.sortedEntrants {
                    ensure(16)
                    let duration = entrant.timeInside().map(Entrant.durationText) ?? "—"
                    let cells = [
                        entrant.displayName,
                        entrant.company,
                        entrant.timeIn?.formatted(date: .omitted, time: .shortened) ?? "—",
                        entrant.timeOut?.formatted(date: .omitted, time: .shortened) ?? (entrant.isInside ? "Still inside" : "—"),
                        duration,
                    ]
                    for (column, text) in zip(columns, cells) {
                        draw(text, at: column.x, y: y, font: smallFont, width: column.width)
                    }
                    y += 14
                }
            }
            y += 10

            // MARK: Signatures
            sectionHeading("Entry supervisor's authorisation")
            ensure(70)
            drawSignature(permit.supervisorSignature, name: permit.supervisorName, at: margin, y: y)
            y += 66

            // MARK: Cancellation
            if permit.status == .closed {
                sectionHeading("Cancellation and retention")
                fieldRow([
                    ("Cancelled", permit.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? ""),
                    ("Outcome", permit.outcome.name),
                ])
                paragraph("Problems encountered", permit.closeNotes)
                ensure(70)
                drawSignature(permit.closeSignature, name: permit.closedBy, at: margin, y: y, label: "Cancelled by")
                y += 66
                if let retainUntil = permit.retainUntil {
                    ensure(16)
                    draw("29 CFR 1910.146(e)(6): retain this cancelled permit until \(retainUntil.formatted(date: .abbreviated, time: .omitted)).",
                         at: margin, y: y, font: smallFont, color: subtleGray)
                    y += 18
                }
            }

            // MARK: Disclaimer, every page
            let disclaimerHeight = textHeight(AppConfig.disclaimer, font: smallFont, width: contentWidth)
            ensure(disclaimerHeight + 10)
            y = page.height - margin - disclaimerHeight
            rule()
            y += 6
            draw(AppConfig.disclaimer, at: margin, y: y, font: smallFont, color: subtleGray, width: contentWidth)
        }
        return url
    }

    // MARK: - Drawing helpers

    private static func draw(_ text: String, at x: CGFloat, y: CGFloat, font: UIFont,
                             color: UIColor = .label, width: CGFloat? = nil) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if let width {
            text.draw(in: CGRect(x: x, y: y, width: width, height: 200), withAttributes: attributes)
        } else {
            text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        }
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font], context: nil)
        return ceil(bounds.height)
    }

    private static func drawSignature(_ data: Data?, name: String, at x: CGFloat, y: CGFloat, label: String = "Entry supervisor") {
        if let data, let image = UIImage(data: data) {
            let targetHeight: CGFloat = 40
            let aspect = image.size.width / max(image.size.height, 1)
            image.draw(in: CGRect(x: x, y: y, width: targetHeight * aspect, height: targetHeight))
        }
        draw("——————————————————————", at: x, y: y + 42, font: smallFont, color: ruleGray)
        draw("\(label): \(name.isEmpty ? "Not named" : name)", at: x, y: y + 52, font: smallFont, color: subtleGray)
    }
}

import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        // Permits expire on a clock, so the widget refreshes on the quarter hour rather than hourly.
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

/// The two numbers an attendant wants on a home screen: permits open, people inside.
struct ConfinedSpaceLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed").font(.caption2)
                Text("Confined Space")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                if snapshot.expiredOpenPermits > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(snapshot.peopleInside)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("inside")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(snapshot.openPermits) open \(snapshot.openPermits == 1 ? "permit" : "permits")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if family != .systemSmall {
                Divider()
                if let label = snapshot.nextExpiryLabel, let expiry = snapshot.nextExpiry {
                    Text("Next to expire: \(label)")
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Text(expiry, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(expiry < .now ? Color.red : Color.secondary)
                        .monospacedDigit()
                } else {
                    Text("No permit is open.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ConfinedSpaceLogWidget: Widget {
    let kind = "ConfinedSpaceLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            ConfinedSpaceLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("Open permits, how many people are inside, and the next one to expire.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ConfinedSpaceLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConfinedSpaceLogWidget()
    }
}

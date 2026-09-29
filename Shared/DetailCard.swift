import SwiftUI
import AppIntents

/// Detail card overlaid on the timeline after tapping an event.
/// Dark translucent panel, hairline border, close button, "Open in Calendar" link.
struct DetailCardView: View {
    let event: EventItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(event.title)
                    .font(.cormorant(19, .semibold))
                    .foregroundStyle(Palette.starlight)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Button(intent: ClearSelectionIntent()) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.starlight.opacity(0.75))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.starlight.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(event.calendarColor.color)
                    .frame(width: 6, height: 6)
                Text(event.calendarTitle)
                    .font(.cormorant(12, .medium))
                    .foregroundStyle(Palette.muted)
            }

            Text(whenLine)
                .font(.cormorant(13, .medium))
                .foregroundStyle(Palette.starlight.opacity(0.92))

            if let location = event.location {
                Text(location)
                    .font(.cormorant(12.5, .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }

            if let notes = event.notes {
                Text(notes)
                    .font(.cormorant(12.5))
                    .foregroundStyle(Palette.starlight.opacity(0.85))
                    .lineLimit(6)
            }

            if let url = event.url, let host = url.host {
                Button(intent: OpenLinkIntent(url: url)) {
                    Text(host)
                        .font(.cormorant(12, .medium, italic: true))
                        .foregroundStyle(Palette.earthlight.opacity(0.9))
                        .underline(color: Palette.earthlight.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            if let organizer = event.organizer {
                metaLine("Organized by \(organizer)")
            }
            if !event.attendees.isEmpty {
                let shown = event.attendees.prefix(4).joined(separator: ", ")
                let extra = event.attendees.count > 4 ? " +\(event.attendees.count - 4)" : ""
                metaLine("With \(shown)\(extra)")
            }
            if let recurrence = event.recurrenceText { metaLine(recurrence) }
            if let alarm = event.alarmText { metaLine(alarm) }
            if let status = event.statusText { metaLine(status) }

            if let link = event.calendarDeepLink {
                HStack {
                    Spacer(minLength: 0)
                    Button(intent: OpenLinkIntent(url: link)) {
                        Text("Open in Calendar")
                            .font(.cormorant(12.5, .medium, italic: true))
                            .foregroundStyle(Palette.dustRose.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x0B0E18).opacity(0.94))
        }
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.starlight.opacity(0.15), lineWidth: 0.5)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Palette.starlight.opacity(0.09), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 26)
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .allowsHitTesting(false)
        }
    }

    private var whenLine: String {
        if event.isAllDay {
            return "\(dateLabel) · All day"
        }
        if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
            return "\(dateLabel) · \(event.timeRangeLabel)"
        }
        return "\(dateLabel) – \(Self.shortDateFormatter.string(from: event.endDate))"
    }

    private var dateLabel: String {
        Self.fullDateFormatter.string(from: event.startDate)
    }

    private func metaLine(_ text: String) -> some View {
        Text(text)
            .font(.cormorant(12, .medium, italic: true))
            .foregroundStyle(Palette.muted)
            .lineLimit(2)
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
}

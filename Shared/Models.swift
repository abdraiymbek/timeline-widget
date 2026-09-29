import SwiftUI

// MARK: - RGB color wrapper (EKCalendar CGColor -> SwiftUI)

struct RGBAColor: Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(cgColor: CGColor?) {
        guard
            let srgb = cgColor?.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!,
                intent: .defaultIntent,
                options: nil
            ),
            let c = srgb.components, c.count >= 3
        else {
            self.init(r: 0.55, g: 0.54, b: 0.58, a: 1)
            return
        }
        self.init(r: c[0], g: c[1], b: c[2], a: c.count > 3 ? c[3] : 1)
    }
}

// MARK: - Event item (view-model over EKEvent)

struct EventItem: Identifiable, Equatable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarTitle: String
    var calendarColor: RGBAColor
    var location: String?
    var notes: String?
    var url: URL?
    var organizer: String?
    var attendees: [String]
    var recurrenceText: String?
    var alarmText: String?
    var statusText: String?
    var isInProgress: Bool
    var isPast: Bool

    var calendarDeepLink: URL? {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return URL(string: "ical://ekevent/\(encoded)?method=show&options=more")
    }

    var shortTimeLabel: String {
        isAllDay ? "" : Self.timeFormatter.string(from: startDate)
    }

    var timeRangeLabel: String {
        if isAllDay { return "All day" }
        return "\(Self.timeFormatter.string(from: startDate)) – \(Self.timeFormatter.string(from: endDate)) \(Self.meridiemFormatter.string(from: endDate).lowercased())"
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    static let meridiemFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }()
}

// MARK: - Day section

enum DayKind: Equatable {
    case past, today, future
}

enum OrbPalette: Equatable, CaseIterable {
    case mars, earth, gold, graphite
}

struct DaySection: Identifiable, Equatable {
    var id: String            // yyyy-MM-dd
    var date: Date            // start of day
    var kind: DayKind
    var label: String         // Yesterday / Today / Monday
    var secondary: String     // "Sep 28" or "Monday, 28 September" for today
    var events: [EventItem]   // visible rows (already capped)
    var overflowCount: Int
    var palette: OrbPalette
    /// Cumulative unit cost of all sections before this one (for rail gradient math).
    var unitOffset: Double
    /// Estimated unit cost of this whole section.
    var unitCost: Double
}

// MARK: - Timeline model

struct TimelineModel: Equatable {
    enum Access {
        case granted, unavailable
    }

    var access: Access
    var days: [DaySection]
    var selection: EventItem?
    var generatedAt: Date
    /// 0...1 estimated vertical position of the today node within the day column.
    var todayNodeFraction: Double
    /// Total height of the day column in points.
    var contentHeight: Double
    /// Distance from the top of the day column to the today-node center, in points.
    var todayNodeCenterY: Double

    static let unavailable = TimelineModel(
        access: .unavailable, days: [], selection: nil,
        generatedAt: Date(), todayNodeFraction: 0.5,
        contentHeight: 0, todayNodeCenterY: 0
    )
}

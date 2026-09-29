import Foundation

// MARK: - Loader (real EventKit path)

enum TimelineLoader {
    struct Result {
        var model: TimelineModel
        var nextReload: Date
    }

    /// Loads events through EventKit and builds the timeline model.
    /// `calendarIDs` nil/empty means "all calendars".
    static func load(calendarIDs: [String]?, now: Date = .init()) -> Result {
        let store = EventStore()
        let status = store.authorizationStatus
        Log.widget.log("authorizationStatus=\(status.rawValue)")

        guard status == .fullAccess else {
            return Result(model: .unavailable, nextReload: now.addingTimeInterval(15 * 60))
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -Metrics.pastLookbackDays, to: today)!
        let end = calendar.date(byAdding: .day, value: Metrics.futureLookaheadDays + 1, to: today)!
        let events = store.events(from: start, to: end, calendarIDs: calendarIDs)
        Log.widget.log("loaded \(events.count) events for \(calendarIDs?.count ?? -1) selected calendars")

        let items = events.map { $0.toItem(now: now) }
        var selectionID = SelectionStore.current()
        if let id = selectionID, !items.contains(where: { $0.id == id }) {
            selectionID = nil // event filtered out or deleted
        }

        let model = TimelineBuilder.build(items: items, now: now, selectionID: selectionID)
        let reload = TimelineBuilder.nextReload(after: now, items: items, selectionActive: selectionID != nil)
        return Result(model: model, nextReload: reload)
    }
}

// MARK: - Demo data (snapshots + host preview fallback)

enum DemoData {

    static func items(now: Date = .init()) -> [EventItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let work = ("Work", RGBAColor(r: 0.85, g: 0.45, b: 0.25))
        let personal = ("Personal", RGBAColor(r: 0.44, g: 0.72, b: 0.85))
        let family = ("Family", RGBAColor(r: 0.93, g: 0.72, b: 0.57))

        func ev(
            _ dayOffset: Int, _ hour: Double, _ duration: Double, _ title: String,
            cal: (String, RGBAColor), allDay: Bool = false,
            location: String? = nil, notes: String? = nil, url: URL? = nil,
            organizer: String? = nil, attendees: [String] = [],
            recurrence: String? = nil, alarm: String? = nil, status: String? = nil
        ) -> EventItem {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let start = calendar.date(byAdding: .minute, value: Int(hour * 60), to: day)!
            let end = calendar.date(byAdding: .minute, value: Int((hour + duration) * 60), to: day)!
            return EventItem(
                id: "demo-\(dayOffset)-\(Int(hour * 60))-\(title.hashValue)",
                title: title, startDate: start, endDate: end, isAllDay: allDay,
                calendarTitle: cal.0, calendarColor: cal.1,
                location: location, notes: notes, url: url, organizer: organizer,
                attendees: attendees, recurrenceText: recurrence, alarmText: alarm,
                statusText: status,
                isInProgress: !allDay && start <= now && now < end,
                isPast: end < now
            )
        }

        // In-progress event spanning "now" (clamped so it stays within today).
        let nowMinutes = Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)
        let inProgressStart = min(max((Double(nowMinutes) - 25) / 60, 0), 22)

        return [
            // Past
            ev(-4, 18.5, 1.5, "Dinner at Casa Lupe", cal: personal, location: "Casa Lupe, 4th St"),
            ev(-1, 9.0, 1.0, "Morning run", cal: personal, recurrence: "Repeats daily"),
            ev(-1, 14.0, 1.0, "Call with Mom", cal: family),
            // Today — five rows so the "+1 more" overflow shows.
            ev(0, inProgressStart, 1.25, "Design review — Orion onboarding", cal: work,
               location: "Studio, 2nd floor", url: URL(string: "https://meet.example.com/orion"),
               organizer: "Mara Chen", attendees: ["Mara Chen", "Jonas Reyes", "Priya Nair", "Sam Okafor", "Leah Kim"],
               recurrence: "Repeats weekly", alarm: "Alert 10 minutes before"),
            ev(0, 9.0, 0.5, "Team standup", cal: work, recurrence: "Repeats daily"),
            ev(0, 12.5, 0.75, "Lunch with Tomas", cal: personal, location: "Bistro Verde"),
            ev(0, 18.0, 1.0, "Piano practice", cal: personal),
            ev(0, 21.25, 1.5, "Reading hour", cal: personal),
            // Future
            ev(1, 10.0, 1.5, "Flight to Lisbon — TP 284", cal: personal, location: "SFO Terminal 2"),
            ev(1, 19.0, 2.0, "Gallery opening", cal: personal),
            ev(3, 16.0, 1.0, "Dentist", cal: family, location: "Fillmore Dental"),
            ev(3, 9.0, 0.5, "1:1 with Mara", cal: work, recurrence: "Repeats weekly"),
            ev(8, 11.0, 2.0, "Weekend hike", cal: personal),
            ev(8, 0, 24, "Mara's birthday", cal: family, allDay: true),
        ]
    }

    static func model(selected: Bool = false, now: Date = .init()) -> TimelineModel {
        let all = items(now: now)
        let selectionID = selected ? all.first(where: { $0.isInProgress })?.id : nil
        return TimelineBuilder.build(items: all, now: now, selectionID: selectionID)
    }

    static func emptyToday(now: Date = .init()) -> TimelineModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let rest = items(now: now).filter { calendar.startOfDay(for: $0.startDate) != today }
        return TimelineBuilder.build(items: rest, now: now, selectionID: nil)
    }
}

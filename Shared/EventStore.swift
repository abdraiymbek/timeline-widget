import EventKit
import OSLog

enum Log {
    static let widget = Logger(subsystem: "com.abdraiymbek.timelinewidget", category: "widget")
    static let app = Logger(subsystem: "com.abdraiymbek.timelinewidget", category: "app")
}

/// Thin wrapper over EKEventStore shared by the host app and the widget extension.
final class EventStore {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var hasFullAccess: Bool { authorizationStatus == .fullAccess }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func eventCalendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// `calendarIDs == nil` or empty means "all calendars".
    func events(from start: Date, to end: Date, calendarIDs: [String]?) -> [EKEvent] {
        let calendars: [EKCalendar]? = {
            guard let ids = calendarIDs, !ids.isEmpty else { return nil }
            return eventCalendars().filter { ids.contains($0.calendarIdentifier) }
        }()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    func event(withIdentifier id: String) -> EKEvent? {
        store.event(withIdentifier: id)
    }
}

// MARK: - EKEvent -> EventItem

extension EKEvent {
    func toItem(now: Date) -> EventItem {
        EventItem(
            id: eventIdentifier ?? UUID().uuidString,
            title: title ?? "Untitled",
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarTitle: calendar?.title ?? "Calendar",
            calendarColor: RGBAColor(cgColor: calendar?.cgColor),
            location: location?.isEmpty == false ? location : nil,
            notes: Self.cleanedNotes(notes),
            url: url,
            organizer: organizer?.name,
            attendees: (attendees ?? []).compactMap { $0.name ?? $0.url.absoluteString },
            recurrenceText: Self.recurrenceDescription(recurrenceRules?.first),
            alarmText: Self.alarmDescription(alarms?.first),
            statusText: Self.statusDescription(status: status, availability: availability),
            isInProgress: !isAllDay && startDate <= now && now < endDate,
            isPast: endDate < now
        )
    }

    private static func cleanedNotes(_ notes: String?) -> String? {
        guard let notes else { return nil }
        // Strip HTML-ish residue and collapse whitespace.
        let stripped = notes.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
        let collapsed = stripped
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return collapsed.isEmpty ? nil : collapsed
    }

    private static func recurrenceDescription(_ rule: EKRecurrenceRule?) -> String? {
        guard let rule else { return nil }
        let unit: String
        switch rule.frequency {
        case .daily:   unit = rule.interval == 1 ? "day" : "days"
        case .weekly:  unit = rule.interval == 1 ? "week" : "weeks"
        case .monthly: unit = rule.interval == 1 ? "month" : "months"
        case .yearly:  unit = rule.interval == 1 ? "year" : "years"
        @unknown default: return "Repeats"
        }
        if rule.interval == 1 {
            switch rule.frequency {
            case .daily:   return "Repeats daily"
            case .weekly:  return "Repeats weekly"
            case .monthly: return "Repeats monthly"
            case .yearly:  return "Repeats yearly"
            @unknown default: return "Repeats"
            }
        }
        return "Repeats every \(rule.interval) \(unit)"
    }

    private static func alarmDescription(_ alarm: EKAlarm?) -> String? {
        guard let alarm else { return nil }
        if let absolute = alarm.absoluteDate {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return "Alert at \(f.string(from: absolute))"
        }
        let seconds = -alarm.relativeOffset // negative offset = before start
        if seconds <= 0 { return "Alert at start time" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 {
            return minutes == 1 ? "Alert 1 minute before" : "Alert \(minutes) minutes before"
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? "Alert 1 hour before" : "Alert \(hours) hours before"
        }
        let days = hours / 24
        return days == 1 ? "Alert 1 day before" : "Alert \(days) days before"
    }

    private static func statusDescription(status: EKEventStatus, availability: EKEventAvailability) -> String? {
        switch status {
        case .canceled:  return "Canceled"
        case .tentative: return "Tentative"
        default: break
        }
        switch availability {
        case .free: return "Free"
        case .tentative: return "Tentative"
        case .unavailable: return "Unavailable"
        default: return nil
        }
    }
}

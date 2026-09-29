import AppIntents
import AppKit
import WidgetKit

// MARK: - Tap an event row -> select it inside the widget

struct SelectEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Event"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Event")
    var eventID: String

    init() { eventID = "" }
    init(eventID: String) { self.eventID = eventID }

    func perform() async throws -> some IntentResult {
        SelectionStore.select(eventID)
        return .result()
    }
}

// MARK: - Close the detail card

struct ClearSelectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Event Details"
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        SelectionStore.clear()
        return .result()
    }
}

// MARK: - Open a URL (event deep link, calendar deep link)
// OpenURLIntent is macOS 15+; on macOS 14 widgets we open through NSWorkspace.

struct OpenLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Link"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    var urlString: String

    init() { urlString = "" }
    init(url: URL) { urlString = url.absoluteString }

    func perform() async throws -> some IntentResult {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Calendar entity (multi-select configuration)

struct CalendarEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Calendar")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = CalendarEntityQuery()
}

struct CalendarEntityQuery: EntityQuery {
    func entities(for identifiers: [CalendarEntity.ID]) async throws -> [CalendarEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CalendarEntity] {
        all()
    }

    private func all() -> [CalendarEntity] {
        EventStore().eventCalendars().map {
            CalendarEntity(id: $0.calendarIdentifier, name: $0.title)
        }
    }
}

// MARK: - Widget configuration

struct TimelineConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Timeline"
    static var description = IntentDescription("Choose which calendars appear on the timeline.")

    /// Empty selection = all calendars.
    @Parameter(title: "Calendars")
    var calendars: [CalendarEntity]?

    init() {}
}

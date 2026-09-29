import WidgetKit
import SwiftUI

struct TimelineWidgetEntry: TimelineEntry {
    let date: Date
    var model: TimelineModel
}

struct TimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TimelineWidgetEntry {
        TimelineWidgetEntry(date: .now, model: DemoData.model())
    }

    func snapshot(
        for configuration: TimelineConfigurationIntent,
        in context: Context
    ) async -> TimelineWidgetEntry {
        if context.isPreview {
            // Widget gallery preview: always show the demo timeline.
            return TimelineWidgetEntry(date: .now, model: DemoData.model())
        }
        let result = TimelineLoader.load(calendarIDs: configuration.calendars?.map(\.id))
        return TimelineWidgetEntry(date: .now, model: result.model)
    }

    func timeline(
        for configuration: TimelineConfigurationIntent,
        in context: Context
    ) async -> Timeline<TimelineWidgetEntry> {
        let result = TimelineLoader.load(calendarIDs: configuration.calendars?.map(\.id))
        let entry = TimelineWidgetEntry(date: .now, model: result.model)
        return Timeline(entries: [entry], policy: .after(result.nextReload))
    }
}

struct TimelineWidgetEntryView: View {
    var entry: TimelineWidgetEntry

    var body: some View {
        TimelineContentView(model: entry.model)
            .containerBackground(for: .widget) {
                SpaceBackground()
            }
    }
}

struct TimelineWidget: Widget {
    let kind = "TimelineWidget"

    init() {
        Cormorant.registerFonts()
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TimelineConfigurationIntent.self,
            provider: TimelineProvider()
        ) { entry in
            TimelineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Timeline")
        .description("Your calendar, as a quiet timeline of days.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct TimelineWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimelineWidget()
    }
}

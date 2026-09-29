import SwiftUI

/// The complete widget surface: timeline content on the space background.
/// The widget uses `containerBackground(for:)` with `SpaceBackground` instead —
/// this standalone form is for the host-app preview and snapshot renders.
struct StandaloneWidgetView: View {
    let model: TimelineModel

    var body: some View {
        TimelineContentView(model: model)
            .background(SpaceBackground())
    }
}

/// Timeline content, transparent background (the backdrop comes from
/// `containerBackground` in the widget, or `StandaloneWidgetView` elsewhere).
struct TimelineContentView: View {
    let model: TimelineModel

    var body: some View {
        Group {
            switch model.access {
            case .granted:
                timeline
            case .unavailable:
                noAccess
            }
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(model.access == .granted ? nil : URL(string: "timelinewidget://open"))
        .overlay {
            if let selection = model.selection {
                selectionOverlay(selection)
            }
        }
    }

    // MARK: Timeline column

    private var timeline: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.days) { day in
                        DayBlockView(day: day)
                    }
                }
                .background(alignment: .leading) {
                    RailLineView(todayFraction: model.todayNodeFraction)
                        .frame(width: Metrics.railWidth)
                }
                .padding(.top, topPadding(in: geo.size.height))
                Spacer(minLength: 0)
            }
        }
        .blur(radius: model.selection == nil ? 0 : 2.5)
    }

    /// Bias the column so the today node sits just above the middle (~47%).
    private func topPadding(in height: Double) -> Double {
        let slack = max(0, height - model.contentHeight)
        let target = height * 0.47 - model.todayNodeCenterY
        return min(max(target, 0), slack)
    }

    // MARK: No-permission state

    private var noAccess: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            PlanetOrb(palette: .mars, size: 22)
            Text("Open Timeline to allow calendar access")
                .font(.cormorant(15, .medium))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Selection overlay

    private func selectionOverlay(_ event: EventItem) -> some View {
        ZStack {
            Color.black.opacity(0.45)
            DetailCardView(event: event)
                .padding(.horizontal, 22)
        }
    }
}

// MARK: - Rail line (one continuous vertical line behind the node column)

private struct RailLineView: View {
    var todayFraction: Double

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Palette.ember.opacity(0.30), location: 0),
                        .init(color: Palette.starlight.opacity(0.20), location: todayFraction),
                        .init(color: Palette.earthlight.opacity(0.32), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 1, height: geo.size.height)
                .position(x: Metrics.railWidth / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - Day block (node + label + event rows)

private struct DayBlockView: View {
    let day: DaySection

    private var isToday: Bool { day.kind == .today }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.railGap) {
            PlanetOrb(
                palette: day.palette,
                size: isToday ? Metrics.todayNodeSize : Metrics.nodeSize,
                halo: isToday,
                glow: isToday
            )
            .padding(.top, isToday ? Metrics.todayNodeTopPad : Metrics.nodeTopPad)
            .frame(width: Metrics.railWidth, alignment: .center)
            .widgetAccentable()

            VStack(alignment: .leading, spacing: 0) {
                header
                if isToday && day.events.isEmpty {
                    Text("Nothing scheduled")
                        .font(.cormorant(13, .medium, italic: true))
                        .foregroundStyle(Palette.muted)
                        .frame(height: Metrics.rowHeight, alignment: .center)
                        .padding(.leading, Metrics.timeColumnWidth + 11)
                }
                ForEach(day.events) { item in
                    EventRowView(
                        item: item,
                        dimmed: day.kind != .past && item.isPast
                    )
                }
                if day.overflowCount > 0 {
                    Text("+\(day.overflowCount) more")
                        .font(.cormorant(12, .medium, italic: true))
                        .foregroundStyle(Palette.muted.opacity(0.85))
                        .frame(height: Metrics.rowHeight, alignment: .center)
                        .padding(.leading, Metrics.timeColumnWidth + 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Metrics.blockGap)
        }
        .opacity(day.kind == .past ? 0.45 : 1)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if isToday {
                Text(day.label)
                    .font(.cormorant(30, .semibold, italic: true))
                    .foregroundStyle(Palette.starlight)
                    .widgetAccentable()
            } else {
                Text(day.label)
                    .font(.cormorant(15, .semibold))
                    .foregroundStyle(Palette.starlight)
            }
            Text(day.secondary)
                .font(.cormorant(11, .medium))
                .foregroundStyle(Palette.muted)
        }
        .frame(height: isToday ? Metrics.todayHeaderHeight : Metrics.headerHeight)
    }
}

// MARK: - Event row (a Button running SelectEventIntent)

private struct EventRowView: View {
    let item: EventItem
    let dimmed: Bool

    var body: some View {
        Button(intent: SelectEventIntent(eventID: item.id)) {
            HStack(spacing: 7) {
                Text(item.shortTimeLabel)
                    .font(.cormorant(11, .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(width: Metrics.timeColumnWidth, alignment: .leading)
                Circle()
                    .fill(item.isInProgress ? Palette.ember : Palette.muted.opacity(0.55))
                    .frame(width: item.isInProgress ? 5 : 4, height: item.isInProgress ? 5 : 4)
                    .shadow(
                        color: item.isInProgress ? Palette.ember.opacity(0.9) : .clear,
                        radius: 3
                    )
                Text(item.title)
                    .font(.cormorant(13, .medium))
                    .foregroundStyle(Palette.starlight)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .frame(height: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(dimmed ? 0.5 : 1)
    }
}

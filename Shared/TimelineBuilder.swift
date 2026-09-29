import Foundation

// MARK: - Layout metrics / budget

enum Metrics {
    /// One layout "unit" in points. Costs below are expressed in units where
    /// 1 unit == one event row; headers fold their trailing block gap in.
    static let unit: Double = 17.0
    /// Vertical budget in units: (345pt widget height - 2x vertical padding) / unit.
    static let budget: Double = (345 - 2 * verticalPadding) / unit
    static let rowCost: Double = 1.0

    static let todayRowCap = 4
    static let dayRowCap = 2
    static let pastDayLimit = 2
    static let pastLookbackDays = 7
    static let futureLookaheadDays = 21

    // Geometry (points)
    static let railWidth: Double = 30
    static let railGap: Double = 12
    static let nodeSize: Double = 12
    static let todayNodeSize: Double = 26
    static let nodeTopPad: Double = 6
    static let todayNodeTopPad: Double = 9
    static let headerHeight: Double = 24
    static let todayHeaderHeight: Double = 38
    static let rowHeight: Double = 17
    static let blockGap: Double = 5
    static let horizontalPadding: Double = 18
    static let verticalPadding: Double = 10
    static let timeColumnWidth: Double = 34
}

// MARK: - Selection persistence (extension-local UserDefaults)

enum SelectionStore {
    private static let idKey = "selectedEventID"
    private static let tsKey = "selectedEventTimestamp"
    static let ttl: TimeInterval = 120

    static func select(_ eventID: String) {
        UserDefaults.standard.set(eventID, forKey: idKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: tsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: tsKey)
    }

    /// Returns the selected event id if still fresh (< 2 minutes).
    static func current() -> String? {
        guard
            let id = UserDefaults.standard.string(forKey: idKey),
            let ts = UserDefaults.standard.object(forKey: tsKey) as? TimeInterval,
            Date().timeIntervalSince1970 - ts < ttl
        else { return nil }
        return id
    }
}

// MARK: - Timeline building

enum TimelineBuilder {

    /// Sections + selection from flat, chronologically sorted event items.
    static func build(items: [EventItem], now: Date, selectionID: String?) -> TimelineModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        var byDay: [Date: [EventItem]] = [:]
        for item in items.sorted(by: { $0.startDate < $1.startDate }) {
            byDay[calendar.startOfDay(for: item.startDate), default: []].append(item)
        }

        // Up to `pastDayLimit` most recent past days with events.
        let pastDays = byDay.keys
            .filter { $0 < today && $0 >= calendar.date(byAdding: .day, value: -Metrics.pastLookbackDays, to: today)! }
            .sorted(by: >)
            .prefix(Metrics.pastDayLimit)
            .sorted() // ascending for display

        let futureLimit = calendar.date(byAdding: .day, value: Metrics.futureLookaheadDays, to: today)!
        let futureDays = byDay.keys
            .filter { $0 > today && $0 <= futureLimit }
            .sorted()

        var remaining = Metrics.budget
        var sections: [DaySection] = []
        var unitOffset = 0.0

        func makeSection(day: Date, kind: DayKind) -> DaySection {
            let all = byDay[day] ?? []
            let cap = kind == .today ? Metrics.todayRowCap : Metrics.dayRowCap
            let visible = Array(all.prefix(cap))
            let overflow = max(0, all.count - cap)
            let header = kind == .today ? Metrics.todayHeaderHeight : Metrics.headerHeight
            // Point-exact cost (in units): header + visible rows + overflow row + block gap.
            // An empty today still renders a "Nothing scheduled" row.
            let rowCount = max(visible.count, kind == .today ? 1 : 0)
            let costPoints = header
                + Double(rowCount) * Metrics.rowHeight
                + (overflow > 0 ? Metrics.rowHeight : 0)
                + Metrics.blockGap
            let cost = costPoints / Metrics.unit
            let section = DaySection(
                id: dayID(day), date: day, kind: kind,
                label: dayLabel(day, kind: kind, now: now, calendar: calendar),
                secondary: secondaryLabel(day, kind: kind, calendar: calendar),
                events: visible, overflowCount: overflow,
                palette: .mars, unitOffset: unitOffset, unitCost: cost
            )
            return section
        }

        for day in pastDays {
            let s = makeSection(day: day, kind: .past)
            guard remaining >= s.unitCost else { continue }
            sections.append(s); remaining -= s.unitCost; unitOffset += s.unitCost
        }

        // Today is always shown, even if it overflows the nominal budget.
        let todaySection = makeSection(day: today, kind: .today)
        sections.append(todaySection)
        remaining = max(0, remaining - todaySection.unitCost)

        let todayIndex = sections.count - 1

        for day in futureDays {
            let s = makeSection(day: day, kind: .future)
            guard remaining >= s.unitCost else { break }
            sections.append(s); remaining -= s.unitCost
        }

        // Assign node palettes: today = mars, everything else cycles earth/gold/graphite.
        let cycle: [OrbPalette] = [.earth, .gold, .graphite]
        var cycleIndex = 0
        var totalUnits = 0.0
        for i in sections.indices {
            sections[i].unitOffset = totalUnits
            totalUnits += sections[i].unitCost
            if sections[i].kind == .today {
                sections[i].palette = .mars
            } else {
                sections[i].palette = cycle[cycleIndex % cycle.count]
                cycleIndex += 1
            }
        }
        let todayCenter = sections[todayIndex].unitOffset + 0.9
        let fraction = totalUnits > 0 ? min(max(todayCenter / totalUnits, 0), 1) : 0.5

        let selection = selectionID.flatMap { id in items.first(where: { $0.id == id }) }

        return TimelineModel(
            access: .granted, days: sections, selection: selection,
            generatedAt: now, todayNodeFraction: fraction,
            contentHeight: totalUnits * Metrics.unit,
            todayNodeCenterY: (sections[todayIndex].unitOffset * Metrics.unit)
                + Metrics.todayNodeTopPad + Metrics.todayNodeSize / 2
        )
    }

    /// Next reload: earliest event boundary, 15-minute cap, and midnight — whichever comes first.
    static func nextReload(after now: Date, items: [EventItem], selectionActive: Bool) -> Date {
        var candidates = [now.addingTimeInterval(15 * 60)]
        if let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            candidates.append(midnight)
        }
        for item in items {
            for boundary in [item.startDate, item.endDate] where boundary > now {
                candidates.append(boundary)
            }
        }
        return candidates.min() ?? now.addingTimeInterval(15 * 60)
    }

    // MARK: Labels

    private static func dayID(_ day: Date) -> String {
        dayIDFormatter.string(from: day)
    }

    private static func dayLabel(_ day: Date, kind: DayKind, now: Date, calendar: Calendar) -> String {
        if kind == .today { return "Today" }
        let today = calendar.startOfDay(for: now)
        if day == calendar.date(byAdding: .day, value: -1, to: today) { return "Yesterday" }
        if day == calendar.date(byAdding: .day, value: 1, to: today) { return "Tomorrow" }
        return weekdayFormatter.string(from: day)
    }

    private static func secondaryLabel(_ day: Date, kind: DayKind, calendar: Calendar) -> String {
        if kind == .today { return todaySecondaryFormatter.string(from: day) }
        return monthDayFormatter.string(from: day)
    }

    private static let dayIDFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()
    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let todaySecondaryFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f
    }()
}

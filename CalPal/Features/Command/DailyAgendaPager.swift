import SwiftUI

struct DailyAgendaPager: View {
    let selectedDay: Date
    let events: [CalendarEvent]
    let state: AgendaLoadingState
    var onSelectEvent: (CalendarEvent) -> Void = { _ in }
    let onSelectDay: (Date) -> Void
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: CalPalTheme.Spacing.sm) {
            WeekStripView(selectedDay: selectedDay, onSelectDay: onSelectDay)
            content
        }
        .gesture(DragGesture(minimumDistance: 40).onEnded { value in
            if value.translation.width < -40 { moveDay(1) }
            if value.translation.width > 40 { moveDay(-1) }
        })
        .accessibilityHint("Swipe left or right to change day")
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading agenda…")
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if events.isEmpty { EmptyAgendaView(onManualCreate: {}) } else { DayAgendaTimeline(day: selectedDay, events: events, onSelectEvent: onSelectEvent) }
        case .denied(let error), .failed(let error):
            FailureCard(error: error).frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func moveDay(_ offset: Int) {
        if let next = calendar.date(byAdding: .day, value: offset, to: selectedDay) { onSelectDay(next) }
    }
}

struct WeekStripView: View {
    let selectedDay: Date
    let onSelectDay: (Date) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CalPalTheme.Spacing.sm) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                    Button { onSelectDay(day) } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2)
                            Text(day.formatted(.dateTime.day())).font(.callout.bold())
                        }
                        .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 58 : 42)
                        .padding(.horizontal, CalPalTheme.Spacing.sm)
                        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 7)
                        .background(isSelected ? CalPalTheme.Colors.selectedDateBackground : Color.clear, in: Capsule())
                        .foregroundStyle(isSelected ? CalPalTheme.Colors.selectedDateForeground : CalPalTheme.Colors.textPrimary)
                    }
                    .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted))\(isSelected ? ", selected" : "")")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var days: [Date] {
        (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: selectedDay) }
    }
}

struct DayAgendaTimeline: View {
    let day: Date
    let events: [CalendarEvent]
    var onSelectEvent: (CalendarEvent) -> Void = { _ in }
    var now: Date = Date()
    var calendar: Calendar = .current

    var body: some View {
        let sections = AgendaNowPlacement.sections(events: events, selectedDay: day, now: now, calendar: calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
                ForEach(sections.earlier) { event in AgendaEventRow(event: event, onSelect: onSelectEvent) }
                if sections.showsNow { NowIndicator() }
                ForEach(sections.upcoming) { event in AgendaEventRow(event: event, onSelect: onSelectEvent) }
            }
            .padding(.vertical, CalPalTheme.Spacing.sm)
            .padding(.bottom, CalPalTheme.Spacing.orb + CalPalTheme.Spacing.xl)
        }
        .accessibilityLabel("Agenda for \(day.formatted(date: .complete, time: .omitted))")
    }
}

struct AgendaNowSections: Equatable {
    var earlier: [CalendarEvent]
    var upcoming: [CalendarEvent]
    var showsNow: Bool
}

enum AgendaNowPlacement {
    static func sections(events: [CalendarEvent], selectedDay: Date, now: Date, calendar: Calendar = .current) -> AgendaNowSections {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        guard calendar.isDate(selectedDay, inSameDayAs: now) else {
            return AgendaNowSections(earlier: sorted, upcoming: [], showsNow: false)
        }
        let earlier = sorted.filter { $0.startDate < now }
        let upcoming = sorted.filter { $0.startDate >= now }
        return AgendaNowSections(earlier: earlier, upcoming: upcoming, showsNow: true)
    }
}

struct AgendaEventRow: View {
    let event: CalendarEvent
    var onSelect: (CalendarEvent) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button { onSelect(event) } label: {
            HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
                if !dynamicTypeSize.isAccessibilitySize { timeView.frame(width: 58, alignment: .leading) }
                HStack(spacing: CalPalTheme.Spacing.md) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(CalPalTheme.Colors.eventAccent(hex: event.calendarColorHex, fallbackID: event.calendarID))
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 5) {
                        if dynamicTypeSize.isAccessibilitySize { timeView }
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(CalPalTheme.Colors.textPrimary)
                        Text("\(event.calendarName) · \(event.formattedRange)")
                            .font(.caption)
                            .foregroundStyle(CalPalTheme.Colors.textSecondary)
                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "location")
                                .font(.caption)
                                .foregroundStyle(CalPalTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, CalPalTheme.Spacing.md)
                    .padding(.trailing, CalPalTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .elevatedCard()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens event details and update options")
    }

    private var timeView: some View {
        Text(event.startDate.formatted(date: .omitted, time: .shortened))
            .font(.caption.monospacedDigit())
            .foregroundStyle(CalPalTheme.Colors.textSecondary)
    }

    private var accessibilitySummary: String {
        var parts = [event.title, event.formattedRange, event.calendarName]
        if event.isRecurring { parts.append("Repeating") }
        if let location = event.location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: ", ")
    }
}

struct NowIndicator: View {
    var body: some View {
        HStack {
            Text("Now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CalPalTheme.Colors.recording)
            Rectangle()
                .fill(CalPalTheme.Colors.recording.opacity(0.65))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

struct EmptyAgendaView: View {
    let onManualCreate: () -> Void
    var body: some View {
        ContentUnavailableView("No events today", systemImage: "calendar", description: Text("Tap the orb to speak, double-tap to type, or create manually when AI is unavailable."))
            .foregroundStyle(CalPalTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty Agenda Light") {
    EmptyAgendaView(onManualCreate: {})
        .padding()
        .background(CalPalTheme.Colors.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("Empty Agenda Dark") {
    EmptyAgendaView(onManualCreate: {})
        .padding()
        .background(CalPalTheme.Colors.backgroundPrimary)
        .preferredColorScheme(.dark)
}

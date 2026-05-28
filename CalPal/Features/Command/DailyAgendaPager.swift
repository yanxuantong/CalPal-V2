import SwiftUI

struct DailyAgendaPager: View {
    let selectedDay: Date
    let events: [CalendarEvent]
    let state: AgendaLoadingState
    var onSelectEvent: (CalendarEvent) -> Void = { _ in }
    var onManualCreate: () -> Void = {}
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
            AgendaLoadingPlaceholderView()
        case .loaded:
            if events.isEmpty { EmptyAgendaView(onManualCreate: onManualCreate) } else { DayAgendaTimeline(day: selectedDay, events: events, onSelectEvent: onSelectEvent) }
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
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? 72 : 54, height: dynamicTypeSize.isAccessibilitySize ? 62 : 48)
                        .background(isSelected ? CalPalTheme.Colors.selectedDateBackground : Color.clear, in: Capsule())
                        .foregroundStyle(isSelected ? CalPalTheme.Colors.selectedDateForeground : CalPalTheme.Colors.textPrimary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted))\(isSelected ? ", selected" : "")")
                    .accessibilityIdentifier("weekDay_\(day.calPalDateIdentifier)")
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
        .accessibilityIdentifier("agendaTimeline")
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
        .accessibilityIdentifier("agendaEventRow_\(event.id)")
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

struct AgendaLoadingPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
            ForEach(0..<3, id: \.self) { index in
                HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(CalPalTheme.Colors.textSecondary.opacity(0.20))
                        .frame(width: 54, height: 14)
                        .padding(.top, CalPalTheme.Spacing.md)
                    HStack(spacing: CalPalTheme.Spacing.md) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(CalPalTheme.Colors.textSecondary.opacity(0.18))
                            .frame(width: 4)
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(CalPalTheme.Colors.textSecondary.opacity(0.22))
                                .frame(width: index == 1 ? 170 : 220, height: 16)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(CalPalTheme.Colors.textSecondary.opacity(0.16))
                                .frame(width: 130, height: 12)
                        }
                        .padding(.vertical, CalPalTheme.Spacing.md)
                        .padding(.trailing, CalPalTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .elevatedCard()
                    .frame(minHeight: 70)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading agenda")
        .accessibilityIdentifier("agendaLoadingPlaceholder")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, CalPalTheme.Spacing.sm)
    }
}

struct EmptyAgendaView: View {
    let onManualCreate: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("No events today", systemImage: "calendar")
        } description: {
            Text("Tap the orb to speak, double-tap to type, or create manually when AI is unavailable.")
        } actions: {
            Button(action: onManualCreate) {
                Label("Create Manually", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier("emptyAgendaManualCreate")
        }
            .foregroundStyle(CalPalTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Date {
    var calPalDateIdentifier: String {
        Self.identifierFormatter.string(from: self)
    }

    static let identifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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

import SwiftUI

struct EventDetailView: View {
    let context: EventDetailContext
    let onUpdate: (EventPatch) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var location: String
    @State private var notes: String

    init(context: EventDetailContext, onUpdate: @escaping (EventPatch) -> Void) {
        self.context = context
        self.onUpdate = onUpdate
        _title = State(initialValue: context.event.title)
        _location = State(initialValue: context.event.location ?? "")
        _notes = State(initialValue: context.event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalPalTheme.Spacing.lg) {
                    header
                    detailRows
                    editSection
                }
                .padding()
            }
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Text(context.event.title)
                .font(.title2.bold())
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
                .accessibilityIdentifier("eventDetailTitle")
            Label(context.event.formattedRange, systemImage: "clock")
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            Label("\(context.event.calendarName) · \(context.event.accountName)", systemImage: "calendar")
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            if context.event.isRecurring {
                Label("Repeating event", systemImage: "repeat")
                    .quietChip(CalPalTheme.Colors.aiChip)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
            DetailLine(label: "Calendar", value: "\(context.event.calendarName) · \(context.event.accountName)", systemImage: "calendar")
            DetailLine(label: "Time", value: fullDateRange, systemImage: "clock")
            DetailLine(label: "Location", value: emptyFallback(context.event.location), systemImage: "location")
            DetailLine(label: "Notes", value: emptyFallback(context.event.notes), systemImage: "note.text")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
            Text("Quick update")
                .font(.headline)
            Text("Changes are reviewed before saving and use existing-event update semantics.")
                .font(.caption)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("eventDetailTitleField")
            TextField("Location", text: $location)
                .textFieldStyle(.roundedBorder)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Button("Review Update") { onUpdate(updatePatch) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!updatePatch.hasChanges)
                .accessibilityIdentifier("eventDetailReviewUpdate")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }

    private var updatePatch: EventPatch {
        EventPatch(
            title: normalized(title) == context.event.title ? nil : normalized(title),
            startDate: nil,
            endDate: nil,
            location: normalized(location) == (context.event.location ?? "") ? nil : normalized(location),
            notes: normalized(notes) == (context.event.notes ?? "") ? nil : normalized(notes)
        )
    }

    private var fullDateRange: String {
        "\(context.event.startDate.formatted(date: .abbreviated, time: .shortened)) – \(context.event.endDate.formatted(date: .abbreviated, time: .shortened))"
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyFallback(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "None" }
        return text
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(CalPalTheme.Colors.brandPrimary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
            }
        }
    }
}

#Preview("Event Detail Full") {
    EventDetailView(context: EventDetailContext(event: PreviewFixtures.workEvent)) { _ in }
        .preferredColorScheme(.light)
}

#Preview("Event Detail Minimal") {
    var event = PreviewFixtures.workEvent
    event.location = nil
    event.notes = nil
    return EventDetailView(context: EventDetailContext(event: event)) { _ in }
        .preferredColorScheme(.dark)
}

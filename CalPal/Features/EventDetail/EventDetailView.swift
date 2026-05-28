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
            EventDetailReviewHint(state: reviewState)
            Button("Review Update") { onUpdate(updatePatch) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!reviewState.canReview)
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

    private var reviewState: EventDetailReviewState {
        EventDetailReviewState(title: title, patch: updatePatch)
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

struct EventDetailReviewState: Equatable {
    enum Status: Equatable {
        case missingTitle
        case unchanged
        case ready(changeCount: Int, clearCount: Int)
    }

    var status: Status

    init(title: String, patch: EventPatch) {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .missingTitle
        } else if !patch.hasChanges {
            status = .unchanged
        } else {
            let changes = patch.confirmationSummaryChanges
            status = .ready(changeCount: changes.count, clearCount: changes.filter(\.isClearIntent).count)
        }
    }

    var canReview: Bool {
        if case .ready = status { return true }
        return false
    }

    var message: String {
        switch status {
        case .missingTitle:
            return "Title is required before review."
        case .unchanged:
            return "Make a change to review before saving."
        case .ready(let changeCount, let clearCount):
            let changeCopy = "\(changeCount) change\(changeCount == 1 ? "" : "s")"
            guard clearCount > 0 else { return "Review \(changeCopy) before saving." }
            let clearCopy = "\(clearCount) clear\(clearCount == 1 ? "" : "s")"
            return "Review \(changeCopy), including \(clearCopy), before saving."
        }
    }

    var systemImage: String {
        switch status {
        case .missingTitle:
            return "exclamationmark.circle.fill"
        case .unchanged:
            return "info.circle"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    var palette: CalPalTheme.ChipPalette {
        switch status {
        case .missingTitle:
            return CalPalTheme.Colors.warningChip
        case .unchanged:
            return CalPalTheme.Colors.aiChip
        case .ready:
            return CalPalTheme.Colors.successChip
        }
    }
}

private struct EventDetailReviewHint: View {
    let state: EventDetailReviewState

    var body: some View {
        Label(state.message, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .quietChip(state.palette)
            .accessibilityIdentifier("eventDetailReviewHint")
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

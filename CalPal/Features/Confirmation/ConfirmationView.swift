import SwiftUI

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: RecurrenceChangeScope
    let context: ConfirmationContext
    let onDecision: (ConfirmationDecision) -> Void

    init(context: ConfirmationContext, onDecision: @escaping (ConfirmationDecision) -> Void) {
        self.context = context
        self.onDecision = onDecision
        _selectedScope = State(initialValue: context.recurrenceScope ?? .thisEvent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalPalTheme.Spacing.lg) {
                    header
                    if let before = context.before { EventSummaryCard(title: "Before", event: before) }
                    if let patch = context.patch { PatchSummaryCard(patch: patch) }
                    if context.recurrenceScope != nil {
                        recurrencePicker
                        RecurrenceScopeReviewCard(scope: selectedScope, operation: context.operation)
                    }
                    actionButtons
                }
                .padding()
            }
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle(context.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(context.isDestructive ? "Destructive change" : "Review change", systemImage: context.isDestructive ? "exclamationmark.triangle.fill" : "checkmark.seal")
                .quietChip(context.isDestructive ? CalPalTheme.Colors.destructiveChip : CalPalTheme.Colors.aiChip)
            if let route = context.parseRoute {
                Label(route.resultLabel, systemImage: route == .foundationModelsGenerated ? "sparkles" : "cpu")
                    .font(.caption.weight(.semibold))
                    .quietChip(route == .foundationModelsGenerated ? CalPalTheme.Colors.aiChip : CalPalTheme.Colors.warningChip)
                    .accessibilityLabel(route.accessibilityLabel)
                    .accessibilityIdentifier("confirmationParseRoute")
            }
            Text(context.message)
                .font(.callout)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(context.isDestructive ? "Destructive change. \(context.message)" : context.message)
    }

    private var recurrencePicker: some View {
        Picker("Repeating event scope", selection: $selectedScope) {
            ForEach(RecurrenceChangeScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Choose whether this change applies to one event or future repeating events")
    }

    private var actionButtons: some View {
        VStack(spacing: CalPalTheme.Spacing.sm) {
            Button(role: context.isDestructive ? .destructive : nil) { onDecision(.confirm(recurrenceScope: context.recurrenceScope == nil ? nil : selectedScope)) } label: {
                Text(context.confirmationActionTitle(selectedScope: selectedScope))
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .tint(context.isDestructive ? CalPalTheme.Colors.destructive : CalPalTheme.Colors.brandPrimary)
                .controlSize(.large)
                .accessibilityIdentifier("confirmationPrimaryAction")
            Button(role: .cancel) { onDecision(.cancel) } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecurrenceScopeReviewCard: View {
    let scope: RecurrenceChangeScope
    let operation: CommandOperation

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(scope.reviewTitle(for: operation))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(scope.reviewMessage(for: operation))
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        } icon: {
            Image(systemName: scope == .futureEvents ? "repeat.badge.exclamationmark" : "repeat.1")
                .foregroundStyle(scope == .futureEvents ? CalPalTheme.Colors.warning : CalPalTheme.Colors.brandPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scope.reviewTitle(for: operation)). \(scope.reviewMessage(for: operation))")
        .accessibilityIdentifier("confirmationRecurrenceScopeReview")
    }
}

struct EventSummaryCard: View {
    let title: String
    let event: CalendarEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.bold()).foregroundStyle(CalPalTheme.Colors.textSecondary)
            Text(event.title).font(.headline).foregroundStyle(CalPalTheme.Colors.textPrimary)
            ForEach(event.confirmationSummaryDetails) { detail in
                Label(detail.value, systemImage: detail.systemImage)
                    .font(.caption)
                    .foregroundStyle(detail.isWarning ? CalPalTheme.Colors.warning : CalPalTheme.Colors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.confirmationAccessibilitySummary(prefix: title))
    }
}

struct EventSummaryDetail: Identifiable, Equatable {
    var id: String
    var value: String
    var systemImage: String
    var isWarning: Bool = false
}

extension CalendarEvent {
    var confirmationSummaryDetails: [EventSummaryDetail] {
        var details = [
            EventSummaryDetail(id: "time", value: formattedRange, systemImage: "clock"),
            EventSummaryDetail(id: "calendar", value: calendarName, systemImage: "calendar")
        ]
        if let location = location?.trimmedConfirmationDetail, !location.isEmpty {
            details.append(EventSummaryDetail(id: "location", value: location, systemImage: "location"))
        }
        if let notes = notes?.trimmedConfirmationDetail, !notes.isEmpty {
            details.append(EventSummaryDetail(id: "notes", value: notes, systemImage: "note.text"))
        }
        if isRecurring {
            details.append(EventSummaryDetail(id: "recurrence", value: "Repeating event", systemImage: "repeat", isWarning: true))
        }
        return details
    }

    func confirmationAccessibilitySummary(prefix: String) -> String {
        let details = confirmationSummaryDetails.map(\.value).joined(separator: ", ")
        return "\(prefix), \(title), \(details)"
    }
}

struct PatchSummaryCard: View {
    let patch: EventPatch
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AFTER").font(.caption.bold()).foregroundStyle(CalPalTheme.Colors.brandPrimary)
            ForEach(patch.confirmationSummaryChanges) { change in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CalPalTheme.Colors.textSecondary)
                        Text(change.value)
                            .font(change.id == "title" ? .headline : .callout)
                            .foregroundStyle(change.isClearIntent ? CalPalTheme.Colors.warning : CalPalTheme.Colors.textPrimary)
                    }
                } icon: {
                    Image(systemName: change.systemImage)
                        .foregroundStyle(change.isClearIntent ? CalPalTheme.Colors.warning : CalPalTheme.Colors.brandPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(patch.confirmationAccessibilitySummary)
    }
}

struct PatchSummaryChange: Identifiable, Equatable {
    var id: String
    var label: String
    var value: String
    var systemImage: String
    var isClearIntent: Bool = false
}

extension EventPatch {
    var confirmationSummaryChanges: [PatchSummaryChange] {
        var changes: [PatchSummaryChange] = []
        if let title = title?.trimmedConfirmationText, !title.isEmpty {
            changes.append(PatchSummaryChange(id: "title", label: "Title", value: title, systemImage: "textformat"))
        }
        if let startDate {
            changes.append(PatchSummaryChange(id: "start", label: "Starts", value: startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock"))
        }
        if let endDate {
            changes.append(PatchSummaryChange(id: "end", label: "Ends", value: endDate.formatted(date: .omitted, time: .shortened), systemImage: "clock.badge.checkmark"))
        }
        if let location {
            let trimmed = location.trimmedConfirmationText
            changes.append(PatchSummaryChange(
                id: "location",
                label: "Location",
                value: trimmed.isEmpty ? "Clear location" : trimmed,
                systemImage: trimmed.isEmpty ? "location.slash" : "location",
                isClearIntent: trimmed.isEmpty
            ))
        }
        if let notes {
            let trimmed = notes.trimmedConfirmationText
            changes.append(PatchSummaryChange(
                id: "notes",
                label: "Notes",
                value: trimmed.isEmpty ? "Clear notes" : trimmed,
                systemImage: "note.text",
                isClearIntent: trimmed.isEmpty
            ))
        }
        return changes
    }

    var confirmationAccessibilitySummary: String {
        let changes = confirmationSummaryChanges.map { "\($0.label): \($0.value)" }
        guard !changes.isEmpty else { return "After update, no visible field changes" }
        return "After update, " + changes.joined(separator: ", ")
    }
}

extension ConfirmationContext {
    func confirmationActionTitle(selectedScope: RecurrenceChangeScope) -> String {
        guard recurrenceScope != nil else {
            return isDestructive ? "Delete Event" : "Apply Change"
        }

        switch (operation, selectedScope) {
        case (.delete, .thisEvent):
            return "Delete This Event"
        case (.delete, .futureEvents):
            return "Delete This and Future Events"
        case (.modify, .thisEvent):
            return "Apply to This Event"
        case (.modify, .futureEvents):
            return "Apply to This and Future Events"
        case (.create, _):
            return "Create Event"
        }
    }
}

extension RecurrenceChangeScope {
    func reviewTitle(for operation: CommandOperation) -> String {
        switch (operation, self) {
        case (.delete, .thisEvent):
            return "Deleting one occurrence"
        case (.delete, .futureEvents):
            return "Deleting future occurrences"
        case (.modify, .thisEvent):
            return "Changing one occurrence"
        case (.modify, .futureEvents):
            return "Changing future occurrences"
        case (.create, _):
            return rawValue
        }
    }

    func reviewMessage(for operation: CommandOperation) -> String {
        switch (operation, self) {
        case (.delete, .thisEvent):
            return "Only this event is removed. Future repeats stay on your calendar."
        case (.delete, .futureEvents):
            return "This event and later repeats are removed. Earlier events stay unchanged."
        case (.modify, .thisEvent):
            return "Only this event changes. Future repeats keep their current details."
        case (.modify, .futureEvents):
            return "This event and later repeats use the reviewed changes."
        case (.create, _):
            return "The selected recurrence scope will be used for this calendar change."
        }
    }
}

private extension String {
    var trimmedConfirmationText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedConfirmationDetail: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("Confirmation Delete Light") {
    ConfirmationView(context: PreviewFixtures.deleteConfirmationContext) { _ in }
        .preferredColorScheme(.light)
}

#Preview("Confirmation Delete Dark") {
    ConfirmationView(context: PreviewFixtures.deleteConfirmationContext) { _ in }
        .preferredColorScheme(.dark)
}

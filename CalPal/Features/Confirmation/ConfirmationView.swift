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
                    if context.recurrenceScope != nil { recurrencePicker }
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
            Button(context.isDestructive ? "Delete Event" : "Apply Change") { onDecision(.confirm(recurrenceScope: context.recurrenceScope == nil ? nil : selectedScope)) }
                .buttonStyle(.borderedProminent)
                .tint(context.isDestructive ? CalPalTheme.Colors.destructive : CalPalTheme.Colors.brandPrimary)
                .controlSize(.large)
            Button("Cancel") { onDecision(.cancel) }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EventSummaryCard: View {
    let title: String
    let event: CalendarEvent
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.bold()).foregroundStyle(CalPalTheme.Colors.textSecondary)
            Text(event.title).font(.headline).foregroundStyle(CalPalTheme.Colors.textPrimary)
            Text(event.formattedRange).font(.callout).foregroundStyle(CalPalTheme.Colors.textSecondary)
            Label(event.calendarName, systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
    }
}

struct PatchSummaryCard: View {
    let patch: EventPatch
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AFTER").font(.caption.bold()).foregroundStyle(CalPalTheme.Colors.brandPrimary)
            if let title = patch.title { Text(title).font(.headline).foregroundStyle(CalPalTheme.Colors.textPrimary) }
            if let start = patch.startDate { Text(start.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(CalPalTheme.Colors.textSecondary) }
            if let end = patch.endDate { Text("Ends " + end.formatted(date: .omitted, time: .shortened)).foregroundStyle(CalPalTheme.Colors.textSecondary) }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
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

import SwiftUI

struct ManualEventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EventDraft
    let context: ManualEventContext
    let onSave: (EventDraft) -> Void

    init(context: ManualEventContext, onSave: @escaping (EventDraft) -> Void) {
        self.context = context
        self.onSave = onSave
        _draft = State(initialValue: context.draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { ManualEventSummaryCard(reason: context.reason) }
                Section("Event") {
                    TextField("Title", text: $draft.title)
                    StartEndTimePicker(start: $draft.startDate, end: $draft.endDate)
                    TextField("Location", text: Binding(optional: $draft.location, replacingNilWith: ""))
                    TextField("Notes", text: Binding(optional: $draft.notes, replacingNilWith: ""), axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Manual create")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Event") { onSave(draft) }.disabled(!draft.hasRequiredFields) }
            }
        }
    }
}

struct ManualEventSummaryCard: View {
    let reason: String
    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label("Create manually", systemImage: "calendar.badge.plus")
                .font(.headline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            Text(reason)
                .font(.callout)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
        }
        .padding(.vertical, CalPalTheme.Spacing.xs)
    }
}

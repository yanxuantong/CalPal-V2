import SwiftUI

struct CorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EventDraft
    let context: CorrectionContext
    let onSave: (EventDraft) -> Void

    init(context: CorrectionContext, onSave: @escaping (EventDraft) -> Void) {
        self.context = context
        self.onSave = onSave
        _draft = State(initialValue: context.draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { CorrectionSummaryCard(title: context.title, message: context.message, sourceText: context.sourceText) }
                if !context.missingFields.isEmpty {
                    Section("Needs attention") {
                        MissingFieldChips(fields: context.missingFields)
                    }
                }
                Section("Event") {
                    TextField("Title", text: $draft.title)
                    StartEndTimePicker(start: $draft.startDate, end: $draft.endDate)
                    TextField("Location", text: Binding(optional: $draft.location, replacingNilWith: ""))
                    TextField("Notes", text: Binding(optional: $draft.notes, replacingNilWith: ""), axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle(context.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Event") { onSave(draft) }.disabled(!draft.hasRequiredFields) }
            }
        }
    }
}

struct CorrectionSummaryCard: View {
    let title: String
    let message: String
    let sourceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(title, systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            Text(message)
                .font(.callout)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            if !sourceText.isEmpty {
                Text("“\(sourceText)”")
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, CalPalTheme.Spacing.xs)
    }
}

struct MissingFieldChips: View {
    let fields: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            ForEach(fields, id: \.self) { field in
                Label(field.capitalized, systemImage: "exclamationmark.circle.fill")
                    .quietChip(CalPalTheme.Colors.warningChip)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StartEndTimePicker: View {
    @Binding var start: Date
    @Binding var end: Date
    var body: some View {
        DatePicker("Starts", selection: $start, displayedComponents: [.date, .hourAndMinute])
        DatePicker("Ends", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
    }
}

extension Binding where Value == String {
    init(optional source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue }, set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

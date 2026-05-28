import SwiftUI

struct CorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EventDraft
    @State private var isSaving = false
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
                Section { CorrectionSummaryCard(title: context.title, message: context.message, sourceText: context.sourceText, parseRoute: context.parseRoute) }
                if !context.missingFields.isEmpty {
                    Section("Needs attention") {
                        MissingFieldChips(fields: context.missingFields)
                    }
                }
                Section("Event") {
                    TextField("Title", text: $draft.title)
                    StartEndTimePicker(start: $draft.startDate, end: $draft.endDate)
                    TargetCalendarRow(summary: draft.targetCalendarSummary)
                    TextField("Location", text: Binding(optional: $draft.location, replacingNilWith: ""))
                    TextField("Notes", text: Binding(optional: $draft.notes, replacingNilWith: ""), axis: .vertical)
                    DraftSaveReadinessHint(state: saveReadiness)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle(context.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Event", action: submit)
                        .disabled(!saveReadiness.canSave)
                        .accessibilityIdentifier("correctionSaveEvent")
                }
            }
        }
    }

    private func submit() {
        guard saveReadiness.canSave else { return }
        isSaving = true
        onSave(draft)
    }

    private var saveReadiness: DraftSaveReadiness {
        DraftSaveReadiness(draft: draft, isSaving: isSaving)
    }
}

struct CorrectionSummaryCard: View {
    let title: String
    let message: String
    let sourceText: String
    var parseRoute: CalendarParseRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(title, systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            if let parseRoute {
                Label(parseRoute.resultLabel, systemImage: parseRoute == .foundationModelsGenerated ? "sparkles" : "cpu")
                    .font(.caption.weight(.semibold))
                    .quietChip(parseRoute == .foundationModelsGenerated ? CalPalTheme.Colors.aiChip : CalPalTheme.Colors.warningChip)
                    .accessibilityLabel(parseRoute.accessibilityLabel)
                    .accessibilityIdentifier("correctionParseRoute")
            }
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
        DatePicker("Starts", selection: startBinding, displayedComponents: [.date, .hourAndMinute])
        DatePicker("Ends", selection: endBinding, in: DraftTimeRangePolicy.minimumEndDate(for: start)..., displayedComponents: [.date, .hourAndMinute])
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { start },
            set: { newStart in
                end = DraftTimeRangePolicy.endDateAfterMovingStart(oldStart: start, oldEnd: end, newStart: newStart)
                start = newStart
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { DraftTimeRangePolicy.validEndDate(start: start, proposedEnd: end) },
            set: { newEnd in
                end = DraftTimeRangePolicy.validEndDate(start: start, proposedEnd: newEnd)
            }
        )
    }
}

enum DraftTimeRangePolicy {
    static let minimumDuration: TimeInterval = 60
    static let fallbackDuration: TimeInterval = 1800

    static func minimumEndDate(for start: Date) -> Date {
        start.addingTimeInterval(minimumDuration)
    }

    static func endDateAfterMovingStart(oldStart: Date, oldEnd: Date, newStart: Date) -> Date {
        let preservedDuration = max(oldEnd.timeIntervalSince(oldStart), fallbackDuration)
        return newStart.addingTimeInterval(preservedDuration)
    }

    static func validEndDate(start: Date, proposedEnd: Date) -> Date {
        guard proposedEnd > start else { return minimumEndDate(for: start) }
        return proposedEnd
    }
}

extension Binding where Value == String {
    init(optional source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue }, set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

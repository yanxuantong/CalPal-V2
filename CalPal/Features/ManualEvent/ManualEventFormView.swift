import SwiftUI

struct ManualEventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: EventDraft
    @State private var isSaving = false
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
                    TargetCalendarRow(summary: draft.targetCalendarSummary)
                    TextField("Location", text: Binding(optional: $draft.location, replacingNilWith: ""))
                    TextField("Notes", text: Binding(optional: $draft.notes, replacingNilWith: ""), axis: .vertical)
                    DraftSaveReadinessHint(state: saveReadiness)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Manual create")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(SheetDismissAutomation.manualEventCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Event", action: submit)
                        .disabled(!saveReadiness.canSave)
                        .accessibilityIdentifier("manualEventSave")
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

struct TargetCalendarRow: View {
    let summary: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar")
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        } icon: {
            Image(systemName: "calendar")
                .foregroundStyle(CalPalTheme.Colors.brandPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calendar, \(summary)")
        .accessibilityIdentifier("targetCalendarRow")
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

struct DraftSaveReadiness: Equatable {
    enum Status: Equatable {
        case missingTitle
        case invalidTimeRange
        case saving
        case ready
    }

    var status: Status

    init(draft: EventDraft, isSaving: Bool = false) {
        if isSaving {
            status = .saving
        } else if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .missingTitle
        } else if draft.endDate <= draft.startDate {
            status = .invalidTimeRange
        } else {
            status = .ready
        }
    }

    var canSave: Bool {
        status == .ready
    }

    var message: String {
        switch status {
        case .missingTitle:
            return "Title is required before saving."
        case .invalidTimeRange:
            return "End time must be after the start time."
        case .saving:
            return "Saving event..."
        case .ready:
            return "Ready to save."
        }
    }

    var systemImage: String {
        switch status {
        case .missingTitle, .invalidTimeRange:
            return "exclamationmark.circle.fill"
        case .saving:
            return "clock"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    var palette: CalPalTheme.ChipPalette {
        switch status {
        case .missingTitle, .invalidTimeRange:
            return CalPalTheme.Colors.warningChip
        case .saving:
            return CalPalTheme.Colors.aiChip
        case .ready:
            return CalPalTheme.Colors.successChip
        }
    }
}

struct DraftSaveReadinessHint: View {
    let state: DraftSaveReadiness

    var body: some View {
        Label(state.message, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .quietChip(state.palette)
            .accessibilityIdentifier("draftSaveReadinessHint")
    }
}

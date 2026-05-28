import SwiftUI

struct CandidateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let context: CandidateSelectionContext
    let onSelect: (CalendarEvent) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CandidateSelectionSummary(context: context)
                }
                Section("Matching events") {
                    ForEach(context.candidates) { event in
                        Button { onSelect(event) } label: {
                            CandidateEventRow(event: event)
                        }
                        .accessibilityIdentifier("candidateEvent-\(event.id)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var navigationTitle: String {
        switch context.operation {
        case .delete: return "Choose Event to Delete"
        case .modify: return "Choose Event to Update"
        case .create: return "Choose Event"
        }
    }
}

private struct CandidateSelectionSummary: View {
    let context: CandidateSelectionContext

    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(summaryTitle, systemImage: context.operation == .delete ? "exclamationmark.triangle.fill" : "checkmark.seal")
                .font(.headline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            if let route = context.parseRoute {
                Label(route.resultLabel, systemImage: route == .foundationModelsGenerated ? "sparkles" : "cpu")
                    .font(.caption.weight(.semibold))
                    .quietChip(route == .foundationModelsGenerated ? CalPalTheme.Colors.aiChip : CalPalTheme.Colors.warningChip)
                    .accessibilityLabel(route.accessibilityLabel)
                    .accessibilityIdentifier("candidateParseRoute")
            }
            Text("CalPal found more than one possible match. Choose the exact event before any calendar change is applied.")
                .font(.callout)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            if !context.sourceText.isEmpty {
                Text("\"\(context.sourceText)\"")
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, CalPalTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var summaryTitle: String {
        switch context.operation {
        case .delete: return "Review delete target"
        case .modify: return "Review update target"
        case .create: return "Review event target"
        }
    }
}

private struct CandidateEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(CalPalTheme.Colors.eventAccent(hex: event.calendarColorHex, fallbackID: event.calendarID))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                Text(event.calendarName)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                if event.isRecurring {
                    Label("Repeating", systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [event.title, event.formattedRange, event.calendarName]
        if event.isRecurring { parts.append("Repeating") }
        return parts.joined(separator: ", ")
    }
}

#Preview("Candidate Selection") {
    CandidateSelectionView(
        context: CandidateSelectionContext(
            operation: .modify,
            candidates: [PreviewFixtures.workEvent],
            patch: EventPatch(title: "Updated review", startDate: nil, endDate: nil, location: nil, notes: nil),
            sourceText: "Move Alex meeting",
            parseRoute: .foundationModelsFailedOver
        )
    ) { _ in }
}

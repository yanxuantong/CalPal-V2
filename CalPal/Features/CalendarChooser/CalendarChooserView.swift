import SwiftUI

struct CalendarChooserView: View {
    @Environment(\.dismiss) private var dismiss
    let context: CalendarChooserContext
    let onChoose: (CalendarInfo) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(context.calendars) { calendar in
                        Button { onChoose(calendar) } label: {
                            CalendarChooserRow(calendar: calendar, isSelected: calendar.id == context.selectedID)
                        }
                        .disabled(!calendar.allowsContentModifications)
                        .accessibilityHint(calendar.allowsContentModifications ? "Choose this writable calendar" : "This calendar is read-only")
                        .accessibilityIdentifier("calendarChooser-\(calendar.id)")
                    }
                } footer: {
                    Text("Only writable calendars can be selected for new events.")
                        .font(.caption)
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("calendarChooserCancel")
                }
            }
        }
    }
}

struct CalendarChooserRow: View {
    let calendar: CalendarInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: CalPalTheme.Spacing.md) {
            Circle()
                .fill(CalPalTheme.Colors.eventAccent(hex: calendar.colorHex, fallbackID: calendar.id))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(calendar.title)
                    .font(.headline)
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(calendar.accountName)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                Label(calendar.allowsContentModifications ? "Writable" : "Read-only", systemImage: calendar.allowsContentModifications ? "pencil.circle.fill" : "lock.fill")
                    .font(.caption.weight(.semibold))
                    .quietChip(calendar.allowsContentModifications ? CalPalTheme.Colors.successChip : CalPalTheme.Colors.warningChip)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CalPalTheme.Colors.brandPrimary)
                    .accessibilityLabel("Selected")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [calendar.title, calendar.accountName, calendar.allowsContentModifications ? "Writable" : "Read-only"]
        if isSelected { parts.append("Selected") }
        return parts.joined(separator: ", ")
    }
}

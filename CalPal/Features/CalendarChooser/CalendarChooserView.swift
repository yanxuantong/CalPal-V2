import SwiftUI

struct CalendarChooserView: View {
    let context: CalendarChooserContext
    let onChoose: (CalendarInfo) -> Void
    var body: some View {
        NavigationStack {
            List(context.calendars) { calendar in
                Button { onChoose(calendar) } label: {
                    HStack(spacing: CalPalTheme.Spacing.md) {
                        Circle()
                            .fill(CalPalTheme.Colors.eventAccent(hex: calendar.colorHex, fallbackID: calendar.id))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.title).font(.headline).foregroundStyle(CalPalTheme.Colors.textPrimary)
                            Text(calendar.subtitle).font(.caption).foregroundStyle(CalPalTheme.Colors.textSecondary)
                        }
                        Spacer()
                        if calendar.id == context.selectedID { Image(systemName: "checkmark").foregroundStyle(CalPalTheme.Colors.brandPrimary) }
                    }
                }
                .disabled(!calendar.allowsContentModifications)
                .accessibilityHint(calendar.allowsContentModifications ? "Choose this calendar" : "This calendar cannot be modified")
            }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Calendar")
        }
    }
}

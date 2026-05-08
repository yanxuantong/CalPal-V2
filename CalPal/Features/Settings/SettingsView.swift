import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var automationMode: AutomationMode = .autoReview
    @State private var confirmReset = false
    let startSection: SettingsSection?

    var body: some View {
        NavigationStack {
            Form {
                Section("Default Calendar") {
                    if appModel.commandHomeModel.calendars.isEmpty {
                        Text("Grant Calendar Full Access to choose a default writable calendar.")
                            .font(.caption)
                            .foregroundStyle(CalPalTheme.Colors.textSecondary)
                    } else {
                        Picker("Write new events to", selection: defaultCalendarBinding) {
                            ForEach(appModel.commandHomeModel.calendars.filter { $0.allowsContentModifications }) { calendar in
                                Text("\(calendar.title) · \(calendar.accountName)").tag(calendar.id as String?)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                Section("Automation Mode") {
                    Picker("Mode", selection: $automationMode) { ForEach(AutomationMode.allCases) { Text($0.rawValue).tag($0) } }
                    Text("Auto Review confirms modify/delete/recurring/ambiguous changes before mutation.")
                        .font(.caption)
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                }

                Section("Local Preferences") {
                    Button("Reset Local Preferences", role: .destructive) { confirmReset = true }
                }
            }
            .task { await appModel.commandHomeModel.loadAgenda() }
            .scrollContentBackground(.hidden)
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Settings")
            .confirmationDialog("Reset local preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset Preferences", role: .destructive) {
                    appModel.dependencies.preferenceSummaryStore.reset(accountID: nil)
                    appModel.commandHomeModel.clearDefaultCalendar()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears local preferences. Calendar events are not deleted.")
            }
        }
    }

    private var defaultCalendarBinding: Binding<String?> {
        Binding(
            get: { appModel.commandHomeModel.selectedCalendar?.id },
            set: { id in
                guard let id, let calendar = appModel.commandHomeModel.calendars.first(where: { $0.id == id }) else { return }
                appModel.commandHomeModel.selectCalendar(calendar)
            }
        )
    }
}

#Preview("Settings Light") {
    let app = AppModel(dependencies: .mock())
    return SettingsView(startSection: nil)
        .environmentObject(app)
        .preferredColorScheme(.light)
}

#Preview("Settings Dark") {
    let app = AppModel(dependencies: .mock())
    return SettingsView(startSection: nil)
        .environmentObject(app)
        .preferredColorScheme(.dark)
}

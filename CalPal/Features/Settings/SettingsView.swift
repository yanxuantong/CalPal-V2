import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var confirmReset = false
    @State private var didScrollToStartSection = false
    let startSection: SettingsSection?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    defaultCalendarSection
                        .id(SettingsSection.language)
                        .accessibilityIdentifier(SettingsSection.language.accessibilityIdentifier)
                    safetySection
                        .id(SettingsSection.automation)
                        .accessibilityIdentifier(SettingsSection.automation.accessibilityIdentifier)
                    readinessSection
                        .id(SettingsSection.diagnostics)
                        .accessibilityIdentifier(SettingsSection.diagnostics.accessibilityIdentifier)
                    localPreferencesSection
                        .id(SettingsSection.privacy)
                        .accessibilityIdentifier(SettingsSection.privacy.accessibilityIdentifier)
                }
                .task {
                    appModel.refreshCapabilities()
                    await appModel.commandHomeModel.loadAgenda()
                    scrollToStartSection(with: proxy)
                }
                .onAppear { scrollToStartSection(with: proxy) }
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
    }

    private var defaultCalendarSection: some View {
        Section(SettingsSection.language.title) {
            if writableCalendars.isEmpty {
                Label("No writable calendar available", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(CalPalTheme.Colors.warning)
                Text("Grant Calendar Full Access or enable a writable account to choose a default calendar.")
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            } else {
                ForEach(writableCalendars) { calendar in
                    Button { appModel.commandHomeModel.selectCalendar(calendar) } label: {
                        HStack(spacing: CalPalTheme.Spacing.md) {
                            Circle()
                                .fill(CalPalTheme.Colors.eventAccent(hex: calendar.colorHex, fallbackID: calendar.id))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                                Text(calendar.accountName)
                                    .font(.caption)
                                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if appModel.commandHomeModel.selectedCalendar?.id == calendar.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CalPalTheme.Colors.brandPrimary)
                                    .accessibilityLabel("Selected")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("defaultCalendar-\(calendar.id)")
                }
            }

            if let notice = appModel.commandHomeModel.calendarSelectionNotice {
                VStack(alignment: .leading, spacing: 3) {
                    Text(notice.title).font(.caption.bold())
                    Text(notice.message).font(.caption)
                }
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        }
    }

    private var safetySection: some View {
        Section(SettingsSection.automation.title) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Review")
                        .foregroundStyle(CalPalTheme.Colors.textPrimary)
                    Text("Modify, delete, recurring, and ambiguous changes require confirmation before EventKit is mutated.")
                        .font(.caption)
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                }
            } icon: {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(CalPalTheme.Colors.brandPrimary)
            }
            .accessibilityIdentifier("safetyModeAutoReview")
        }
    }

    private var readinessSection: some View {
        Section(SettingsSection.diagnostics.title) {
            ReadinessSummaryCard(summary: readinessSummary)
            ForEach(readinessItems) { item in
                ReadinessChecklistRow(item: item)
            }
            Button {
                appModel.refreshCapabilities()
                Task { await appModel.commandHomeModel.loadAgenda() }
            } label: {
                Label("Refresh Readiness", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("refreshReadiness")
            Text("Manual checks are completed during TestFlight or real-device review. CalPal stays in TestFlight-readiness until those are verified.")
                .font(.caption)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
        }
    }

    private var localPreferencesSection: some View {
        Section(SettingsSection.privacy.title) {
            Button("Reset Local Preferences", role: .destructive) { confirmReset = true }
        }
    }

    private var writableCalendars: [CalendarInfo] {
        appModel.commandHomeModel.calendars.filter(\.allowsContentModifications)
    }

    private var readinessItems: [ReadinessChecklistItem] {
        AppStoreReadinessChecklist.items(
            summary: appModel.capabilitySummary,
            writableCalendarCount: writableCalendars.count,
            selectedCalendar: appModel.commandHomeModel.selectedCalendar
        )
    }

    private var readinessSummary: ReadinessChecklistSummary {
        ReadinessChecklistSummary(items: readinessItems)
    }

    private func scrollToStartSection(with proxy: ScrollViewProxy) {
        guard let startSection, !didScrollToStartSection else { return }
        didScrollToStartSection = true
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(startSection, anchor: .top)
            }
        }
    }
}

struct ReadinessChecklistSummary: Equatable {
    let readyCount: Int
    let manualGateCount: Int
    let needsAttentionCount: Int

    init(items: [ReadinessChecklistItem]) {
        readyCount = items.filter { $0.state == .ready }.count
        manualGateCount = items.filter { $0.state == .manualGate }.count
        needsAttentionCount = items.filter { $0.state == .needsAttention }.count
    }

    var statusTitle: String {
        if needsAttentionCount > 0 { return "Readiness needs attention" }
        if manualGateCount > 0 { return "Manual release gates remain" }
        return "Automated readiness complete"
    }

    var detail: String {
        if needsAttentionCount > 0 {
            return "Resolve \(needsAttentionCount) item(s) and complete \(manualGateCount) manual gate(s) before App Store submission."
        }
        if manualGateCount > 0 {
            return "\(readyCount) automated item(s) are ready. Complete \(manualGateCount) manual gate(s) during TestFlight or real-device owner review before submission."
        }
        return "All listed readiness items are ready for this environment."
    }

    var iconName: String {
        if needsAttentionCount > 0 { return "exclamationmark.triangle.fill" }
        if manualGateCount > 0 { return "iphone.gen3" }
        return "checkmark.circle.fill"
    }

    var palette: CalPalTheme.ChipPalette {
        if needsAttentionCount > 0 { return CalPalTheme.Colors.warningChip }
        if manualGateCount > 0 { return CalPalTheme.Colors.aiChip }
        return CalPalTheme.Colors.successChip
    }
}

struct ReadinessChecklistItem: Identifiable, Equatable {
    enum State: String, Equatable {
        case ready = "Ready"
        case needsAttention = "Needs attention"
        case manualGate = "Manual gate"
    }

    var id: String
    var title: String
    var detail: String
    var state: State

    var iconName: String {
        switch state {
        case .ready: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .manualGate: return "iphone.gen3"
        }
    }

    var palette: CalPalTheme.ChipPalette {
        switch state {
        case .ready: return CalPalTheme.Colors.successChip
        case .needsAttention: return CalPalTheme.Colors.warningChip
        case .manualGate: return CalPalTheme.Colors.aiChip
        }
    }
}

enum AppStoreReadinessChecklist {
    static func items(summary: CapabilitySummary, writableCalendarCount: Int, selectedCalendar: CalendarInfo?) -> [ReadinessChecklistItem] {
        [
            ReadinessChecklistItem(
                id: "calendar-access",
                title: "Calendar access",
                detail: summary.calendar == .allowed ? "Full calendar access is available." : "Grant Full Access before real-device QA.",
                state: summary.calendar == .allowed ? .ready : .needsAttention
            ),
            ReadinessChecklistItem(
                id: "writable-calendar",
                title: "Writable calendar",
                detail: writableCalendarCount > 0 ? "New events can be written to \(selectedCalendar?.targetSummary ?? "an available calendar")." : "Enable at least one writable calendar.",
                state: writableCalendarCount > 0 ? .ready : .needsAttention
            ),
            ReadinessChecklistItem(
                id: "speech",
                title: "Voice command path",
                detail: summary.speech == .allowed ? "Speech recognition is authorized." : "Verify speech authorization and fallback behavior on device.",
                state: summary.speech == .allowed ? .ready : .manualGate
            ),
            ReadinessChecklistItem(
                id: "foundation-models",
                title: "Foundation Models route",
                detail: foundationModelsDetail(for: summary.model),
                state: foundationModelsState(for: summary.model)
            ),
            ReadinessChecklistItem(
                id: "deterministic-parser",
                title: "Deterministic parser fallback",
                detail: "English and Chinese parser coverage remains available when Apple Intelligence cannot generate.",
                state: .ready
            ),
            ReadinessChecklistItem(
                id: "privacy-manifest",
                title: "Privacy manifest",
                detail: "Bundled manifest declares local preference storage and no tracking domains.",
                state: .ready
            ),
            ReadinessChecklistItem(
                id: "calendar-open",
                title: "Open in Calendar",
                detail: "Verify the result action opens Apple Calendar near the event date on a real iPhone.",
                state: .manualGate
            ),
            ReadinessChecklistItem(
                id: "store-assets",
                title: "Store materials",
                detail: "Confirm screenshots, privacy answers, metadata, archive signing, and TestFlight notes.",
                state: .manualGate
            )
        ]
    }

    private static func foundationModelsState(for status: PermissionStatus) -> ReadinessChecklistItem.State {
        switch status {
        case .allowed:
            return .ready
        case .notDetermined, .unknown:
            return .manualGate
        case .unavailable, .denied, .restricted:
            return .needsAttention
        }
    }

    private static func foundationModelsDetail(for status: PermissionStatus) -> String {
        switch status {
        case .allowed:
            return "Apple Intelligence can be attempted before deterministic fallback."
        case .notDetermined:
            return "Apple Intelligence is not ready or not enabled; verify on an eligible device."
        case .unknown:
            return "Foundation Models availability is unknown; keep real-device smoke as a release gate."
        case .unavailable:
            return "This environment cannot run Foundation Models generation."
        case .denied, .restricted:
            return "Foundation Models are restricted in this environment."
        }
    }
}

private struct ReadinessSummaryCard: View {
    let summary: ReadinessChecklistSummary

    var body: some View {
        HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
            Image(systemName: summary.iconName)
                .foregroundStyle(summary.palette.foreground)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                HStack(spacing: CalPalTheme.Spacing.sm) {
                    Text("\(summary.readyCount) ready")
                        .quietChip(CalPalTheme.Colors.successChip)
                    Text("\(summary.manualGateCount) manual")
                        .quietChip(CalPalTheme.Colors.aiChip)
                    if summary.needsAttentionCount > 0 {
                        Text("\(summary.needsAttentionCount) attention")
                            .quietChip(CalPalTheme.Colors.warningChip)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("readinessSummary")
        .accessibilityLabel("\(summary.statusTitle). \(summary.detail)")
    }
}

private struct ReadinessChecklistRow: View {
    let item: ReadinessChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: CalPalTheme.Spacing.md) {
            Image(systemName: item.iconName)
                .foregroundStyle(item.palette.foreground)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .foregroundStyle(CalPalTheme.Colors.textPrimary)
                    Spacer()
                    Text(item.state.rawValue)
                        .quietChip(item.palette)
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.state.rawValue), \(item.detail)")
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

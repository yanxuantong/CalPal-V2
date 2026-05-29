import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            CommandHomeView()
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $appModel.activeSheet) { sheet in
            AppSheetHost(sheet: sheet)
                .environmentObject(appModel)
                .environmentObject(appModel.commandHomeModel)
        }
        .onAppear { appModel.presentOnboardingIfNeeded() }
        .task { await appModel.initializeRequiredPermissionsIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await appModel.refreshAfterReturningToForeground() }
            case .background:
                appModel.prepareForBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

struct AppSheetHost: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var homeModel: CommandHomeModel
    @Environment(\.openURL) private var openURL
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .onboarding:
            OnboardingView(onContinue: { appModel.completeOnboarding() })
                .presentationDetents([.large])
        case .textEntry:
            TextEntryView { text in
                appModel.dismissSheet()
                Task { await homeModel.submit(text: text) }
            }
            .presentationDetents([.large])
        case .correction(let context):
            CorrectionView(context: context) { draft in
                appModel.dismissSheet()
                Task { await homeModel.applyCorrectedDraft(draft, parseRoute: context.parseRoute) }
            }
            .presentationDetents([.large])
        case .confirmation(let context):
            ConfirmationView(context: context) { decision in
                appModel.dismissSheet()
                Task { await homeModel.resolveConfirmation(context, decision: decision) }
            }
            .presentationDetents([.large])
        case .candidateSelection(let context):
            CandidateSelectionView(context: context) { event in
                appModel.dismissSheet()
                homeModel.selectCandidate(event, for: context)
            }
            .presentationDetents([.large])
        case .calendarChooser(let context):
            CalendarChooserView(context: context) { calendar in
                appModel.dismissSheet()
                homeModel.selectCalendar(calendar)
            }
            .presentationDetents([.large])
        case .eventDetail(let context):
            EventDetailView(context: context) { patch in
                appModel.dismissSheet()
                homeModel.confirmUpdate(for: context.event, patch: patch)
            }
            .presentationDetents([.medium, .large])
        case .settings(let startSection):
            SettingsView(startSection: startSection)
                .presentationDetents([.large])
        case .modelUnavailable(let context), .speechUnavailable(let context):
            UnavailableView(context: context) { action in
                handleUnavailableAction(action)
            }
            .presentationDetents([.medium, .large])
        case .manualEventForm(let context):
            ManualEventFormView(context: context) { draft in
                appModel.dismissSheet()
                Task { await homeModel.applyCorrectedDraft(draft) }
            }
            .presentationDetents([.large])
        }
    }

    private func handleUnavailableAction(_ action: UnavailableAction) {
        appModel.dismissSheet()
        switch action {
        case .openSystemSettings:
            openURL(AppSettingsLink.url)
        case .openSettings:
            appModel.openSettings(.diagnostics)
        default:
            homeModel.handleUnavailableAction(action)
        }
    }
}

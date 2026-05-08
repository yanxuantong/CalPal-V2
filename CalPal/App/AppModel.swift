import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var activeSheet: AppSheet?
    @Published var capabilitySummary: CapabilitySummary

    let dependencies: DependencyContainer
    let commandHomeModel: CommandHomeModel
    private let onboardingKey = "calpal.hasSeenOnboarding"
    private let initializationKey = "calpal.hasRequestedInitialPermissions"
    private let defaults: UserDefaults
    private var isInitializingPermissions = false

    init(dependencies: DependencyContainer, defaults: UserDefaults = .standard) {
        self.dependencies = dependencies
        self.defaults = defaults
        self.capabilitySummary = dependencies.capabilityService.currentSummary()
        self.commandHomeModel = CommandHomeModel(dependencies: dependencies)
        self.commandHomeModel.sheetPresenter = { [weak self] sheet in self?.activeSheet = sheet }
    }

    func presentOnboardingIfNeeded() {
        guard !defaults.bool(forKey: onboardingKey), activeSheet == nil else { return }
        activeSheet = .onboarding
    }

    func initializeRequiredPermissionsIfNeeded() async {
        guard !isInitializingPermissions else { return }
        guard !defaults.bool(forKey: initializationKey) else {
            refreshCapabilities()
            if dependencies.calendarRepository.authorizationStatus() == .allowed { await commandHomeModel.loadAgenda() }
            return
        }
        isInitializingPermissions = true
        defer { isInitializingPermissions = false }

        _ = await dependencies.speechService.requestAuthorization()
        _ = await dependencies.calendarRepository.requestFullAccessIfNeeded()
        defaults.set(true, forKey: initializationKey)
        refreshCapabilities()
        if dependencies.calendarRepository.authorizationStatus() == .allowed { await commandHomeModel.loadAgenda() }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: onboardingKey)
        activeSheet = nil
        Task { await initializeRequiredPermissionsIfNeeded() }
    }

    func openSettings(_ section: SettingsSection? = nil) {
        refreshCapabilities()
        activeSheet = .settings(section)
    }
    func openTextEntry() { activeSheet = .textEntry(TextEntryContext()) }
    func dismissSheet() { activeSheet = nil }
    func refreshCapabilities() { capabilitySummary = dependencies.capabilityService.currentSummary() }
}

enum AppSheet: Identifiable, Equatable {
    case onboarding
    case textEntry(TextEntryContext)
    case correction(CorrectionContext)
    case confirmation(ConfirmationContext)
    case candidateSelection(CandidateSelectionContext)
    case calendarChooser(CalendarChooserContext)
    case settings(SettingsSection?)
    case modelUnavailable(UnavailableContext)
    case speechUnavailable(UnavailableContext)
    case manualEventForm(ManualEventContext)

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .textEntry: return "textEntry"
        case .correction(let context): return "correction-\(context.id)"
        case .confirmation(let context): return "confirmation-\(context.id)"
        case .candidateSelection(let context): return "candidate-\(context.id)"
        case .calendarChooser(let context): return "calendar-\(context.id)"
        case .settings(let section): return "settings-\(section?.rawValue ?? "root")"
        case .modelUnavailable(let context): return "model-\(context.id)"
        case .speechUnavailable(let context): return "speech-\(context.id)"
        case .manualEventForm(let context): return "manual-\(context.id)"
        }
    }
}

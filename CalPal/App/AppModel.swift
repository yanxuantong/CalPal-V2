import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var activeSheet: AppSheet?
    @Published var capabilitySummary: CapabilitySummary

    let dependencies: DependencyContainer
    let commandHomeModel: CommandHomeModel
    private let onboardingKey = "calpal.hasSeenOnboarding"
    private let calendarPermissionInitializationKey = "calpal.hasRequestedInitialCalendarPermission"
    private let defaults: UserDefaults
    private let runtime: AppRuntimeConfiguration
    private var isInitializingPermissions = false

    convenience init(dependencies: DependencyContainer, defaults: UserDefaults = .standard) {
        self.init(runtime: .test(dependencies: dependencies), defaults: defaults)
    }

    init(runtime: AppRuntimeConfiguration, defaults: UserDefaults = .standard) {
        self.runtime = runtime
        self.dependencies = runtime.dependencies
        self.defaults = defaults
        self.capabilitySummary = runtime.dependencies.capabilityService.currentSummary()
        self.commandHomeModel = CommandHomeModel(dependencies: runtime.dependencies)
        self.commandHomeModel.sheetPresenter = { [weak self] sheet in self?.activeSheet = sheet }
    }

    func presentOnboardingIfNeeded() {
        guard !runtime.skipsOnboarding else { return }
        guard !defaults.bool(forKey: onboardingKey), activeSheet == nil else { return }
        activeSheet = .onboarding
    }

    func initializeRequiredPermissionsIfNeeded() async {
        guard !isInitializingPermissions else { return }
        if runtime.skipsPermissionRequests {
            refreshCapabilities()
            if runtime.preloadsAgenda { await commandHomeModel.loadAgenda() }
            return
        }
        guard activeSheet != .onboarding else {
            refreshCapabilities()
            return
        }
        guard !defaults.bool(forKey: calendarPermissionInitializationKey) else {
            refreshCapabilities()
            if dependencies.calendarRepository.authorizationStatus() == .allowed { await commandHomeModel.loadAgenda() }
            return
        }
        isInitializingPermissions = true
        defer { isInitializingPermissions = false }

        _ = await dependencies.calendarRepository.requestFullAccessIfNeeded()
        defaults.set(true, forKey: calendarPermissionInitializationKey)
        refreshCapabilities()
        if dependencies.calendarRepository.authorizationStatus() == .allowed { await commandHomeModel.loadAgenda() }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: onboardingKey)
        activeSheet = nil
        Task { await initializeRequiredPermissionsIfNeeded() }
    }

    func refreshAfterReturningToForeground() async {
        refreshCapabilities()
        guard runtime.skipsOnboarding || activeSheet != .onboarding else { return }
        guard dependencies.calendarRepository.authorizationStatus() == .allowed else { return }
        await commandHomeModel.loadAgenda()
    }

    func openSettings(_ section: SettingsSection? = nil) {
        refreshCapabilities()
        activeSheet = .settings(section)
    }
    func openTextEntry() {
        commandHomeModel.hideCommandHint()
        activeSheet = .textEntry(TextEntryContext())
    }
    func dismissSheet() { activeSheet = nil }
    func refreshCapabilities() { capabilitySummary = dependencies.capabilityService.currentSummary() }
}

enum AppSettingsLink {
    static let url = URL(string: UIApplication.openSettingsURLString)!
}

enum AppSheet: Identifiable, Equatable {
    case onboarding
    case textEntry(TextEntryContext)
    case correction(CorrectionContext)
    case confirmation(ConfirmationContext)
    case candidateSelection(CandidateSelectionContext)
    case calendarChooser(CalendarChooserContext)
    case eventDetail(EventDetailContext)
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
        case .eventDetail(let context): return "event-\(context.event.id)-\(context.id)"
        case .settings(let section): return "settings-\(section?.rawValue ?? "root")"
        case .modelUnavailable(let context): return "model-\(context.id)"
        case .speechUnavailable(let context): return "speech-\(context.id)"
        case .manualEventForm(let context): return "manual-\(context.id)"
        }
    }
}

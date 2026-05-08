import Foundation

protocol CapabilityServiceProtocol { func currentSummary() -> CapabilitySummary }

struct DefaultCapabilityService: CapabilityServiceProtocol {
    var calendarRepository: CalendarRepositoryProtocol
    var speechService: SpeechServiceProtocol
    var modelProvider: ModelProviderProtocol

    func currentSummary() -> CapabilitySummary {
        CapabilitySummary(calendar: calendarRepository.authorizationStatus(), speech: speechService.authorizationStatus(), model: modelProvider.availability(), preferredLocales: ["en-US", "zh-Hans"], runsOnDevice: modelProvider.availability() == .allowed)
    }
}

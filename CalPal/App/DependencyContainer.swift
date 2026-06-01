import Foundation

struct DependencyContainer {
    var calendarRepository: CalendarRepositoryProtocol
    var commandPipeline: CalendarCommandPipelineProtocol
    var speechService: SpeechServiceProtocol
    var modelProvider: ModelProviderProtocol
    var preferenceSummaryStore: PreferenceSummaryStoreProtocol
    var capabilityService: CapabilityServiceProtocol
    var diagnosticsStore: ProductionDiagnosticsStoreProtocol = InMemoryProductionDiagnosticsStore()
    var privacyConfiguration: ProductionPrivacyConfiguration = .appStoreLocalOnly

    static var live: DependencyContainer {
        let calendarRepository = EventKitCalendarRepository()
        let modelProvider = LocalFoundationModelProvider()
        let prefs = UserDefaultsPreferenceSummaryStore()
        let diagnostics = UserDefaultsProductionDiagnosticsStore()
        let fallbackParser = NaturalLanguageCalendarParser()
        let parser = FoundationModelsCalendarParser(fallback: fallbackParser, modelProvider: modelProvider)
        let policy = CalendarMutationPolicy(preferredCalendarID: { prefs.loadDefaultCalendarID() })
        let pipeline = CalendarCommandPipeline(parser: parser, policy: policy, repository: calendarRepository)
        let speech = SystemSpeechService()
        let capability = DefaultCapabilityService(calendarRepository: calendarRepository, speechService: speech, modelProvider: modelProvider)
        return DependencyContainer(calendarRepository: calendarRepository, commandPipeline: pipeline, speechService: speech, modelProvider: modelProvider, preferenceSummaryStore: prefs, capabilityService: capability, diagnosticsStore: diagnostics, privacyConfiguration: .appStoreLocalOnly)
    }

    static func mock(now: Date = PreviewFixtures.now) -> DependencyContainer {
        let repo = MockCalendarRepository(now: now)
        let prefs = InMemoryPreferenceSummaryStore()
        let diagnostics = InMemoryProductionDiagnosticsStore()
        let parser = NaturalLanguageCalendarParser(now: { now })
        let policy = CalendarMutationPolicy(now: { now }, preferredCalendarID: { prefs.loadDefaultCalendarID() })
        let pipeline = CalendarCommandPipeline(parser: parser, policy: policy, repository: repo)
        let speech = MockSpeechService()
        let model = MockModelProvider()
        let capability = DefaultCapabilityService(calendarRepository: repo, speechService: speech, modelProvider: model)
        return DependencyContainer(calendarRepository: repo, commandPipeline: pipeline, speechService: speech, modelProvider: model, preferenceSummaryStore: prefs, capabilityService: capability, diagnosticsStore: diagnostics, privacyConfiguration: .appStoreLocalOnly)
    }
}

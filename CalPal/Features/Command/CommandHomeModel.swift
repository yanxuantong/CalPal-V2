import Foundation

@MainActor
final class CommandHomeModel: ObservableObject {
    @Published var selectedDay: Date
    @Published var agendaState: AgendaLoadingState = .idle
    @Published var events: [CalendarEvent] = []
    @Published var commandState: CommandInteractionState = .idle
    @Published var latestResult: CommandResultViewState?
    @Published var latestError: ErrorPresentation?
    @Published var calendars: [CalendarInfo] = []
    @Published var selectedCalendar: CalendarInfo?

    let dependencies: DependencyContainer
    var sheetPresenter: ((AppSheet) -> Void)?
    private let calendar = Calendar.autoupdatingCurrent
    private var resultDismissTask: Task<Void, Never>?
    private var recordingFinishTask: Task<Void, Never>?
    private var activeRecordingID: UUID?

    init(dependencies: DependencyContainer, selectedDay: Date = Date()) {
        self.dependencies = dependencies
        self.selectedDay = selectedDay
    }

    func loadAgenda() async {
        agendaState = .loading
        guard dependencies.calendarRepository.authorizationStatus() == .allowed else {
            agendaState = .denied(ErrorPresentation(title: "Connect Calendars", message: "Allow full calendar access when you are ready to show and update your agenda.", recovery: "Use a calendar command or manual create to trigger access."))
            return
        }
        do {
            async let calendarsTask = dependencies.calendarRepository.fetchCalendars()
            async let eventsTask = dependencies.calendarRepository.fetchEvents(for: selectedDay)
            calendars = try await calendarsTask
            selectedCalendar = preferredCalendar(from: calendars)
            events = try await eventsTask
            agendaState = .loaded
        } catch CalendarRepositoryError.accessDenied {
            agendaState = .denied(ErrorPresentation(title: "Calendar Access Needed", message: "Allow full calendar access to show and update your agenda.", recovery: "You can still use manual fallback once access is available."))
        } catch {
            agendaState = .failed(ErrorPresentation(title: "Could Not Load Agenda", message: error.localizedDescription, recovery: "Try again later."))
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = day
        Task { await loadAgenda() }
    }

    func beginRecording() {
        guard !commandState.isProcessing else { return }
        if case .recording = commandState { return }
        recordingFinishTask?.cancel()
        latestError = nil
        let recordingID = UUID()
        activeRecordingID = recordingID
        commandState = .recording(startedAt: Date())
        Task {
            let status = await dependencies.speechService.requestAuthorization()
            guard status == .allowed else {
                commandState = .failed(ErrorPresentation(title: "Speech Permission Needed", message: "Allow speech recognition to use press-and-hold voice commands.", recovery: "Double-tap the orb to type instead."))
                sheetPresenter?(.speechUnavailable(UnavailableContext(title: "Speech Permission Needed", message: "Speech recognition was not authorized. Text input remains available.", primaryAction: .openTextEntry, secondaryAction: .openManualCreate)))
                return
            }
            do {
                guard activeRecordingID == recordingID, case .recording = commandState else { return }
                let locale = Locale.preferredLanguages.first ?? "en-US"
                let supportedLocale = dependencies.speechService.supports(localeIdentifier: locale) ? locale : "en-US"
                try await dependencies.speechService.startTranscription(localeIdentifier: supportedLocale)
            } catch {
                guard activeRecordingID == recordingID else { return }
                commandState = .failed(ErrorPresentation(title: "Speech Unavailable", message: error.localizedDescription, recovery: "Double-tap the orb to type instead."))
                sheetPresenter?(.speechUnavailable(UnavailableContext(title: "Speech Unavailable", message: error.localizedDescription, primaryAction: .openTextEntry, secondaryAction: .openManualCreate)))
            }
        }
    }

    func finishRecording() {
        guard case .recording = commandState else { return }
        activeRecordingID = nil
        commandState = .transcribing(nil)
        recordingFinishTask?.cancel()
        recordingFinishTask = Task {
            do {
                let transcript = try await dependencies.speechService.finishTranscription()
                commandState = .transcribing(transcript)
                await submit(text: transcript)
            } catch {
                commandState = .failed(ErrorPresentation(title: "Speech Unavailable", message: error.localizedDescription, recovery: "Double-tap the orb to type, or create manually."))
                sheetPresenter?(.speechUnavailable(UnavailableContext(title: "Speech Unavailable", message: error.localizedDescription, primaryAction: .openTextEntry, secondaryAction: .openManualCreate)))
            }
        }
    }

    func cancelRecording() {
        activeRecordingID = nil
        recordingFinishTask?.cancel()
        dependencies.speechService.cancelTranscription()
        commandState = .idle
    }

    func submit(text: String) async {
        commandState = .parsing(text)
        let output = await dependencies.commandPipeline.process(text: text)
        await handle(output)
    }

    func applyCorrectedDraft(_ draft: EventDraft) async {
        commandState = .applying
        await handle(dependencies.commandPipeline.apply(draft: draft))
    }

    func resolveConfirmation(_ context: ConfirmationContext, decision: ConfirmationDecision) async {
        commandState = .applying
        await handle(dependencies.commandPipeline.confirm(context, decision: decision))
    }

    func selectCandidate(_ event: CalendarEvent, for context: CandidateSelectionContext) {
        sheetPresenter?(.confirmation(confirmationContext(for: event, selection: context)))
    }

    func selectCalendar(_ calendar: CalendarInfo) {
        guard calendar.allowsContentModifications else { return }
        selectedCalendar = calendar
        dependencies.preferenceSummaryStore.saveDefaultCalendarID(calendar.id)
    }

    func clearDefaultCalendar() {
        dependencies.preferenceSummaryStore.saveDefaultCalendarID(nil)
        selectedCalendar = calendars.first(where: { $0.allowsContentModifications })
    }

    func openCalendarChooser() { sheetPresenter?(.calendarChooser(CalendarChooserContext(calendars: calendars, selectedID: selectedCalendar?.id))) }

    func openManualCreate(reason: String = "Create the event manually.") {
        let start = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        sheetPresenter?(.manualEventForm(ManualEventContext(reason: reason, draft: EventDraft(title: "", startDate: start, endDate: start.addingTimeInterval(3600), calendarID: selectedCalendar?.id, calendarName: selectedCalendar?.title, location: nil, notes: nil))))
    }

    func handleUnavailableAction(_ action: UnavailableAction) {
        switch action {
        case .openManualCreate: openManualCreate(reason: "Fallback manual create")
        case .openTextEntry: sheetPresenter?(.textEntry(TextEntryContext()))
        case .openSettings: sheetPresenter?(.settings(.diagnostics))
        case .dismiss: break
        }
    }

    func cancelProcessing() { commandState = .idle }

    private func handle(_ output: CalendarCommandPipelineOutput) async {
        switch output {
        case .result(let result):
            latestError = nil
            latestResult = result
            commandState = .completed(result)
            scheduleResultDismissal()
            await loadAgenda()
        case .correction(let context):
            commandState = .idle
            sheetPresenter?(.correction(context))
        case .confirmation(let context):
            commandState = .idle
            sheetPresenter?(.confirmation(context))
        case .candidateSelection(let context):
            commandState = .idle
            sheetPresenter?(.candidateSelection(context))
        case .calendarChooser(let context):
            commandState = .idle
            sheetPresenter?(.calendarChooser(context))
        case .unavailable(let context):
            commandState = .failed(ErrorPresentation(title: context.title, message: context.message, recovery: context.primaryAction.title))
            sheetPresenter?(.modelUnavailable(context))
        case .failure(let error):
            latestResult = nil
            latestError = error
            commandState = .failed(error)
        }
    }

    func dismissLatestResult() {
        resultDismissTask?.cancel()
        latestResult = nil
    }

    private func scheduleResultDismissal() {
        resultDismissTask?.cancel()
        resultDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.latestResult = nil }
        }
    }

    private func preferredCalendar(from calendars: [CalendarInfo]) -> CalendarInfo? {
        let preferredID = dependencies.preferenceSummaryStore.loadDefaultCalendarID()
        return calendars.first { $0.id == preferredID && $0.allowsContentModifications }
            ?? calendars.first(where: { $0.allowsContentModifications })
    }

    private func confirmationContext(for event: CalendarEvent, selection: CandidateSelectionContext) -> ConfirmationContext {
        ConfirmationContext(
            operation: selection.operation,
            title: selection.operation == .delete ? "Delete Event?" : "Review Change",
            message: event.isRecurring ? "This is a repeating event. Choose the recurrence scope before applying." : "Confirm before changing your calendar.",
            before: event,
            afterDraft: nil,
            patch: selection.patch,
            targetEventID: event.id,
            recurrenceScope: event.isRecurring ? .thisEvent : nil
        )
    }
}

enum AgendaLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case denied(ErrorPresentation)
    case failed(ErrorPresentation)
}

enum CommandInteractionState: Equatable {
    case idle
    case recording(startedAt: Date)
    case transcribing(String?)
    case parsing(String)
    case applying
    case completed(CommandResultViewState)
    case failed(ErrorPresentation)

    var isProcessing: Bool {
        if case .transcribing = self { return true }
        if case .parsing = self { return true }
        if case .applying = self { return true }
        return false
    }
}

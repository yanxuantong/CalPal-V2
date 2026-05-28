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
    @Published var calendarSelectionNotice: CalendarSelectionNotice?
    @Published var showsCommandHint = true

    let dependencies: DependencyContainer
    var sheetPresenter: ((AppSheet) -> Void)?
    private let calendar = Calendar.autoupdatingCurrent
    private let now: () -> Date
    private var resultDismissTask: Task<Void, Never>?
    private var recordingFinishTask: Task<Void, Never>?
    private var activeRecordingID: UUID?
    private var agendaLoadGeneration = 0
    private var commandGeneration = 0

    init(dependencies: DependencyContainer, selectedDay: Date = Date(), now: @escaping () -> Date = Date.init) {
        self.dependencies = dependencies
        self.selectedDay = selectedDay
        self.now = now
    }

    func loadAgenda() async {
        let requestID = nextAgendaLoadGeneration()
        let requestedDay = selectedDay
        agendaState = .loading
        guard dependencies.calendarRepository.authorizationStatus() == .allowed else {
            guard isCurrentAgendaLoad(requestID) else { return }
            agendaState = .denied(ErrorPresentation(title: "Connect Calendars", message: "Allow full calendar access when you are ready to show and update your agenda.", recovery: "Open iOS Settings to grant Calendar access, then try again."))
            return
        }
        do {
            async let calendarsTask = dependencies.calendarRepository.fetchCalendars()
            async let eventsTask = dependencies.calendarRepository.fetchEvents(for: requestedDay)
            let fetchedCalendars = try await calendarsTask
            let fetchedEvents = try await eventsTask
            guard isCurrentAgendaLoad(requestID) else { return }
            calendars = fetchedCalendars
            selectedCalendar = reconcileSelectedCalendar(from: fetchedCalendars)
            events = fetchedEvents
            agendaState = .loaded
        } catch CalendarRepositoryError.accessDenied {
            guard isCurrentAgendaLoad(requestID) else { return }
            agendaState = .denied(ErrorPresentation(title: "Calendar Access Needed", message: "Allow full calendar access to show and update your agenda.", recovery: "Open iOS Settings to grant Calendar access, then try again."))
        } catch {
            guard isCurrentAgendaLoad(requestID) else { return }
            agendaState = .failed(ErrorPresentation(title: "Could Not Load Agenda", message: error.localizedDescription, recovery: "Try again later."))
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = day
        Task { await loadAgenda() }
    }

    func selectToday() {
        let today = now()
        guard !calendar.isDate(selectedDay, inSameDayAs: today) else { return }
        selectDay(today)
    }

    var isSelectedDayToday: Bool {
        calendar.isDate(selectedDay, inSameDayAs: now())
    }

    func hideCommandHint() {
        showsCommandHint = false
    }

    func beginRecording() {
        guard !commandState.isProcessing else { return }
        if case .recording = commandState { return }
        hideCommandHint()
        recordingFinishTask?.cancel()
        latestError = nil
        let recordingID = UUID()
        activeRecordingID = recordingID
        commandState = .recording(startedAt: Date())
        Task {
            let status = await dependencies.speechService.requestAuthorization()
            guard status == .allowed else {
                commandState = .failed(ErrorPresentation(title: "Speech Permission Needed", message: "Allow speech recognition to use voice commands.", recovery: "Double-tap the orb to type instead."))
                sheetPresenter?(.speechUnavailable(UnavailableContext(title: "Speech Permission Needed", message: "Speech recognition was not authorized. Text input remains available.", primaryAction: .openTextEntry, secondaryAction: .openSystemSettings)))
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
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            let error = ErrorPresentation(
                title: "Command Needed",
                message: "Type or say what you want CalPal to schedule.",
                recovery: "Try a short command like \"Coffee tomorrow at noon\" or create manually."
            )
            latestResult = nil
            latestError = error
            commandState = .failed(error)
            return
        }
        let requestID = nextCommandGeneration()
        commandState = .parsing(trimmedText)
        let output = await dependencies.commandPipeline.process(text: trimmedText)
        guard isCurrentCommand(requestID) else { return }
        await handle(output)
    }

    func applyCorrectedDraft(_ draft: EventDraft, parseRoute: CalendarParseRoute? = nil) async {
        let requestID = nextCommandGeneration()
        commandState = .applying
        let output = await dependencies.commandPipeline.apply(draft: draft).annotatingResult(parseRoute: parseRoute)
        guard isCurrentCommand(requestID) else { return }
        await handle(output)
    }

    func resolveConfirmation(_ context: ConfirmationContext, decision: ConfirmationDecision) async {
        guard case .confirm = decision else {
            latestError = nil
            commandState = .idle
            return
        }
        let requestID = nextCommandGeneration()
        commandState = .applying
        let output = await dependencies.commandPipeline.confirm(context, decision: decision)
        guard isCurrentCommand(requestID) else { return }
        await handle(output)
    }

    func selectCandidate(_ event: CalendarEvent, for context: CandidateSelectionContext) {
        sheetPresenter?(.confirmation(confirmationContext(for: event, selection: context)))
    }

    func selectCalendar(_ calendar: CalendarInfo) {
        guard calendar.allowsContentModifications else { return }
        selectedCalendar = calendar
        dependencies.preferenceSummaryStore.saveDefaultCalendarID(calendar.id)
        calendarSelectionNotice = CalendarSelectionNotice(
            title: "Default calendar saved",
            message: "New events will be written to \(calendar.title) · \(calendar.accountName)."
        )
    }

    func clearDefaultCalendar() {
        dependencies.preferenceSummaryStore.saveDefaultCalendarID(nil)
        selectedCalendar = calendars.first(where: { $0.allowsContentModifications })
        calendarSelectionNotice = nil
    }

    func openCalendarChooser() { sheetPresenter?(.calendarChooser(CalendarChooserContext(calendars: calendars, selectedID: selectedCalendar?.id))) }

    func openEventDetail(_ event: CalendarEvent) {
        sheetPresenter?(.eventDetail(EventDetailContext(event: event)))
    }

    func confirmUpdate(for event: CalendarEvent, patch: EventPatch) {
        guard patch.hasChanges else { return }
        sheetPresenter?(.confirmation(ConfirmationContext(
            operation: .modify,
            title: "Update Event?",
            message: "Review before changing this existing calendar event.",
            before: event,
            afterDraft: nil,
            patch: patch,
            targetEventID: event.id,
            recurrenceScope: event.isRecurring ? .thisEvent : nil,
            parseRoute: nil
        )))
    }

    func openManualCreate(reason: String = "Create the event manually.") {
        let start = calendar.date(byAdding: .hour, value: 1, to: now()) ?? now().addingTimeInterval(3600)
        sheetPresenter?(.manualEventForm(ManualEventContext(reason: reason, draft: EventDraft(title: "", startDate: start, endDate: start.addingTimeInterval(3600), calendarID: selectedCalendar?.id, calendarName: selectedCalendar?.title, location: nil, notes: nil))))
    }

    func handleUnavailableAction(_ action: UnavailableAction) {
        switch action {
        case .openManualCreate: openManualCreate(reason: "Fallback manual create")
        case .openTextEntry: sheetPresenter?(.textEntry(TextEntryContext()))
        case .openSettings: sheetPresenter?(.settings(.diagnostics))
        case .openSystemSettings: break
        case .dismiss: break
        }
    }

    func cancelProcessing() {
        commandGeneration += 1
        commandState = .idle
    }

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

    func focusLatestResultDate() {
        resultDismissTask?.cancel()
        guard let event = latestResult?.event else {
            latestResult = nil
            return
        }
        latestResult = nil
        guard !calendar.isDate(selectedDay, inSameDayAs: event.startDate) else { return }
        selectedDay = event.startDate
        Task { await loadAgenda() }
    }

    private func scheduleResultDismissal() {
        resultDismissTask?.cancel()
        resultDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.latestResult = nil }
        }
    }

    private func nextAgendaLoadGeneration() -> Int {
        agendaLoadGeneration += 1
        return agendaLoadGeneration
    }

    private func isCurrentAgendaLoad(_ generation: Int) -> Bool {
        generation == agendaLoadGeneration
    }

    private func nextCommandGeneration() -> Int {
        commandGeneration += 1
        return commandGeneration
    }

    private func isCurrentCommand(_ generation: Int) -> Bool {
        generation == commandGeneration
    }

    private func reconcileSelectedCalendar(from calendars: [CalendarInfo]) -> CalendarInfo? {
        let preferredID = dependencies.preferenceSummaryStore.loadDefaultCalendarID()
        let writableCalendars = calendars.filter(\.allowsContentModifications)

        if let preferredID, let preferred = writableCalendars.first(where: { $0.id == preferredID }) {
            if calendarSelectionNotice?.title == "Default calendar needs attention" {
                calendarSelectionNotice = nil
            }
            return preferred
        }

        guard let fallback = writableCalendars.first else {
            selectedCalendar = nil
            calendarSelectionNotice = CalendarSelectionNotice(
                title: "No writable calendar",
                message: "CalPal can read your calendars, but none can accept new or updated events."
            )
            return nil
        }

        if preferredID != nil {
            dependencies.preferenceSummaryStore.saveDefaultCalendarID(fallback.id)
            calendarSelectionNotice = CalendarSelectionNotice(
                title: "Default calendar needs attention",
                message: "The saved calendar is unavailable or read-only. CalPal is using \(fallback.title) · \(fallback.accountName)."
            )
        }
        return fallback
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
            recurrenceScope: event.isRecurring ? .thisEvent : nil,
            parseRoute: selection.parseRoute
        )
    }
}

private extension CalendarCommandPipelineOutput {
    func annotatingResult(parseRoute: CalendarParseRoute?) -> CalendarCommandPipelineOutput {
        guard let parseRoute, case .result(var result) = self else { return self }
        result.parseRoute = parseRoute
        return .result(result)
    }
}

struct CalendarSelectionNotice: Equatable {
    var title: String
    var message: String
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

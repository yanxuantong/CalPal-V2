import SwiftUI

struct CommandHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var model: CommandHomeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .bottom) {
            CalPalTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
                header
                DailyAgendaPager(selectedDay: model.selectedDay, events: model.events, state: model.agendaState, onSelectEvent: model.openEventDetail, onManualCreate: {
                    model.openManualCreate(reason: "Create an event from an empty agenda.")
                }, onRetryAgenda: {
                    Task { await model.loadAgenda() }
                }, onOpenSettings: {
                    openURL(AppSettingsLink.url)
                }) { day in
                    model.selectDay(day)
                }
            }
            .padding(.horizontal, CalPalTheme.Spacing.lg)
            .padding(.top, CalPalTheme.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(alignment: .trailing, spacing: CalPalTheme.Spacing.sm) {
                if let result = model.latestResult {
                    ResultCard(result: result) { url in
                        openURL(url)
                    }
                        .onTapGesture { model.focusLatestResultDate() }
                }
                if let error = model.latestError { FailureCard(error: error) }
                if model.commandState.isProcessing { ProcessingCard(state: model.commandState, onCancel: model.cancelProcessing) }
                CommandOrb(state: model.commandState, reduceMotion: reduceMotion, showsIdleHint: model.showsCommandHint && model.events.isEmpty, onRecordingStart: model.beginRecording, onRecordingFinish: model.finishRecording, onDoubleTap: {
                    model.hideCommandHint()
                    appModel.openTextEntry()
                }, onCancel: model.cancelRecording)
                    .frame(width: CommandOrb.touchFieldSize)
                    .padding(.bottom, CalPalTheme.Spacing.lg)
            }
            .padding(.horizontal, CalPalTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: CalPalTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text("CalPal")
                    .font(.headline.bold())
                    .foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(model.selectedDay.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("CalPal, selected date \(model.selectedDay.formatted(date: .complete, time: .omitted))")

            Spacer(minLength: CalPalTheme.Spacing.sm)

            if !model.isSelectedDayToday {
                Button { model.selectToday() } label: {
                    Label(todayButtonTitle, systemImage: "calendar")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(CalPalTheme.Colors.brandPrimary)
                .accessibilityLabel(todayButtonAccessibilityLabel)
            }

            Button { appModel.openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Settings")
        }
        .padding(.vertical, CalPalTheme.Spacing.xs)
    }

    private var todayButtonTitle: String {
        Locale.current.language.languageCode?.identifier == "zh" ? "回到今天" : "Back to Today"
    }

    private var todayButtonAccessibilityLabel: String {
        Locale.current.language.languageCode?.identifier == "zh" ? "回到今天" : "Return to today"
    }
}

#Preview("Command Home Light") {
    let app = AppModel(dependencies: .mock())
    return NavigationStack { CommandHomeView().environmentObject(app).environmentObject(app.commandHomeModel) }
        .preferredColorScheme(.light)
}

#Preview("Command Home Dark") {
    let app = AppModel(dependencies: .mock())
    return NavigationStack { CommandHomeView().environmentObject(app).environmentObject(app.commandHomeModel) }
        .preferredColorScheme(.dark)
}

#Preview("Command Home Non-Today") {
    let app = AppModel(dependencies: .mock())
    app.commandHomeModel.selectedDay = Calendar.current.date(byAdding: .day, value: 2, to: PreviewFixtures.now) ?? PreviewFixtures.now
    return NavigationStack { CommandHomeView().environmentObject(app).environmentObject(app.commandHomeModel) }
        .preferredColorScheme(.light)
}

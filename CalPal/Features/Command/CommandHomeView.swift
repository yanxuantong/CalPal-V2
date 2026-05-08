import SwiftUI

struct CommandHomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var model: CommandHomeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            CalPalTheme.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.lg) {
                header
                DailyAgendaPager(selectedDay: model.selectedDay, events: model.events, state: model.agendaState) { day in
                    model.selectDay(day)
                }
            }
            .padding(.horizontal, CalPalTheme.Spacing.lg)
            .padding(.top, CalPalTheme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(spacing: CalPalTheme.Spacing.sm) {
                if let result = model.latestResult {
                    ResultCard(result: result)
                        .onTapGesture { model.dismissLatestResult() }
                }
                if let error = model.latestError { FailureCard(error: error) }
                if model.commandState.isProcessing { ProcessingCard(onCancel: model.cancelProcessing) }
                CommandOrb(state: model.commandState, reduceMotion: reduceMotion, onHoldStart: model.beginRecording, onHoldEnd: model.finishRecording, onDoubleTap: appModel.openTextEntry, onCancel: model.cancelRecording)
                    .padding(.bottom, CalPalTheme.Spacing.lg)
            }
            .padding(.horizontal, CalPalTheme.Spacing.lg)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { appModel.openSettings() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CalPal")
                .font(.largeTitle.bold())
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            Text(model.selectedDay.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
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

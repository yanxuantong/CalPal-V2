import SwiftUI

struct CommandOrb: View {
    let state: CommandInteractionState
    let reduceMotion: Bool
    let showsIdleHint: Bool
    let onRecordingStart: () -> Void
    let onRecordingFinish: () -> Void
    let onDoubleTap: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var singleTapTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: CalPalTheme.Spacing.xs) {
            ZStack {
                orb
                if isRecording {
                    cancelButton
                        .offset(x: 46)
                        .transition(.opacity)
                }
            }
            .frame(width: Self.touchFieldSize, height: Self.touchFieldSize)
            Text(statusText ?? " ")
                .font(.caption2)
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
                .opacity(statusText == nil ? 0 : 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: statusText)
    }

    private var orb: some View {
        Button(action: handleSingleTap) {
            ZStack {
                if isRecording && !reduceMotion { RecordingRippleView() }
                Circle()
                    .fill(orbFill)
                    .frame(width: Self.orbDiameter, height: Self.orbDiameter)
                    .shadow(color: shadowColor, radius: isRecording ? 24 : 20, x: 0, y: 10)
                    .overlay(label)
                    .overlay(Circle().stroke(Color.white.opacity(reduceTransparency ? 0 : 0.24), lineWidth: 1))
                    .scaleEffect(orbScale)
                    .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.72), value: isRecording)
            }
            .frame(width: Self.touchFieldSize, height: Self.touchFieldSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: Self.touchFieldSize, height: Self.touchFieldSize)
        .simultaneousGesture(TapGesture(count: 2).onEnded(handleDoubleTap))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction(named: "Type command", onDoubleTap)
        .modifier(RecordingCancelAccessibilityAction(isRecording: isRecording, onCancel: onCancel))
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Label("Cancel", systemImage: "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(CalPalTheme.Colors.destructive)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        }
        .accessibilityLabel("Cancel recording")
    }

    private func handleSingleTap() {
        singleTapTask?.cancel()
        singleTapTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isRecording {
                    onRecordingFinish()
                } else if !isProcessing {
                    onRecordingStart()
                }
            }
        }
    }

    private func handleDoubleTap() {
        singleTapTask?.cancel()
        if isRecording {
            onCancel()
        }
        onDoubleTap()
    }

    static let touchFieldSize: CGFloat = 96
    static let orbDiameter: CGFloat = 60

    private var isRecording: Bool { if case .recording = state { return true }; return false }
    private var isProcessing: Bool { state.isProcessing }
    private var orbScale: CGFloat {
        if reduceMotion { return 1 }
        return isRecording ? 1.04 : 1
    }
    private var shadowColor: Color { (isRecording ? CalPalTheme.Colors.recording : CalPalTheme.Colors.brandPrimary).opacity(reduceTransparency ? 0.18 : 0.36) }

    private var orbFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(isRecording ? CalPalTheme.Colors.recording : CalPalTheme.Colors.brandPrimary)
        }
        if isRecording {
            return AnyShapeStyle(RadialGradient(colors: [CalPalTheme.Colors.recording.opacity(0.78), CalPalTheme.Colors.recording], center: .topLeading, startRadius: 8, endRadius: 82))
        }
        return AnyShapeStyle(CalPalTheme.Colors.brandGradient)
    }

    private var label: some View {
        VStack(spacing: 2) {
            Image(systemName: isRecording ? "waveform" : (isProcessing ? "hourglass" : "mic.fill"))
                .font(.title2.bold())
            Text(isRecording ? "Rec" : (isProcessing ? "…" : "mic"))
                .font(.caption.bold())
        }
        .foregroundStyle(Color.white)
    }

    private var statusText: String? {
        if isRecording { return "Tap again to finish · Cancel available" }
        if isProcessing { return "Processing calendar command" }
        return showsIdleHint ? "Tap to speak · double-tap to type" : nil
    }

    private var accessibilityLabel: String {
        if isRecording { return "Recording calendar command" }
        if isProcessing { return "Processing calendar command" }
        return "Calendar command button"
    }

    private var accessibilityHint: String {
        if isRecording { return "Tap again to process. Use Cancel recording to stop." }
        if isProcessing { return "Calendar command is being processed." }
        return "Tap to start recording. Double-tap to type."
    }
}

private struct RecordingCancelAccessibilityAction: ViewModifier {
    let isRecording: Bool
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        if isRecording {
            content.accessibilityAction(named: "Cancel recording", onCancel)
        } else {
            content
        }
    }
}

struct RecordingRippleView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(CalPalTheme.Colors.recording.opacity(0.25), lineWidth: 2)
                    .frame(width: 110 + CGFloat(i * 34), height: 110 + CGFloat(i * 34))
                    .scaleEffect(animate ? 1.12 : 0.82)
                    .opacity(animate ? 0.15 : 0.55)
                    .animation(.easeInOut(duration: 1.2).repeatForever().delay(Double(i) * 0.16), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

#Preview("Orb Recording Light") {
    CommandOrb(state: .recording(startedAt: Date()), reduceMotion: false, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {})
        .padding()
        .background(CalPalTheme.Colors.backgroundPrimary)
        .preferredColorScheme(.light)
}

#Preview("Orb Recording Dark") {
    CommandOrb(state: .recording(startedAt: Date()), reduceMotion: false, showsIdleHint: true, onRecordingStart: {}, onRecordingFinish: {}, onDoubleTap: {}, onCancel: {})
        .padding()
        .background(CalPalTheme.Colors.backgroundPrimary)
        .preferredColorScheme(.dark)
}

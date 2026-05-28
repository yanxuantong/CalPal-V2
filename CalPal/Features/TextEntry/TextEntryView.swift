import SwiftUI

struct TextEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var text = ""
    @State private var isSubmitting = false
    let onSubmit: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CalPalTheme.Spacing.lg) {
                    Text("Type a calendar command")
                        .font(.title2.bold())
                        .foregroundStyle(CalPalTheme.Colors.textPrimary)
                    Text("Use natural English or Chinese. CalPal will ask before risky changes.")
                        .font(.callout)
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                    TextField("What should I schedule?", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4...8)
                        .focused($inputFocused)
                        .accessibilityLabel("Calendar command text")
                        .accessibilityIdentifier("calendarCommandTextField")
                    TextCommandReadinessHint(state: sendReadiness)
                    Button(action: submit) {
                        Label("Send Command", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!sendReadiness.canSend)
                    .accessibilityIdentifier("textCommandSend")
                    exampleChips
                }
                .padding()
            }
            .background(CalPalTheme.Colors.backgroundPrimary)
            .navigationTitle("Text Command")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { submit() }
                        .disabled(!sendReadiness.canSend)
                        .accessibilityIdentifier("textCommandToolbarSend")
                }
            }
            .onAppear { inputFocused = true }
        }
    }

    private var exampleChips: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Text("Examples")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CalPalTheme.Colors.textSecondary)
            FlowLikeChips(examples: ["Meeting with Alex tomorrow at 3 PM", "明天下午三点和 Alex 开会"]) { example in
                text = example
                inputFocused = true
            }
        }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var sendReadiness: TextCommandReadiness {
        TextCommandReadiness(text: text, isSubmitting: isSubmitting)
    }

    private func submit() {
        guard sendReadiness.canSend else { return }
        isSubmitting = true
        onSubmit(trimmedText)
    }
}

struct TextCommandReadiness: Equatable {
    enum Status: Equatable {
        case empty
        case sending
        case ready
    }

    var status: Status

    init(text: String, isSubmitting: Bool = false) {
        if isSubmitting {
            status = .sending
        } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .empty
        } else {
            status = .ready
        }
    }

    var canSend: Bool {
        status == .ready
    }

    var message: String {
        switch status {
        case .empty:
            return "Type a command before sending."
        case .sending:
            return "Sending command..."
        case .ready:
            return "Ready to send."
        }
    }

    var systemImage: String {
        switch status {
        case .empty:
            return "keyboard"
        case .sending:
            return "paperplane"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    var palette: CalPalTheme.ChipPalette {
        switch status {
        case .empty:
            return CalPalTheme.Colors.warningChip
        case .sending:
            return CalPalTheme.Colors.aiChip
        case .ready:
            return CalPalTheme.Colors.successChip
        }
    }
}

private struct TextCommandReadinessHint: View {
    let state: TextCommandReadiness

    var body: some View {
        Label(state.message, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .quietChip(state.palette)
            .accessibilityIdentifier("textCommandReadinessHint")
    }
}

struct FlowLikeChips: View {
    let examples: [String]
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            ForEach(examples, id: \.self) { example in
                Button { onPick(example) } label: {
                    Text(example)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .quietChip(CalPalTheme.Colors.aiChip)
                .accessibilityHint("Insert example command")
            }
        }
    }
}

#Preview("Text Entry Light") {
    TextEntryView { _ in }
        .preferredColorScheme(.light)
}

#Preview("Text Entry Dark") {
    TextEntryView { _ in }
        .preferredColorScheme(.dark)
}

import SwiftUI

struct TextEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var text = ""
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
                    Button(action: submit) {
                        Label("Send Command", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(trimmedText.isEmpty)
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
                        .disabled(trimmedText.isEmpty)
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
    private func submit() { onSubmit(trimmedText) }
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

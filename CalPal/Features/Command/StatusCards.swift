import SwiftUI

struct CapabilityStatusBar: View {
    let summary: CapabilitySummary
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CalPalTheme.Spacing.sm) {
                CapabilityBadge(title: "Calendar", status: summary.calendar)
                CapabilityBadge(title: "AI Local", status: summary.model)
                CapabilityBadge(title: "Speech", status: summary.speech)
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Capabilities: calendar \(summary.calendar.rawValue), AI \(summary.model.rawValue), speech \(summary.speech.rawValue)")
    }
}

struct CapabilityBadge: View {
    let title: String
    let status: PermissionStatus
    var body: some View {
        Label(title, systemImage: icon)
            .quietChip(palette)
    }
    private var icon: String { status == .allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill" }
    private var palette: CalPalTheme.ChipPalette {
        switch status {
        case .allowed: return title == "AI Local" ? CalPalTheme.Colors.aiChip : CalPalTheme.Colors.successChip
        case .unknown, .notDetermined, .unavailable: return CalPalTheme.Colors.warningChip
        case .denied, .restricted: return CalPalTheme.Colors.destructiveChip
        }
    }
}

struct ProcessingCard: View {
    let state: CommandInteractionState
    let onCancel: () -> Void
    var body: some View {
        HStack(spacing: CalPalTheme.Spacing.md) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(CalPalTheme.Colors.textPrimary)
                Text(detail).font(.caption).foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
            Spacer()
            Button("Cancel", action: onCancel).buttonStyle(.bordered)
        }
        .padding()
        .glassCard()
        .accessibilityLabel("Processing calendar command. Cancel processing available.")
    }

    private var title: String {
        switch state {
        case .transcribing:
            return "Finishing transcript…"
        case .parsing:
            return "Understanding command…"
        case .applying:
            return "Updating calendar…"
        default:
            return "Checking calendar…"
        }
    }

    private var detail: String {
        switch state {
        case .transcribing(let transcript):
            return transcript == nil ? "Waiting for speech recognition" : "Preparing the recognized command"
        case .parsing:
            return "Using Apple Intelligence when available, with local fallback"
        case .applying:
            return "Saving through EventKit"
        default:
            return "Taking longer than usual"
        }
    }
}

struct ResultCard: View {
    let result: CommandResultViewState
    var onAction: ((URL) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(result.title, systemImage: "checkmark.circle.fill")
                .quietChip(CalPalTheme.Colors.successChip)
            Text(result.message)
                .font(.subheadline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            if let actionTitle = result.actionTitle {
                if let actionURL = result.actionURL, let onAction {
                    Button {
                        onAction(actionURL)
                    } label: {
                        Label(actionTitle, systemImage: "calendar")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("resultOpenInCalendar")
                } else {
                    Label(actionTitle, systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CalPalTheme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
    }
}

struct FailureCard: View {
    let error: ErrorPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Label(error.title, systemImage: "exclamationmark.triangle.fill")
                .quietChip(CalPalTheme.Colors.warningChip)
            Text(error.message)
                .font(.subheadline)
                .foregroundStyle(CalPalTheme.Colors.textPrimary)
            if let recovery = error.recovery {
                Text(recovery)
                    .font(.caption)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

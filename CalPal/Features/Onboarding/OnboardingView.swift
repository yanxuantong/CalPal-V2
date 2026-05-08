import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.xl) {
            Spacer()
            Image(systemName: "calendar.badge.sparkles").font(.system(size: 56)).foregroundStyle(CalPalTheme.Colors.brandGradient)
            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
                Text("CalPal").font(.largeTitle.bold())
                Text("Your private calendar assistant").font(.title3).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.md) {
                PrivacyPrincipleRow(icon: "calendar", text: "Uses your existing calendars")
                PrivacyPrincipleRow(icon: "mic.fill", text: "Understands voice or text")
                PrivacyPrincipleRow(icon: "lock.shield", text: "Processes on device when available")
                PrivacyPrincipleRow(icon: "internaldrive", text: "Stores lightweight local preferences")
            }
            Text("Modify/delete actions are reviewed before changing your calendar.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Continue", action: onContinue).buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
        }
        .padding(24)
    }
}

struct PrivacyPrincipleRow: View {
    let icon: String
    let text: String
    var body: some View {
        Label(text, systemImage: icon).font(.headline)
    }
}

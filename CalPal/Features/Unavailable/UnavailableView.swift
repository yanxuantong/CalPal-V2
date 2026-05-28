import SwiftUI

struct UnavailableView: View {
    let context: UnavailableContext
    let onAction: (UnavailableAction) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CalPalTheme.Spacing.lg) {
                Label(context.title, systemImage: "exclamationmark.triangle.fill")
                    .quietChip(CalPalTheme.Colors.warningChip)
                Text(context.message)
                    .font(.callout)
                    .foregroundStyle(CalPalTheme.Colors.textSecondary)
                actionButtons
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: CalPalTheme.Spacing.sm) }
        .background(CalPalTheme.Colors.backgroundPrimary)
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: CalPalTheme.Spacing.sm) {
            Button { onAction(context.primaryAction) } label: {
                Label(context.primaryAction.title, systemImage: context.primaryAction.systemImage)
            }
                .buttonStyle(.borderedProminent)
                .tint(CalPalTheme.Colors.brandPrimary)
                .controlSize(.large)
            if let secondary = context.secondaryAction {
                Button { onAction(secondary) } label: {
                    Label(secondary.title, systemImage: secondary.systemImage)
                }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

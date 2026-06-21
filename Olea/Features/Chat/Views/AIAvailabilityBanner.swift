import SwiftUI

/// Shown when on-device Apple Intelligence is unavailable on this device, so the user
/// understands why advanced features (Foundation Models chat, structured outputs) are off.
/// Dismissible permanently per device.
struct AIAvailabilityBanner: View {
    @AppStorage("aiBannerDismissed") private var dismissed = false

    var body: some View {
        if dismissed || AIService.shared.isOnDeviceAIAvailable {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Basic mode")
                        .font(.appCaption)
                        .foregroundStyle(Color.appText)
                    Text("Apple Intelligence isn't available on this device. Olea is using a keyword fallback for chat.")
                        .font(.appMicro)
                        .foregroundStyle(Color.appTextMuted)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                Button {
                    HapticManager.light()
                    withAnimation(.easeOut(duration: 0.2)) { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appTextDim)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss banner")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.appAccent.opacity(0.08))
            .overlay(
                Rectangle()
                    .fill(Color.appAccent.opacity(0.25))
                    .frame(height: 0.5),
                alignment: .bottom
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

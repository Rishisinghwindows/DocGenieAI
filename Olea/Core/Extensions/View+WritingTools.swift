import SwiftUI

extension View {
    /// Enables Apple Intelligence Writing Tools (Rewrite/Proofread/Summarize) on
    /// iOS 18.1+ where supported. No-op on older OSes.
    @ViewBuilder
    func appWritingTools(_ enabled: Bool = true) -> some View {
        if #available(iOS 18.1, *) {
            self.writingToolsBehavior(enabled ? .complete : .disabled)
        } else {
            self
        }
    }
}

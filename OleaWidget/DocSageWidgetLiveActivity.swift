import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity that surfaces an expiring document on the lock screen and in
/// the Dynamic Island. Backed by `ExpiringDocAttributes` (defined in Shared/).
struct DocSageWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExpiringDocAttributes.self) { context in
            // Lock-screen / banner UI
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo, .cyan],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: context.attributes.iconSystemName)
                        .foregroundStyle(.white)
                        .font(.system(size: 20, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.documentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(daysCopy(context.state.daysRemaining))
                        .font(.caption)
                        .foregroundStyle(urgencyColor(context.state.daysRemaining))
                }
                Spacer()
                Text(context.state.expiryDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .activityBackgroundTint(.black.opacity(0.7))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.iconSystemName)
                        .foregroundStyle(.indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.expiryDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.documentName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(daysCopy(context.state.daysRemaining))
                        .font(.caption.bold())
                        .foregroundStyle(urgencyColor(context.state.daysRemaining))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.attributes.iconSystemName)
                    .foregroundStyle(urgencyColor(context.state.daysRemaining))
            } compactTrailing: {
                Text("\(context.state.daysRemaining)d")
                    .font(.caption.bold())
                    .foregroundStyle(urgencyColor(context.state.daysRemaining))
            } minimal: {
                Text("\(context.state.daysRemaining)")
                    .font(.caption2.bold())
                    .foregroundStyle(urgencyColor(context.state.daysRemaining))
            }
            .keylineTint(.indigo)
        }
    }

    private func daysCopy(_ days: Int) -> String {
        if days <= 0 { return "Expired" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days <= 0 { return .red }
        if days <= 7 { return .red }
        if days <= 30 { return .orange }
        return .secondary
    }
}

#Preview("Lock Screen", as: .content, using: ExpiringDocAttributes.preview) {
   DocSageWidgetLiveActivity()
} contentStates: {
    ExpiringDocAttributes.ContentState(daysRemaining: 30, expiryDate: Date().addingTimeInterval(60*60*24*30))
    ExpiringDocAttributes.ContentState(daysRemaining: 7, expiryDate: Date().addingTimeInterval(60*60*24*7))
}

extension ExpiringDocAttributes {
    fileprivate static var preview: ExpiringDocAttributes {
        ExpiringDocAttributes(
            documentID: "preview",
            documentName: "Passport - John Smith",
            documentType: "Passport",
            iconSystemName: "person.text.rectangle"
        )
    }
}

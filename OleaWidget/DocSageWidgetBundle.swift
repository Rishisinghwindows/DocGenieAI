import WidgetKit
import SwiftUI

@main
struct DocSageWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentDocumentsWidget()
        QuickActionsWidget()
        DocumentStatsWidget()
        if #available(iOS 18.0, *) {
            DocSageWidgetControl()
        }
        DocSageWidgetLiveActivity()
    }
}

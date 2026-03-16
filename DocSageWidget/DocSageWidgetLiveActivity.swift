//
//  DocSageWidgetLiveActivity.swift
//  DocSageWidget
//
//  Created by pawan singh on 15/03/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DocSageWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DocSageWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DocSageWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DocSageWidgetAttributes {
    fileprivate static var preview: DocSageWidgetAttributes {
        DocSageWidgetAttributes(name: "World")
    }
}

extension DocSageWidgetAttributes.ContentState {
    fileprivate static var smiley: DocSageWidgetAttributes.ContentState {
        DocSageWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DocSageWidgetAttributes.ContentState {
         DocSageWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DocSageWidgetAttributes.preview) {
   DocSageWidgetLiveActivity()
} contentStates: {
    DocSageWidgetAttributes.ContentState.smiley
    DocSageWidgetAttributes.ContentState.starEyes
}

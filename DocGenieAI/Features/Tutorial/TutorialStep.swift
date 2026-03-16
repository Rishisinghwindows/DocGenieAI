import SwiftUI

enum TutorialTarget: String, CaseIterable {
    case menuButton
    case toolsButton
    case chatInput
    case suggestionCards
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let target: TutorialTarget
    let title: String
    let description: String
    let icon: String

    static let steps: [TutorialStep] = [
        TutorialStep(target: .menuButton, title: "New Chat", description: "Start a fresh conversation anytime by tapping here.", icon: "plus.bubble"),
        TutorialStep(target: .toolsButton, title: "Chat History", description: "View and switch between your past conversations.", icon: "clock.arrow.circlepath"),
        TutorialStep(target: .suggestionCards, title: "Quick Actions", description: "Tap a card to scan, merge, convert, or extract text right away.", icon: "sparkles"),
        TutorialStep(target: .chatInput, title: "Ask Anything", description: "Type a request or tap the mic to use voice. Attach files with the + button.", icon: "bubble.left.and.text.bubble.right"),
    ]
}

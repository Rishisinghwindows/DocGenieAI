import SwiftUI

struct SpotlightAnchorData: Equatable {
    let target: TutorialTarget
    let frame: CGRect
}

struct SpotlightAnchorKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [SpotlightAnchorData] = []
    static func reduce(value: inout [SpotlightAnchorData], nextValue: () -> [SpotlightAnchorData]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func spotlightAnchor(_ target: TutorialTarget) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightAnchorKey.self,
                    value: [SpotlightAnchorData(target: target, frame: geo.frame(in: .global))]
                )
            }
        )
    }
}

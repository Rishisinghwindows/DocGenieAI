//
//  AdBannerView.swift
//  DocGenieAI
//
//  Role: SwiftUI banner placement. Wraps Google's UIKit-based
//  `GADBannerView` in a SwiftUI representable, sized adaptively via
//  `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth` so the
//  banner matches the parent container's width without manual layout.
//
//  Use:
//    VStack {
//      content
//      AdBannerView()    // sits above the tab bar
//    }
//
//  Behavior:
//    • Returns `EmptyView()` entirely when the AdsCoordinator says ads are
//      off (Pro user, ads disabled, consent denied). No reserved space, no
//      layout shift — clean no-op.
//    • Banner self-reloads its ad size when the parent width changes
//      (rotation, multitasking).
//
//  Concurrency: @preconcurrency on the import to silence Swift 6 strict
//  warnings until Google ships Sendable conformance.
//

import SwiftUI
import UIKit
@preconcurrency import GoogleMobileAds

struct AdBannerView: View {
    @ObservedObject private var coordinator = AdsCoordinator.shared

    var body: some View {
        if coordinator.shouldShowAds {
            GeometryReader { geo in
                AdaptiveBanner(width: max(320, geo.size.width))
                    .frame(width: geo.size.width, height: adHeight(for: geo.size.width))
            }
            .frame(height: 60)        // approximate reserved space; banner re-sizes itself
            .background(Color.clear)
        } else {
            EmptyView()
        }
    }

    /// Match the adaptive banner system-recommended height by width.
    private func adHeight(for width: CGFloat) -> CGFloat {
        let size = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        return size.size.height
    }
}

// MARK: - UIViewControllerRepresentable wrapper

private struct AdaptiveBanner: UIViewControllerRepresentable {
    let width: CGFloat

    func makeUIViewController(context: Context) -> UIViewController {
        let host = BannerHostViewController()
        host.load(width: width)
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let host = uiViewController as? BannerHostViewController {
            host.load(width: width)
        }
    }
}

private final class BannerHostViewController: UIViewController, @preconcurrency GADBannerViewDelegate {
    private var banner: GADBannerView?

    func load(width: CGFloat) {
        let size = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        if banner == nil {
            let b = GADBannerView(adSize: size)
            b.adUnitID = AdsConfig.UnitID.banner
            b.rootViewController = self
            b.delegate = self
            view.addSubview(b)
            b.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                b.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                b.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            banner = b
        } else {
            banner?.adSize = size
        }
        banner?.load(GADRequest())
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        AppLogger.ui.error("Banner load failed: \(error.localizedDescription, privacy: .public)")
    }
}

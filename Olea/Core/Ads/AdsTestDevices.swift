import Foundation

/// AdMob test-device whitelist. Devices listed here see real production ad
/// inventory but each impression is labeled "Test Ad" — clicks don't count
/// toward revenue and don't trigger Google's invalid-traffic detection.
///
/// HOW TO FIND YOUR DEVICE ID
/// 1. Build & run Olea on the device with this array empty.
/// 2. Open the Xcode console and search for `testDeviceIdentifiers`. You'll
///    see a log line like:
///       <Google> To get test ads on this device, set:
///       GADMobileAds.sharedInstance().requestConfiguration
///         .testDeviceIdentifiers = @[ @"33BE2250-XXXX-XXXX-XXXX-XXXXXXXXXXXX" ]
/// 3. Copy that hex/UUID string into `identifiers` below and rebuild.
///
/// IMPORTANT: never ship this app with `identifiers` set to a real production
/// device ID — those devices will only ever see test ads, never live revenue.
/// Keep this list to dev devices only (yours, QA, internal testers).
enum AdsTestDevices {
    static let identifiers: [String] = [
        // Paste your device ID here, e.g. "33BE2250-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    ]
}

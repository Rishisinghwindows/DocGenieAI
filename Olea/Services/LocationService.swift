import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    static let autoTagDefaultsKey = "autoTagLocationEnabled"

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var pendingContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var requestInFlight = false

    var lastLocation: CLLocation?
    private var lastFetchAt: Date?
    private let cacheWindow: TimeInterval = 60

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAutoTagEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.autoTagDefaultsKey)
    }

    func setAutoTagEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.autoTagDefaultsKey)
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Get a one-shot location fix. Concurrent callers within `cacheWindow` share one fix.
    func getCurrentLocation() async -> CLLocation? {
        if let location = lastLocation,
           let fetchedAt = lastFetchAt,
           Date().timeIntervalSince(fetchedAt) < cacheWindow {
            return location
        }

        requestPermission()
        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            if !requestInFlight {
                requestInFlight = true
                manager.requestLocation()
            }
        }
    }

    /// Reverse geocode a CLLocation into a human-readable address string.
    func reverseGeocode(location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            var parts: [String] = []
            if let name = placemark.name { parts.append(name) }
            if let city = placemark.locality { parts.append(city) }
            if let state = placemark.administrativeArea { parts.append(state) }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            return nil
        }
    }

    /// Tag a single document. No-op unless the user has explicitly opted in.
    func tagDocumentWithLocation(_ document: DocumentFile) async {
        guard isAutoTagEnabled else { return }
        guard let location = await getCurrentLocation() else { return }
        document.latitude = location.coordinate.latitude
        document.longitude = location.coordinate.longitude
        if let name = await reverseGeocode(location: location) {
            document.locationName = name
        }
    }

    /// Tag many documents with one shared location/geocode result. Used during batch imports.
    func tagDocuments(_ documents: [DocumentFile]) async {
        guard isAutoTagEnabled else { return }
        guard !documents.isEmpty else { return }
        guard let location = await getCurrentLocation() else { return }
        let name = await reverseGeocode(location: location)
        for doc in documents {
            doc.latitude = location.coordinate.latitude
            doc.longitude = location.coordinate.longitude
            if let name { doc.locationName = name }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in
            self.lastLocation = last
            self.lastFetchAt = Date()
            self.requestInFlight = false
            let waiting = self.pendingContinuations
            self.pendingContinuations.removeAll()
            for cont in waiting { cont.resume(returning: last) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.requestInFlight = false
            let waiting = self.pendingContinuations
            self.pendingContinuations.removeAll()
            for cont in waiting { cont.resume(returning: nil) }
        }
    }
}

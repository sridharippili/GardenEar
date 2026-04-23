import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - One-shot async location

    func requestOneTimeLocation() async -> CLLocation? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait briefly for the user to respond to the permission dialog
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            self.lastLocation = locations.first
            self.locationContinuation?.resume(returning: locations.first)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print("[Location] Failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }
}

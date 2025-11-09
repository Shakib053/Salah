//
//  LocationManager.swift
//  Salah
//
//  Created by Kazi Tanjim Shakib on 9/11/25.
//

import CoreLocation

@Observable
 class LocationManager: NSObject, CLLocationManagerDelegate  {
    private let manager = CLLocationManager()

    var location: Location?
    var authorizationStatus: CLAuthorizationStatus?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization() // Ask for permission
        manager.requestLocation() 
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Permission granted — requesting location now")
            manager.requestLocation() // this will trigger didUpdateLocations()
        case .denied, .restricted:
            print("❌ Permission denied or restricted")
            // optionally fallback to a default coordinate
        case .notDetermined:
            print("🕓 Permission not yet determined")
        case .none:
            print("⚠️ Unknown authorization status")
        @unknown default:
            print("⚠️ Unknown authorization status")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("[LocationManager] all Location Data \(locations)")

        guard let location = locations.last else {
            print("[LocationManager] could not get user location")
            return
        }
    
        self.location = .coordinate(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print("[LocationManager] location manager failed with error: \(error)")
    }
}

//
//  LocationManager.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Handles location services to detect state and country
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var state: String = ""
    @Published var county: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationAuthorization()
    }
    
    func checkLocationAuthorization() {
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            errorMessage = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocation()
        @unknown default:
            break
        }
    }
    
    func requestLocation() {
        isLoading = true
        errorMessage = nil
        print("📍 Requesting location... (authorization: \(authorizationStatus.rawValue))")
        locationManager.requestLocation()
    }
    
    private func getFullStateName(from input: String) -> String {
        // State code to full name mapping
        let stateCodeToName: [String: String] = [
            "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
            "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
            "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
            "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
            "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
            "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
            "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
            "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
            "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
            "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
            "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
            "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
            "WI": "Wisconsin", "WY": "Wyoming"
        ]

        // If input is a 2-letter code, convert to full name
        if input.count == 2, let fullName = stateCodeToName[input.uppercased()] {
            return fullName
        }

        // Otherwise return as-is (already full name)
        return input
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to get location details: \(error.localizedDescription)"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self.errorMessage = "No location information found"
                    return
                }
                
                // Extract state (administrativeArea is the state in US)
                if let administrativeArea = placemark.administrativeArea {
                    // administrativeArea can be either full name or code
                    // Convert to full state name for consistency
                    self.state = self.getFullStateName(from: administrativeArea)
                    print("📍 Location found - State: \(self.state)")
                } else {
                    print("⚠️ No administrative area found in placemark")
                    self.errorMessage = "Could not determine state from location"
                }

                // Extract county (subAdministrativeArea is typically the county)
                if let county = placemark.subAdministrativeArea {
                    self.county = county
                }

                // If county is not available, try locality
                if self.county.isEmpty, let locality = placemark.locality {
                    self.county = locality
                }

                // Debug info
                print("📍 Full location details:")
                print("  - State: \(self.state)")
                print("  - County: \(self.county)")
                print("  - Locality: \(placemark.locality ?? "N/A")")
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("⚠️ No location in update")
            return
        }
        print("📍 Location received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        currentLocation = location
        reverseGeocodeLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Failed to get location: \(error.localizedDescription)"
        }
    }
}

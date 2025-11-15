//
//  SalahApp.swift
//  Salah
//
//  Created by Mahi Al Jawad on 18/2/24.
//

import SwiftUI

@main
struct SalahApp: App {
    private let salahAPIManager = SalahAPIManager()
    private let locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            TabBarView(salahAPIManager: salahAPIManager, locatioManager: locationManager)
                .fontDesign(.rounded)
                .task {
                    await salahAPIManager.fetchMonthlySalahTime(of: Date.now, location: locationManager.location)
                }
        }
    }
}

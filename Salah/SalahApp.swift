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
                    let result = await salahAPIManager.fetchMonthlySalahTime(of: Date.now, location: locationManager.location)
                    switch result {
                    case .success:
                        print("Monthly date fetched")
                    case .failure(let error):
                        print("Failed fetcing monthly data with error: \(error)")
                        // TODO: Show some error in the UI end
                    }
                }
        }
    }
}

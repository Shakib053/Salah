//
//  TabBarView.swift
//  Salah
//
//  Created by Mahi Al Jawad on 23/2/24.
//

import SwiftUI

struct TabBarView: View {
    typealias Tab = TabBarModel.Item
    @State var selectedTab: Tab = .timings
    private let salahAPIManager: SalahAPIManager
    private let locationManager: LocationManager
    
    init(salahAPIManager: SalahAPIManager, locatioManager: LocationManager) {
        self.salahAPIManager = salahAPIManager
        self.locationManager = locatioManager
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TimingsView(
                    viewModel: .init(salahAPIManager: salahAPIManager, locationManager: locationManager)
                )
            }
            .tabItem {
                Label(Tab.timings.title, systemImage: Tab.timings.icon)
            }
            .tag(Tab.timings)
            
            Text("Coming Soon")
                .tabItem {
                    Label(Tab.tracker.title, systemImage: Tab.tracker.icon)
                }
                .tag(Tab.tracker)
            
            Text("Coming Soon")
                .tabItem {
                    Label(Tab.more.title, systemImage: Tab.more.icon)
                }
                .tag(Tab.more)
        }
    }
}

//
//  TimingViewModel.swift
//  Salah
//
//  Created by Mahi Al Jawad on 24/2/24.
//

import SwiftUI
import Combine

@Observable
final class TimingsViewModel {
    private var salahAPIManager: SalahAPIManager
    private let locationManager: LocationManager
    private var cancellable: Cancellable?
    private var locationCancellable = Set<AnyCancellable>()
    private(set) var waqtUpdater = PassthroughSubject<Salah.Waqt?, Never>()
    
    var currentWaqt: Salah.Waqt?
    var dataResponse: LoadingState<DataResponse> = .loading
    var selectedDate: Date = .now
    
    var selectedCard: Int = 0
    var showCalendar: Bool = false
    
    var waqtDetailCardScaleValue: CGFloat {
        selectedCard == 0 ? 1.0 : 0.7
    }
    
    var fastingCardScaleValue: CGFloat {
        selectedCard == 1 ? 1.0 : 0.7
    }
    
    init(salahAPIManager: SalahAPIManager, locationManager: LocationManager) {
        self.salahAPIManager = salahAPIManager
        self.locationManager = locationManager
        observeWaqtChanges()
        observeLocationChanges()

    }
    
    func observeWaqtChanges() {
        cancellable = waqtUpdater
            .receive(on: RunLoop.main)
            .map { $0 }
            .removeDuplicates()
            .assign(to: \.currentWaqt, on: self)
    }
    
    func observeLocationChanges() {
        locationManager.location
            .publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("finished")
                case .failure(let error):
                    print("error occured \(error)")
                }
            }, receiveValue: { _ in })
            .store(in: &locationCancellable)
    }
    
    @MainActor
    func loadData() async {
        let result = await salahAPIManager.dailySalahTimeResponse(of: selectedDate, location: locationManager.location)
        
        switch result {
        case .success(let response):
            dataResponse = .loaded(response)
        case .failure(let error):
            dataResponse = .failed(error)
        }
    }
}

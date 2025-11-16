//
//  SalahAPIManager.swift
//  Salah
//
//  Created by Mahi Al Jawad on 22/2/24.
//

import Foundation

class SalahAPIManager {
    private var dateResponse: [String: DataResponse] = [:]
    
    func dailySalahTimeResponse(
        of date: Date = Date(),
        location: Location? = nil,
        method: Method = .UIS_Karachi,
        cautionDelay: CautionDelay = .IslamicFoundation,
        madhab: Madhab = .hanafi,
        hijriDateAdjustment: HijriDateAdjustment = .adjustDays(-1)
    ) async -> Result<DataResponse, ResponseError> {
        print("[SalahAPIManager] current location is: \(String(describing: location))")
        
        if let response = dateResponse[date.dateString] {
            print("Returning from cache")
            return .success(response)
        }
        
        guard let url = getDailyURL(
            date: date,
            location: location ?? .coordinate(lat: 23.7115253, lon: 90.4111451),
            method: method,
            cautionDelay: cautionDelay,
            madhab: madhab,
            hijriDateAdjustment: hijriDateAdjustment
        ) else {
            print("Failed getting daily URL")
            return /.failure(.urlConvertionError)
        }
        
        print("Fetching data with location \(location)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let salahAPIResponse = try JSONDecoder().decode(DailyAPIResponse.self, from: data)
            return .success(salahAPIResponse.data)
        } catch {
            print("Error: \(error)")
            return .failure(.error(error.localizedDescription))
        }
    }
    
    private func getDailyURL(
        date: Date,
        location: Location,
        method: Method,
        cautionDelay: CautionDelay,
        madhab: Madhab,
        hijriDateAdjustment: HijriDateAdjustment
    ) -> URL? {
        var urlString: String = "https://api.aladhan.com/v1"
        
        urlString += "/timings/\(date.dateString)?latitude=\(location.lattitude)&longitude=\(location.longitude)"
        
        if method == .UIS_Karachi {
            urlString += "&method=1"
        }
        // For other methods the method will be selected by nearest location
        
        if madhab == .hanafi {
            urlString += "&school=1"
        }
        // For other madhabs default will be set in the API
        
        urlString += "&adjustment=\(hijriDateAdjustment.days)"
        urlString += "&tune=\(cautionDelay.delay)"
        
        print("URL: \(urlString)")
        
        return URL(string: urlString)
    }
        
    
    func fetchMonthlySalahTime(
        of date: Date = Date(),
        location: Location? = nil,
        method: Method = .UIS_Karachi,
        cautionDelay: CautionDelay = .IslamicFoundation,
        madhab: Madhab = .hanafi,
        hijriDateAdjustment: HijriDateAdjustment = .adjustDays(-1)
    ) async -> Result<Void, ResponseError> {
        if dateResponse[date.dateString] != nil {
            print("Monthly data already fethced previously")
            return .success(())
        }
        
        guard let url = getMonthlyURL(
            date: date,
            location: location ?? .coordinate(lat: 23.7115253, lon: 90.4111451),
            method: method,
            cautionDelay: cautionDelay,
            madhab: madhab,
            hijriDateAdjustment: hijriDateAdjustment
        ) else {
            print("Failed getting monthly URL")
            return .failure(.urlConvertionError)
        }
        
        print("Fetching monthly data")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let salahAPIResponse = try JSONDecoder().decode(MonthlyAPIResponse.self, from: data)
            
            salahAPIResponse.data.forEach { dataResponse in
                let date = dataResponse.date.gregorian.date
                dateResponse[date] = dataResponse
            }
            
            return .success(())
        } catch {
            print("Error: \(error)")
            return .failure(.error(error.localizedDescription))
        }
    }
    
    private func getMonthlyURL(
        date: Date,
        location: Location,
        method: Method,
        cautionDelay: CautionDelay,
        madhab: Madhab,
        hijriDateAdjustment: HijriDateAdjustment
    ) -> URL? {
        var urlString: String = "https://api.aladhan.com/v1"
        
        let calendar = Calendar.current
        guard
            let month = calendar.dateComponents([.month], from: date).month,
            let year = calendar.dateComponents([.year], from: date).year
        else {
            return nil
        }
        
        print("month =\(month) and year=\(year)")
        
        urlString += "/calendar/\(year)/\(month)?latitude=\(location.lattitude)&longitude=\(location.longitude)"
        
        if method == .UIS_Karachi {
            urlString += "&method=1"
        }
        // For other methods the method will be selected by nearest location
        
        if madhab == .hanafi {
            urlString += "&school=1"
        }
        // For other madhabs default will be set in the API
        
        urlString += "&adjustment=\(hijriDateAdjustment.days)"
        urlString += "&tune=\(cautionDelay.delay)"
        
        print("URL: \(urlString)")
        
        return URL(string: urlString)
    }
    
    func getAllDistricts() -> [BDDistrict] {
        if let bdLocationsURL = Bundle.main.url(forResource: "districts", withExtension: "json") {
            guard let bdLocationsData = try? Data(contentsOf: bdLocationsURL) else {
                return []
            }
            
            guard let bdLocations = try? JSONDecoder().decode(BDLocations.self, from: bdLocationsData) else {
                return []
            }
            
            return bdLocations.districts
        }
        return []
    }
}

/*
 https://api.aladhan.com/v1/timings/22-02-2024?latitude=23.7115253&longitude=90.4111451&method=1&school=1&adjustment=-1&tune=3
 */
//    func getDummyvalue() -> String {
//        if let url = Bundle.main.url(forResource: "Test", withExtension: "json") {
//            guard let data = try? Data(contentsOf: url) else {
//                return "FFAILED"
//            }
//            let decoder = JSONDecoder()
//            guard let data = try? decoder.decode(APIResponse.self, from: data) else {
//                return "Failed"
//            }
//
//            return data.data.timings.isha
//
//        }
//
//
//        return "Failed last"
//    }

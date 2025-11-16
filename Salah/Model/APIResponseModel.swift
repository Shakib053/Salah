//
//  APIResponseModel.swift
//  Salah
//
//  Created by Mahi Al Jawad on 21/2/24.
//

import Foundation
import SwiftData

// MARK: LoadingState
enum LoadingState<Data> {
    case loaded(Data)
    case loading
    case failed(ResponseError)
}

// MARK: Errors
enum ResponseError: Error {
    case urlConvertionError
    case error(String)
    case dataNotFound
}

// MARK: For Salah API Response
struct DailyAPIResponse: Codable {
    let data: DataResponse
}

struct MonthlyAPIResponse: Codable {
    let data: [DataResponse]
}

struct DataResponse: Codable {
    let timings: TimingResponse
    let date: DateResponse
}

struct TimingResponse: Codable {
    let imsak: String
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let sunset: String
    let maghrib: String
    let isha: String
    
    enum CodingKeys: String, CodingKey {
        case imsak = "Imsak"
        case fajr = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case sunset = "Sunset"
        case maghrib = "Maghrib"
        case isha = "Isha"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        func trim(_ value: String) -> String {
            value.count > 6 ? String(value.dropLast(6)) : value
        }
        
        imsak   = trim(try container.decode(String.self, forKey: .imsak))
        fajr    = trim(try container.decode(String.self, forKey: .fajr))
        sunrise = trim(try container.decode(String.self, forKey: .sunrise))
        dhuhr   = trim(try container.decode(String.self, forKey: .dhuhr))
        asr     = trim(try container.decode(String.self, forKey: .asr))
        sunset  = trim(try container.decode(String.self, forKey: .sunset))
        maghrib = trim(try container.decode(String.self, forKey: .maghrib))
        isha    = trim(try container.decode(String.self, forKey: .isha))
    }
}

struct DateResponse: Codable {
    let hijri: HijriDateResponse
    let gregorian: GregorianDateResponse
}

struct HijriDateResponse: Codable {
    let date: String
    let day: String
    let month: MonthResponse
}

struct MonthResponse: Codable {
    let en: String
}

struct GregorianDateResponse: Codable {
    let date: String
    let day: String
    let weekday: WeekdayResponse
    let month: MonthResponse
}

struct WeekdayResponse: Codable {
    let en: String
}
// MARK: For Location by City Response

struct BDLocations: Codable {
    let districts: [BDDistrict]
}

struct BDDistrict: Codable, Identifiable {
    let id = UUID()
    let name: String
    let banglaName: String
    let lat: String
    let lon: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case banglaName = "bn_name"
        case lat
        case lon
    }
}

#if DEBUG
extension TimingResponse {
    init(imsak: String, fajr: String, sunrise: String, dhuhr: String, asr: String, sunset: String, maghrib: String, isha: String) {
        self.imsak = imsak
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.sunset = sunset
        self.maghrib = maghrib
        self.isha = isha
    }
}
#endif

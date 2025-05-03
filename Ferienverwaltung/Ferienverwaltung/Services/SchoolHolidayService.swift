import Foundation

enum SchoolHolidayError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case httpError(Int)
}

class SchoolHolidayService {
    static let shared = SchoolHolidayService()
    private let baseURL = "https://openholidaysapi.org"
    
    private init() {}
    
    func fetchHolidays(for state: FederalState, year: Int) async throws -> [SchoolHoliday] {
        async let schoolHolidays = fetchSchoolHolidays(for: state, year: year)
        async let publicHolidays = fetchPublicHolidays(for: state, year: year)
        
        do {
            let (school, public_) = try await (schoolHolidays, publicHolidays)
            
            var allHolidays = school + public_
            var uniqueDates = Set<String>()
            allHolidays.removeAll { holiday in
                let dateString = "\(holiday.start)-\(holiday.end)"
                if uniqueDates.contains(dateString) {
                    return true
                }
                uniqueDates.insert(dateString)
                return false
            }
            
            return allHolidays.sorted { 
                $0.startDateObject < $1.startDateObject
            }
        } catch {
            throw error
        }
    }
    
    private func fetchSchoolHolidays(for state: FederalState, year: Int) async throws -> [SchoolHoliday] {
        var urlComponents = URLComponents(string: "\(baseURL)/SchoolHolidays")
        urlComponents?.queryItems = [
            URLQueryItem(name: "countryIsoCode", value: "DE"),
            URLQueryItem(name: "subdivisionCode", value: "DE-\(state.stateCode)"),
            URLQueryItem(name: "validFrom", value: "\(year)-01-01"),
            URLQueryItem(name: "validTo", value: "\(year)-12-31"),
            URLQueryItem(name: "languageIsoCode", value: "DE")
        ]
        
        return try await fetchHolidays(from: urlComponents?.url)
    }
    
    private func fetchPublicHolidays(for state: FederalState, year: Int) async throws -> [SchoolHoliday] {
        var urlComponents = URLComponents(string: "\(baseURL)/PublicHolidays")
        urlComponents?.queryItems = [
            URLQueryItem(name: "countryIsoCode", value: "DE"),
            URLQueryItem(name: "subdivisionCode", value: "DE-\(state.stateCode)"),
            URLQueryItem(name: "validFrom", value: "\(year)-01-01"),
            URLQueryItem(name: "validTo", value: "\(year)-12-31"),
            URLQueryItem(name: "languageIsoCode", value: "DE")
        ]
        
        return try await fetchHolidays(from: urlComponents?.url)
    }
    
    private func fetchHolidays(from url: URL?) async throws -> [SchoolHoliday] {
        guard let url = url else {
            throw SchoolHolidayError.invalidURL
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw SchoolHolidayError.networkError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if String(data: data, encoding: .utf8) != nil {
                    // Do nothing; removed unused variable warning
                }
                throw SchoolHolidayError.httpError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            do {
                let holidays = try decoder.decode([SchoolHoliday].self, from: data)
                return holidays
            } catch {
                let response = try decoder.decode(SchoolHolidayResponse.self, from: data)
                return response.items
            }
        } catch let error as DecodingError {
            throw SchoolHolidayError.decodingError(error)
        } catch {
            throw SchoolHolidayError.networkError(error)
        }
    }
}

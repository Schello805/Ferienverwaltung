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
        print("Fetching holidays for state: \(state.rawValue), year: \(year)")
        
        async let schoolHolidays = fetchSchoolHolidays(for: state, year: year)
        async let publicHolidays = fetchPublicHolidays(for: state, year: year)
        
        do {
            let (school, public_) = try await (schoolHolidays, publicHolidays)
            print("Found \(school.count) school holidays and \(public_.count) public holidays")
            
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
            
            print("After removing duplicates: \(allHolidays.count) total holidays")
            
            // Sort by start date
            return allHolidays.sorted { 
                ($0.startDateObject ?? Date.distantFuture) < ($1.startDateObject ?? Date.distantFuture)
            }
        } catch {
            print("Error fetching holidays: \(error)")
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
        
        print("School holidays URL: \(urlComponents?.url?.absoluteString ?? "invalid URL")")
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
        
        print("Public holidays URL: \(urlComponents?.url?.absoluteString ?? "invalid URL")")
        return try await fetchHolidays(from: urlComponents?.url)
    }
    
    private func fetchHolidays(from url: URL?) async throws -> [SchoolHoliday] {
        guard let url = url else {
            print("Invalid URL provided")
            throw SchoolHolidayError.invalidURL
        }
        
        print("Fetching URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                print("Invalid response type received")
                throw SchoolHolidayError.networkError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Error Response: \(jsonString)")
                }
                throw SchoolHolidayError.httpError(httpResponse.statusCode)
            }
            
            // Print response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            do {
                let holidays = try decoder.decode([SchoolHoliday].self, from: data)
                print("Successfully decoded \(holidays.count) holidays")
                return holidays
            } catch {
                print("Failed to decode response as [SchoolHoliday]. Attempting to decode as SchoolHolidayResponse...")
                let response = try decoder.decode(SchoolHolidayResponse.self, from: data)
                print("Successfully decoded SchoolHolidayResponse with \(response.items.count) items")
                return response.items
            }
        } catch let error as DecodingError {
            print("Decoding Error: \(error)")
            throw SchoolHolidayError.decodingError(error)
        } catch {
            print("Network Error: \(error)")
            throw SchoolHolidayError.networkError(error)
        }
    }
}

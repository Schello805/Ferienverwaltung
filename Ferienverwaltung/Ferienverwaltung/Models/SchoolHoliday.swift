import Foundation

// Die API gibt ein Array von Ferien direkt zurück, keine umschließende Response
struct SchoolHolidayResponse: Codable {
    let items: [SchoolHoliday]
}

struct HolidayName: Codable, Equatable {
    let language: String
    let text: String
}

struct Subdivision: Codable {
    let code: String
    let shortName: String
}

struct SchoolHoliday: Codable, Identifiable {
    let id: String
    let startDate: String
    let endDate: String
    let type: String
    let name: [HolidayName]
    let regionalScope: String
    let temporalScope: String
    let nationwide: Bool
    let subdivisions: [Subdivision]?
    
    var holidayName: String {
        name.first(where: { $0.language == "DE" })?.text ?? "Unbekannte Ferien"
    }
    
    var start: String {
        startDate
    }
    
    var end: String {
        endDate
    }
    
    var startDateObject: Date? {
        DateFormatter.apiDateFormatter.date(from: startDate)
    }
    
    var endDateObject: Date? {
        DateFormatter.apiDateFormatter.date(from: endDate)
    }
}

extension DateFormatter {
    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        return formatter
    }()
}

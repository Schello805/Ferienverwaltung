import Foundation

// Die API gibt ein Array von Ferien direkt zurück, keine umschließende Response
struct SchoolHolidayResponse: Codable {
    let items: [SchoolHoliday]
}

struct HolidayName: Codable, Equatable {
    let language: String
    let text: String
}

struct Subdivision: Codable, Equatable {
    let code: String
    let shortName: String
}

struct SchoolHoliday: Codable, Identifiable, Equatable {
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
    
    static func == (lhs: SchoolHoliday, rhs: SchoolHoliday) -> Bool {
        lhs.id == rhs.id &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.type == rhs.type &&
        lhs.name == rhs.name &&
        lhs.regionalScope == rhs.regionalScope &&
        lhs.temporalScope == rhs.temporalScope &&
        lhs.nationwide == rhs.nationwide &&
        lhs.subdivisions == rhs.subdivisions
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

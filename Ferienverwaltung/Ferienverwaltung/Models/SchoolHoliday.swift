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

    let startDateObject: Date
    let endDateObject: Date

    var holidayName: String {
        name.first(where: { $0.language == "DE" })?.text ?? "Unbekannte Ferien"
    }

    var start: String {
        startDate
    }

    var end: String {
        endDate
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

    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, type, name, regionalScope, temporalScope, nationwide, subdivisions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decode(String.self, forKey: .endDate)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decode([HolidayName].self, forKey: .name)
        regionalScope = try container.decode(String.self, forKey: .regionalScope)
        temporalScope = try container.decode(String.self, forKey: .temporalScope)
        nationwide = try container.decode(Bool.self, forKey: .nationwide)
        subdivisions = try container.decodeIfPresent([Subdivision].self, forKey: .subdivisions)
        startDateObject = Self.safeParseDate(startDate) ?? Date.distantPast
        endDateObject = Self.safeParseDate(endDate) ?? Date.distantFuture
    }

    // Convenience-Init für manuelle Initialisierung
    init(
        id: String,
        startDate: String,
        endDate: String,
        type: String,
        name: [HolidayName],
        regionalScope: String,
        temporalScope: String,
        nationwide: Bool,
        subdivisions: [Subdivision]?,
        startDateObject: Date? = nil,
        endDateObject: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.type = type
        self.name = name
        self.regionalScope = regionalScope
        self.temporalScope = temporalScope
        self.nationwide = nationwide
        self.subdivisions = subdivisions
        self.startDateObject = startDateObject ?? Self.safeParseDate(startDate) ?? Date.distantPast
        self.endDateObject = endDateObject ?? Self.safeParseDate(endDate) ?? Date.distantFuture
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(regionalScope, forKey: .regionalScope)
        try container.encode(temporalScope, forKey: .temporalScope)
        try container.encode(nationwide, forKey: .nationwide)
        try container.encodeIfPresent(subdivisions, forKey: .subdivisions)
    }
}

extension SchoolHoliday {
    static func safeParseDate(_ string: String, format: String = "yyyy-MM-dd") -> Date? {
        guard !string.isEmpty else {
            print("[SchoolHoliday] Date string is empty")
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        if let date = formatter.date(from: string) {
            return date
        } else {
            // Versuche deutsches Format dd.MM.yyyy
            let altFormatter = DateFormatter()
            altFormatter.dateFormat = "dd.MM.yyyy"
            altFormatter.calendar = Calendar(identifier: .gregorian)
            altFormatter.timeZone = TimeZone(identifier: "Europe/Berlin")
            if let altDate = altFormatter.date(from: string) {
                return altDate
            }
            print("[SchoolHoliday] Invalid date string: \(string)")
            return nil
        }
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

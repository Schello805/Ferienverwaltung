import Foundation

struct Parent: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var relationship: Relationship
    var vacationDays: [VacationDay]
    var profileImageData: Data?
    var colorHex: String // z.B. "#FFAA00"
    var symbolName: String // z.B. "person.fill"
    var fixedWeekdays: [Int] = [] // 0 = Sonntag, 1 = Montag, ... 6 = Samstag
    
    init(id: UUID = UUID(), name: String, relationship: Relationship, vacationDays: [VacationDay] = [], profileImageData: Data? = nil, colorHex: String = "#007AFF", symbolName: String = "person.fill", fixedWeekdays: [Int] = []) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.vacationDays = vacationDays
        self.profileImageData = profileImageData
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.fixedWeekdays = fixedWeekdays
    }

    static func == (lhs: Parent, rhs: Parent) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.relationship == rhs.relationship &&
        lhs.vacationDays == rhs.vacationDays &&
        lhs.profileImageData == rhs.profileImageData &&
        lhs.colorHex == rhs.colorHex &&
        lhs.symbolName == rhs.symbolName &&
        lhs.fixedWeekdays == rhs.fixedWeekdays
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(relationship)
        hasher.combine(vacationDays)
        hasher.combine(profileImageData)
        hasher.combine(colorHex)
        hasher.combine(symbolName)
        hasher.combine(fixedWeekdays)
    }
}

enum Relationship: String, Codable, CaseIterable, Hashable {
    case father = "Vater"
    case mother = "Mutter"
    case grandparents = "Großeltern"
    case other = "Andere"
}

// MARK: - VacationDay mit lokalem Datum-Codierer
struct VacationDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var type: VacationType

    // Custom Coding für Datum als "yyyy-MM-dd" (lokale Mitternacht)
    enum CodingKeys: String, CodingKey {
        case id, date, type
    }

    init(id: UUID = UUID(), date: Date, type: VacationType) {
        self.id = id
        self.date = date
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(VacationType.self, forKey: .type)
        // Datum als String im Format "yyyy-MM-dd"
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        guard let parsedDate = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Ungültiges Datumsformat: \(dateString)")
        }
        self.date = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        try container.encode(dateString, forKey: .date)
    }

    static func == (lhs: VacationDay, rhs: VacationDay) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(type)
    }
}

enum VacationType: String, Codable, Hashable {
    case vacation = "Urlaub"
    case holiday = "Feiertag"
    case schoolHoliday = "Schulferien"
}

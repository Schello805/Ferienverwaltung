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

struct VacationDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var type: VacationType
    
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

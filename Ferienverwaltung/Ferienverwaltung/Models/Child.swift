import Foundation
import SwiftUI

enum ChildType: String, Codable, CaseIterable, Identifiable {
    case schulkind = "Schulkind"
    case kindergartenkind = "Kindergartenkind"
    var id: String { rawValue }
}

// MARK: - Freie Tage Modell
struct FreeDay: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var reason: String?

    // Custom Coding für Datum als "yyyy-MM-dd" (lokale Mitternacht)
    enum CodingKeys: String, CodingKey {
        case id, date, reason
    }

    init(id: UUID = UUID(), date: Date, reason: String? = nil) {
        self.id = id
        self.date = date
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
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
        try container.encodeIfPresent(reason, forKey: .reason)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        try container.encode(dateString, forKey: .date)
    }
}

struct Child: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var birthdate: Date?
    var profileImageData: Data?
    var notes: String?
    var type: ChildType = .schulkind
    var freeDays: [FreeDay] = [] // Individuelle freie Tage für dieses Kind

    // Convenience: Alter berechnen
    var age: Int? {
        guard let birthdate = birthdate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthdate, to: now)
        return ageComponents.year
    }
}

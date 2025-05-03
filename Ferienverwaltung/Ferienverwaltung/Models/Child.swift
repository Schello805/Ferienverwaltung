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
        self.date = Self.safeParseDate(dateString) ?? Date.distantPast
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(reason, forKey: .reason)
        let dateString = Self.formatDate(date)
        try container.encode(dateString, forKey: .date)
    }

    static func safeParseDate(_ string: String, format: String = "yyyy-MM-dd") -> Date? {
        guard !string.isEmpty else {
            print("[FreeDay] Date string is empty")
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.current
        if let date = formatter.date(from: string) {
            return date
        } else {
            print("[FreeDay] Invalid date string: \(string)")
            return nil
        }
    }

    static func formatDate(_ date: Date, format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    static func == (lhs: FreeDay, rhs: FreeDay) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.reason == rhs.reason
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

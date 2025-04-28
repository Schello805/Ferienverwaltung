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

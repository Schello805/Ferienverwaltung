import Foundation

class StorageService {
    static let shared = StorageService()
    private let defaults = UserDefaults.standard
    
    private let parentsKey = "savedParents"
    private let childrenKey = "savedChildren"
    private let selectedStateKey = "selectedState"
    private let schoolHolidaysKey = "schoolHolidaysCache"
    private let publicHolidaysKey = "publicHolidaysCache"
    private let holidaysTimestampKey = "holidaysCacheTimestamp"
    
    private init() {}
    
    func saveParents(_ parents: [Parent]) {
        print("[DEBUG] saveParents aufgerufen mit:", parents)
        if let encoded = try? JSONEncoder().encode(parents) {
            defaults.set(encoded, forKey: parentsKey)
        }
    }
    
    func loadParents() -> [Parent] {
        guard let data = defaults.data(forKey: parentsKey),
              let parents = try? JSONDecoder().decode([Parent].self, from: data) else {
            print("[DEBUG] loadParents: keine oder ungültige Daten im Storage")
            return []
        }
        print("[DEBUG] loadParents: geladen:", parents)
        return parents
    }
    
    func saveChildren(_ children: [Child]) {
        print("[DEBUG] saveChildren aufgerufen mit:", children)
        if let encoded = try? JSONEncoder().encode(children) {
            defaults.set(encoded, forKey: childrenKey)
        }
    }
    
    func loadChildren() -> [Child] {
        guard let data = defaults.data(forKey: childrenKey),
              let children = try? JSONDecoder().decode([Child].self, from: data) else {
            print("[DEBUG] loadChildren: keine oder ungültige Daten im Storage")
            return []
        }
        print("[DEBUG] loadChildren: geladen:", children)
        return children
    }
    
    func saveSelectedState(_ state: FederalState) {
        defaults.set(state.rawValue, forKey: selectedStateKey)
    }
    
    func loadSelectedState() -> FederalState {
        guard let stateRawValue = defaults.string(forKey: selectedStateKey),
              let state = FederalState(rawValue: stateRawValue) else {
            return .bw // Default to Baden-Württemberg
        }
        return state
    }
    
    // MARK: - Holidays Storage
    
    // Speichert Ferien/Feiertage für 2 Jahre als JSON-Daten
    func saveSchoolHolidays(_ holidays: [SchoolHoliday]) {
        if let encoded = try? JSONEncoder().encode(holidays) {
            defaults.set(encoded, forKey: schoolHolidaysKey)
            defaults.set(Date(), forKey: holidaysTimestampKey)
        }
    }
    
    func loadSchoolHolidays() -> [SchoolHoliday] {
        guard let data = defaults.data(forKey: schoolHolidaysKey),
              let holidays = try? JSONDecoder().decode([SchoolHoliday].self, from: data) else {
            return []
        }
        return holidays
    }

    func savePublicHolidays(_ holidays: [SchoolHoliday]) {
        if let encoded = try? JSONEncoder().encode(holidays) {
            defaults.set(encoded, forKey: publicHolidaysKey)
            defaults.set(Date(), forKey: holidaysTimestampKey)
        }
    }
    
    func loadPublicHolidays() -> [SchoolHoliday] {
        guard let data = defaults.data(forKey: publicHolidaysKey),
              let holidays = try? JSONDecoder().decode([SchoolHoliday].self, from: data) else {
            return []
        }
        return holidays
    }

    // Gibt das Datum des letzten Updates zurück
    func lastHolidaysUpdate() -> Date? {
        return defaults.object(forKey: holidaysTimestampKey) as? Date
    }
    
    // Löscht alle gespeicherten App-Daten (Parents, Children, Bundesland, Ferien, Feiertage, Timestamps)
    func resetAll() {
        defaults.removeObject(forKey: parentsKey)
        defaults.removeObject(forKey: childrenKey)
        defaults.removeObject(forKey: selectedStateKey)
        defaults.removeObject(forKey: schoolHolidaysKey)
        defaults.removeObject(forKey: publicHolidaysKey)
        defaults.removeObject(forKey: holidaysTimestampKey)
    }
}

import Foundation
import SwiftUI

// Zentrale Hilfsfunktion für alle Views: Zählt schulfreie Werktage in einem Zeitraum, exkl. Feiertage, optional Filter auf Jahr
func countSchoolFreeWeekdays(start: Date, end: Date, publicHolidays: [SchoolHoliday], filterYear: Int? = nil) -> Int {
    let calendar = Calendar.current
    let publicHolidayDates: [Date] = publicHolidays.compactMap { ph in
        guard let phDate = ph.startDateObject else { return nil }
        if phDate >= start && phDate <= end { return phDate } else { return nil }
    }
    var count = 0
    var current = start
    while current <= end {
        let weekday = calendar.component(.weekday, from: current)
        let isWeekend = (weekday == 1 || weekday == 7)
        let isPublicHoliday = publicHolidayDates.contains(where: { calendar.isDate($0, inSameDayAs: current) })
        let currentYear = calendar.component(.year, from: current)
        if !isWeekend && !isPublicHoliday && (filterYear == nil || currentYear == filterYear) {
            count += 1
        }
        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }
    return count
}

// Hilfs-Struct für Export/Import
struct FerienverwaltungExport: Codable {
    var parents: [Parent]
    var selectedState: String
    var schoolHolidays: [SchoolHoliday]
    var publicHolidays: [SchoolHoliday]
    var children: [Child]

    // Custom CodingKeys for FederalState as String
    enum CodingKeys: String, CodingKey {
        case parents, selectedState, schoolHolidays, publicHolidays, children
    }

    init(parents: [Parent], selectedState: FederalState, schoolHolidays: [SchoolHoliday], publicHolidays: [SchoolHoliday], children: [Child]) {
        self.parents = parents
        self.selectedState = selectedState.rawValue
        self.schoolHolidays = schoolHolidays
        self.publicHolidays = publicHolidays
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parents = try container.decode([Parent].self, forKey: .parents)
        let stateRaw = try container.decode(String.self, forKey: .selectedState)
        selectedState = stateRaw
        schoolHolidays = try container.decode([SchoolHoliday].self, forKey: .schoolHolidays)
        publicHolidays = try container.decode([SchoolHoliday].self, forKey: .publicHolidays)
        children = try container.decode([Child].self, forKey: .children)
    }

    func federalState() -> FederalState {
        FederalState(rawValue: selectedState) ?? .bw
    }
}

@MainActor
class VacationViewModel: ObservableObject {
    @Published var parents: [Parent] = [] {
        didSet {
            StorageService.shared.saveParents(parents)
        }
    }
    @Published var selectedState: FederalState = .bw {
        didSet {
            StorageService.shared.saveSelectedState(selectedState)
            Task {
                await updateHolidayCacheIfNeeded()
            }
        }
    }
    @Published var schoolHolidays: [SchoolHoliday] = []
    @Published var publicHolidays: [SchoolHoliday] = [] // Optional: falls für UI benötigt
    @Published var isLoading = false
    @Published var error: String?
    @Published var showPublicHolidaysInSchoolHolidays: Bool = true
    @Published var children: [Child] = [] {
        didSet {
            StorageService.shared.saveChildren(children)
        }
    }

    private let holidayService = SchoolHolidayService.shared
    
    init() {
        // Load saved data
        self.parents = StorageService.shared.loadParents()
        self.selectedState = StorageService.shared.loadSelectedState()
        self.children = StorageService.shared.loadChildren()
        
        // Initial fetch/caching für 2 Jahre
        Task {
            await updateHolidayCacheIfNeeded()
        }
    }
    
    func addParent(name: String, relationship: Relationship) {
        // Prevent empty names
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        parents.append(Parent(name: name, relationship: relationship, vacationDays: [], symbolName: "person.fill"))
    }
    
    func addVacationDay(for parent: Parent, date: Date, type: VacationType) {
        guard let parentIndex = parents.firstIndex(where: { p in p.id == parent.id }) else { return }
        
        // Normalize the date to start of day for comparison
        let normalizedDate = Calendar.current.startOfDay(for: date)
        
        // Check if the date already exists
        let dateExists = parents[parentIndex].vacationDays.contains { day in
            Calendar.current.isDate(day.date, inSameDayAs: normalizedDate)
        }
        
        // Only add if the date doesn't already exist
        if !dateExists {
            parents[parentIndex].vacationDays.append(VacationDay(date: normalizedDate, type: type))
        }
    }
    
    func removeVacationDay(for parent: Parent, date: Date) {
        guard let parentIndex = parents.firstIndex(where: { p in p.id == parent.id }) else { return }
        parents[parentIndex].vacationDays.removeAll { vacationDay in
            Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
        }
    }
    
    func fetchSchoolHolidays() async {
        isLoading = true
        error = nil
        
        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            let holidays = try await holidayService.fetchHolidays(for: selectedState, year: currentYear)
            schoolHolidays = holidays
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    func isSchoolHoliday(on date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return schoolHolidays.contains { holiday in
            guard let start = holiday.startDateObject,
                  let end = holiday.endDateObject else {
                return false
            }
            let range = DateInterval(start: start, end: end)
            return range.contains(normalizedDate)
        }
    }
    
    func getHolidayName(for date: Date) -> String? {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return schoolHolidays.first { holiday in
            guard let start = holiday.startDateObject,
                  let end = holiday.endDateObject else {
                return false
            }
            let range = DateInterval(start: start, end: end)
            return range.contains(normalizedDate)
        }?.holidayName
    }
    
    func hasUnattendedDay(on date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return !parents.contains { parent in
            parent.vacationDays.contains { day in
                Calendar.current.isDate(day.date, inSameDayAs: normalizedDate)
            }
        }
    }
    
    // Lädt und cached Schulferien & Feiertage für 2 Jahre, nur wenn nötig
    func updateHolidayCacheIfNeeded() async {
        isLoading = true
        error = nil
        let cacheAgeLimit: TimeInterval = 60 * 60 * 24 * 7 // 7 Tage
        let now = Date()
        let lastUpdate = StorageService.shared.lastHolidaysUpdate() ?? .distantPast
        let needsUpdate = now.timeIntervalSince(lastUpdate) > cacheAgeLimit
        let currentYear = Calendar.current.component(.year, from: now)
        _ = currentYear + 1 // nextYear entfernt, da nicht direkt verwendet
        
        // Prüfe, ob Cache leer ist oder zu alt
        let cachedSchool = StorageService.shared.loadSchoolHolidays()
        let cachedPublic = StorageService.shared.loadPublicHolidays()
        // Cache ist nur gültig, wenn BEIDE Listen nicht leer sind
        if !needsUpdate && !cachedSchool.isEmpty && !cachedPublic.isEmpty {
            // Nutze Cache
            self.schoolHolidays = cachedSchool
            self.publicHolidays = cachedPublic
            print("[DEBUG] Feiertage aus Cache geladen: \(cachedPublic.count)")
            isLoading = false
            return
        }
        await updateHolidayCache(force: true)
    }
    
    // Lädt und cached Schulferien & Feiertage für 2 Jahre, unabhängig vom Cache
    @MainActor
    func reloadSchoolHolidays() {
        Task {
            await updateHolidayCache(force: true)
        }
    }

    // Angepasst: updateHolidayCache kann jetzt forciert werden
    func updateHolidayCache(force: Bool = false) async {
        isLoading = true
        error = nil
        let cacheAgeLimit: TimeInterval = 60 * 60 * 24 * 7 // 7 Tage
        let now = Date()
        let lastUpdate = StorageService.shared.lastHolidaysUpdate() ?? .distantPast
        let needsUpdate = now.timeIntervalSince(lastUpdate) > cacheAgeLimit
        let currentYear = Calendar.current.component(.year, from: now)
        _ = currentYear + 1 // nextYear entfernt, da nicht direkt verwendet

        let cachedSchool = StorageService.shared.loadSchoolHolidays()
        let cachedPublic = StorageService.shared.loadPublicHolidays()
        if !force && !needsUpdate && !cachedSchool.isEmpty && !cachedPublic.isEmpty {
            self.schoolHolidays = cachedSchool
            self.publicHolidays = cachedPublic
            print("[DEBUG] Feiertage aus Cache geladen: \(cachedPublic.count)")
            isLoading = false
            return
        }
        do {
            var allSchool: [SchoolHoliday] = []
            var allPublic: [SchoolHoliday] = []
            for year in [currentYear, currentYear + 1] {
                let holidays = try await holidayService.fetchHolidays(for: selectedState, year: year)
                let school = holidays.filter { $0.type.lowercased() == "school" }
                let publicH = holidays.filter { $0.type.lowercased() == "public" }
                allSchool.append(contentsOf: school)
                allPublic.append(contentsOf: publicH)
            }
            StorageService.shared.saveSchoolHolidays(allSchool)
            StorageService.shared.savePublicHolidays(allPublic)
            self.schoolHolidays = allSchool
            self.publicHolidays = allPublic
            print("[DEBUG] Feiertage aus API geladen: \(allPublic.count)")
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // Liefert alle Feiertage, die NICHT in den Schulferien liegen
    var filteredPublicHolidays: [SchoolHoliday] {
        let schoolPeriods = schoolHolidays.compactMap { holiday -> DateInterval? in
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { return nil }
            return DateInterval(start: start, end: end)
        }
        return publicHolidays.filter { holiday in
            guard let date = holiday.startDateObject else { return false }
            // Feiertage, die NICHT in einen Ferienzeitraum fallen
            return !schoolPeriods.contains { $0.contains(date) }
        }
    }
    
    // Gefilterte Eltern mit nur aktuellen Urlaubstagen
    var filteredParents: [Parent] {
        let today = Calendar.current.startOfDay(for: Date())
        return parents.map { parent in
            var filteredParent = parent
            filteredParent.vacationDays = parent.vacationDays.filter { $0.date >= today }
            return filteredParent
        }
    }

    // Gefilterte Schulferien (entfernt Duplikate nach Zeitraum und Name UND nach ID)
    var filteredSchoolHolidays: [SchoolHoliday] {
        let calendar = Calendar.current
        // 1. Splitte alle Ferien, die über den Jahreswechsel gehen, in einzelne Jahres-Einträge
        var splitHolidays: [SchoolHoliday] = []
        for h in schoolHolidays {
            guard let start = h.startDateObject, let end = h.endDateObject else { continue }
            let startYear = calendar.component(.year, from: start)
            let endYear = calendar.component(.year, from: end)
            if startYear == endYear {
                splitHolidays.append(h)
            } else {
                // Teil 1: Startjahr bis 31.12.
                if let endOfYear = calendar.date(from: DateComponents(year: startYear, month: 12, day: 31)) {
                    let firstPart = splitHoliday(h, start: start, end: endOfYear)
                    splitHolidays.append(firstPart)
                }
                // Teil 2: 1.1. bis Endjahr
                if let startOfNextYear = calendar.date(from: DateComponents(year: endYear, month: 1, day: 1)) {
                    let secondPart = splitHoliday(h, start: startOfNextYear, end: end)
                    splitHolidays.append(secondPart)
                }
            }
        }

        // 2. Weihnachtsferien: Pro Jahr alle überlappenden/aneinandergrenzenden Einträge zusammenfassen
        let groupedByYear = Dictionary(grouping: splitHolidays.filter { $0.holidayName.contains("Weihnachtsferien") }) { h in
            calendar.component(.year, from: h.startDateObject ?? Date.distantPast)
        }
        var mergedWeihnachtsferien: [SchoolHoliday] = []
        for (_, list) in groupedByYear {
            var pool = list
            while !pool.isEmpty {
                var current = pool.removeFirst()
                var didMerge = false
                repeat {
                    didMerge = false
                    if let idx = pool.firstIndex(where: { datesOverlap(current, $0) || datesTouch(current, $0) }) {
                        current = mergeHolidays(current, pool[idx])
                        pool.remove(at: idx)
                        didMerge = true
                    }
                } while didMerge
                mergedWeihnachtsferien.append(current)
            }
        }
        // 3. Alle anderen Ferien wie bisher, aber KEINE Weihnachtsferien-Duplikate
        let nonWeihnachtsferien = splitHolidays.filter { !$0.holidayName.contains("Weihnachtsferien") }
        var unique: [SchoolHoliday] = []
        for h in nonWeihnachtsferien {
            if !unique.contains(where: { $0.holidayName == h.holidayName && $0.startDate == h.startDate && $0.endDate == h.endDate }) {
                unique.append(h)
            }
        }
        // 4. Weihnachtsferien pro Jahr nur einmal hinzufügen (nach Zeitraum/Name deduplizieren)
        for h in mergedWeihnachtsferien {
            if !unique.contains(where: { $0.holidayName == h.holidayName && $0.startDate == h.startDate && $0.endDate == h.endDate }) {
                unique.append(h)
            }
        }
        // 5. Entferne doppelte IDs nach dem Splitten (z.B. wenn mehrere Einträge für dieselben Weihnachtsferien existieren)
        var trulyUnique: [SchoolHoliday] = []
        var seen: Set<String> = []
        for h in unique {
            let key = "\(h.holidayName)-\(h.startDate)-\(h.endDate)-\(calendar.component(.year, from: h.startDateObject ?? Date.distantPast))"
            if !seen.contains(key) {
                let newHoliday = SchoolHoliday(
                    id: key,
                    startDate: h.startDate,
                    endDate: h.endDate,
                    type: h.type,
                    name: h.name,
                    regionalScope: h.regionalScope,
                    temporalScope: h.temporalScope,
                    nationwide: h.nationwide,
                    subdivisions: h.subdivisions
                )
                trulyUnique.append(newHoliday)
                seen.insert(key)
            }
        }
        // 6. Endgültig: Nur EIN Eintrag pro Zeitraum/Name/Jahr (alle weiteren werden entfernt)
        var finalDeduped: [SchoolHoliday] = []
        var finalSeen: Set<String> = []
        for h in trulyUnique {
            let year = calendar.component(.year, from: h.startDateObject ?? Date.distantPast)
            let dedupeKey = "\(h.holidayName)-\(h.startDate)-\(h.endDate)-\(year)"
            if !finalSeen.contains(dedupeKey) {
                let newHoliday = SchoolHoliday(
                    id: dedupeKey,
                    startDate: h.startDate,
                    endDate: h.endDate,
                    type: h.type,
                    name: h.name,
                    regionalScope: h.regionalScope,
                    temporalScope: h.temporalScope,
                    nationwide: h.nationwide,
                    subdivisions: h.subdivisions
                )
                finalDeduped.append(newHoliday)
                finalSeen.insert(dedupeKey)
            }
        }
        return finalDeduped
    }
    
    func addChild(_ child: Child) {
        children.append(child)
        StorageService.shared.saveChildren(children)
    }
    
    func updateChild(_ child: Child) {
        if let idx = children.firstIndex(where: { $0.id == child.id }) {
            children[idx] = child
            StorageService.shared.saveChildren(children)
        }
    }
    
    func deleteChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
        StorageService.shared.saveChildren(children)
    }
    
    // Setzt alle gespeicherten App-Daten zurück (Eltern, Kinder, Bundesland, Ferien etc.)
    func resetAllData() {
        parents = []
        children = []
        schoolHolidays = []
        publicHolidays = []
        selectedState = .bw
        // Optional: UserDefaults komplett löschen, falls gewünscht
        StorageService.shared.resetAll()
    }
    
    // MARK: - Unbetreute Ferientage ermitteln
    func unattendedHolidayDates() -> [Date] {
        let calendar = Calendar.current
        var unattended: [Date] = []
        for holiday in schoolHolidays {
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { continue }
            var current = start
            while current <= end {
                let isWeekend = calendar.isDateInWeekend(current)
                let isAttended = parents.contains { parent in
                    parent.fixedWeekdays.contains(calendar.component(.weekday, from: current) - 1)
                }
                if !isWeekend && !isAttended {
                    unattended.append(current)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return unattended
    }

    // MARK: - Push Notifications für unbetreute Ferientage
    func scheduleUnattendedHolidayNotifications() {
        let unattended = unattendedHolidayDates()
        NotificationService.shared.scheduleUnattendedHolidayNotifications(unattendedDates: unattended)
    }
    
    /// Prüft, ob sich die Zeiträume zweier Ferien überlappen
    private func datesOverlap(_ h1: SchoolHoliday, _ h2: SchoolHoliday) -> Bool {
        guard let s1 = h1.startDateObject, let e1 = h1.endDateObject, let s2 = h2.startDateObject, let e2 = h2.endDateObject else { return false }
        return max(s1, s2) <= min(e1, e2)
    }
    /// Gibt ein zusammengefasstes Ferienobjekt zurück (frühester Start, spätestes Ende, Name etc. bleibt gleich)
    private func mergeHolidays(_ h1: SchoolHoliday, _ h2: SchoolHoliday) -> SchoolHoliday {
        let start = min(h1.startDateObject ?? Date.distantFuture, h2.startDateObject ?? Date.distantFuture)
        let end = max(h1.endDateObject ?? Date.distantPast, h2.endDateObject ?? Date.distantPast)
        let startDate = DateFormatter.apiDateFormatter.string(from: start)
        let endDate = DateFormatter.apiDateFormatter.string(from: end)
        return SchoolHoliday(
            id: h1.id, // ID bleibt gleich (oder nimm h2.id)
            startDate: startDate,
            endDate: endDate,
            type: h1.type,
            name: h1.name,
            regionalScope: h1.regionalScope,
            temporalScope: h1.temporalScope,
            nationwide: h1.nationwide,
            subdivisions: h1.subdivisions
        )
    }
    
    /// Prüft, ob zwei Ferien direkt aneinandergrenzen
    private func datesTouch(_ a: SchoolHoliday, _ b: SchoolHoliday) -> Bool {
        guard let aEnd = a.endDateObject, let bStart = b.startDateObject, let bEnd = b.endDateObject, let aStart = a.startDateObject else { return false }
        return Calendar.current.isDate(aEnd.addingTimeInterval(60*60*24), inSameDayAs: bStart) || Calendar.current.isDate(bEnd.addingTimeInterval(60*60*24), inSameDayAs: aStart)
    }
    
    /// Splitte einen Ferien-Eintrag in ein neues Objekt mit eindeutiger ID für das Jahr
    private func splitHoliday(_ holiday: SchoolHoliday, start: Date, end: Date) -> SchoolHoliday {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: start)
        let id = holiday.id + "-" + String(year)
        let startDate = DateFormatter.apiDateFormatter.string(from: start)
        let endDate = DateFormatter.apiDateFormatter.string(from: end)
        return SchoolHoliday(
            id: id,
            startDate: startDate,
            endDate: endDate,
            type: holiday.type,
            name: holiday.name,
            regionalScope: holiday.regionalScope,
            temporalScope: holiday.temporalScope,
            nationwide: holiday.nationwide,
            subdivisions: holiday.subdivisions
        )
    }
    
    // MARK: - Dashboard Statistiken für ein Kalenderjahr
    func workdays(in year: Int) -> Int {
        print("[DEBUG] workdays for year", year, "schoolHolidays count:", schoolHolidays.count, "filteredSchoolHolidays count:", filteredSchoolHolidays.count, "publicHolidays count:", publicHolidays.count)
        let calendar = Calendar.current
        var count = 0
        var date = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        while date <= end {
            let weekday = calendar.component(.weekday, from: date)
            if weekday != 1 && weekday != 7 { count += 1 }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return count
    }

    func publicHolidayCount(in year: Int) -> Int {
        print("[DEBUG] publicHolidayCount for year", year, "publicHolidays count:", publicHolidays.count)
        let calendar = Calendar.current
        let holidays = publicHolidays.filter {
            guard let d = $0.startDateObject else { return false }
            return calendar.component(.year, from: d) == year
        }
        let uniqueDays = Set(holidays.compactMap { $0.startDateObject })
        print("[DEBUG] publicHolidayCount uniqueDays:", uniqueDays.count)
        return uniqueDays.count
    }

    func vacationDaysIncludingHolidays(in year: Int) -> Int {
        print("[DEBUG] vacationDaysIncludingHolidays for year", year, "filteredSchoolHolidays count:", filteredSchoolHolidays.count)
        let calendar = Calendar.current
        let holidays = filteredSchoolHolidays.filter {
            guard let s = $0.startDateObject, let e = $0.endDateObject else { return false }
            let match = calendar.component(.year, from: s) == year || calendar.component(.year, from: e) == year
            if match {
                print("[DEBUG] Ferien für Jahr", year, ":", $0.holidayName, $0.startDate, "-", $0.endDate)
            }
            return match
        }
        var days = Set<Date>()
        for holiday in holidays {
            guard let s = holiday.startDateObject, let e = holiday.endDateObject else { continue }
            var date = max(s, calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
            let end = min(e, calendar.date(from: DateComponents(year: year, month: 12, day: 31))!)
            while date <= end {
                days.insert(calendar.startOfDay(for: date))
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
        }
        print("[DEBUG] vacationDaysIncludingHolidays unique days:", days.sorted().map { DateFormatter.apiDateFormatter.string(from: $0) })
        print("[DEBUG] vacationDaysIncludingHolidays count for year", year, ":", days.count)
        return days.count
    }

    func vacationWorkdaysExcludingHolidays(in year: Int) -> Int {
        print("[DEBUG] vacationWorkdaysExcludingHolidays for year", year, "filteredSchoolHolidays count:", filteredSchoolHolidays.count, "publicHolidays count:", publicHolidays.count)
        let calendar = Calendar.current
        let holidays = filteredSchoolHolidays.filter {
            guard let s = $0.startDateObject, let e = $0.endDateObject else { return false }
            let match = calendar.component(.year, from: s) == year || calendar.component(.year, from: e) == year
            if match {
                print("[DEBUG] Ferien für Jahr (Werktage)", year, ":", $0.holidayName, $0.startDate, "-", $0.endDate)
            }
            return match
        }
        let publicHolidayDays = Set(publicHolidays.compactMap { $0.startDateObject }.filter { calendar.component(.year, from: $0) == year })
        var days = Set<Date>()
        for holiday in holidays {
            guard let s = holiday.startDateObject, let e = holiday.endDateObject else { continue }
            var date = max(s, calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
            let end = min(e, calendar.date(from: DateComponents(year: year, month: 12, day: 31))!)
            while date <= end {
                let weekday = calendar.component(.weekday, from: date)
                if weekday != 1 && weekday != 7 && !publicHolidayDays.contains(calendar.startOfDay(for: date)) {
                    days.insert(calendar.startOfDay(for: date))
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
        }
        print("[DEBUG] vacationWorkdaysExcludingHolidays unique days:", days.sorted().map { DateFormatter.apiDateFormatter.string(from: $0) })
        print("[DEBUG] vacationWorkdaysExcludingHolidays count for year", year, ":", days.count)
        return days.count
    }
    
    // MARK: - Export/Import
    func exportAllDataAsJSON() -> Data? {
        let exportStruct = FerienverwaltungExport(parents: parents, selectedState: selectedState, schoolHolidays: schoolHolidays, publicHolidays: publicHolidays, children: children)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(exportStruct)
        } catch {
            print("[Export] Fehler beim Kodieren: \(error)")
            return nil
        }
    }

    func importAllDataFromJSON(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let importStruct = try decoder.decode(FerienverwaltungExport.self, from: data)
            self.parents = importStruct.parents
            self.selectedState = importStruct.federalState()
            self.schoolHolidays = importStruct.schoolHolidays
            self.publicHolidays = importStruct.publicHolidays
            self.children = importStruct.children
        } catch {
            print("[Import] Fehler beim Dekodieren: \(error)")
        }
    }
}

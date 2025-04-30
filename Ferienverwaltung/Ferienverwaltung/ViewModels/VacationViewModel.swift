import Foundation
import SwiftUI
import Combine

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
            // Defensive Copy: parents ist @Published, daher muss eine Kopie erzeugt werden
            var normalizedParents = parents
            for i in 0..<normalizedParents.count {
                var parent = normalizedParents[i]
                parent.vacationDays = parent.vacationDays.map { vacationDay in
                    var vd = vacationDay
                    vd.date = Calendar.current.startOfDay(for: vacationDay.date)
                    return vd
                }
                normalizedParents[i] = parent
            }
            StorageService.shared.saveParents(normalizedParents)
            // parents = normalizedParents // NICHT setzen, sonst Rekursion!
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
    {
        didSet {
            let old = publicHolidays
            let normalized = publicHolidays.map { h in
                let newStart = midnight(for: h.startDateObject ?? Date())
                let newEnd = midnight(for: h.endDateObject ?? Date())
                // Debug: Ursprungs-String und resultierendes Date mit Zeitzone ausgeben
                print("[DEBUG] Feiertag-Import: \(h.holidayName) | API-String: \(h.startDate) | startDateObject: \(String(describing: h.startDateObject)) | normalisiert: \(newStart) [TZ: \(selectedTimeZone.identifier)]")
                print("[DEBUG] Feiertag-Import: \(h.holidayName) | API-String: \(h.endDate) | endDateObject: \(String(describing: h.endDateObject)) | normalisiert: \(newEnd) [TZ: \(selectedTimeZone.identifier)]")
                // Workaround: Rückgabe als neues SchoolHoliday-Objekt mit normalisierten Strings
                var copy = h
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.timeZone = selectedTimeZone
                copy = SchoolHoliday(
                    id: h.id,
                    startDate: f.string(from: newStart),
                    endDate: f.string(from: newEnd),
                    type: h.type,
                    name: h.name,
                    regionalScope: h.regionalScope,
                    temporalScope: h.temporalScope,
                    nationwide: h.nationwide,
                    subdivisions: h.subdivisions
                )
                return copy
            }
            // Nur ersetzen, wenn es wirklich Änderungen gibt
            if normalized != old {
                publicHolidays = normalized
            }
        }
    }
    @Published var isLoading = false
    @Published var error: String?
    @Published var showPublicHolidaysInSchoolHolidays: Bool = true
    private var cancellables = Set<AnyCancellable>()
    @Published var children: [Child] = [] {
        didSet {
            // Defensive Copy: children ist @Published, daher muss eine Kopie erzeugt werden
            var normalizedChildren = children
            for i in 0..<normalizedChildren.count {
                var child = normalizedChildren[i]
                child.freeDays = child.freeDays.map { freeDay in
                    var fd = freeDay
                    fd.date = utcMidnight(for: freeDay.date)
                    return fd
                }
                normalizedChildren[i] = child
            }
            StorageService.shared.saveChildren(normalizedChildren)
            // children = normalizedChildren // NICHT setzen, sonst Rekursion!
        }
    }
    // MARK: - Zeitzonen-Handling
    @Published var selectedTimeZone: TimeZone = TimeZone.current {
        didSet {
            UserDefaults.standard.set(selectedTimeZone.identifier, forKey: "userSelectedTimeZone")
        }
    }
    var currentTimeZone: TimeZone {
        selectedTimeZone
    }
    private let holidayService = SchoolHolidayService.shared
    
    // Zentrale UTC-Kalender-Property
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()
    
    init() {
        // Load saved data
        self.parents = StorageService.shared.loadParents()
        self.selectedState = StorageService.shared.loadSelectedState()
        self.children = StorageService.shared.loadChildren()
        self.schoolHolidays = StorageService.shared.loadSchoolHolidays()
        self.publicHolidays = StorageService.shared.loadPublicHolidays()

        // --- BEGIN: Migration für bestehende Termine auf Mitternacht ---
        let migrationKey = "didMigrateVacationDatesToMidnight_v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            var migrated = false
            // Eltern-Termine
            var normalizedParents = self.parents
            for i in 0..<normalizedParents.count {
                var parent = normalizedParents[i]
                let oldDays = parent.vacationDays
                parent.vacationDays = parent.vacationDays.map { day in
                    var vd = day
                    vd.date = Calendar.current.startOfDay(for: day.date)
                    return vd
                }
                if parent.vacationDays != oldDays { migrated = true }
                normalizedParents[i] = parent
            }
            // DEBUG: Direkt nach der Normalisierung ausgeben (vor dem Speichern)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
            df.timeZone = TimeZone.current
            for parent in normalizedParents {
                print("[DEBUG][MIGRATION] Parent: \(parent.name)")
                for day in parent.vacationDays {
                    print("[DEBUG][MIGRATION]   VacationDay: \(df.string(from: day.date)) (\(day.date))")
                }
            }
            if migrated { StorageService.shared.saveParents(normalizedParents) }
            self.parents = normalizedParents

            // Kinder-Termine
            migrated = false
            var normalizedChildren = self.children
            for i in 0..<normalizedChildren.count {
                var child = normalizedChildren[i]
                let oldDays = child.freeDays
                child.freeDays = child.freeDays.map { freeDay in
                    var fd = freeDay
                    fd.date = utcMidnight(for: freeDay.date)
                    return fd
                }
                if child.freeDays != oldDays { migrated = true }
                normalizedChildren[i] = child
            }
            // DEBUG: Direkt nach der Normalisierung ausgeben (vor dem Speichern)
            for child in normalizedChildren {
                print("[DEBUG][MIGRATION] Child: \(child.name)")
                for freeDay in child.freeDays {
                    print("[DEBUG][MIGRATION]   FreeDay: \(df.string(from: freeDay.date)) (\(freeDay.date))")
                }
            }
            if migrated { StorageService.shared.saveChildren(normalizedChildren) }
            self.children = normalizedChildren

            UserDefaults.standard.set(true, forKey: migrationKey)
            print("[Migration] Alle bestehenden Termine wurden auf Mitternacht normalisiert.")
        }
        // --- ENDE: Migration ---
        if let savedTZ = UserDefaults.standard.string(forKey: "userSelectedTimeZone"), let tz = TimeZone(identifier: savedTZ) {
            selectedTimeZone = tz
        } else {
            selectedTimeZone = TimeZone.current
        }
        // Listener für Bundesland-Änderungen
        $selectedState
            .sink(receiveValue: { [weak self] _ in
                Task {
                    await self?.updateHolidayCacheIfNeeded()
                }
            })
            .store(in: &cancellables)

        // Initial fetch/caching für 2 Jahre
        Task {
            await updateHolidayCacheIfNeeded()
        }
    }
    
    // Hilfsfunktion: Mitternacht in UTC
    private func utcMidnight(for date: Date) -> Date {
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: components)!
    }
    // Hilfsfunktion: Mitternacht in userdefinierter Zeitzone
    private func midnight(for date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = selectedTimeZone
        let components = cal.dateComponents([.year, .month, .day], from: date)
        return cal.date(from: components)!
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
    
    // Gefilterte Schulferien (entfernt Duplikate nach Zeitraum und Name UND nach ID)
    var filteredSchoolHolidays: [SchoolHoliday] {
        var unique: [SchoolHoliday] = []
        for h in schoolHolidays {
            if !unique.contains(where: { $0.holidayName == h.holidayName && $0.startDate == h.startDate && $0.endDate == h.endDate }) {
                unique.append(h)
            }
        }
        return unique
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
    
    func addFreeDay(for child: Child, date: Date, reason: String?) {
        guard let childIndex = children.firstIndex(where: { $0.id == child.id }) else { return }
        let normalizedDate = midnight(for: date)
        // Prüfen, ob es den Tag schon gibt
        let exists = children[childIndex].freeDays.contains { freeDay in
            midnight(for: freeDay.date) == normalizedDate
        }
        if !exists {
            var updatedChild = children[childIndex]
            updatedChild.freeDays.append(FreeDay(id: UUID(), date: normalizedDate, reason: reason))
            // Alle freeDays auf userdefinierte Zeitzone normalisieren
            updatedChild.freeDays = updatedChild.freeDays.map {
                var fd = $0
                fd.date = midnight(for: fd.date)
                return fd
            }
            children[childIndex] = updatedChild
            print("[DEBUG] addFreeDay: Kind=\(updatedChild.name), Tag=\(normalizedDate)")
        }
    }

    // Kinder beim Laden immer auf userdefinierte Zeitzone normalisieren
    func loadChildren() {
        let loadedChildren = StorageService.shared.loadChildren()
        let normalizedChildren = loadedChildren.map { child in
            var newChild = child
            newChild.freeDays = child.freeDays.map { fd in
                var nfd = fd
                nfd.date = midnight(for: fd.date)
                return nfd
            }
            return newChild
        }
        self.children = normalizedChildren
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
        guard let s1 = h1.startDateObject,
              let e1 = h1.endDateObject else {
            return false
        }
        guard let s2 = h2.startDateObject,
              let e2 = h2.endDateObject else {
            return false
        }
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
        let holidays = publicHolidays.filter {
            guard let d = $0.startDateObject else { return false }
            return Calendar.current.component(.year, from: d) == year
        }
        let uniqueDays = Set(holidays.compactMap { $0.startDateObject })
        print("[DEBUG] publicHolidayCount uniqueDays:", uniqueDays.count)
        return uniqueDays.count
    }

    func vacationDaysIncludingHolidays(in year: Int) -> Int {
        print("[DEBUG] vacationDaysIncludingHolidays for year", year, "filteredSchoolHolidays count:", filteredSchoolHolidays.count)
        let holidays = filteredSchoolHolidays.filter {
            guard let s = $0.startDateObject, let e = $0.endDateObject else { return false }
            return Calendar.current.component(.year, from: s) == year || Calendar.current.component(.year, from: e) == year
        }
        var days = Set<Date>()
        for holiday in holidays {
            guard let s = holiday.startDateObject, let e = holiday.endDateObject else { continue }
            var date = max(s, Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!)
            let endDate = min(e, Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31))!)
            while date <= endDate {
                days.insert(Calendar.current.startOfDay(for: date))
                date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            }
        }
        print("[DEBUG] vacationDaysIncludingHolidays unique days:", days.sorted().map { DateFormatter.apiDateFormatter.string(from: $0) })
        print("[DEBUG] vacationDaysIncludingHolidays count for year", year, ":", days.count)
        return days.count
    }

    func vacationWorkdaysExcludingHolidays(in year: Int) -> Int {
        print("[DEBUG] vacationWorkdaysExcludingHolidays for year", year, "filteredSchoolHolidays count:", filteredSchoolHolidays.count, "publicHolidays count:", publicHolidays.count)
        let calendar = utcCalendar
        let holidays = filteredSchoolHolidays.filter {
            guard let s = $0.startDateObject, let e = $0.endDateObject else { return false }
            return calendar.component(.year, from: s) == year || calendar.component(.year, from: e) == year
        }
        // Alle relevanten Werktage in den Ferien (Mo-Fr, ohne Feiertage)
        let publicHolidaySet = Set(publicHolidays.compactMap { $0.startDateObject }.map { calendar.startOfDay(for: $0) }.filter { calendar.component(.year, from: $0) == year })
        var allVacationDays = Set<Date>()
        for holiday in holidays {
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { continue }
            var date = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            while date <= endDay {
                let weekday = calendar.component(.weekday, from: date)
                if weekday != 1 && weekday != 7 && calendar.component(.year, from: date) == year && !publicHolidaySet.contains(date) {
                    allVacationDays.insert(date)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
        }
        let vacationDayCount = allVacationDays.count
        print("[DEBUG] alleFerienWerktage (max 20):", Array(allVacationDays.sorted().prefix(20)).map { String(describing: $0) }, "... total count:", vacationDayCount)

        // Alle FreeDays aller Kinder im Jahr
        let allChildFreeDays = children.flatMap { $0.freeDays }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { calendar.component(.year, from: $0) == year }
        let abgedeckteTage = Set(allChildFreeDays)
        print("[DEBUG] abgedeckteTage (durch FreeDays der Kinder, max 20):", Array(abgedeckteTage.sorted().prefix(20)).map { String(describing: $0) }, "... total count:", abgedeckteTage.count)

        // Nur die Werktage, die NICHT durch FreeDays abgedeckt sind, zählen
        let relevanteTage = allVacationDays.subtracting(abgedeckteTage)
        print("[DEBUG] relevanteTage (zu betreuen, max 20):", Array(relevanteTage.sorted().prefix(20)).map { String(describing: $0) }, "... total count:", relevanteTage.count)
        print("[DEBUG] vacationWorkdaysExcludingHolidays count for year", year, ":", relevanteTage.count)
        return relevanteTage.count
    }
    
    // MARK: - Vacation Workdays for Parent (Centralized)
    /// Gibt die Werktage (Mo-Fr, ohne Feiertage) eines Elternteils im Jahr gruppiert nach Kalenderjahr zurück
    /// Es werden nur bundesweite oder landesweite Feiertage (für das aktuelle Bundesland) berücksichtigt, keine regionalen Feiertage.
    func vacationWorkdaysPerYear(for parent: Parent) -> [Int: Int] {
        let calendar = utcCalendar
        var yearCounts: [Int: Int] = [:]
        // Bundesland-Code für Filterung
        let bundeslandCode = selectedState.rawValue.lowercased()
        // Nur bundesweite oder für das aktuelle Bundesland gültige Feiertage
        let filteredHolidays = publicHolidays.filter { ph in
            if ph.nationwide == true { return true }
            // subdivisions: ["BY", "NW", ...] => muss Bundesland enthalten
            if let subs = ph.subdivisions, subs.map({ $0.lowercased() }).contains(bundeslandCode) { return true }
            return false
        }
        for vacation in parent.vacationDays {
            let date = calendar.startOfDay(for: vacation.date)
            let weekday = calendar.component(.weekday, from: date)
            let isWorkday = weekday >= 2 && weekday <= 6 // Mo-Fr
            let isHoliday = filteredHolidays.contains { ph in
                guard let s = ph.startDateObject, let e = ph.endDateObject else { return false }
                return date >= calendar.startOfDay(for: s) && date <= calendar.startOfDay(for: e)
            }
            if isWorkday && !isHoliday {
                let year = calendar.component(.year, from: date)
                yearCounts[year, default: 0] += 1
            }
        }
        return yearCounts
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

    /// Gibt die Anzahl der zu betreuenden Tage zurück: Ferien-Werktage + zusätzliche relevante FreeDays der Kinder (die nicht auf Ferien-Werktage oder Feiertage fallen).
    func totalBetreuungstageMitZusatzFreieTage(in year: Int) -> Int {
        let calendar = utcCalendar
        // 1. Ferien-Werktage (Mo-Fr, keine Feiertage)
        let ferienWerktage = self.vacationWorkdaysExcludingHolidaysRaw(in: year)
        // 2. Feiertage (als Date-Set, UTC-normalisiert!)
        let feiertageSet: Set<Date> = Set(publicHolidays.compactMap { $0.startDateObject }.map { calendar.startOfDay(for: $0) }.filter { calendar.component(.year, from: $0) == year })
        // 3. Alle FreeDays aller Kinder im Jahr (UTC-normalisiert!)
        let alleFreeDays = children.flatMap { $0.freeDays }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { calendar.component(.year, from: $0) == year }
        // 4. Zusätzliche FreeDays, die NICHT auf Ferien-Werktag und NICHT auf Feiertag liegen
        let ferienWerktageSet = Set(ferienWerktage.map { calendar.startOfDay(for: $0) })
        let zusaetzlicheFreeDays = alleFreeDays.filter { !ferienWerktageSet.contains($0) && !feiertageSet.contains($0) }
        // Debug-Ausgaben
        print("[DEBUG][totalBetreuungstageMitZusatzFreieTage] Ferien-Werktage: \(ferienWerktage.count)")
        print("[DEBUG][totalBetreuungstageMitZusatzFreieTage] Zusätzliche FreeDays: \(zusaetzlicheFreeDays.sorted()) (\(zusaetzlicheFreeDays.count))")
        return ferienWerktage.count + zusaetzlicheFreeDays.count
    }

    /// Gibt ein Array aller Ferien-Werktage (Mo-Fr, ohne Feiertage) für das Jahr zurück. (Hilfsfunktion)
    func vacationWorkdaysExcludingHolidaysRaw(in year: Int) -> [Date] {
        let calendar = utcCalendar
        let filteredSchoolHolidays = schoolHolidays.filter {
            guard let s = $0.startDateObject, let e = $0.endDateObject else { return false }
            return calendar.component(.year, from: s) == year || calendar.component(.year, from: e) == year
        }
        var allVacationDays = Set<Date>()
        let feiertageSet: Set<Date> = Set(publicHolidays.compactMap { $0.startDateObject }.map { calendar.startOfDay(for: $0) }.filter { calendar.component(.year, from: $0) == year })
        for holiday in filteredSchoolHolidays {
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { continue }
            var date = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            while date <= endDay {
                let weekday = calendar.component(.weekday, from: date)
                let normalized = calendar.startOfDay(for: date)
                if weekday != 1 && weekday != 7 && calendar.component(.year, from: normalized) == year && !feiertageSet.contains(normalized) {
                    allVacationDays.insert(normalized)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
        }
        let result = Array(allVacationDays).sorted()
        print("[DEBUG][vacationWorkdaysExcludingHolidaysRaw] Werktage: \(result)")
        return result
    }

    /// Gibt die Anzahl der schulfreien Werktage (Mo-Fr, ohne Feiertage) für ein Jahr zurück
    func schoolFreeDaysCount(in year: Int) -> Int {
        return schoolHolidays.reduce(0) { sum, holiday in
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { return sum }
            return sum + countSchoolFreeWeekdays(start: start, end: end, publicHolidays: publicHolidays, filterYear: year)
        }
    }

    /// Gibt die Gesamtzahl der schulfreien Werktage (Mo-Fr, ohne Feiertage) für ein Jahr zurück (wie in HolidaysView)
    func schoolFreeDaysFromHolidayView(in year: Int) -> Int {
        let holidaysForYear = deduplicatedSchoolHolidays(for: year)
        return holidaysForYear.reduce(0) { sum, holiday in
            if let start = holiday.startDateObject, let end = holiday.endDateObject {
                return sum + countSchoolFreeWeekdays(start: start, end: end, publicHolidays: publicHolidays, filterYear: year)
            } else {
                return sum
            }
        }
    }

    /// Gibt die Gesamtzahl der zusätzlichen freien Tage aller Kinder für ein Jahr zurück
    func totalAdditionalChildFreeDays(in year: Int) -> Int {
        let calendar = Calendar.current
        return children.flatMap { $0.freeDays }
            .map { calendar.startOfDay(for: $0.date) }
            .filter { calendar.component(.year, from: $0) == year }
            .count
    }

    /// Neue Methode für das Dashboard: Summe aus Ferien-View-Zahl + Kindertage
    func totalFreeDaysDashboard(in year: Int) -> Int {
        return schoolFreeDaysFromHolidayView(in: year) + totalAdditionalChildFreeDays(in: year)
    }

    /// Gibt ein dedupliziertes Array aller Schulferien für ein Jahr zurück (wie groupedHolidays in HolidaysView)
    func deduplicatedSchoolHolidays(for year: Int) -> [SchoolHoliday] {
        let calendar = Calendar.current
        // 1. Filter: Nur Ferien, die ganz oder teilweise im Jahr liegen
        let holidaysInYear = schoolHolidays.filter { holiday in
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { return false }
            let startYear = calendar.component(.year, from: start)
            let endYear = calendar.component(.year, from: end)
            return startYear == year || endYear == year
        }
        // 2. Deduplizieren: Nach id + Start/Ende
        var seen = Set<String>()
        let deduped = holidaysInYear.filter { holiday in
            let key = "\(holiday.id)-\(holiday.startDate)-\(holiday.endDate)"
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
        return deduped
    }

    /// Gibt die Gesamtanzahl der Werktage (Mo-Fr, ohne Wochenenden und Feiertage) im Jahr zurück
    func anzahlWerktageImJahr(_ year: Int) -> Int {
        let calendar = Calendar.current
        var count = 0
        var date = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        // Nur Feiertage ohne regionale Einschränkung (bundesweit/landesweit)
        let feiertage: Set<Date> = Set(publicHolidays.compactMap { h -> Date? in
            guard let d = h.startDateObject, calendar.component(.year, from: d) == year else { return nil }
            // Nur Feiertage ohne subdivisions oder mit subdivisions, die den Bundesland-Code enthalten
            if let subs = h.subdivisions, !subs.isEmpty, !subs.contains(where: { $0.code == selectedState.stateCode }) {
                return nil // regional, nicht landesweit
            }
            let weekday = calendar.component(.weekday, from: d)
            return (weekday >= 2 && weekday <= 6) ? d : nil
        })
        while date <= end {
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = (weekday == 1 || weekday == 7)
            let isHoliday = feiertage.contains { calendar.isDate($0, inSameDayAs: date) }
            if !isWeekend && !isHoliday {
                count += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return count
    }
    
    /// Gibt die Werktage (Mo-Fr, ohne Feiertage) eines Elternteils im Jahr gruppiert nach Kalenderjahr zurück
    func vacationWorkdaysPerYear(for parent: Parent) -> [Int: Int] {
        let calendar = utcCalendar
        var yearCounts: [Int: Int] = [:]
        // Bundesland-Code für Filterung
        let bundeslandCode = selectedState.rawValue.lowercased()
        // Nur bundesweite oder für das aktuelle Bundesland gültige Feiertage
        let filteredHolidays = publicHolidays.filter { ph in
            if ph.nationwide == true { return true }
            // subdivisions: ["BY", "NW", ...] => muss Bundesland enthalten
            if let subs = ph.subdivisions, subs.map({ $0.lowercased() }).contains(bundeslandCode) { return true }
            return false
        }
        for vacation in parent.vacationDays {
            let date = calendar.startOfDay(for: vacation.date)
            let weekday = calendar.component(.weekday, from: date)
            let isWorkday = weekday >= 2 && weekday <= 6 // Mo-Fr
            let isHoliday = filteredHolidays.contains { ph in
                guard let s = ph.startDateObject, let e = ph.endDateObject else { return false }
                return date >= calendar.startOfDay(for: s) && date <= calendar.startOfDay(for: e)
            }
            if isWorkday && !isHoliday {
                let year = calendar.component(.year, from: date)
                yearCounts[year, default: 0] += 1
            }
        }
        return yearCounts
    }
}

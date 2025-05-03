import SwiftUI

struct HolidaysView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedTab = 0 // 0: Schulferien, 1: Feiertage
    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $selectedTab) {
                Text("Schulferien").tag(0)
                Text("Feiertage").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            List {
                if selectedTab == 0 {
                    // Jahr-Gruppierung aller Schulferien
                    ForEach(groupedHolidays().sorted(by: { $0.key < $1.key }), id: \ .key) { year, holidays in
                        // Berechne die Gesamtzahl der schulfreien Werktage für dieses Jahr
                        let totalSchoolFreeDays = holidays.reduce(0) { sum, holiday in
                            let start = holiday.startDateObject
                            let end = holiday.endDateObject
                            // Optional: Prüfe auf Fallback-Werte
                            // if start == Date.distantPast || end == Date.distantFuture { return sum }
                            return sum + countSchoolFreeWeekdays(start: start, end: end, publicHolidays: viewModel.publicHolidays, filterYear: year)
                        }
                        Section(header:
                            HStack {
                                Text("Schulferien \(String(format: "%04d", year))")
                                Spacer()
                                Text("Gesamt: \(totalSchoolFreeDays) Tage")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        ) {
                            ForEach(holidays.sorted { $0.startDateObject < $1.startDateObject }, id: \.id) { holiday in
                                NavigationLink(destination: HolidayDetailView(viewModel: viewModel, holiday: holiday)) {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(holiday.holidayName)
                                                .font(.headline)
                                            Spacer()
                                            let start = holiday.startDateObject
                                            let end = holiday.endDateObject
                                            // Optional: Prüfe auf Fallback-Werte
                                            // if start == Date.distantPast || end == Date.distantFuture { return }
                                            let count = countSchoolFreeWeekdays(start: start, end: end, publicHolidays: viewModel.publicHolidays)
                                            Text("\(count) Tage")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        let start = holiday.startDateObject
                                        let end = holiday.endDateObject
                                        // Optional: Prüfe auf Fallback-Werte
                                        // if start == Date.distantPast || end == Date.distantFuture { return }
                                        Text("\(formatDate(start)) bis \(formatDate(end))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Jahr-Gruppierung aller relevanten Feiertage (nicht in Ferien)
                    let holidaysToGroup = viewModel.publicHolidays
                    let grouped = Dictionary(grouping: holidaysToGroup) { holiday in
                        Calendar.current.component(.year, from: holiday.startDateObject)
                    }.sorted(by: { $0.key < $1.key })
                    if grouped.isEmpty {
                        Text("Keine Feiertage gefunden.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        Section(header:
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Feiertage")
                                Text("(Regionale Feiertage werden nicht für die Werktagsberechnung berücksichtigt)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.bottom, 4)
                        ) {
                            ForEach(grouped, id: \ .key) { year, holidays in
                                // Berechne die Gesamtzahl der Feiertage (ohne Wochenenden, aber mit ggf. mehreren Feiertagen an Werktagen)
                                let totalPublicHolidays = holidays.reduce(0) { sum, holiday in
                                    let start = holiday.startDateObject
                                    let end = holiday.endDateObject
                                    return sum + countPublicHolidayWeekdays(start: start, end: end)
                                }
                                Section(header:
                                    HStack {
                                        Text("Feiertage \(String(format: "%04d", year))")
                                        Spacer()
                                        Text("Gesamt: \(totalPublicHolidays) Tage")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                ) {
                                    ForEach(holidays) { holiday in
                                        VStack(alignment: .leading) {
                                            Text(holiday.holidayName)
                                                .font(.headline)
                                            Text("\(formatDate(holiday.startDateObject)) bis \(formatDate(holiday.endDateObject))")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            HolidayScopeInfoView(holiday: holiday)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Ferienübersicht")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        // .edgesIgnoringSafeArea(.all) // Entfernt, damit Titel nicht hinter Notch verschwindet
    }
    
    // Verwende einen statischen Formatter für Performance und Sicherheit
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    
    func groupedHolidays() -> [Int: [SchoolHoliday]] {
        var result: [Int: [SchoolHoliday]] = [:]
        let calendar = Calendar.current
        // Immer das deduplizierte Array verwenden!
        for holiday in viewModel.filteredSchoolHolidays {
            let start = holiday.startDateObject
            let end = holiday.endDateObject
            // Optional: Prüfe auf Fallback-Werte
            // if start == Date.distantPast || end == Date.distantFuture { continue }
            let startYear = calendar.component(.year, from: start)
            let endYear = calendar.component(.year, from: end)
            if startYear == endYear {
                // Normalfall: Ferien liegen komplett in einem Jahr
                result[startYear, default: []].append(holiday)
            } else {
                // Splitte Ferien, die über den Jahreswechsel gehen
                let endOfYear = calendar.date(from: DateComponents(year: startYear, month: 12, day: 31))!
                let firstPart = splitHoliday(holiday, start: start, end: endOfYear)
                result[startYear, default: []].append(firstPart)
                // Teil 2: 1.1. bis Endjahr
                let startOfNextYear = calendar.date(from: DateComponents(year: endYear, month: 1, day: 1))!
                let secondPart = splitHoliday(holiday, start: startOfNextYear, end: end)
                result[endYear, default: []].append(secondPart)
            }
        }
        return result
    }
    
    func splitHoliday(_ holiday: SchoolHoliday, start: Date, end: Date) -> SchoolHoliday {
        // Erzeuge eine neue ID für das Teilstück (alte ID + Jahr)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: start)
        let id = holiday.id + "-" + String(year)
        let startDate = Self.dateFormatter.string(from: start)
        let endDate = Self.dateFormatter.string(from: end)
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
}

// MARK: - Zusatzinfo-View für Feiertags-Gültigkeit
struct HolidayScopeInfoView: View {
    let holiday: SchoolHoliday
    var body: some View {
        if holiday.nationwide {
            Text("bundesweit").font(.caption).foregroundColor(.green)
        } else if let subdivisions = holiday.subdivisions, !subdivisions.isEmpty {
            let bundeslaender = subdivisions.map { $0.shortName }.joined(separator: ", ")
            Text("nur: \(bundeslaender)").font(.caption).foregroundColor(.orange)
        } else {
            Text("regional").font(.caption).foregroundColor(.orange)
        }
    }
}

// Feiertags-Werktage (ohne Wochenenden) zählen
fileprivate func countPublicHolidayWeekdays(start: Date, end: Date) -> Int {
    let calendar = Calendar.current
    var count = 0
    var current = start
    while current <= end {
        let weekday = calendar.component(.weekday, from: current)
        let isWeekend = (weekday == 1 || weekday == 7)
        if !isWeekend {
            count += 1
        }
        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }
    return count
}

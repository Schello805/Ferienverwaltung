import SwiftUI

struct HolidaysView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedTab = 0 // 0: Schulferien, 1: Feiertage
    var body: some View {
        NavigationView {
            VStack {
                Picker("Ansicht", selection: $selectedTab) {
                    Text("Schulferien").tag(0)
                    Text("Feiertage").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.top, .horizontal])

                List {
                    if selectedTab == 0 {
                        // Jahr-Gruppierung aller Schulferien
                        ForEach(groupedHolidays().sorted(by: { $0.key < $1.key }), id: \ .key) { year, holidays in
                            // Berechne die Gesamtzahl der schulfreien Werktage für dieses Jahr
                            let totalSchoolFreeDays = holidays.reduce(0) { sum, holiday in
                                if let start = holiday.startDateObject, let end = holiday.endDateObject {
                                    return sum + countSchoolFreeWeekdays(start: start, end: end, publicHolidays: viewModel.publicHolidays, filterYear: year)
                                } else {
                                    return sum
                                }
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
                                ForEach(holidays.sorted { ($0.startDateObject ?? Date.distantPast) < ($1.startDateObject ?? Date.distantPast) }, id: \.id) { holiday in
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(holiday.holidayName)
                                                .font(.headline)
                                            Spacer()
                                            if let start = holiday.startDateObject, let end = holiday.endDateObject {
                                                let count = countSchoolFreeWeekdays(start: start, end: end, publicHolidays: viewModel.publicHolidays)
                                                Text("\(count) Tage")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        if let start = holiday.startDateObject, let end = holiday.endDateObject {
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
                        let holidaysToGroup = viewModel.hideExpiredData ? viewModel.filteredPublicHolidays : viewModel.publicHolidays
                        let grouped = Dictionary(grouping: holidaysToGroup) { holiday in
                            Calendar.current.component(.year, from: holiday.startDateObject ?? Date())
                        }.sorted(by: { $0.key < $1.key })
                        if grouped.isEmpty {
                            Text("Keine Feiertage gefunden.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(grouped, id: \ .key) { year, holidays in
                                // Berechne die Gesamtzahl der Feiertage (ohne Wochenenden, aber mit ggf. mehreren Feiertagen an Werktagen)
                                let totalPublicHolidays = holidays.reduce(0) { sum, holiday in
                                    if let start = holiday.startDateObject, let end = holiday.endDateObject {
                                        return sum + countPublicHolidayWeekdays(start: start, end: end)
                                    } else {
                                        return sum
                                    }
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
                                            if let start = holiday.startDateObject, let end = holiday.endDateObject {
                                                Text("\(formatDate(start)) bis \(formatDate(end))")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            HolidayScopeInfoView(holiday: holiday)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Ferien & Feiertage")
        }
    }
    
    func groupedHolidays() -> [Int: [SchoolHoliday]] {
        var result: [Int: [SchoolHoliday]] = [:]
        let calendar = Calendar.current
        // Immer das deduplizierte Array verwenden!
        for holiday in viewModel.filteredSchoolHolidays {
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { continue }
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
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

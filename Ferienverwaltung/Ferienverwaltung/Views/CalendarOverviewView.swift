import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CalendarOverviewView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Environment(\.dismiss) private var dismiss
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                // Abstand zur oberen Kante vergrößern
                Spacer().frame(height: 20)
                // Kompakte, standardisierte Legende
                ColorLegendView()
                .padding(.vertical, 4)
                
                Picker("Jahr", selection: $selectedYear) {
                    ForEach(yearRange(), id: \.self) { year in
                        Text(String(format: "%d", year)).tag(year)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(1...12, id: \.self) { month in
                            VStack(alignment: .leading, spacing: 4) {
                                // Monatsnamen auf Deutsch
                                Text("\(deMonthName(for: month))")
                                    .font(.headline)
                                    .padding(.leading, 4)
                                CalendarGridView(
                                    year: selectedYear,
                                    month: month,
                                    isHoliday: isHoliday,
                                    isAttendedHoliday: isAttendedHoliday,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            // Sichtbarer Schließen-Button immer oben rechts
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.secondary)
                    .shadow(radius: 2)
                    .padding(8)
            }
        }
        .navigationTitle("Kalenderübersicht")
    }
    
    func yearRange() -> [Int] {
        // Wieder mehrere Jahre anzeigen
        let current = Calendar.current.component(.year, from: Date())
        return [current - 1, current, current + 1]
    }
    
    /// Ein Tag ist ein "Ferientag ohne Betreuung" wenn Schulferien sind und KEIN Elternteil Urlaub hat, oder wenn ein Kind einen freien Tag hat und KEIN Elternteil Urlaub hat.
    func isHoliday(_ date: Date) -> Bool {
        let isSchoolHoliday = viewModel.schoolHolidays.contains { h in
            guard let start = h.startDateObject, let end = h.endDateObject else { return false }
            return (start...end).contains(date)
        }
        let isChildFree = isChildFreeDay(date)
        let isAttended = isAttendedHoliday(date)
        // Wenn Schulferien ODER Kind-freier Tag, aber kein Elternteil Urlaub hat
        return (isSchoolHoliday || isChildFree) && !isAttended
    }
    
    /// Prüft, ob der Tag ein "Ferientag mit Betreuung" ist (mind. ein Elternteil hat Urlaub an diesem Ferientag oder an einem freien Kindertag)
    func isAttendedHoliday(_ date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let weekday = Calendar.current.component(.weekday, from: normalizedDate) // 1=Sonntag ... 7=Samstag
        let weekdayZeroBased = (weekday + 5) % 7 // 0=Montag ... 6=Sonntag
        // Eltern haben Urlaub ODER festen freien Tag
        return viewModel.parents.contains { parent in
            parent.vacationDays.contains { vac in
                Calendar.current.isDate(Calendar.current.startOfDay(for: vac.date), inSameDayAs: normalizedDate)
            } || parent.fixedWeekdays.contains(weekdayZeroBased)
        }
    }
    
    /// Prüft, ob an diesem Tag mindestens ein Kind einen zusätzlichen freien Tag hat
    func isChildFreeDay(_ date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return viewModel.children.contains { child in
            child.freeDays.contains { freeDay in
                Calendar.current.isDate(Calendar.current.startOfDay(for: freeDay.date), inSameDayAs: normalizedDate)
            }
        }
    }
    
    // Hilfsfunktion für deutschen Monatsnamen
    func deMonthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.monthSymbols[month-1].capitalized
    }
}

struct CalendarGridView: View {
    let year: Int
    let month: Int
    let isHoliday: (Date) -> Bool
    let isAttendedHoliday: (Date) -> Bool
    @ObservedObject var viewModel: VacationViewModel
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    @AppStorage("legendColorPublicHoliday") private var colorPublicHolidayHex: String = "#FF3B30"
    
    var body: some View {
        let calendar = Calendar.current
        let days = daysInMonth(year: year, month: month)
        let firstWeekday = calendar.component(.weekday, from: days.first ?? Date())
        // Apple: 1=Sonntag, 2=Montag, ..., 7=Samstag
        let weekdayIndex = (firstWeekday + 5) % 7 // 0=Montag, 1=Dienstag, ..., 6=Sonntag
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        LazyVGrid(columns: columns, spacing: 2) {
            // Deutsche Wochentage
            ForEach(0..<7, id: \.self) { wd in
                Text(deShortWeekday(wd)).font(.caption2).frame(maxWidth: .infinity)
                    .id("weekday-\(wd)")
            }
            ForEach(0..<weekdayIndex, id: \.self) { idx in
                Color.clear.frame(height: 28)
                    .id("placeholder-\(idx)")
            }
            ForEach(days, id: \.self) { date in
                let isPH = isPublicHoliday(date)
                let relevant = isSchoolHoliday(date) || parentIsChildFreeDay(date: date)
                ZStack {
                    if isPH {
                        RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorPublicHolidayHex)) // Feiertag: rot
                    } else if relevant && isAttendedHoliday(date) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorAttendedHex)) // BETREUT: orange
                    } else if relevant {
                        RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorUnattendedHex)) // UNBETREUT: grau
                    } else {
                        Color.clear
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .foregroundColor(
                            isPH ? .white :
                            relevant && isAttendedHoliday(date) ? .white :
                            relevant ? .white :
                            .primary
                        )
                        .fontWeight(
                            (isPH || (relevant && !isAttendedHoliday(date))) ? .bold : .regular
                        )
                }
                .frame(height: 28)
                .id("day-\(date.timeIntervalSince1970)")
            }
        }
        .padding(.vertical, 8)
    }
    
    func daysInMonth(year: Int, month: Int) -> [Date] {
        let calendar = Calendar.current
        var days: [Date] = []
        let components = DateComponents(year: year, month: month)
        guard let start = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        for day in range {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }
        return days
    }
    
    // Deutsche Kurzbezeichnung für Wochentage (Mo, Di, ...)
    func deShortWeekday(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        guard let symbols = formatter.shortWeekdaySymbols else { return "" }
        // In Deutschland beginnt die Woche mit Montag (index 0)
        // DateFormatter: [So, Mo, Di, Mi, Do, Fr, Sa]
        let germanOrder = [1,2,3,4,5,6,0]
        return symbols[germanOrder[index]]
    }
    
    // Hilfsfunktion, damit die Logik auch im Grid verfügbar ist
    func isSchoolHoliday(_ date: Date) -> Bool {
        viewModel.schoolHolidays.contains { h in
            guard let start = h.startDateObject, let end = h.endDateObject else { return false }
            return (start...end).contains(date)
        }
    }
    
    // Korrekt im Scope: Kind-freie Tage für das Grid
    func parentIsChildFreeDay(date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return viewModel.children.contains { child in
            child.freeDays.contains { freeDay in
                Calendar.current.isDate(Calendar.current.startOfDay(for: freeDay.date), inSameDayAs: normalizedDate)
            }
        }
    }
    
    // Feiertagsprüfung: true, wenn Tag in viewModel.publicHolidays
    func isPublicHoliday(_ date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        // publicHolidays ist [SchoolHoliday]
        for ph in viewModel.publicHolidays {
            if let start = ph.startDateObject, let end = ph.endDateObject {
                if (start...end).contains(normalized) {
                    return true
                }
            }
        }
        return false
    }
}

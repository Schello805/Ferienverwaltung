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
                                    isAttendedHoliday: isAttendedHoliday
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
    
    func isHoliday(_ date: Date) -> Bool {
        viewModel.schoolHolidays.contains { h in
            guard let start = h.startDateObject, let end = h.endDateObject else { return false }
            return (start...end).contains(date)
        }
    }
    
    /// Prüft, ob der Tag ein betreuter Ferientag ist (mind. ein Elternteil hat Urlaub an diesem Ferientag oder einen regelmäßigen freien Tag)
    func isAttendedHoliday(_ date: Date) -> Bool {
        guard isHoliday(date) else { return false }
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let weekday = Calendar.current.component(.weekday, from: normalizedDate) // 1=Sonntag ... 7=Samstag
        let weekdayZeroBased = (weekday + 5) % 7 // 0=Montag ... 6=Sonntag
        return viewModel.parents.contains { parent in
            parent.vacationDays.contains { vac in
                Calendar.current.isDate(Calendar.current.startOfDay(for: vac.date), inSameDayAs: normalizedDate)
            } || parent.fixedWeekdays.contains(weekdayZeroBased)
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
    
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    
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
                ZStack {
                    if isHoliday(date) && isAttendedHoliday(date) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: colorAttendedHex)) // BETREUT: orange
                    } else if isHoliday(date) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: colorUnattendedHex)) // UNBETREUT: grau
                    } else {
                        Color.clear
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .foregroundColor(
                            isHoliday(date) && isAttendedHoliday(date) ? .white :
                            isHoliday(date) ? .white :
                            .primary
                        )
                        .fontWeight(
                            isHoliday(date) && !isAttendedHoliday(date) ? .bold : .regular
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
}

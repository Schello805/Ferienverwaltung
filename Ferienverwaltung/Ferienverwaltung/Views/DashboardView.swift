import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return [current, current + 1]
    }
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard")
                .font(.largeTitle).bold()
                .padding(.bottom, 6)
            // Jahr-Auswahl
            Picker("Jahr", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)
            .onChange(of: selectedYear) {
                viewModel.reloadSchoolHolidays()
            }
            // --- SCHÖNER Statistik-Block ---
            VStack(alignment: .leading, spacing: 12) {
                Text("Jahr: " + String(selectedYear))
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatisticCard(
                        icon: "briefcase",
                        iconColor: .blue,
                        title: "Werktage",
                        value: Text(String(viewModel.workdays(in: selectedYear))),
                        infoText: "Alle Mo-Fr im Jahr, exkl. Wochenenden und Feiertage."
                    )
                    StatisticCard(
                        icon: "sparkles",
                        iconColor: .orange,
                        title: "Feiertage",
                        value: Text(String(viewModel.publicHolidayCount(in: selectedYear))),
                        infoText: "Alle gesetzlichen Feiertage des Jahres."
                    )
                    StatisticCard(
                        icon: "person.2.fill",
                        iconColor: .green,
                        title: "Betreuungszeit (ohne FT)",
                        value: Text(String(viewModel.vacationWorkdaysExcludingHolidays(in: selectedYear))),
                        infoText: "Alle Mo-Fr während Schulferien, exkl. Feiertage und Wochenenden."
                    )
                    StatisticCard(
                        icon: "percent",
                        iconColor: quoteColor(betreuungsquote(selectedYear)),
                        title: "Betreuungsquote",
                        value: Text(String(format: "%.0f%%", betreuungsquote(selectedYear) * 100))
                            .font(.title.bold())
                            .foregroundColor(quoteColor(betreuungsquote(selectedYear))),
                        infoText: "Anteil der durch Eltern abgedeckten Werktage während der Schulferien (Mo–Fr, ohne Feiertage)."
                    )
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(colorScheme == .dark ? 0.3 : 1.0))
            .cornerRadius(16)
            // --- ENDE SCHÖNER Statistik-Block ---
            // --- ELTERN & BETREUUNGSZEIT ---
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.accentColor)
                    Text("Eltern & Betreuungszeit")
                        .font(.headline)
                }
                if viewModel.parents.isEmpty {
                    Text("Keine Elternteile vorhanden.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.parents) { parent in
                        let days = parentVacationDaysDuringSchoolHolidays(parent: parent, year: selectedYear)
                        HStack {
                            Text(parent.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(days) Tage")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(14)
            .padding(.top, 24)
            // --- ENDE ELTERN & BETREUUNGSZEIT ---
            Spacer()
        }
        .padding()
    }
    
    // --- Hilfsfunktion für Betreuungsquote-Farbe ---
    func quoteColor(_ quote: Double) -> Color {
        // 0% = rot, 50% = gelb, 100% = grün
        let clamped = max(0, min(1, quote))
        let hue = 0.0 + (0.33 - 0.0) * clamped // 0=rot, 0.33=grün
        return Color(hue: hue, saturation: 0.8, brightness: 0.95)
    }
}

// --- StatisticCard View ---
struct StatisticCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Text
    let infoText: String
    @State private var showInfo = false
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(iconColor)
                    .padding(8)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .alert(isPresented: $showInfo) {
                    Alert(title: Text(title), message: Text(infoText), dismissButton: .default(Text("OK")))
                }
            }
            value
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            Color(uiColor: UIColor.systemBackground)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

// --- Hilfsfunktion für Eltern-Betreuungszeit ---
extension DashboardView {
    func parentVacationDaysDuringSchoolHolidays(parent: Parent, year: Int) -> Int {
        let calendar = Calendar.current
        let schoolHolidayDays = viewModel.schoolHolidays.flatMap { holiday -> [Date] in
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { return [] }
            var days: [Date] = []
            var current = max(start, calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
            let endDate = min(end, calendar.date(from: DateComponents(year: year, month: 12, day: 31))!)
            while current <= endDate {
                let weekday = calendar.component(.weekday, from: current)
                if weekday != 1 && weekday != 7 { // Mo-Fr
                    days.append(current)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return days
        }
        let uniqueSchoolDays = Set(schoolHolidayDays.map { calendar.startOfDay(for: $0) })
        let parentDays = parent.vacationDays.filter { vac in
            let vacDate = calendar.startOfDay(for: vac.date)
            return uniqueSchoolDays.contains(vacDate)
        }
        return parentDays.count
    }
    
    func betreuungsquote(_ year: Int) -> Double {
        let calendar = Calendar.current
        // Alle betreuungspflichtigen Werktage während Schulferien (Mo-Fr, ohne Feiertage)
        let schoolHolidayDays = viewModel.schoolHolidays.flatMap { holiday -> [Date] in
            guard let start = holiday.startDateObject, let end = holiday.endDateObject else { return [] }
            var days: [Date] = []
            var current = max(start, calendar.date(from: DateComponents(year: year, month: 1, day: 1))!)
            let endDate = min(end, calendar.date(from: DateComponents(year: year, month: 12, day: 31))!)
            while current <= endDate {
                let weekday = calendar.component(.weekday, from: current)
                let isFeiertag = viewModel.publicHolidays.contains { ph in
                    guard let phDate = ph.startDateObject else { return false }
                    return calendar.isDate(phDate, inSameDayAs: current)
                }
                if weekday != 1 && weekday != 7 && !isFeiertag {
                    days.append(calendar.startOfDay(for: current))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return days
        }
        // Stelle sicher, dass alle Vergleichsdaten auf startOfDay normalisiert werden
        let alleFerienWerktage = Set(schoolHolidayDays.map { calendar.startOfDay(for: $0) })
        // Alle durch Eltern abgedeckten Werktage (doppelte Tage nur einfach zählen)
        let abgedeckteTage = Set(viewModel.parents.flatMap { parent in
            parent.vacationDays.compactMap { vac in
                let vacDate = calendar.startOfDay(for: vac.date)
                return alleFerienWerktage.contains(vacDate) ? vacDate : nil
            }
        })
        // Debug-Ausgabe:
        print("[DEBUG] alleFerienWerktage: \(alleFerienWerktage.sorted())")
        print("[DEBUG] abgedeckteTage: \(abgedeckteTage.sorted())")
        guard !alleFerienWerktage.isEmpty else { return 0 }
        return Double(abgedeckteTage.count) / Double(alleFerienWerktage.count)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let demoVM = VacationViewModel()
        DashboardView(viewModel: demoVM)
    }
}

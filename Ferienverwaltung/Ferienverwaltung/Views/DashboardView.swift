import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedParent: Parent? = nil
    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return [current, current + 1]
    }
    @Environment(\.colorScheme) var colorScheme
    @State var showCalendarOverview = false
    var sortedParents: [Parent] {
        viewModel.parents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        NavigationView {
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
                            title: "Werktage (Mo-Fr)",
                            value: Text("\(viewModel.anzahlWerktageImJahr(selectedYear))"),
                            infoText: "Gesamtanzahl der Werktage (Mo-Fr, ohne Wochenenden und Feiertage) im Jahr."
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
                            title: "Betreuungszeit (inkl. Zusatz-Freie Tage)",
                            value: Text("\(viewModel.schoolFreeDaysFromHolidayView(in: selectedYear) + viewModel.totalAdditionalChildFreeDays(in: selectedYear))"),
                            infoText: "Ferien-Werktage plus zusätzliche freie Kindertage, die nicht auf Werktage oder Feiertage fallen."
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
                ParentListView(
                    parents: sortedParents,
                    selectedYear: selectedYear,
                    viewModel: viewModel
                )
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(14)
                .padding(.top, 24)
                // --- Neuer Button unter Eltern-Block ---
                Button(action: {
                    showCalendarOverview = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title2)
                        Text("Kalenderübersicht")
                            .font(.title2.bold())
                            .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color.accentColor.opacity(0.22))
                .cornerRadius(16)
                .padding(.top, 28)
            }
            .padding()
            .sheet(isPresented: $showCalendarOverview) {
                CalendarOverviewView(viewModel: viewModel)
            }
        }
    }
    
    // --- Hilfsfunktion für Betreuungsquote-Farbe ---
    func quoteColor(_ quote: Double) -> Color {
        // 0% = rot, 50% = gelb, 100% = grün
        let clamped = max(0, min(1, quote))
        let hue = 0.0 + (0.33 - 0.0) * clamped // 0=rot, 0.33=grün
        return Color(hue: hue, saturation: 0.8, brightness: 0.95)
    }
}

// Neue View für die Elternliste
struct ParentListView: View {
    let parents: [Parent]
    let selectedYear: Int
    let viewModel: VacationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.accentColor)
                Text("Eltern & Betreuungszeit")
                    .font(.headline)
            }
            if parents.isEmpty {
                Text("Keine Elternteile vorhanden.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(parents.enumerated()), id: \.element.id) { idx, parent in
                    NavigationLink(destination: ParentDetailView(viewModel: viewModel, parent: parent)) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.fromHex(parent.colorHex))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(parent.name)
                                    .font(.headline)
                                Text(parent.relationship.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            // Anzahl der Urlaubstage während Schulferien im gewählten Jahr
                            Text("\(viewModel.vacationWorkdaysExcludingHolidays(for: parent, in: selectedYear)) Tage")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
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
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
                    .padding(6)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
                Button(action: { showInfo.toggle() }) {
                    Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                        .foregroundColor(showInfo ? iconColor : .gray)
                        .font(.title3)
                }
            }
            if showInfo {
                Text(infoText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            value
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 98) // Einheitliche Mindesthöhe für alle Karten
        .padding(8)
        .background(
            Color(uiColor: UIColor.systemBackground)
        )
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 1)
    }
}

// --- Hilfsfunktion für Betreuungsquote ---
extension DashboardView {
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

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import PDFKit

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct CalendarOverviewView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Environment(\.dismiss) private var dismiss
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    @State private var showShareSheet = false
    @State private var pdfURL: URL? = nil
    @State private var shareItem: ShareItem? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                // Abstand zur oberen Kante vergrößern
                Spacer().frame(height: 20)
                // Kompakte, standardisierte Legende
                ColorLegendView()
                .padding(.vertical, 4)
                // Eltern-Legende oben
                ParentLegendView(parents: viewModel.parents)
                .padding(.bottom, 8)
                
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
                            monthView(for: month)
                        }
                    }
                    .padding(.bottom)
                }
                Button(action: exportCalendarAsPDF) {
                    Label("Kalender als PDF exportieren", systemImage: "square.and.arrow.up")
                }
                .padding(.vertical, 8)
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
        .sheet(item: $shareItem, onDismiss: {
            self.shareItem = nil
        }) { item in
            ShareSheet(activityItems: [item.url])
        }
        .navigationTitle("Kalenderübersicht")
    }
    
    // Hilfsfunktion für Monatsansicht, um Compiler zu entlasten
    private func monthView(for month: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deMonthName(for: month))
                .font(.headline)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                CalendarGridView(
                    year: selectedYear,
                    month: month,
                    isHoliday: { date in isHoliday(date) },
                    isAttendedHoliday: { date in isAttendedHoliday(date) },
                    viewModel: viewModel
                )
                .frame(minHeight: 6 * 32, idealHeight: 6 * 36, maxHeight: .infinity)
                .padding(.vertical, 1)
            }
            .padding(4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    func yearRange() -> [Int] {
        // Wieder mehrere Jahre anzeigen
        let current = Calendar.current.component(.year, from: Date())
        return [current - 1, current, current + 1]
    }
    
    /// Ein Tag ist ein "Ferientag ohne Betreuung" wenn Schulferien sind und KEIN Elternteil Urlaub hat, oder wenn ein Kind einen freien Tag hat und KEIN Elternteil Urlaub hat.
    func isHoliday(_ date: Date) -> Bool {
        let isSchoolHoliday = viewModel.schoolHolidays.contains { h in
            let start = h.startDateObject
            let end = h.endDateObject
            // Optional: Prüfe auf Fallback-Werte
            // if start == Date.distantPast || end == Date.distantFuture { return false }
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
    static let deMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    func deMonthName(for month: Int) -> String {
        Self.deMonthFormatter.monthSymbols[month-1].capitalized
    }
    
    // PDFKit-Export
    private func exportCalendarAsPDF() {
        let exportView = CalendarExportView(viewModel: viewModel)
        let renderer = ImageRenderer(content: exportView.frame(width: 1123, height: 794))
        if let image = renderer.uiImage {
            let pdfData = NSMutableData()
            let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
            var mediaBox = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
            pdfContext.beginPDFPage(nil)
            pdfContext.draw(image.cgImage!, in: mediaBox)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docsDir.appendingPathComponent("Kalender.pdf")
            pdfData.write(to: fileURL, atomically: true)
            self.shareItem = ShareItem(url: fileURL)
            print("[DEBUG] PDF erfolgreich im Dokumentenverzeichnis erstellt und ShareSheet wird geöffnet.")
        } else {
            print("[ERROR] PDF-Export fehlgeschlagen: Renderer liefert kein Bild.")
        }
    }
}

// Export-View für PDF-Rendering
struct CalendarExportView: View {
    let viewModel: VacationViewModel
    var body: some View {
        // DIN A4 Querformat: 1123 x 794 pt @ 72dpi
        VStack(spacing: 10) {
            Text("Ferienübersicht")
                .font(.title2)
                .bold()
                .padding(.top, 4)
            Text("Jahr \(Calendar.current.component(.year, from: Date()))")
                .font(.headline)
                .padding(.bottom, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    exportMonthView(for: month)
                }
            }
            Spacer(minLength: 16)
            PDFLegendView(viewModel: viewModel)
                .padding(.top, 8)
            Text("Erstellt mit der iOSApp \"Ferien Buddy\"")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 4)
        }
        .padding(56) // 20mm Rand bei 72dpi ≈ 56pt
        .frame(width: 1123, height: 794)
        .background(Color.white)
    }
    // Hilfsfunktion für Monatsansicht im PDF-Export
    private func exportMonthView(for month: Int) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(deMonthName(for: month))
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { wd in
                        Text(wd)
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 2)
                CalendarGridView(
                    year: Calendar.current.component(.year, from: Date()),
                    month: month,
                    isHoliday: { date in isHoliday(date: date) },
                    isAttendedHoliday: { date in isAttendedHoliday(date: date) },
                    viewModel: viewModel
                )
                .frame(height: 6 * 32)
                .padding(.bottom, 2)
            }
            .padding(4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    // Hilfsfunktion für deutschen Monatsnamen
    static let deMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    func deMonthName(for month: Int) -> String {
        Self.deMonthFormatter.monthSymbols[month-1].capitalized
    }
    static let deShortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    func deShortWeekday(_ index: Int) -> String {
        let mapping = [1,2,3,4,5,6,0] // Mo, Di, Mi, Do, Fr, Sa, So
        let symbols = Self.deShortWeekdayFormatter.veryShortWeekdaySymbols ?? ["So","Mo","Di","Mi","Do","Fr","Sa"]
        return symbols[mapping[index]]
    }
    // Die benötigten Methoden lokal implementieren:
    func isHoliday(date: Date) -> Bool {
        let isSchoolHoliday = viewModel.schoolHolidays.contains { h in
            let start = h.startDateObject
            let end = h.endDateObject
            // Optional: Prüfe auf Fallback-Werte
            // if start == Date.distantPast || end == Date.distantFuture { return false }
            return (start...end).contains(date)
        }
        let isChildFree = isChildFreeDay(date: date)
        let isAttended = isAttendedHoliday(date: date)
        return (isSchoolHoliday || isChildFree) && !isAttended
    }
    func isAttendedHoliday(date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let weekday = Calendar.current.component(.weekday, from: normalizedDate)
        let weekdayZeroBased = (weekday + 5) % 7
        return viewModel.parents.contains { parent in
            parent.vacationDays.contains { vac in
                Calendar.current.isDate(Calendar.current.startOfDay(for: vac.date), inSameDayAs: normalizedDate)
            } || parent.fixedWeekdays.contains(weekdayZeroBased)
        }
    }
    func isChildFreeDay(date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return viewModel.children.contains { child in
            child.freeDays.contains { freeDay in
                Calendar.current.isDate(Calendar.current.startOfDay(for: freeDay.date), inSameDayAs: normalizedDate)
            }
        }
    }
}

// Kompakte Legende für PDF-Export
struct PDFLegendView: View {
    let viewModel: VacationViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 24) {
                legendItem(color: .green, text: "Ferientag (ohne Betreuung)")
                legendItem(color: .yellow, text: "Ferientag (mit Betreuung)")
                legendItem(color: .red, text: "Feiertag")
            }
            if !viewModel.parents.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(zip(viewModel.parents.map { Color(hex: $0.colorHex) }, viewModel.parents.map { $0.name })), id: \.1) { color, name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 14, height: 14)
                            Text(name)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 18, height: 18)
            Text(text)
                .font(.caption)
        }
    }
}

// Eltern-Legende
struct ParentLegendView: View {
    let parents: [Parent]
    var body: some View {
        HStack(spacing: 16) {
            ForEach(parents, id: \.name) { parent in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: parent.colorHex))
                        .frame(width: 14, height: 14)
                    Text(parent.name)
                        .font(.caption)
                }
            }
        }
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

    // --- Hilfsfunktionen ---
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
    static let deShortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    func deShortWeekday(_ index: Int) -> String {
        let mapping = [1,2,3,4,5,6,0] // Mo, Di, Mi, Do, Fr, Sa, So
        let symbols = Self.deShortWeekdayFormatter.veryShortWeekdaySymbols ?? ["So","Mo","Di","Mi","Do","Fr","Sa"]
        return symbols[mapping[index]]
    }
    func isPublicHoliday(_ date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        for ph in viewModel.publicHolidays {
            let start = ph.startDateObject
            let end = ph.endDateObject
            // Optional: Prüfe auf Fallback-Werte
            // if start == Date.distantPast || end == Date.distantFuture { continue }
            if (start...end).contains(normalized) {
                return true
            }
        }
        return false
    }
    func isSchoolHoliday(_ date: Date) -> Bool {
        viewModel.schoolHolidays.contains { h in
            let start = h.startDateObject
            let end = h.endDateObject
            // Optional: Prüfe auf Fallback-Werte
            // if start == Date.distantPast || end == Date.distantFuture { return false }
            return (start...end).contains(date)
        }
    }
    func parentIsChildFreeDay(date: Date) -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return viewModel.children.contains { child in
            child.freeDays.contains { freeDay in
                Calendar.current.isDate(Calendar.current.startOfDay(for: freeDay.date), inSameDayAs: normalizedDate)
            }
        }
    }
    func parentsOnVacation(on date: Date) -> [Parent] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return viewModel.parents.filter { parent in
            parent.vacationDays.contains { vac in
                Calendar.current.isDate(Calendar.current.startOfDay(for: vac.date), inSameDayAs: normalizedDate)
            }
        }
    }

    // Neue Hilfsfunktion für Wochenaufteilung
    func buildWeeksArray(from allDays: [Date?]) -> [[Date?]] {
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []
        for day in allDays {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        return weeks
    }

    var body: some View {
        let calendar = Calendar.current
        let days = daysInMonth(year: year, month: month)
        let firstWeekday = calendar.component(.weekday, from: days.first ?? Date())
        let weekdayIndex = (firstWeekday + 5) % 7 // 0=Montag ... 6=Sonntag
        let allDays: [Date?] = Array(repeating: nil, count: weekdayIndex) + days
        let weeks = buildWeeksArray(from: allDays)
        VStack(spacing: 8) {
            // Wochentagsleiste (Mo–So)
            HStack(spacing: 2) {
                ForEach(0..<7, id: \ .self) { wd in
                    Text(deShortWeekday(wd))
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            // Kalenderwochen mit Farben und Markierungen
            ForEach(0..<6, id: \ .self) { weekIdx in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \ .self) { dayIdx in
                        let date = (weekIdx < weeks.count && dayIdx < weeks[weekIdx].count) ? weeks[weekIdx][dayIdx] : nil
                        if let date = date {
                            let isPH = isPublicHoliday(date)
                            let isHoliday = isHoliday(date)
                            let isAtt = isAttendedHoliday(date)
                            let parents = parentsOnVacation(on: date)
                            ZStack {
                                if isPH {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.fromHex(colorPublicHolidayHex))
                                        .frame(height: 32)
                                } else if isHoliday {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.fromHex(colorUnattendedHex))
                                        .frame(height: 32)
                                } else if isAtt {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.fromHex(colorAttendedHex))
                                        .frame(height: 32)
                                } else if !parents.isEmpty {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: parents.first?.colorHex ?? "#1976D2").opacity(0.5))
                                        .frame(height: 32)
                                }
                                Text("\(calendar.component(.day, from: date))")
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .font(.body)
                                    .foregroundColor(isPH ? .white : .primary)
                                if !parents.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(parents.prefix(2).indices, id: \ .self) { idx in
                                            Circle()
                                                .fill(Color(hex: parents[idx].colorHex))
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: 16, alignment: .bottom)
                                    .offset(y: 8)
                                }
                            }
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    // ... restliche Hilfsfunktionen ...
}

// Hilfskomponente für das Teilen/Exportieren
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// Präsentiere das ShareSheet direkt über einen UIViewControllerRepresentable (ShareSheetPresenter) im .background-Modifier, statt über .sheet
import UIKit

struct ShareSheetPresenter: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Hilfs-Extension für Hex-Farben
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

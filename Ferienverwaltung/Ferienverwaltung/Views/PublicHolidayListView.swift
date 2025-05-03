import SwiftUI

struct PublicHolidayListView: View {
    @State private var holidays: [SchoolHoliday] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Verwende einen statischen Formatter für Performance und Sicherheit
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    var body: some View {
        let dateFormatter = Self.dateFormatter
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Hinweistext ganz oben, außerhalb der List
                Text("Hinweis: In der Ferienberechnung werden ausschließlich bundesweite und landesweite Feiertage berücksichtigt. Regionale Feiertage (z.B. nur in einzelnen Gemeinden) werden NICHT einbezogen.")
                    .font(.callout)
                    .foregroundColor(.orange)
                    .padding([.horizontal, .top])
                Group {
                    if isLoading {
                        ProgressView("Lade Feiertage...")
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else if holidays.isEmpty {
                        Text("Keine Feiertage gefunden.")
                    } else {
                        List(holidays) { holiday in
                            VStack(alignment: .leading) {
                                Text(holiday.holidayName)
                                    .font(.headline)
                                let start = holiday.startDateObject
                                let end = holiday.endDateObject
                                // Optional: Prüfe auf Fallback-Werte
                                // if start == Date.distantPast || end == Date.distantFuture { return }
                                Text("\(dateFormatter.string(from: start)) bis \(dateFormatter.string(from: end))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Feiertage")
        }
        .onAppear(perform: loadData)
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        holidays = StorageService.shared.loadPublicHolidays()
        isLoading = false
    }
}

struct PublicHolidayListView_Previews: PreviewProvider {
    static var previews: some View {
        PublicHolidayListView()
    }
}

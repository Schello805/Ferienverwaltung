import SwiftUI

struct SchoolHolidayListView: View {
    @State private var holidays: [SchoolHoliday] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Verwende einen statischen Formatter für Performance und Sicherheit
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    var body: some View {
        let dateFormatter = Self.dateFormatter
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Lade Schulferien...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else if holidays.isEmpty {
                    Text("Keine Schulferien gefunden.")
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
            .navigationTitle("Schulferien")
        }
        .onAppear(perform: loadData)
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        holidays = StorageService.shared.loadSchoolHolidays()
        isLoading = false
    }
}

struct SchoolHolidayListView_Previews: PreviewProvider {
    static var previews: some View {
        SchoolHolidayListView()
    }
}

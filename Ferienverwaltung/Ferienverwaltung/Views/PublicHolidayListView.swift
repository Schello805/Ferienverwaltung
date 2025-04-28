import SwiftUI

struct PublicHolidayListView: View {
    @State private var holidays: [SchoolHoliday] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.locale = Locale(identifier: "de_DE")
            return formatter
        }()
        NavigationView {
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
                            if let start = holiday.startDateObject, let end = holiday.endDateObject {
                                Text("\(dateFormatter.string(from: start)) bis \(dateFormatter.string(from: end))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(holiday.start) bis \(holiday.end)")
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

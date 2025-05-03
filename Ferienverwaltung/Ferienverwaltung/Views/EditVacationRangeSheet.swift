import SwiftUI

struct EditVacationRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date
    let isEditing: Bool
    let onSave: (Date, Date) -> Void
    @ObservedObject var viewModel: VacationViewModel

    init(initialStart: Date, initialEnd: Date, isEditing: Bool = false, onSave: @escaping (Date, Date) -> Void, viewModel: VacationViewModel) {
        _startDate = State(initialValue: initialStart)
        _endDate = State(initialValue: initialEnd)
        self.isEditing = isEditing
        self.onSave = onSave
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(isEditing ? "Urlaub bearbeiten" : "Urlaub hinzufügen")
                    .font(.title2).bold()
                    .padding(.top, 24)
                Divider()
                VStack(spacing: 16) {
                    CustomHolidayDatePicker(
                        title: "Von",
                        selection: $startDate,
                        publicHolidays: viewModel.publicHolidays
                    )
                    CustomHolidayDatePicker(
                        title: "Bis",
                        selection: $endDate,
                        publicHolidays: viewModel.publicHolidays
                    )
                }
                .padding(.horizontal, 16)
                Spacer(minLength: 16)
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Abbrechen")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                    Button(action: {
                        if startDate <= endDate {
                            onSave(startDate, endDate)
                            dismiss()
                        }
                    }) {
                        Text(isEditing ? "Speichern" : "Hinzufügen")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(startDate > endDate)
                }
                .padding([.horizontal, .bottom])
            }
        }
    }
}

// MARK: - Custom DatePicker mit Feiertagsanzeige
struct CustomHolidayDatePicker: View {
    let title: String
    @Binding var selection: Date
    let publicHolidays: [SchoolHoliday]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .padding(.leading, 6)
            ZStack(alignment: .topTrailing) {
                DatePicker("", selection: $selection, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    .labelsHidden()
                    .frame(maxWidth: 330, maxHeight: 320) 
                if let holiday = holidayOn(selection) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(holiday.holidayName)
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Color(.systemYellow).opacity(0.85))
                            .cornerRadius(7)
                            .shadow(radius: 2)
                    }
                    .padding([.top, .trailing], 4)
                }
            }
        }
    }

    private func holidayOn(_ date: Date) -> SchoolHoliday? {
        let calendar = Calendar.current
        return publicHolidays.first(where: { h in
            let start = calendar.startOfDay(for: h.startDateObject)
            let end = calendar.startOfDay(for: h.endDateObject)
            return (start...end).contains(calendar.startOfDay(for: date))
        })
    }
}

// Preview
struct EditVacationRangeSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditVacationRangeSheet(initialStart: Date(), initialEnd: Date().addingTimeInterval(86400), isEditing: false, onSave: { _, _ in }, viewModel: VacationViewModel())
    }
}

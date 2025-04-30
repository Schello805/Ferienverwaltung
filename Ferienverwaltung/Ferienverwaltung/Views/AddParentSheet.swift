import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct AddParentSheet: View {
    @ObservedObject var viewModel: VacationViewModel
    var onSave: ((Parent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var relationship: Relationship = .mother
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var color: Color = .blue
    @State private var symbolName: String = "person.fill"
    @State private var vacationDays: [VacationDay] = []
    @State private var fixedWeekdays: [Int] = []
    @State private var showAddVacationRangeSheet = false

    // Farben für die Kalenderdarstellung zentral via AppStorage
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    @AppStorage("legendColorCare") private var colorCareHex: String = "#34C759"

    private func parentImageSection() -> some View {
        VStack {
            ParentImageView(image: profileImage, color: color)
            Button("Bild wählen") { showImagePicker = true }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.15), Color.clear]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .edgesIgnoringSafeArea(.top)
            NavigationView {
                buildForm()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let newParent = Parent(
                            name: name,
                            relationship: relationship,
                            vacationDays: vacationDays,
                            profileImageData: profileImage?.jpegData(compressionQuality: 0.8),
                            colorHex: color.toHex() ?? "#007AFF",
                            symbolName: symbolName,
                            fixedWeekdays: fixedWeekdays
                        )
                        viewModel.parents.append(newParent)
                        onSave?(newParent)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showAddVacationRangeSheet) {
                VacationRangePicker(onSave: { start, end in
                    let days = createVacationDays(from: start, to: end)
                    vacationDays.append(contentsOf: days)
                }, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func buildForm() -> some View {
        Form {
            Section {
                parentImageSection()
            }
            Section(header: Text("Name")) {
                TextField("Name", text: $name)
            }
            Section(header: Text("Beziehung")) {
                Picker("Beziehung", selection: $relationship) {
                    ForEach(Relationship.allCases, id: \.self) { rel in
                        Text(rel.rawValue).tag(rel)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text("Farbe")) {
                ColorPicker("Farbe wählen", selection: $color)
            }
            Section(header: Text("Urlaubstage")) {
                let vacationRanges = calculateVacationRanges(from: vacationDays)
                if vacationRanges.isEmpty {
                    Text("Noch keine Urlaubszeiträume eingetragen")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(vacationRanges, id: \ .self) { range in
                        HStack {
                            Text("\(dateFormatter.string(from: range.start)) – \(dateFormatter.string(from: range.end))")
                            Spacer()
                            Button(role: .destructive) {
                                deleteVacationRange(range)
                            } label: {
                                Image(systemName: "trash")
                            }
                            Button {
                                editVacationRange(range)
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                }
                Button("Urlaubszeitraum hinzufügen") {
                    showAddVacationRangeSheet = true
                }
            }
            Section(header: Text("Feste Betreuungstage")) {
                Text("Wähle beliebig viele feste Wochentage, an denen dieser Elternteil regelmäßig zu Hause ist und die Kinder betreuen kann.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    let days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                    let weekdayIndices = [0, 1, 2, 3, 4, 5, 6] // Mo=0, So=6
                    ForEach(weekdayIndices, id: \.self) { idx in
                        Button(action: {
                            if let index = fixedWeekdays.firstIndex(of: idx) {
                                fixedWeekdays.remove(at: index)
                            } else {
                                fixedWeekdays.append(idx)
                            }
                        }) {
                            Text(days[idx])
                                .padding(8)
                                .background(fixedWeekdays.contains(idx) ? Color.blue : Color(.systemGray5))
                                .foregroundColor(fixedWeekdays.contains(idx) ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func createVacationDays(from start: Date, to end: Date) -> [VacationDay] {
        var days: [VacationDay] = []
        var date = Calendar.current.startOfDay(for: start)
        let endDate = Calendar.current.startOfDay(for: end)
        while date <= endDate {
            days.append(VacationDay(date: date, type: .vacation))
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }
}

struct VacationRangePicker: View {
    var onSave: (Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VacationViewModel
    var initialStartDate: Date = Date()
    var initialEndDate: Date = Date()
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectingStart = true
    @State private var fixedWeekdays: [Int] = []

    init(onSave: @escaping (Date, Date) -> Void, viewModel: VacationViewModel, initialStartDate: Date = Date(), initialEndDate: Date = Date()) {
        self.onSave = onSave
        self.viewModel = viewModel
        self.initialStartDate = initialStartDate
        self.initialEndDate = initialEndDate
        _startDate = State(initialValue: initialStartDate)
        _endDate = State(initialValue: initialEndDate)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Urlaubszeitraum auswählen")
                    .font(.headline)
                    .padding(.top, 8)
                ColorLegendView()
                .padding(.vertical, 4)
                CalendarMonthRangeSelector(
                    viewModel: viewModel,
                    selectedStart: $startDate,
                    selectedEnd: $endDate,
                    selectingStart: $selectingStart,
                    fixedWeekdays: $fixedWeekdays
                )
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(startDate, endDate)
                        dismiss()
                    }
                    .disabled(startDate > endDate)
                }
            }
        }
    }
}

struct CalendarMonthRangeSelector: View {
    @ObservedObject var viewModel: VacationViewModel
    @Binding var selectedStart: Date
    @Binding var selectedEnd: Date
    @Binding var selectingStart: Bool
    @Binding var fixedWeekdays: [Int]
    @State private var currentMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var currentYear: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { prevMonth() }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text("\(deMonthName(for: currentMonth)) \(currentYear.description.replacingOccurrences(of: ".", with: ""))")
                    .font(.headline)
                Spacer()
                Button(action: { nextMonth() }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            CalendarGridRangeView(
                year: currentYear,
                month: currentMonth,
                isHoliday: { isSchoolHoliday($0) },
                isPublicHoliday: { isPublicHoliday($0) },
                isSelected: { isSelected($0) },
                isInRange: { isInRange($0) },
                isCareDay: { weekdayIsCareDay($0) },
                onDayTap: { tappedDate in
                    if selectingStart {
                        selectedStart = tappedDate
                        if selectedEnd < selectedStart { selectedEnd = selectedStart }
                        selectingStart = false
                    } else {
                        selectedEnd = tappedDate
                        if selectedEnd < selectedStart { swap(&selectedStart, &selectedEnd) }
                        selectingStart = true
                    }
                }
            )
        }
    }

    func prevMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }
    func nextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }
    func isSchoolHoliday(_ date: Date) -> Bool {
        viewModel.schoolHolidays.contains { h in
            guard let start = h.startDateObject, let end = h.endDateObject else { return false }
            return (start...end).contains(date)
        }
    }
    func isPublicHoliday(_ date: Date) -> Bool {
        viewModel.publicHolidays.contains { h in
            guard let start = h.startDateObject else { return false }
            return Calendar.current.isDate(start, inSameDayAs: date)
        }
    }
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedStart) || Calendar.current.isDate(date, inSameDayAs: selectedEnd)
    }
    func isInRange(_ date: Date) -> Bool {
        let start = Calendar.current.startOfDay(for: selectedStart)
        let end = Calendar.current.startOfDay(for: selectedEnd)
        return (start...end).contains(Calendar.current.startOfDay(for: date))
    }
    func deMonthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.monthSymbols[month-1].capitalized
    }
    func weekdayIsCareDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) - 1 // Mo=0
        return fixedWeekdays.contains(weekday)
    }
}

struct CalendarGridRangeView: View {
    let year: Int
    let month: Int
    let isHoliday: (Date) -> Bool
    let isPublicHoliday: (Date) -> Bool
    let isSelected: (Date) -> Bool
    let isInRange: (Date) -> Bool
    let isCareDay: (Date) -> Bool
    let onDayTap: (Date) -> Void
    
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#B0B0B0"
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFA500"
    @AppStorage("legendColorCare") private var colorCareHex: String = "#34C759"
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let calendar = Calendar.current
        let days = daysInMonth(year: year, month: month)
        let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let weekdayOffset = (calendar.component(.weekday, from: firstDayOfMonth) + 5) % 7 // Mo=0
        VStack(spacing: 6) {
            HStack {
                ForEach(["Mo.", "Di.", "Mi.", "Do.", "Fr.", "Sa.", "So."], id: \ .self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            let rows = (days.count + weekdayOffset + 6) / 7
            ForEach(0..<rows, id: \ .self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \ .self) { col in
                        let idx = row * 7 + col
                        if idx < weekdayOffset || idx - weekdayOffset >= days.count {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                        } else {
                            let date = days[idx - weekdayOffset]
                            ZStack {
                                if isHoliday(date) && !isCareDay(date) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorUnattendedHex))
                                } else if isHoliday(date) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorAttendedHex))
                                } else if isCareDay(date) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.fromHex(colorCareHex))
                                } else {
                                    Color.clear
                                }
                                if isSelected(date) || isInRange(date) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(colorScheme == .dark ? Color.white : Color.blue, lineWidth: 2)
                                }
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.body)
                                    .foregroundColor(
                                        (isHoliday(date) || isCareDay(date)) ? (colorScheme == .dark ? .black : .primary) : .primary
                                    )
                            }
                            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                            .contentShape(Rectangle())
                            .onTapGesture { onDayTap(date) }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(colorScheme == .dark ? Color(.systemGray5).opacity(0.25) : Color.white)
        .cornerRadius(8)
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
}

extension AddParentSheet {
    func calculateVacationRanges(from days: [VacationDay]) -> [DateInterval] {
        let sortedDates = days.map { $0.date }.sorted()
        var ranges: [DateInterval] = []
        guard var rangeStart = sortedDates.first else { return [] }
        var previousDate = rangeStart
        let calendar = Calendar.current
        for date in sortedDates.dropFirst() {
            if !calendar.isDate(date, inSameDayAs: previousDate) &&
                calendar.dateComponents([.day], from: previousDate, to: date).day! > 1 {
                ranges.append(DateInterval(start: rangeStart, end: previousDate))
                rangeStart = date
            }
            previousDate = date
        }
        if !sortedDates.isEmpty {
            ranges.append(DateInterval(start: rangeStart, end: previousDate))
        }
        return ranges
    }
    
    func deleteVacationRange(_ range: DateInterval) {
        var current = range.start
        let calendar = Calendar.current
        while current <= range.end {
            if let idx = vacationDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                vacationDays.remove(at: idx)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
    }
    
    func editVacationRange(_ range: DateInterval) {
        // Entferne alten Zeitraum und öffne Sheet mit vorbelegten Daten
        deleteVacationRange(range)
        showAddVacationRangeSheet = true
        // Hinweis: Für echtes Vorbelegen müsste VacationRangePicker angepasst werden.
    }
    
    var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "de_DE")
        return df
    }
    
    func weekdayIsCareDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) - 1 // Mo=0
        return fixedWeekdays.contains(weekday)
    }
}

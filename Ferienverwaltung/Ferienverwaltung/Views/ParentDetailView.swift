import SwiftUI

// --- Color(hex:) und toHex() Extension entfernt. Die zentrale Extension befindet sich jetzt in Color+Hex.swift ---
struct ParentDetailView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State var parent: Parent
    @State private var showEditSheet = false
    @State private var showAddVacationRange = false
    @State private var vacationRangeStart = Date()
    @State private var vacationRangeEnd = Date()
    @State private var editingVacationRange: DateInterval? = nil

    private static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        // Hilfsvariablen VOR dem ersten View deklarieren!
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.fromHex(parent.colorHex), lineWidth: 5)
                        .frame(width: 110, height: 110)
                    if let data = parent.profileImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.fromHex(parent.colorHex))
                            .frame(width: 100, height: 100)
                    }
                }
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.fromHex(parent.colorHex))
                            .frame(width: 16, height: 16)
                        Text(parent.colorHex)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(spacing: 2) {
                    Text(parent.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(parent.relationship.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Divider().padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feste Betreuungstage")
                        .font(.subheadline.bold())
                    Text("Diese Tage können im Bearbeiten-Dialog angepasst werden.")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 2)
                    if parent.fixedWeekdays.isEmpty {
                        Text("Keine festen Betreuungstage hinterlegt.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            let days = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
                            let weekdayIndices = [0, 1, 2, 3, 4, 5, 6]
                            ForEach(weekdayIndices, id: \.self) { idx in
                                if parent.fixedWeekdays.contains(idx) {
                                    Text(days[idx])
                                        .padding(8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                Divider().padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Urlaubszeiträume")
                        .font(.subheadline.bold())
                    Button(action: {
                        vacationRangeStart = Date()
                        vacationRangeEnd = Date()
                        editingVacationRange = nil
                        showAddVacationRange = true
                    }) {
                        Label("Urlaubszeitraum hinzufügen", systemImage: "plus")
                    }
                    .padding(.vertical, 4)
                    let vacationRanges = calculateVacationRanges(from: parent.vacationDays)
                    if vacationRanges.isEmpty {
                        Text("Noch keine Urlaubszeiträume eingetragen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vacationRanges, id: \.self) { range in
                            HStack(spacing: 16) {
                                Text("\(Self.germanDateFormatter.string(from: range.start)) – \(Self.germanDateFormatter.string(from: range.end))")
                                    .font(.body)
                                let yearCounts = workdaysPerYear(start: range.start, end: range.end)
                                let yearStrings = yearCounts.keys.sorted().map { "\(yearCounts[$0] ?? 0) Werktage in \($0)" }
                                Text("(" + yearStrings.joined(separator: ", ") + ")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    editVacationRange(range)
                                }) {
                                    Image(systemName: "pencil")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                                Button(role: .destructive, action: {
                                    deleteVacationRange(range)
                                }) {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(minHeight: 48)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") {
                    showEditSheet = true
                }
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                EditParentSheet(viewModel: viewModel, parent: parent) { updatedParent in
                    parent = updatedParent
                    if let idx = viewModel.parents.firstIndex(where: { $0.id == updatedParent.id }) {
                        viewModel.parents[idx] = updatedParent
                    }
                    showEditSheet = false
                }
            }
        }
        .sheet(isPresented: $showAddVacationRange) {
            VStack(spacing: 20) {
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.gray.opacity(0.3))
                    .padding(.top, 8)
                Text(editingVacationRange == nil ? "Neuen Urlaubszeitraum hinzufügen" : "Urlaubszeitraum bearbeiten")
                    .font(.headline)
                VStack(spacing: 12) {
                    DatePicker("Von", selection: $vacationRangeStart, in: ...Date.distantFuture, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                    DatePicker("Bis", selection: $vacationRangeEnd, in: vacationRangeStart...Date.distantFuture, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                }
                HStack(spacing: 16) {
                    Button("Abbrechen", role: .cancel) {
                        // Reset Bearbeitungsmodus ohne zu löschen
                        showAddVacationRange = false
                        // Wichtig: KEINE Löschlogik!
                        editingVacationRange = nil
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Speichern") {
                        let calendar = Calendar.current
                        if let oldRange = editingVacationRange {
                            var current = calendar.startOfDay(for: oldRange.start)
                            let end = calendar.startOfDay(for: oldRange.end)
                            while current <= end {
                                if let idx = parent.vacationDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                                    parent.vacationDays.remove(at: idx)
                                }
                                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                            }
                        }
                        var current = calendar.startOfDay(for: vacationRangeStart)
                        let end = calendar.startOfDay(for: vacationRangeEnd)
                        while current <= end {
                            if !parent.vacationDays.contains(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                                parent.vacationDays.append(VacationDay(date: current, type: .vacation))
                            }
                            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                        }
                        if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
                            viewModel.parents[idx] = parent
                        }
                        showAddVacationRange = false
                        editingVacationRange = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
    
    func editVacationRange(_ range: DateInterval) {
        vacationRangeStart = range.start
        vacationRangeEnd = range.end
        editingVacationRange = range
        showAddVacationRange = true
    }
    
    func deleteVacationRange(_ range: DateInterval) {
        let calendar = Calendar.current
        var current = calendar.startOfDay(for: range.start)
        let end = calendar.startOfDay(for: range.end)
        while current <= end {
            if let idx = parent.vacationDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                parent.vacationDays.remove(at: idx)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
            viewModel.parents[idx] = parent
        }
    }
    
    func calculateVacationRanges(from days: [VacationDay]) -> [DateInterval] {
        guard !days.isEmpty else { return [] }
        let calendar = Calendar.current
        let sorted = days.sorted { $0.date < $1.date }
        var result: [DateInterval] = []
        var start = sorted[0].date
        var end = sorted[0].date
        for i in 1..<sorted.count {
            let prev = sorted[i - 1].date
            let curr = sorted[i].date
            if calendar.date(byAdding: .day, value: 1, to: prev) == curr {
                end = curr
            } else {
                result.append(DateInterval(start: start, end: end))
                start = curr
                end = curr
            }
        }
        result.append(DateInterval(start: start, end: end))
        return result
    }
    
    // Liefert ein Dictionary: Jahr -> Werktage in diesem Jahr
    private func workdaysPerYear(start: Date, end: Date) -> [Int: Int] {
        let calendar = Calendar.current
        let publicHolidayDates: Set<Date> = Set(viewModel.publicHolidays.flatMap { ph -> [Date] in
            guard let s = ph.startDateObject, let e = ph.endDateObject else { return [] }
            var dates: [Date] = []
            var current = calendar.startOfDay(for: s)
            let endDay = calendar.startOfDay(for: e)
            while current <= endDay {
                dates.append(current)
                if let next = calendar.date(byAdding: .day, value: 1, to: current) {
                    current = next
                } else {
                    break
                }
            }
            return dates
        })
        var yearCounts: [Int: Int] = [:]
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            let weekday = calendar.component(.weekday, from: current)
            let isWorkday = weekday >= 2 && weekday <= 6 // Mo-Fr
            let isHoliday = publicHolidayDates.contains(current)
            if isWorkday && !isHoliday {
                let year = calendar.component(.year, from: current)
                yearCounts[year, default: 0] += 1
            }
            if let next = calendar.date(byAdding: .day, value: 1, to: current) {
                current = next
            } else {
                break
            }
        }
        return yearCounts
    }

}

struct ParentDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let demoParent = Parent(
            name: "Max Mustermann",
            relationship: .father,
            vacationDays: [],
            profileImageData: nil,
            colorHex: "#007AFF",
            symbolName: "person.fill"
        )
        ParentDetailView(viewModel: VacationViewModel(), parent: demoParent)
    }
}

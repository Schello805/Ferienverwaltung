import SwiftUI

struct ParentCalendarView: View {
    let parent: Parent
    @ObservedObject var viewModel: VacationViewModel
    @Environment(\.calendar) var calendar
    @State private var showingAddVacation = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingEditVacation = false
    @State private var editingRange: DateInterval? = nil
    @State private var editStartDate = Date()
    @State private var editEndDate = Date()
    @State private var showDeleteAlert = false
    @State private var pendingDeleteRange: DateInterval? = nil
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
    
    var body: some View {
        List {
            Section {
                Button(action: { showingAddVacation = true }) {
                    Label("Urlaubszeitraum hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }
            
            if !parent.vacationDays.isEmpty {
                let ranges = calculateDateRanges()
                let groupedByYear = Dictionary(grouping: ranges) { range in
                    calendar.component(.year, from: range.start)
                }
                
                ForEach(groupedByYear.keys.sorted(), id: \.self) { year in
                    Section("Urlaubszeiträume \(String(year))") {
                        if let yearRanges = groupedByYear[year] {
                            ForEach(yearRanges, id: \.self) { range in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(dateFormatter.string(from: range.start))")
                                        Text("bis \(dateFormatter.string(from: range.end))")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(calendar.dateComponents([.day], from: range.start, to: range.end).day! + 1) Tage")
                                        .foregroundColor(.blue)
                                }
                                .swipeActions {
                                    Button {
                                        editingRange = range
                                        editStartDate = range.start
                                        editEndDate = range.end
                                        showingEditVacation = true
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                    Button(role: .destructive) {
                                        pendingDeleteRange = range
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Zusammenfassung") {
                    ForEach(groupedByYear.keys.sorted(), id: \.self) { year in
                        if let yearRanges = groupedByYear[year] {
                            let totalDays = yearRanges.reduce(0) { sum, range in
                                sum + (calendar.dateComponents([.day], from: range.start, to: range.end).day! + 1)
                            }
                            Text("\(String(year)): \(totalDays) Urlaubstage")
                                .font(.subheadline)
                        }
                    }
                    Text("Gesamt: \(parent.vacationDays.count) Urlaubstage")
                        .font(.headline)
                }
            }
        }
        .navigationTitle("\(parent.name)'s Urlaub")
        .sheet(isPresented: $showingAddVacation) {
            NavigationView {
                Form {
                    DatePicker("Von", selection: $startDate, displayedComponents: .date)
                    DatePicker("Bis", selection: $endDate, displayedComponents: .date)
                }
                .navigationTitle("Urlaub hinzufügen")
                .navigationBarItems(
                    leading: Button("Abbrechen") {
                        showingAddVacation = false
                    },
                    trailing: Button("Hinzufügen") {
                        addVacationRange()
                        showingAddVacation = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingEditVacation) {
            if let range = editingRange {
                NavigationView {
                    Form {
                        DatePicker("Von", selection: $editStartDate, displayedComponents: .date)
                        DatePicker("Bis", selection: $editEndDate, displayedComponents: .date)
                    }
                    .navigationTitle("Urlaub bearbeiten")
                    .navigationBarItems(
                        leading: Button("Abbrechen") {
                            showingEditVacation = false
                        },
                        trailing: Button("Speichern") {
                            // Alten Zeitraum löschen
                            deleteDateRange(range)
                            // Neuen Zeitraum hinzufügen
                            var current = calendar.startOfDay(for: editStartDate)
                            let end = calendar.startOfDay(for: editEndDate)
                            while current <= end {
                                if !isDateSelected(current) {
                                    viewModel.addVacationDay(for: parent, date: current, type: .vacation)
                                }
                                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                            }
                            showingEditVacation = false
                        }.disabled(editStartDate > editEndDate)
                    )
                }
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Urlaub löschen"),
                message: Text("Möchtest du diesen Urlaubszeitraum wirklich löschen?"),
                primaryButton: .destructive(Text("Löschen")) {
                    if let range = pendingDeleteRange {
                        deleteDateRange(range)
                    }
                    pendingDeleteRange = nil
                },
                secondaryButton: .cancel {
                    pendingDeleteRange = nil
                }
            )
        }
    }
    
    private func addVacationRange() {
        guard startDate <= endDate else { return }
        
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        while current <= end {
            if !isDateSelected(current) {
                viewModel.addVacationDay(for: parent, date: current, type: .vacation)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
    }
    
    private func isDateSelected(_ date: Date) -> Bool {
        parent.vacationDays.contains { day in
            calendar.isDate(day.date, inSameDayAs: date)
        }
    }
    
    private func calculateDateRanges() -> [DateInterval] {
        let sortedDates = parent.vacationDays.map { $0.date }.sorted()
        var ranges: [DateInterval] = []
        
        guard var rangeStart = sortedDates.first else { return [] }
        var previousDate = rangeStart
        
        for date in sortedDates.dropFirst() {
            if !calendar.isDate(date, inSameDayAs: previousDate) &&
                calendar.dateComponents([.day], from: previousDate, to: date).day! > 1 {
                ranges.append(DateInterval(start: rangeStart, end: previousDate))
                rangeStart = date
            }
            previousDate = date
        }
        
        // Add the last range
        if !sortedDates.isEmpty {
            ranges.append(DateInterval(start: rangeStart, end: previousDate))
        }
        
        return ranges
    }
    
    private func deleteDateRange(_ range: DateInterval) {
        var current = range.start
        while current <= range.end {
            viewModel.removeVacationDay(for: parent, date: current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
    }
}

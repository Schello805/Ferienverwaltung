import SwiftUI
import Foundation

// ParentCalendarView anzeigen: Übersicht und Verwaltung der Urlaubszeiträume
struct ParentDetailView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State var parent: Parent
    @State private var showEditSheet = false
    @State private var showAddVacationRange = false
    @State private var editingVacationRange: IdentifiableDateInterval? = nil
    @State private var vacationRangeStart = Date()
    @State private var vacationRangeEnd = Date()
    @State private var showDeleteAlert = false
    @State private var pendingDeleteRange: DateInterval? = nil
    static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
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
                        let days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
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
                Divider().padding(.vertical, 8)
                // --- Urlaubszeiträume Liste ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Urlaubszeiträume")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            vacationRangeStart = Date()
                            vacationRangeEnd = Date()
                            showAddVacationRange = true
                        }) {
                            Label("Hinzufügen", systemImage: "plus.circle")
                        }
                    }
                    if parent.vacationDays.isEmpty {
                        Text("Keine Urlaubszeiträume vorhanden.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(groupedVacationIntervals(for: parent.vacationDays)) { idInterval in
                            let interval = idInterval.interval
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Self.germanDateFormatter.string(from: interval.start))")
                                        .font(.headline)
                                    Text("bis \(Self.germanDateFormatter.string(from: interval.end))")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    editingVacationRange = idInterval
                                    vacationRangeStart = interval.start
                                    vacationRangeEnd = interval.end
                                    showAddVacationRange = false
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.accentColor)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .clipShape(Circle())
                                }
                                Button(role: .destructive, action: {
                                    pendingDeleteRange = interval
                                    showDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .clipShape(Circle())
                                }
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
                Divider().padding(.vertical, 8)
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
            EditVacationRangeSheet(initialStart: vacationRangeStart, initialEnd: vacationRangeEnd, isEditing: false, onSave: { newStart, newEnd in
                // Füge alle Tage im Bereich hinzu
                let calendar = Calendar.current
                var current = calendar.startOfDay(for: newStart)
                let end = calendar.startOfDay(for: newEnd)
                while current <= end {
                    if !parent.vacationDays.contains(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                        viewModel.addVacationDay(for: parent, date: current, type: .vacation)
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                }
                // Parent-Objekt aktualisieren
                if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
                    parent = viewModel.parents[idx]
                }
            }, viewModel: viewModel)
            .id(vacationRangeStart.timeIntervalSince1970)
        }
        .sheet(item: $editingVacationRange) { idInterval in
            let interval = idInterval.interval
            EditVacationRangeSheet(initialStart: interval.start, initialEnd: interval.end, isEditing: true, onSave: { newStart, newEnd in
                // Lösche alten Bereich
                let calendar = Calendar.current
                var current = calendar.startOfDay(for: interval.start)
                let oldEnd = calendar.startOfDay(for: interval.end)
                while current <= oldEnd {
                    viewModel.removeVacationDay(for: parent, date: current)
                    current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                }
                // Füge neue Tage hinzu
                current = calendar.startOfDay(for: newStart)
                let newEnd = calendar.startOfDay(for: newEnd)
                while current <= newEnd {
                    if !parent.vacationDays.contains(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                        viewModel.addVacationDay(for: parent, date: current, type: .vacation)
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                }
                // Parent-Objekt aktualisieren
                if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
                    parent = viewModel.parents[idx]
                }
            }, viewModel: viewModel)
            .id(idInterval.id)
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Urlaubszeitraum löschen"),
                message: Text("Möchtest du diesen Urlaubszeitraum wirklich löschen?"),
                primaryButton: .destructive(Text("Löschen")) {
                    if let interval = pendingDeleteRange {
                        let calendar = Calendar.current
                        var current = calendar.startOfDay(for: interval.start)
                        let end = calendar.startOfDay(for: interval.end)
                        while current <= end {
                            viewModel.removeVacationDay(for: parent, date: current)
                            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                        }
                        if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
                            parent = viewModel.parents[idx]
                        }
                        pendingDeleteRange = nil
                    }
                },
                secondaryButton: .cancel {
                    pendingDeleteRange = nil
                }
            )
        }
    }
    
    // Hilfsfunktion: Gruppiert zusammenhängende VacationDays zu DateIntervals
    private func groupedVacationIntervals(for vacationDays: [VacationDay]) -> [IdentifiableDateInterval] {
        guard !vacationDays.isEmpty else { return [] }
        let calendar = Calendar.current
        let sortedDates = vacationDays.map { $0.date }.sorted()
        var intervals: [DateInterval] = []
        var start = sortedDates[0]
        var prev = sortedDates[0]
        for date in sortedDates.dropFirst() {
            if calendar.dateComponents([.day], from: prev, to: date).day == 1 {
                prev = date
            } else {
                intervals.append(DateInterval(start: start, end: prev))
                start = date
                prev = date
            }
        }
        intervals.append(DateInterval(start: start, end: prev))
        return intervals.map { IdentifiableDateInterval(interval: $0) }
    }
}

// Hilfswrapper für Identifiable-Sheet (außerhalb von ParentDetailView)
fileprivate struct IdentifiableDateInterval: Identifiable, Equatable {
    let id = UUID()
    let interval: DateInterval
    static func ==(lhs: IdentifiableDateInterval, rhs: IdentifiableDateInterval) -> Bool {
        lhs.interval.start == rhs.interval.start && lhs.interval.end == rhs.interval.end
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

// --- Behalte nur EINE Extension Color (init(hex:) und toHex()) in diesem Projekt! ---
// Entferne alle weiteren Color(hex:) Extensions aus anderen Dateien.

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// --- Color(hex:) und toHex() Extension entfernt. Die zentrale Extension befindet sich jetzt in Color+Hex.swift ---
struct ParentDetailView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State var parent: Parent
    @State private var showEditSheet = false
    @State private var showAddVacationRange = false
    @State private var vacationRangeStart = Date()
    @State private var vacationRangeEnd = Date()

    var body: some View {
        // Hilfsvariablen VOR dem ersten View deklarieren!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        let weekdaySymbols = formatter.shortWeekdaySymbols ?? []
        let germanOrder = [1, 2, 3, 4, 5, 6, 0] // Mo=0, So=6
        let sortedFixedWeekdays = parent.fixedWeekdays.sorted().filter { germanOrder[$0] < weekdaySymbols.count }
        return NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Profilbild/Symbol mit farbigem Rand
                    ZStack {
                        Circle()
                            .stroke(Color(hex: parent.colorHex), lineWidth: 5)
                            .frame(width: 110, height: 110)
                        if let data = parent.profileImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(hex: parent.colorHex))
                                .frame(width: 100, height: 100)
                            // Kein Symbol mehr
                        }
                    }
                    // Symbolname, Farbwert (Hex) und ggf. weitere Felder explizit anzeigen
                    VStack(spacing: 2) {
                        // Symbolname entfernt
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: parent.colorHex))
                                .frame(width: 16, height: 16)
                            Text(parent.colorHex)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    // Name und Beziehung
                    VStack(spacing: 2) {
                        Text(parent.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(parent.relationship.rawValue)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Divider().padding(.vertical, 8)
                    // Wöchentlich wiederkehrende freie Tage anzeigen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wöchentlich freie Tage (z.B. Homeoffice, feste Betreuung):")
                            .font(.subheadline.bold())
                        if parent.fixedWeekdays.isEmpty {
                            Text("Keine wöchentlichen freien Tage hinterlegt.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(sortedFixedWeekdays, id: \.self) { i in
                                    let label = weekdaySymbols[germanOrder[i]]
                                    Text(label)
                                        .padding(6)
                                        .background(Color.green.opacity(0.18))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    // Urlaubstage-Liste
                    VStack(alignment: .leading, spacing: 8) {
                        let vacationRanges = calculateVacationRanges(from: parent.vacationDays)
                        Text("Urlaubszeiträume: \(vacationRanges.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if !vacationRanges.isEmpty {
                            ForEach(vacationRanges, id: \ .self) { range in
                                HStack {
                                    Text("\(dateFormatter.string(from: range.start)) – \(dateFormatter.string(from: range.end))")
                                        .font(.body)
                                    Spacer()
                                    Button(action: {
                                        deleteVacationRange(range)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    Button(action: {
                                        editVacationRange(range)
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        } else {
                            Text("Noch keine Urlaubszeiträume eingetragen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    Button(action: {
                        vacationRangeStart = Date()
                        vacationRangeEnd = Date()
                        showAddVacationRange = true
                    }) {
                        Label("Urlaubszeitraum hinzufügen", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .accessibilityIdentifier("addVacationRangeButton")
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            //.toolbar {
            //    ToolbarItemGroup(placement: .navigationBarTrailing) {
            //        Button("Bearbeiten") {
            //            showEditSheet = true
            //        }
            //    }
            //}
        }
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
                Text("Urlaubszeitraum hinzufügen")
                    .font(.title3).bold()
                Text("Bitte wähle Start- und Enddatum für den Urlaub aus.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                VStack(spacing: 14) {
                    DatePicker("Von", selection: $vacationRangeStart, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    DatePicker("Bis", selection: $vacationRangeEnd, in: vacationRangeStart..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                Button("Hinzufügen") {
                    let calendar = Calendar.current
                    var current = calendar.startOfDay(for: vacationRangeStart)
                    let end = calendar.startOfDay(for: vacationRangeEnd)
                    while current <= end {
                        if !parent.vacationDays.contains(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                            let newDay = VacationDay(date: current, type: .vacation)
                            parent.vacationDays.append(newDay)
                        }
                        current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                    }
                    if let idx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
                        viewModel.parents[idx] = parent
                    }
                    showAddVacationRange = false
                }
                .buttonStyle(.borderedProminent)
                Button("Abbrechen", role: .cancel) {
                    showAddVacationRange = false
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal)
            .presentationDetents([.large])
        }
    }
}

// MARK: - Hilfsfunktionen für Zeiträume
extension ParentDetailView {
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
            if let idx = parent.vacationDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                parent.vacationDays.remove(at: idx)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        if let pidx = viewModel.parents.firstIndex(where: { $0.id == parent.id }) {
            viewModel.parents[pidx] = parent
        }
    }
    
    func editVacationRange(_ range: DateInterval) {
        vacationRangeStart = range.start
        vacationRangeEnd = range.end
        // Erst alten Zeitraum löschen, dann Sheet öffnen
        deleteVacationRange(range)
        showAddVacationRange = true
    }
    
    var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "de_DE")
        return df
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

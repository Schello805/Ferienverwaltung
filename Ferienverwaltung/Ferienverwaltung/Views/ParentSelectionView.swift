//
//  ParentSelectionView.swift
//  Ferienverwaltung
//
//  Created by Michael Schellenberger on 12.04.25.
//

import SwiftUI

struct ParentSelectionView: View {
    @ObservedObject var viewModel: VacationViewModel
    let holidayDays: [Date]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedParent: Parent?
    @State private var selectedDays: Set<Date> = []

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Elternteil auswählen")) {
                    ForEach(viewModel.parents, id: \Parent.id) { parent in
                        Button(action: {
                            selectedParent = parent
                        }) {
                            HStack {
                                Text(parent.name)
                                Spacer()
                                if selectedParent?.id == parent.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                if viewModel.parents.isEmpty {
                    Section {
                        Text("Keine Elternteile vorhanden. Bitte fügen Sie zuerst Elternteile in den Einstellungen hinzu.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                if let parent = selectedParent {
                    Section(header: Text("Zu planende Tage auswählen")) {
                        ForEach(holidayDays.sorted(), id: \.self) { date in
                            let alreadyPlanned = parent.vacationDays.contains { vacationDay in
                                Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
                            }
                            Button(action: {
                                if selectedDays.contains(date) {
                                    selectedDays.remove(date)
                                } else {
                                    selectedDays.insert(date)
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(date, style: .date)
                                            .font(.body)
                                    }
                                    Spacer()
                                    if alreadyPlanned {
                                        Text("bereits geplant")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if selectedDays.contains(date) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .disabled(alreadyPlanned)
                        }
                    }
                }
                Section(header: Text("Zusammenfassung")) {
                    if let parent = selectedParent {
                        let alreadyPlannedDays = holidayDays.filter { date in
                            parent.vacationDays.contains { vacationDay in
                                Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
                            }
                        }.count
                        let neuZuPlanen = selectedDays.count
                        Text("Zu planende Tage: \(holidayDays.count)")
                            .font(.subheadline)
                        Text("Davon bereits geplant für \(parent.name): \(alreadyPlannedDays)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Neu zu planende Tage: \(neuZuPlanen)")
                            .font(.subheadline)
                            .foregroundColor(neuZuPlanen > 0 ? .blue : .green)
                    } else {
                        Text("Bitte zuerst Elternteil auswählen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Betreuung planen")
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    dismiss()
                },
                trailing: Button("Weiter") {
                    if let parent = selectedParent {
                        planVacationDays(for: parent)
                    }
                }
                .disabled(selectedParent == nil || selectedDays.isEmpty)
            )
        }
    }
    
    private func planVacationDays(for parent: Parent) {
        // Füge nur die ausgewählten Tage hinzu, die noch nicht geplant sind
        for date in selectedDays {
            let isAlreadyPlanned = parent.vacationDays.contains { vacationDay in
                Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
            }
            if !isAlreadyPlanned {
                viewModel.addVacationDay(for: parent, date: date, type: .vacation)
            }
        }
        dismiss()
    }
    
    // Initialisiere die Auswahl, wenn sich die holidayDays ändern (z.B. beim Öffnen)
    init(viewModel: VacationViewModel, holidayDays: [Date]) {
        self.viewModel = viewModel
        self.holidayDays = holidayDays
        _selectedDays = State(initialValue: Set(holidayDays))
    }
}

struct ParentSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ParentSelectionView(
            viewModel: VacationViewModel(),
            holidayDays: [Date(), Date().addingTimeInterval(86400)]
        )
    }
}

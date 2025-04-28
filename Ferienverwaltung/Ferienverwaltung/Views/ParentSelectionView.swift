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
                
                Section(header: Text("Zusammenfassung")) {
                    Text("Zu planende Tage: \(holidayDays.count)")
                        .font(.subheadline)
                    
                    if let parent = selectedParent {
                        let alreadyPlannedDays = holidayDays.filter { date in
                            parent.vacationDays.contains { vacationDay in
                                Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
                            }
                        }.count
                        
                        Text("Davon bereits geplant für \(parent.name): \(alreadyPlannedDays)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Neu zu planende Tage: \(holidayDays.count - alreadyPlannedDays)")
                            .font(.subheadline)
                            .foregroundColor(holidayDays.count - alreadyPlannedDays > 0 ? .blue : .green)
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
                .disabled(selectedParent == nil)
            )
        }
    }
    
    private func planVacationDays(for parent: Parent) {
        // Füge nur die Tage hinzu, die noch nicht geplant sind
        for date in holidayDays {
            let isAlreadyPlanned = parent.vacationDays.contains { vacationDay in
                Calendar.current.isDate(vacationDay.date, inSameDayAs: date)
            }
            
            if !isAlreadyPlanned {
                viewModel.addVacationDay(for: parent, date: date, type: .vacation)
            }
        }
        
        dismiss()
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

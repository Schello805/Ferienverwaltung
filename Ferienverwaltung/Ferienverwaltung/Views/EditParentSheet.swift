import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct EditParentSheet: View {
    @ObservedObject var viewModel: VacationViewModel
    var parent: Parent
    var onSave: (Parent) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var relationship: Relationship
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var color: Color
    @State private var vacationDays: [VacationDay]
    @State private var fixedWeekdays: [Int]

    init(viewModel: VacationViewModel, parent: Parent, onSave: @escaping (Parent) -> Void) {
        self.viewModel = viewModel
        self.parent = parent
        self.onSave = onSave
        _name = State(initialValue: parent.name)
        _relationship = State(initialValue: parent.relationship)
        if let data = parent.profileImageData, let img = UIImage(data: data) {
            _profileImage = State(initialValue: img)
        } else {
            _profileImage = State(initialValue: nil)
        }
        _color = State(initialValue: Color.blue)
        _vacationDays = State(initialValue: parent.vacationDays)
        _fixedWeekdays = State(initialValue: parent.fixedWeekdays)
    }

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
                    .navigationTitle("Elternteil bearbeiten")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let updatedParent = Parent(
                                    id: parent.id,
                                    name: name,
                                    relationship: relationship,
                                    vacationDays: vacationDays,
                                    profileImageData: profileImage?.jpegData(compressionQuality: 0.8),
                                    colorHex: (color.toHex() ?? "#007AFF"),
                                    symbolName: parent.symbolName,
                                    fixedWeekdays: fixedWeekdays
                                )
                                if let idx = viewModel.parents.firstIndex(where: { $0.id == updatedParent.id }) {
                                    viewModel.parents[idx] = updatedParent
                                }
                                onSave(updatedParent)
                                dismiss()
                            }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
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
                if vacationDays.isEmpty {
                    Text("Noch keine Urlaubstage eingetragen")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(vacationDays) { day in
                        HStack {
                            Text(day.date, style: .date)
                            Spacer()
                            Text(day.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Button(role: .destructive) {
                                vacationDays.removeAll { $0.id == day.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                Button("Urlaubstag hinzufügen") {
                    let newDay = VacationDay(date: Date(), type: .vacation)
                    vacationDays.append(newDay)
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
}

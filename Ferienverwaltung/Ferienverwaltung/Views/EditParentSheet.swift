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
    @State private var fixedWeekdays: [Int]
    @State private var vacationDays: [VacationDay]

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
        _color = State(initialValue: Color.fromHex(parent.colorHex))
        _fixedWeekdays = State(initialValue: parent.fixedWeekdays)
        _vacationDays = State(initialValue: parent.vacationDays)
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Abbrechen") { dismiss() }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
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
                                    viewModel.objectWillChange.send()
                                }
                                onSave(updatedParent)
                                dismiss()
                            }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 24)
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
            Section(header: Text("Feste Betreuungstage")) {
                Text("Wähle beliebig viele feste Wochentage, an denen dieser Elternteil regelmäßig zu Hause ist und die Kinder betreuen kann.")
                    .font(.caption)
                HStack {
                    let days = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                    ForEach(0..<7) { weekday in
                        Button(action: {
                            if fixedWeekdays.contains(weekday) {
                                fixedWeekdays.removeAll { $0 == weekday }
                            } else {
                                fixedWeekdays.append(weekday)
                            }
                        }) {
                            Text(days[weekday])
                                .font(.subheadline)
                                .foregroundColor(fixedWeekdays.contains(weekday) ? .white : .primary)
                                .padding(8)
                                .background(fixedWeekdays.contains(weekday) ? Color.accentColor : Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Urlaubszeitraum-Logik
    private func calculateVacationRanges(from days: [VacationDay]) -> [DateInterval] {
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
    private func deleteVacationRange(_ range: DateInterval) {
        var current = range.start
        let calendar = Calendar.current
        while current <= range.end {
            if let idx = vacationDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current) }) {
                vacationDays.remove(at: idx)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
    }
    // Verwende einen statischen Formatter für Performance und Sicherheit
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "de_DE")
        return df
    }()
    private var dateFormatter: DateFormatter { Self.dateFormatter }
}

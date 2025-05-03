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
    @State private var fixedWeekdays: [Int] = []

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
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let newParent = Parent(
                            name: name,
                            relationship: relationship,
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

extension AddParentSheet {
    // Verwende einen statischen Formatter für Performance und Sicherheit
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "de_DE")
        return df
    }()
    var dateFormatter: DateFormatter { Self.dateFormatter }
}

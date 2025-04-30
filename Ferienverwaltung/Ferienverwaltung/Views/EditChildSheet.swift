import SwiftUI
import Foundation

struct EditChildSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VacationViewModel
    var onSave: (() -> Void)? = nil
    
    @State var child: Child
    @State private var name: String
    @State private var birthdate: Date?
    @State private var showDatePicker = false
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var notes: String
    @State private var type: ChildType
    
    // State für das Hinzufügen eines freien Tages
    @State private var showAddFreeDaySheet = false
    @State private var newFreeDayDate = Date()
    @State private var newFreeDayReason = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    init(viewModel: VacationViewModel, child: Child, onSave: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self._child = State(initialValue: child)
        self.onSave = onSave
        _name = State(initialValue: child.name)
        _birthdate = State(initialValue: child.birthdate)
        if let data = child.profileImageData, let uiImage = UIImage(data: data) {
            _profileImage = State(initialValue: uiImage)
        } else {
            _profileImage = State(initialValue: nil)
        }
        _notes = State(initialValue: child.notes ?? "")
        _type = State(initialValue: child.type)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 3)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                )
                        }
                        Button("Bild wählen") { showImagePicker = true }
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                }
                Section(header: Text("Typ")) {
                    ChildTypePicker(selection: $type)
                }
                Section(header: Text("Name")) {
                    TextField("Name", text: $name)
                }
                Section(header: Text("Geburtsdatum")) {
                    HStack {
                        if let date = birthdate {
                            Text(dateFormatter.string(from: date))
                            Spacer()
                            Button("Ändern") { showDatePicker = true }
                        } else {
                            Button("Geburtsdatum wählen") { showDatePicker = true }
                        }
                    }
                }
                Section(header: Text("Notiz")) {
                    TextField("Notiz (optional)", text: $notes, axis: .vertical)
                }
                
                // --- Freie Tage Section ---
                Section(header: Text("Freie Tage"), footer: Text("Hier kannst du individuelle freie Tage für dieses Kind eintragen, z.B. Schließtage, Brückentage oder besondere Anlässe.")) {
                    ForEach(child.freeDays.sorted(by: { $0.date < $1.date })) { freeDay in
                        HStack {
                            Text(dateFormatter.string(from: freeDay.date))
                            if let reason = freeDay.reason, !reason.isEmpty {
                                Text("· " + reason)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                child.freeDays.removeAll { $0.id == freeDay.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    Button(action: { showAddFreeDaySheet = true }) {
                        Label("Freien Tag hinzufügen", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Kind bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Abbrechen") { dismiss() },
                trailing: Button("Speichern") {
                    child.name = name
                    child.birthdate = birthdate
                    child.profileImageData = profileImage?.jpegData(compressionQuality: 0.8)
                    child.notes = notes.isEmpty ? nil : notes
                    child.type = type
                    viewModel.updateChild(child)
                    onSave?()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker("Geburtsdatum", selection: Binding(
                        get: { birthdate ?? Date() },
                        set: { birthdate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    Button("Übernehmen") { showDatePicker = false }
                        .padding(.top)
                }
                .padding()
            }
            .sheet(isPresented: $showAddFreeDaySheet) {
                VStack(spacing: 16) {
                    DatePicker("Datum", selection: $newFreeDayDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "de_DE"))
                    TextField("Grund (optional)", text: $newFreeDayReason)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Abbrechen", role: .cancel) { showAddFreeDaySheet = false }
                        Spacer()
                        Button("Hinzufügen") {
                            let normalizedDate = Calendar.current.startOfDay(for: newFreeDayDate)
                            let newDay = FreeDay(date: normalizedDate, reason: newFreeDayReason.isEmpty ? nil : newFreeDayReason)
                            child.freeDays.append(newDay)
                            newFreeDayDate = Date()
                            newFreeDayReason = ""
                            showAddFreeDaySheet = false
                        }.buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
    }
}

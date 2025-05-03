import SwiftUI
import Foundation

struct AddChildSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VacationViewModel
    
    @State private var name: String = ""
    @State private var birthdate: Date? = nil
    @State private var showDatePicker = false
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var notes: String = ""
    @State private var type: ChildType = .schulkind
    @State private var freeDays: [FreeDay] = []
    @State private var showAddFreeDaySheet = false
    @State private var newFreeDayDate = Date()
    @State private var newFreeDayReason = ""
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Profilbild ganz oben außerhalb des Forms
                VStack {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 46))
                                    .foregroundColor(.blue)
                            )
                    }
                    Button("Bild wählen") { showImagePicker = true }
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                Form {
                    Section(header: Text("Name")) {
                        TextField("Name", text: $name)
                    }
                    Section(header: Text("Typ")) {
                        ChildTypePicker(selection: $type)
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
                        ForEach(freeDays.sorted(by: { $0.date < $1.date })) { freeDay in
                            HStack {
                                Text(dateFormatter.string(from: freeDay.date))
                                if let reason = freeDay.reason, !reason.isEmpty {
                                    Text("· " + reason)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    freeDays.removeAll { $0.id == freeDay.id }
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
            }
            .navigationTitle("Kind hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let newChild = Child(
                            name: name,
                            birthdate: birthdate,
                            profileImageData: profileImage?.jpegData(compressionQuality: 0.8),
                            notes: notes.isEmpty ? nil : notes,
                            type: type,
                            freeDays: freeDays
                        )
                        viewModel.addChild(newChild)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showDatePicker) {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("Geburtsdatum wählen")
                                .font(.headline)
                                .padding(.top, 20)
                            DatePicker("Geburtsdatum", selection: Binding(
                                get: { birthdate ?? Date() },
                                set: { birthdate = $0 }
                            ), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "de_DE"))
                            Button("Übernehmen") { showDatePicker = false }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(26)
                        .shadow(radius: 18)
                        .frame(maxWidth: 340)
                    }
                }
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
                            let newDay = FreeDay(date: newFreeDayDate, reason: newFreeDayReason.isEmpty ? nil : newFreeDayReason)
                            freeDays.append(newDay)
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

// ImagePicker für Profilbild-Auswahl
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

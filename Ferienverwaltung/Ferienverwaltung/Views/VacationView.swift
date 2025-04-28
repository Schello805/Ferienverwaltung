import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import PhotosUI

struct VacationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VacationViewModel
    @State private var selectedParent: Parent?
    @State private var showAddParentSheet = false
    @State private var showEditParentSheet = false
    @State private var parentToEdit: Parent?
    @State private var debugMessage = ""
    @State private var showDeleteParentAlert = false
    @State private var pendingDeleteParentIndexSet: IndexSet? = nil
    // Für ImagePicker und ColorPicker
    @State private var selectedImage: UIImage? = nil
    @State private var selectedColor: Color = Color.blue
    @State private var showImagePicker = false
    @State private var showAddChildSheet = false
    @State private var showEditChildSheet = false
    @State private var childToEdit: Child? = nil
    @State private var showDeleteChildAlert = false
    @State private var pendingDeleteChild: Child? = nil

    private var headerBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.accentColor.opacity(0.15), Color.clear]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .edgesIgnoringSafeArea(.top)
    }

    private var parentsToShow: [Parent] {
        viewModel.hideExpiredData ? viewModel.filteredParents : viewModel.parents
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Familie")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding([.horizontal, .top])
                .background(headerBackground)
                List {
                    adultsSection
                    Section(header:
                        HStack {
                            Image(systemName: "person.3.sequence.fill")
                                .foregroundColor(.blue)
                            Text("Kinder")
                                .font(.headline)
                        }
                    ) {
                        ForEach(viewModel.children, id: \.id) { child in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !child.freeDays.isEmpty {
                                        Text("Freie Tage:")
                                            .font(.subheadline)
                                            .bold()
                                        ForEach(child.freeDays.sorted(by: { $0.date < $1.date })) { freeDay in
                                            HStack {
                                                Text(dateFormatter.string(from: freeDay.date))
                                                if let reason = freeDay.reason, !reason.isEmpty {
                                                    Text("· " + reason)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    } else {
                                        Text("Keine freien Tage eingetragen.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            } label: {
                                Button(action: {
                                    childToEdit = child
                                    showEditChildSheet = true
                                }) {
                                    HStack(spacing: 16) {
                                        if let data = child.profileImageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 48, height: 48)
                                                .clipShape(Circle())
                                        } else {
                                            ZStack {
                                                Circle().fill(Color.accentColor)
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 28))
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(child.name)
                                                .font(.headline)
                                            if let age = child.age {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "calendar")
                                                        .font(.system(size: 13))
                                                    Text("Alter: \(age)")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            if let notes = child.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeleteChild = child
                                    showDeleteChildAlert = true
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                        Button(action: { showAddChildSheet = true }) {
                            Label("Kind hinzufügen", systemImage: "plus")
                        }
                    }
                }
                .listStyle(.plain)
                .alert(isPresented: $showDeleteParentAlert) {
                    Alert(
                        title: Text("Betreuer löschen?"),
                        message: Text("Bist du sicher, dass du diesen Betreuer löschen möchtest?"),
                        primaryButton: .destructive(Text("Löschen")) {
                            if let indexSet = pendingDeleteParentIndexSet {
                                viewModel.parents.remove(atOffsets: indexSet)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                Spacer()
            }
            .sheet(isPresented: $showAddParentSheet) {
                NavigationView {
                    AddParentSheet(viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showAddChildSheet) {
                AddChildSheet(viewModel: viewModel)
            }
            .sheet(item: $childToEdit) { child in
                EditChildSheet(viewModel: viewModel, child: child) {
                    // Nach dem Speichern Sheet schließen und State zurücksetzen
                    showEditChildSheet = false
                    childToEdit = nil
                }
            }
            .sheet(item: $parentToEdit) { parent in
                EditParentSheet(viewModel: viewModel, parent: parent) { updatedParent in
                    if let idx = viewModel.parents.firstIndex(where: { $0.id == updatedParent.id }) {
                        viewModel.parents[idx] = updatedParent
                    }
                    parentToEdit = nil
                }
            }
            .alert(isPresented: $showDeleteChildAlert) {
                Alert(
                    title: Text("Kind löschen?"),
                    message: Text("Möchtest du \(pendingDeleteChild?.name ?? "das Kind") wirklich löschen?"),
                    primaryButton: .destructive(Text("Löschen")) {
                        if let child = pendingDeleteChild {
                            viewModel.deleteChild(child)
                        }
                        pendingDeleteChild = nil
                    },
                    secondaryButton: .cancel {
                        pendingDeleteChild = nil
                    }
                )
            }
        }
        .navigationTitle("Betreuer hinzufügen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
    }

    private var adultsSection: some View {
        Section(header: sectionHeaderErwachsene) {
            ForEach(viewModel.parents, id: \.id) { parent in
                NavigationLink(destination: ParentDetailView(viewModel: viewModel, parent: parent)) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color(hex: parent.colorHex), lineWidth: 3)
                                .frame(width: 48, height: 48)
                            if let data = parent.profileImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(hex: parent.colorHex))
                                    .frame(width: 44, height: 44)
                                Text(String(parent.name.prefix(1)))
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parent.name)
                                .font(.headline)
                            Text(parent.relationship.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Urlaubstage: \(parent.vacationDays.count)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDeleteParentIndexSet = IndexSet(integer: viewModel.parents.firstIndex(where: { $0.id == parent.id })!)
                        showDeleteParentAlert = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
            Button(action: { showAddParentSheet = true }) {
                Label("Erwachsenen hinzufügen", systemImage: "plus")
            }
        }
    }

    private var sectionHeaderErwachsene: some View {
        HStack {
            Text("Erwachsene")
                .font(.headline)
        }
    }

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
}

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
    @State private var selectedTab: Int = 0

    private var headerBackground: some View {
        Color(.systemGroupedBackground)
        .edgesIgnoringSafeArea(.top)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    var body: some View {
        GeometryReader { geometry in
            if UIDevice.current.userInterfaceIdiom == .pad {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Section(header: EmptyView()) {
                            adultsSection
                        }
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
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color(.systemGray5))
                                                    .frame(width: 44, height: 44)
                                                Text(String(child.name.prefix(1)))
                                                    .font(.title2)
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(child.name)
                                                    .font(.headline)
                                                Text(child.type.rawValue)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
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
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .listRowSeparator(.hidden)
                .listStyle(.plain)
                .sheet(isPresented: $showAddParentSheet) {
                    AddParentSheet(viewModel: viewModel) { _ in
                        showAddParentSheet = false
                    }
                }
                .background(Color(.systemGroupedBackground))
                .edgesIgnoringSafeArea(.all)
            } else {
                // iPhone-Layout (wie gehabt)
                NavigationView {
                    List {
                        Section(header: EmptyView()) {
                            adultsSection
                        }
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
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color(.systemGray5))
                                                    .frame(width: 44, height: 44)
                                                Text(String(child.name.prefix(1)))
                                                    .font(.title2)
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(child.name)
                                                    .font(.headline)
                                                Text(child.type.rawValue)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
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
                }
                .navigationBarTitle("Familie")
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            }
        }
        .navigationTitle("Familie")
    }

    private var adultsSection: some View {
        Section(header: Text("Erwachsene")) {
            ForEach(viewModel.parents, id: \.id) { parent in
                NavigationLink(destination: ParentDetailView(viewModel: viewModel, parent: parent)) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.fromHex(parent.colorHex), lineWidth: 3)
                                .frame(width: 48, height: 48)
                            if let data = parent.profileImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.fromHex(parent.colorHex))
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
                            // Urlaubstage-Anzeige entfernt, da nur Zeiträume für den User sichtbar sein sollen
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

    // --- iPad Main Content ---
    private struct MainContent: View {
        let viewModel: VacationViewModel
        let headerBackground: AnyView
        let adultsSection: AnyView
        let dateFormatter: DateFormatter
        @Binding var childToEdit: Child?
        @Binding var showEditChildSheet: Bool
        @Binding var pendingDeleteChild: Child?
        @Binding var showDeleteChildAlert: Bool
        @Binding var showAddChildSheet: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                List {
                    Section(header: EmptyView()) {
                        adultsSection
                    }
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
                                                .frame(width: 44, height: 44)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color(.systemGray5))
                                                .frame(width: 44, height: 44)
                                            Text(String(child.name.prefix(1)))
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(child.name)
                                                .font(.headline)
                                            Text(child.type.rawValue)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
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
            }
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

extension View {
    func ipadStyled() -> some View {
        self
            .navigationBarHidden(UIDevice.current.userInterfaceIdiom == .pad)
            .padding(UIDevice.current.userInterfaceIdiom == .pad ? EdgeInsets() : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

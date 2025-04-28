import Foundation
import UniformTypeIdentifiers
import SwiftUI

class ImportExportCoordinator: NSObject, UIDocumentPickerDelegate {
    let viewModel: VacationViewModel
    init(viewModel: VacationViewModel) {
        self.viewModel = viewModel
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        var data: Data?
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            data = try Data(contentsOf: url)
            if let data = data {
                viewModel.importAllDataFromJSON(data)
            }
        } catch {
            print("[Import] Fehler beim Lesen der Datei: \(error)")
        }
    }
}

struct ImportExportDocumentPicker: UIViewControllerRepresentable {
    let viewModel: VacationViewModel
    func makeCoordinator() -> ImportExportCoordinator {
        ImportExportCoordinator(viewModel: viewModel)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

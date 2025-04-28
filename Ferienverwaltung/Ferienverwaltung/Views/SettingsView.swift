import SwiftUI
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: VacationViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var showNotificationErrorBanner = false
    @State private var notificationErrorMessage = ""
    @State private var showResetConfirmation = false
    
    var body: some View {
        ZStack {
            List {
                Section(header: Text("Bundesland wählen")) {
                    Picker("Bundesland", selection: $viewModel.selectedState) {
                        ForEach(FederalState.allCases) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.menu) // Dropdown-Stil für bessere Optik und Usability
                    .onChange(of: viewModel.selectedState) {
                        viewModel.reloadSchoolHolidays()
                    }
                    Text("Aktuelles Bundesland: \(viewModel.selectedState.rawValue)") // Debug-Ausgabe
                }
                // --- Import/Export direkt unter Bundesland-Auswahl ---
                Section(header: Text("Daten teilen & sichern"), footer: Text("Mit diesen Funktionen kannst du alle App-Daten ganz einfach exportieren (z.B. per AirDrop oder Mail) und auf einem anderen Gerät wieder importieren. So kannst du die Ferien- und Elterndaten mit deiner Familie teilen oder Backups anlegen.")) {
                    ImportExportButton(viewModel: viewModel)
                    Button {
                        exportData()
                    } label: {
                        Label("Daten exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                Section(header: Text("App-Einstellungen")) {
                    // Daten zurücksetzen
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Alle Daten zurücksetzen", systemImage: "trash")
                    }
                    // Daten ausblenden: Abgelaufene Urlaube und Ferien nicht anzeigen
                    Toggle("Abgelaufene Daten ausblenden", isOn: $viewModel.hideExpiredData)
                }
                Section(header: Text("Benachrichtigungen"), footer: Text("Du erhältst Push-Benachrichtigungen 4 Wochen und 1 Woche vor jedem unbetreuten Ferientag. So kannst du rechtzeitig Betreuung organisieren. Über den Test-Button kannst du eine Beispiel-Benachrichtigung auslösen.")) {
                    NotificationToggle(notificationsEnabled: $notificationsEnabled, viewModel: viewModel, onError: { msg in
                        notificationErrorMessage = msg
                        showNotificationErrorBanner = true
                    })
                    Button("Test-Benachrichtigung senden") {
                        NotificationService.shared.sendTestNotification { errorMsg in
                            if let errorMsg = errorMsg {
                                notificationErrorMessage = errorMsg
                                showNotificationErrorBanner = true
                            }
                        }
                    }
                }
                Section(header: Text("Farben der Kalender-Legende")) {
                    ColorPicker("Ferientag ohne Betreuung", selection: Binding(
                        get: { Color(hex: UserDefaults.standard.string(forKey: "legendColorUnattended") ?? "#B0B0B0") },
                        set: { UserDefaults.standard.set($0.toHex(), forKey: "legendColorUnattended") }
                    ))
                    ColorPicker("Ferientag mit Betreuung", selection: Binding(
                        get: { Color(hex: UserDefaults.standard.string(forKey: "legendColorAttended") ?? "#FFA500") },
                        set: { UserDefaults.standard.set($0.toHex(), forKey: "legendColorAttended") }
                    ))
                }
                Section(header: Text("Info & Dokumentation")) {
                    NavigationLink(destination: AppInfoView()) {
                        Label("Über diese App", systemImage: "info.circle")
                    }
                    Button {
                        if let url = URL(string: "mailto:support@ferienverwaltung.app?subject=Feedback zur Ferienverwaltung") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Feedback geben", systemImage: "envelope")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Einstellungen")
            // Bestätigungs-Alert für Daten zurücksetzen
            .alert("Alle Daten wirklich löschen?", isPresented: $showResetConfirmation, actions: {
                Button("Löschen", role: .destructive) {
                    viewModel.resetAllData()
                }
                Button("Abbrechen", role: .cancel) {}
            }, message: {
                Text("Alle gespeicherten Daten werden unwiderruflich entfernt.")
            })
            // Dezent platzierter Fehler-Banner oben
            if showNotificationErrorBanner {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                        Text(notificationErrorMessage)
                            .font(.footnote)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: { showNotificationErrorBanner = false }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    Spacer()
                }
                .padding(.horizontal)
                .transition(.move(edge: .top))
                .zIndex(1)
            }
            // Farbverlauf entfernt
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Lade Daten...")
                    .padding(40)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(radius: 8)
            }
        }
    }
}

struct NotificationToggle: View {
    @Binding var notificationsEnabled: Bool
    var viewModel: VacationViewModel
    var onError: ((String) -> Void)? = nil
    
    var body: some View {
        Group {
            Toggle("Push-Benachrichtigungen für unbetreute Ferientage", isOn: $notificationsEnabled)
                .onReceive(Just(notificationsEnabled).removeDuplicates()) { _ in
                    handleChange()
                }
        }
    }
    
    private func handleChange() {
        if notificationsEnabled {
            NotificationService.shared.requestAuthorization { granted in
                if granted {
                    viewModel.scheduleUnattendedHolidayNotifications()
                } else {
                    onError?("Push-Benachrichtigungen sind nicht erlaubt. Bitte in den iOS-Einstellungen aktivieren.")
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
}

struct ParentManagementView: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var newParentName = ""
    @State private var selectedRelationship: Relationship = .father
    @State private var debugMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Eltern hinzufügen")) {
                VStack {
                    TextField("Name", text: $newParentName)
                    Picker("Beziehung", selection: $selectedRelationship) {
                        ForEach(Relationship.allCases, id: \.self) { rel in
                            Text(rel.rawValue).tag(rel)
                        }
                    }
                    Button(action: {
                        viewModel.addParent(name: newParentName, relationship: selectedRelationship)
                        debugMessage = "[DEBUG] Parents nach Hinzufügen: \(viewModel.parents)"
                        print(debugMessage)
                        newParentName = ""
                        selectedRelationship = .father
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newParentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !debugMessage.isEmpty {
                    Text(debugMessage).font(.caption).foregroundColor(.red)
                }
            }
            Section(header: Text("Elternliste")) {
                ForEach(viewModel.parents, id: \Parent.id) { parent in
                    Text(parent.name + " (" + parent.relationship.rawValue + ")")
                }
                .onDelete { indexSet in
                    viewModel.parents.remove(atOffsets: indexSet)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Elternverwaltung")
    }
}

// MARK: - Export Funktion
extension SettingsView {
    private func exportData() {
        guard let jsonData = viewModel.exportAllDataAsJSON() else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ferienverwaltung_export.json")
        do {
            try jsonData.write(to: tempURL)
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } catch {
            print("Export fehlgeschlagen: \(error)")
        }
    }
}

// MARK: - SwiftUI Import-Button
struct ImportExportButton: View {
    @ObservedObject var viewModel: VacationViewModel
    @State private var showPicker = false
    var body: some View {
        Button {
            showPicker = true
        } label: {
            Label("Daten importieren", systemImage: "square.and.arrow.down")
        }
        .sheet(isPresented: $showPicker) {
            ImportExportDocumentPicker(viewModel: viewModel)
        }
    }
}

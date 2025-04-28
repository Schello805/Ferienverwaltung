import SwiftUI

struct AppInfoView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.clock")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)
            Text("Ferienverwaltung")
                .font(.title)
                .bold()
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Diese App hilft Eltern, Schulferien, Feiertage und Urlaubsplanung für alle Bundesländer Deutschlands übersichtlich zu verwalten.")
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dokumentation")
                        .font(.headline)
                    Text("README (Kurzfassung):")
                        .font(.subheadline)
                        .bold()
                    Text("""
# Ferienverwaltung (Vacation Management)

Eine moderne iOS-App zur Verwaltung von Schulferien, Feiertagen und Elternurlaub in Deutschland.

## Features
- Übersicht aller schulfreien Tage (Ferien + relevante Feiertage) pro Jahr
- Verwaltung von Eltern und Urlaubstagen
- Anzeige unbetreuter Ferientage & Push-Benachrichtigungen
- Auswahl Bundesland, Speicherung lokal
""")
                        .font(.footnote)
                        .padding(.bottom, 8)
                    Divider()
                    Text("Lizenz")
                        .font(.headline)
                    Text("""
Copyright 2025 Michael Schellenberger. Alle Rechte vorbehalten. Keine Weitergabe oder Nutzung ohne Genehmigung. Siehe LICENSE.md für Details.
""")
                        .font(.footnote)
                        .padding(.bottom, 8)
                    Divider()
                    Text("Datenschutz")
                        .font(.headline)
                    Text("""
Alle Daten werden ausschließlich lokal gespeichert. Es werden keine personenbezogenen Daten an Server übermittelt. Details siehe Datenschutzerklärung (PRIVACY_POLICY.md).
""")
                        .font(.footnote)
                }
                .padding(.top, 8)
            }
            Divider()
            Link("Komplette Datenschutzerklärung lesen", destination: URL(string: "https://ferienverwaltung.app/datenschutz")!)
                .font(.footnote)
                .padding(.top, 8)
            Spacer()
        }
        .padding()
        .navigationTitle("Über diese App")
    }
}

struct AppInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppInfoView()
        }
    }
}

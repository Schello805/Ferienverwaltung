import SwiftUI

struct AppInfoView: View {
    var body: some View {
        ScrollView {
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
                Divider()
                Text("Entwickelt von Michael Schellenberger")
                    .font(.headline)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Datenschutzerklärung")
                        .font(.headline)
                    Text("Ihre Daten werden ausschließlich lokal auf Ihrem Gerät gespeichert. Es erfolgt keine Übertragung an Dritte. Weitere Informationen finden Sie auf unserer Website oder per E-Mail an info@schellenberger.biz.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Divider()
                    Text("Impressum")
                        .font(.headline)
                    Text("Michael Schellenberger, info@schellenberger.biz\nBreslauer Str. 18, 82194 Gröbenzell")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Divider()
                    Text("Nutzungsbedingungen")
                        .font(.headline)
                    Text("Die App wird ohne Gewähr bereitgestellt. Die Nutzung erfolgt auf eigene Verantwortung.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
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

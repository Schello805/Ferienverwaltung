import SwiftUI

struct DocumentView: View {
    let title: String
    let content: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2)
                    .bold()
                Divider()
                Text(content)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding()
        }
        .navigationTitle(title)
    }
}

struct DocumentTexts {
    static let privacy = """
1. Verantwortlicher
Michael Schellenberger
E-Mail: info@schellenberger.biz
Webseite: https://michael.schellenberger.biz
Ort: 91572 Bechhofen

2. Erhebung und Speicherung personenbezogener Daten
Beim Verwenden dieser App werden keine personenbezogenen Daten an Server übertragen. Alle Daten (z. B. Namen, Ferienzeiten, Einstellungen) werden ausschließlich lokal auf Ihrem Gerät gespeichert.

3. Zweck der Datenverarbeitung
Die gespeicherten Daten dienen ausschließlich zur Nutzung der App-Funktionen (Ferienverwaltung, Erinnerungen, etc.).

4. Weitergabe von Daten
Es erfolgt keine Weitergabe Ihrer Daten an Dritte.

5. Rechte der Nutzer
Sie haben das Recht auf Auskunft, Berichtigung, Löschung und Einschränkung der Verarbeitung Ihrer Daten. Da keine Übertragung an Dritte oder Server erfolgt, liegen alle Daten ausschließlich auf Ihrem Gerät.

6. Datensicherheit
Die App speichert alle Daten lokal auf Ihrem Gerät. Es liegt in Ihrer Verantwortung, für die Sicherheit Ihres Geräts zu sorgen (z. B. durch Gerätesperre, regelmäßige Updates).

7. Kontakt
Bei Fragen zum Datenschutz können Sie sich jederzeit an info@schellenberger.biz wenden.

8. Änderungen
Die Datenschutzerklärung kann bei Bedarf angepasst werden. Die aktuelle Version finden Sie immer in der App.

GitHub: Schello805
"""

    static let imprint = """
Angaben gemäß § 5 TMG:
Michael Schellenberger
Ort: 91572 Bechhofen
E-Mail: info@schellenberger.biz
Webseite: https://michael.schellenberger.biz
GitHub: Schello805
"""

    static let terms = """
1. Nutzung der App
Die App darf ausschließlich für private, nicht-kommerzielle Zwecke verwendet werden. Eine Weitergabe, Vervielfältigung oder kommerzielle Nutzung ist nicht gestattet.

2. Haftungsausschluss
Die Nutzung der App erfolgt auf eigene Verantwortung. Es wird keine Haftung für Schäden, Datenverluste oder fehlerhafte Ergebnisse übernommen. Die bereitgestellten Informationen (z.B. Ferien, Feiertage) erfolgen ohne Gewähr auf Richtigkeit oder Aktualität.

3. Verfügbarkeit
Es besteht kein Anspruch auf eine dauerhafte Verfügbarkeit oder Funktionalität der App. Updates und Änderungen können jederzeit erfolgen.

4. Rechte an Inhalten
Alle Rechte an der App und den bereitgestellten Inhalten verbleiben beim Entwickler. Die App darf nicht ohne Genehmigung verändert oder weitergegeben werden.

5. Datenschutz
Es gelten die Hinweise der Datenschutzerklärung.

6. Änderungen
Die Nutzungsbedingungen können jederzeit angepasst werden. Die jeweils aktuelle Version ist in der App einsehbar.
"""

    static let about = """
Diese App wurde von Michael Schellenberger mit Hilfe von Windsurf erstellt – ganz ohne eine einzige Zeile Code zu schreiben. Ich kann nicht programmieren! Das ist bereits meine dritte App nach dem ICS Generator und der App Haustiermanagement.

Für die Entwicklung habe ich etwa 8 Wochen mit ca. 30 Stunden Zeitaufwand investiert. Über 60% der Entwicklung erfolgte mit Claude 3.5, die letzten 2 Wochen habe ich GPT-4.1 verwendet.

Windsurf und KI haben es mir ermöglicht, meine Idee in eine funktionierende App zu verwandeln.
"""
}

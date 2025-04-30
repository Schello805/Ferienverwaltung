#if canImport(UIKit)
import UIKit
#endif

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    func getKeyWindow() -> UIWindow? {
        // iOS 15+: Alle aktiven WindowScenes durchsuchen
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            // Fallback für ältere iOS-Versionen
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            completion(granted)
        }
    }
    
    func scheduleUnattendedHolidayNotifications(unattendedDates: [Date]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests() // Optional: Entfernt alte geplante Benachrichtigungen
        for date in unattendedDates {
            let calendar = Calendar.current
            let notifyOffsets: [Int] = [28, 7] // 4 Wochen, 1 Woche
            for offset in notifyOffsets {
                if let notifyDate = calendar.date(byAdding: .day, value: -offset, to: date), notifyDate > Date() {
                    let content = UNMutableNotificationContent()
                    let formatter = DateFormatter()
                    formatter.dateStyle = .long
                    content.title = "Unbetreuter Ferientag"
                    content.body = offset == 28 ? "In 4 Wochen ist am \(formatter.string(from: date)) ein unbetreuter Ferientag! Jetzt Betreuung organisieren." : "In 1 Woche ist am \(formatter.string(from: date)) ein unbetreuter Ferientag!"
                    content.sound = .default
                    let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                    let request = UNNotificationRequest(identifier: "unattended-\(date.timeIntervalSince1970)-\(offset)", content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }
    
    // Test-Benachrichtigung für die Einstellungen
    func sendTestNotification(completion: ((String?) -> Void)? = nil) {
        print("[NotificationService] sendTestNotification aufgerufen")
        requestAuthorization { granted in
            print("[NotificationService] requestAuthorization completion: granted=\(granted)")
            guard granted else {
                let msg = "Push-Benachrichtigungen sind nicht erlaubt. Bitte in den iOS-Einstellungen aktivieren."
                print("[NotificationService] " + msg)
                DispatchQueue.main.async {
                    if let topController = self.getKeyWindow()?.rootViewController {
                        let alert = UIAlertController(title: "Fehler", message: msg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        topController.present(alert, animated: true)
                    }
                }
                completion?(msg)
                return
            }
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Test-Benachrichtigung"
            content.body = "Dies ist eine Testnachricht der Ferienverwaltung. Push funktioniert!"
            content.sound = .default
            // Sende die Benachrichtigung nach 2 Sekunden
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "test-notification-ferienverwaltung", content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    let msg = "Fehler beim Senden der Test-Benachrichtigung: \(error.localizedDescription)"
                    print("[NotificationService] " + msg)
                    DispatchQueue.main.async {
                        if let topController = self.getKeyWindow()?.rootViewController {
                            let alert = UIAlertController(title: "Fehler", message: msg, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            topController.present(alert, animated: true)
                        }
                    }
                    completion?(msg)
                } else {
                    print("[NotificationService] Test-Benachrichtigung wurde erfolgreich hinzugefügt")
                    // --- FOREGROUND-WORKAROUND: Zeige Hinweis als Alert, wenn App im Vordergrund ist ---
                    DispatchQueue.main.async {
                        if let topController = self.getKeyWindow()?.rootViewController {
                            let alert = UIAlertController(title: "Test-Benachrichtigung", message: "Die Test-Benachrichtigung wurde geplant.\n\nAchtung: iOS zeigt Mitteilungen nur an, wenn die App im Hintergrund oder geschlossen ist. Im Vordergrund erscheint KEINE Push-Nachricht!", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            topController.present(alert, animated: true)
                        }
                    }
                    completion?(nil)
                }
            }
        }
    }
}

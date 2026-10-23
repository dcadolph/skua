import BackgroundTasks
import CoreLocation
import Foundation
import UserNotifications

// Notifier surfaces severe weather as local notifications: lightning-bearing
// storm warnings, floods, and anything else the NWS marks Severe or Extreme.
// Real-time push arrives with the hosted backend; this covers the phone today.
enum Notifier {
    // refreshTaskID is the background refresh identifier.
    static let refreshTaskID = "com.douglasadolph.skua.refresh"

    // seenKey tracks already-notified alerts so each fires once.
    private static let seenKey = "skua.notified"

    // lightningSeenKey tracks the last notified storm so each fires once.
    private static let lightningSeenKey = "skua.lightning.notified"

    // requestPermission asks once for notification authorization.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // scheduleReminder fires a one-off local notification at a future moment, used
    // by the flight plan's remind-me action. It asks for permission first so a tap
    // works even before the app has been granted alerts.
    static func scheduleReminder(at date: Date, title: String, body: String) {
        guard date > Date() else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "reminder-\(Int(date.timeIntervalSince1970))"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // notify raises one notification per unseen severe alert, unless alerts are
    // switched off.
    static func notify(alerts: [WeatherAlert]) {
        guard UserDefaults.standard.object(forKey: "skua.notify") as? Bool ?? true else { return }
        let severe = alerts.filter { $0.severity == "Severe" || $0.severity == "Extreme" }
        guard !severe.isEmpty else { return }
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        for a in severe where !seen.contains(a.id) {
            let content = UNMutableNotificationContent()
            content.title = a.event
            content.body = a.headline.isEmpty ? a.area : a.headline
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: a.id, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req)
            seen.insert(a.id)
        }
        UserDefaults.standard.set(Array(seen.suffix(50)), forKey: seenKey)
    }

    // notifyLightning raises one notification when a storm is imminent or the
    // risk runs high, unless alerts are off, deduped by the storm's hour.
    static func notifyLightning(_ lightning: Lightning?, place: String) {
        guard UserDefaults.standard.object(forKey: "skua.notify") as? Bool ?? true else { return }
        guard let l = lightning, l.hasNext, l.imminent || l.level >= 3 else { return }
        let id = "lightning-\(Int(l.next.timeIntervalSince1970))"
        guard UserDefaults.standard.string(forKey: lightningSeenKey) != id else { return }
        let content = UNMutableNotificationContent()
        content.title = l.imminent ? "Storm closing in" : "\(l.risk.capitalized) storm risk"
        content.body = "\(l.headline) \(place)"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil))
        UserDefaults.standard.set(id, forKey: lightningSeenKey)
    }

    // scheduleRefresh asks the system for a background check in about 30
    // minutes. The system decides the actual timing.
    static func scheduleRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    // backgroundCheck fetches alerts for the last shown place and notifies.
    static func backgroundCheck() async {
        let loc = SharedStore.lastLocation()
        if let found = try? await SkuaClient.shared.alerts(lat: loc.lat, lon: loc.lon) {
            notify(alerts: found.alerts)
        }
        scheduleRefresh()
    }
}

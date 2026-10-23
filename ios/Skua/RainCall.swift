import Foundation

// RainCall builds the short rain fact shown in the hero chip row.
enum RainCall {
    // wetThresholdMM is the per-span precipitation that counts as rain.
    private static let wetThresholdMM = 0.1

    // spanSeconds is the length each minutely point covers.
    private static let spanSeconds: TimeInterval = 15 * 60

    // wetWords are condition fragments that mean it is raining now.
    private static let wetWords = ["rain", "shower", "drizzle", "storm", "thunder"]

    // make returns the rain call for the current conditions and minutely series, or nil when
    // there is neither rain now nor a minutely series to describe.
    static func make(current: Current, minutely: [MinutelyPoint], now: Date) -> String? {
        let condition = current.condition.lowercased()
        if current.precipMM >= wetThresholdMM || wetWords.contains(where: condition.contains) {
            return "Rain now"
        }
        let ahead = minutely.filter { $0.time.addingTimeInterval(spanSeconds) > now }
        if let wet = ahead.first(where: { $0.precipMM >= wetThresholdMM }) {
            let mins = max(0, Int(wet.time.timeIntervalSince(now) / 60))
            return mins <= 1 ? "Rain now" : "Rain ~\(mins)m"
        }
        guard let last = minutely.last else { return nil }
        let covered = Int(last.time.addingTimeInterval(spanSeconds).timeIntervalSince(now) / 60)
        let rounded = covered / 15 * 15
        return rounded > 0 ? "Dry next \(rounded)m" : nil
    }
}

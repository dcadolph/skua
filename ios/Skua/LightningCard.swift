import SwiftUI

// LightningCard surfaces near-term storm and strike risk: a graded bolt, the
// bird's read, a severity meter, and when the next storm lands. It shows only
// when there is real risk, so a quiet sky stays out of the way.
struct LightningCard: View {
    let lightning: Lightning

    var body: some View {
        let color = lightningColor(lightning.level)
        return GlassSection(title: "Lightning", icon: "bolt.fill", tint: color) {
            HStack(spacing: 12) {
                Image(systemName: lightning.imminent ? "bolt.trianglebadge.exclamationmark.fill" : "bolt.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(lightning.risk.capitalized) storm risk")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(lightning.headline)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            meter(color: color)
            HStack(spacing: 16) {
                if lightning.hasNext {
                    Stat(
                        label: lightning.imminent ? "Storm imminent" : "Next storm",
                        value: nextStormText,
                        icon: "clock.fill", tint: color)
                }
                Stat(
                    label: "Instability", value: "\(Int(lightning.peakCapeJPerKg)) J/kg",
                    icon: "tornado", tint: Theme.teal)
                if lightning.stormHours > 0 {
                    Stat(
                        label: "Storm hours", value: "\(lightning.stormHours)",
                        icon: "cloud.bolt.fill", tint: Theme.slate)
                }
            }
        }
    }

    // meter is the four-segment severity bar, filled to the risk level.
    private func meter(color: Color) -> some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { seg in
                Capsule()
                    .fill(seg <= lightning.level ? color : Theme.hair)
                    .frame(height: 5)
            }
        }
    }

    // nextStormText pairs the storm's clock time with a countdown.
    private var nextStormText: String {
        "\(lightning.next.formatted(date: .omitted, time: .shortened)) · \(countdownText(to: lightning.next))"
    }
}

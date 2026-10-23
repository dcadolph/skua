import SwiftUI

// SkuaTab is the bird's own page: the mascot, its voice, your maturity setting,
// and the high scores and statistics you have racked up together.
struct SkuaTab: View {
    @ObservedObject var store: WeatherStore
    @ObservedObject var style: StyleStore
    @Binding var level: String
    @State private var bounce = false

    private let levels = ["dry", "proper", "sassy", "salty", "feral"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                bird
                bubble
                PartySection(style: style, store: store)
                personality
                stolenGoods
                statistics
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
    }

    // bird is the mascot, with a small hop on tap.
    private var bird: some View {
        Button {
            Haptics.tick()
            bounce.toggle()
        } label: {
            Group {
                if let plan = style.live {
                    Image(plan.kind.art(heat: plan.heat))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .background(Theme.accent.opacity(0.18), in: Circle())
                } else {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(width: 128, height: 128)
                        .background(Theme.accent, in: Circle())
                }
            }
            .scaleEffect(bounce ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bounce)
        }
        .buttonStyle(.plain)
    }

    // bubble is the skua speaking its current line.
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let v = store.voice {
                Text(v.line)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.text)
                if !v.briefing.isEmpty {
                    Text(v.briefing)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text("The bird is thinking...")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Text(style.live.map { "\($0.kind.crew) Skua, heat set to \($0.heat.title.lowercased())" } ?? "Skua, feeling \(level)")
                .font(.caption)
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    // personality is the maturity dial.
    private var personality: some View {
        GlassSection(title: "Personality", icon: "theatermasks.fill", tint: Theme.accent) {
            Picker("Level", selection: $level) {
                ForEach(levels, id: \.self) { Text($0.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(style.live == nil
                ? "Dry is the house voice: weathered, unbothered, watching out for you. The rest run from proper to feral."
                : "Party mode is doing the talking. This dial comes back when the party ends.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    // stolenGoods is the record extremes the bird has snatched, because skuas
    // steal for a living.
    private var stolenGoods: some View {
        GlassSection(title: "Stolen goods", icon: "bag.fill", tint: Theme.yellow) {
            Text("Skuas steal. These records are yours now.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            VStack(spacing: 12) {
                scoreRow("Hottest heist", Stats.hottest.map { "\(Int($0))°" } ?? "—", "thermometer.sun.fill", Theme.warn)
                scoreRow("Coldest catch", Stats.coldest.map { "\(Int($0))°" } ?? "—", "thermometer.snowflake", Theme.blue)
                scoreRow("Fiercest gust nabbed", Stats.biggestGust > 0 ? "\(Int(Stats.biggestGust)) \(unitSpeed())" : "—", "wind", Theme.green)
                scoreRow("Harshest sun swiped", Stats.highestUV > 0 ? String(format: "%.0f", Stats.highestUV) : "—", "sun.max.fill", Theme.yellow)
            }
        }
    }

    // statistics is the lifetime usage ledger.
    private var statistics: some View {
        GlassSection(title: "Statistics", icon: "chart.bar.fill", tint: Theme.muted) {
            VStack(spacing: 12) {
                scoreRow("First flight", Stats.firstUse?.formatted(date: .abbreviated, time: .omitted) ?? "—", "calendar", Theme.accent)
                scoreRow("Days used", "\(Stats.daysUsed)", "clock.fill", Theme.muted)
                scoreRow("Forecasts fetched", "\(Stats.fetches)", "arrow.triangle.2.circlepath", Theme.muted)
                scoreRow("Cities visited", "\(Stats.cities)", "map.fill", Theme.muted)
            }
        }
    }

    // scoreRow is one labeled record line.
    private func scoreRow(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .font(.system(.subheadline, design: .monospaced))
        }
    }

    // footer credits the product.
    private var footer: some View {
        VStack(spacing: 2) {
            Text("Skua \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("Your fowl-weather friend")
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 6)
    }
}

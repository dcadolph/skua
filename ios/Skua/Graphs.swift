import Charts
import SwiftUI

// GraphSeries defines one graphable hourly data series.
struct GraphSeries: Identifiable {
    // id is the stable series key.
    let id: String
    // label names the series in the picker and header.
    let label: String
    // unit is the display unit shown in the header and readout.
    let unit: String
    // color draws the series.
    let color: Color
    // bar renders bars instead of a line, right for probabilities.
    let bar: Bool
    // value extracts the display value from an hour, nil when the backend did
    // not send the series.
    let value: (HourlyPoint) -> Double?
}

// graphSeriesList is the catalog of series the graph can show, with unit
// labels following the chosen measurement system.
func graphSeriesList() -> [GraphSeries] { [
    GraphSeries(id: "temp", label: "Temperature", unit: unitTemp(), color: Theme.accent, bar: false) { Double(f($0.tempC)) },
    GraphSeries(id: "feels", label: "Feels like", unit: unitTemp(), color: Theme.amber, bar: false) {
        $0.apparentTempC.map { Double(f($0)) }
    },
    GraphSeries(id: "rain", label: "Rain chance", unit: "%", color: Theme.rain, bar: true) { Double($0.precipProb) },
    GraphSeries(id: "wind", label: "Wind", unit: "mph", color: Theme.green, bar: false) {
        Double(mph($0.windKph))
    },
    GraphSeries(id: "gusts", label: "Gusts", unit: "mph", color: Theme.teal, bar: false) {
        $0.windGustKph.map { Double(mph($0)) }
    },
    GraphSeries(id: "humidity", label: "Humidity", unit: "%", color: Theme.blue, bar: false) {
        $0.humidity.map(Double.init)
    },
    GraphSeries(id: "dew", label: "Dew point", unit: unitTemp(), color: Theme.cyan, bar: false) {
        $0.dewPointC.map { Double(f($0)) }
    },
    GraphSeries(id: "pressure", label: "Pressure", unit: "inHg", color: Theme.purple, bar: false) {
        $0.pressureHPa.map { ($0 * 0.02953 * 100).rounded() / 100 }
    },
    GraphSeries(id: "cloud", label: "Cloud cover", unit: "%", color: Theme.slate, bar: false) {
        $0.cloudCover.map(Double.init)
    },
    GraphSeries(id: "uv", label: "UV index", unit: "", color: Theme.yellow, bar: false) { $0.uvIndex },
] }

// GraphCard graphs any hourly series across the next 48 hours. Hold and drag to
// scrub; the header reads out the exact hour and value, so nothing floats over
// the plot.
struct GraphCard: View {
    let hours: [HourlyPoint]
    let seriesID: String
    // window is how many hours ahead to plot.
    var window: Int = 24
    // onSeriesChange persists a chip selection back to the layout instance.
    let onSeriesChange: (String) -> Void
    // onWindowChange persists the chosen horizon back to the layout instance.
    var onWindowChange: (Int) -> Void = { _ in }
    @State private var picked: (time: Date, value: Double)?

    // windowOptions are the horizons the graph offers.
    private let windowOptions = [2, 3, 4, 5, 8, 10, 12, 24]

    private var series: GraphSeries {
        graphSeriesList().first { $0.id == seriesID } ?? graphSeriesList()[0]
    }

    // points pairs each hour in the chosen window with the selected series value.
    private var points: [(time: Date, value: Double)] {
        hours.compactMap { h in
            series.value(h).map { (h.time, $0) }
        }
    }

    var body: some View {
        GlassSection(title: "Graphs", icon: "chart.xyaxis.line", tint: Theme.accent) {
            seriesHeader
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(graphSeriesList()) { s in
                        Button {
                            onSeriesChange(s.id)
                            Haptics.tick()
                        } label: {
                            Text(s.label)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(
                                    seriesID == s.id
                                        ? AnyShapeStyle(s.color.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule())
                                .foregroundStyle(seriesID == s.id ? Color.black : Theme.muted)
                        }
                    }
                }
            }
            if points.count > 1 {
                chart
                Text("Hold and drag the chart to read exact values.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted.opacity(0.8))
            } else {
                Text("This series is not available from the current source.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    // seriesHeader names what is on screen and hosts the live readout in a
    // fixed slot, so scrubbing never overlays the plot.
    private var seriesHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(series.color)
                .frame(width: 8, height: 8)
            Text(series.label)
                .font(.headline)
                .foregroundStyle(series.color)
            Text(series.unit)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Spacer()
            if let picked {
                Text("\(picked.time.formatted(.dateTime.weekday(.abbreviated).hour()))  \(readout(picked.value))")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(series.color)
                    .contentTransition(.numericText())
            } else {
                Menu {
                    ForEach(windowOptions, id: \.self) { w in
                        Button("Next \(w) hours") {
                            onWindowChange(w)
                            Haptics.tick()
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("Next \(window)h")
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(height: 22)
    }

    // chart draws the selected series with values on the curve and a scrub rule.
    private var chart: some View {
        Chart {
            ForEach(points.indices, id: \.self) { i in
                let p = points[i]
                if series.bar {
                    BarMark(x: .value("Hour", p.time), y: .value(series.label, p.value))
                        .foregroundStyle(series.color.opacity(0.8))
                } else {
                    AreaMark(x: .value("Hour", p.time), y: .value(series.label, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [series.color.opacity(0.25), series.color.opacity(0)],
                                startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Hour", p.time), y: .value(series.label, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(series.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    if points.count <= 8 || i % 6 == 2 {
                        PointMark(x: .value("Hour", p.time), y: .value(series.label, p.value))
                            .symbolSize(0)
                            .annotation(position: .top, spacing: 3) {
                                Text(axisText(p.value))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(series.color)
                            }
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Double(max(2, window)) * 3600)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: window <= 6 ? 1 : (window <= 12 ? 3 : 12))) { _ in
                AxisGridLine().foregroundStyle(Theme.hair)
                AxisValueLabel(format: window <= 12 ? .dateTime.hour() : .dateTime.weekday(.narrow).hour())
                    .foregroundStyle(Theme.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.hair)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(axisText(v))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .frame(height: 160)
        .animation(.snappy(duration: 0.25), value: seriesID)
    }

    // scrubGesture requires a brief hold before the drag, so normal page
    // scrolling never fights the chart.
    private func scrubGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                guard let drag else {
                    Haptics.tick()
                    return
                }
                let origin = geo[proxy.plotAreaFrame].origin
                guard let date: Date = proxy.value(atX: drag.location.x - origin.x) else { return }
                if let nearest = points.min(by: {
                    abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date))
                }) {
                    if picked?.time != nearest.time {
                        Haptics.tick()
                    }
                    picked = nearest
                }
            }
            .onEnded { _ in picked = nil }
    }

    // readout formats a scrubbed value with the series unit.
    private func readout(_ v: Double) -> String {
        if series.id == "pressure" {
            return String(format: "%.2f %@", v, series.unit)
        }
        if series.unit.isEmpty {
            return "\(Int(v.rounded()))"
        }
        if series.unit == unitTemp() {
            return "\(Int(v.rounded()))°"
        }
        if series.unit == "%" {
            return "\(Int(v.rounded()))%"
        }
        return "\(Int(v.rounded())) \(series.unit)"
    }

    // axisText compactly labels axis ticks and on-curve values.
    private func axisText(_ v: Double) -> String {
        switch series.id {
        case "pressure":
            return String(format: "%.2f", v)
        case "temp", "feels", "dew":
            return "\(Int(v.rounded()))°"
        case "rain", "humidity", "cloud":
            return "\(Int(v.rounded()))%"
        default:
            return "\(Int(v.rounded()))"
        }
    }

    // yDomain pads the series range, with extra headroom for the on-curve
    // value labels; probability series pin to the full scale.
    private var yDomain: ClosedRange<Double> {
        if series.bar || series.id == "humidity" || series.id == "cloud" {
            return 0...112
        }
        let values = points.map(\.value)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let pad = max(2, (hi - lo) * 0.2)
        return (lo - pad * 0.6)...(hi + pad * 1.6)
    }
}

// NowcastCard is the next two hours of fine-grained rain, shown only when rain
// is actually in play.
struct NowcastCard: View {
    let minutely: [MinutelyPoint]

    var body: some View {
        if minutely.contains(where: { $0.precipMM > 0 }) {
            GlassSection(title: "Nowcast", icon: "umbrella.fill", tint: Theme.rain) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Theme.rain).frame(width: 8, height: 8)
                    Text("Rain intensity")
                        .font(.headline)
                        .foregroundStyle(Theme.rain)
                    Text("in per 15 min")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Text("Next 2 hours")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Chart(minutely, id: \.time) { p in
                    BarMark(
                        x: .value("Time", p.time),
                        y: .value("Rain", p.precipMM * 0.0393701),
                        width: .ratio(0.7))
                    .foregroundStyle(Theme.rain.opacity(0.85))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 30)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hair)
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .foregroundStyle(Theme.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { _ in
                        AxisValueLabel().foregroundStyle(Theme.muted)
                    }
                }
                .frame(height: 80)
                .clipped()
            }
        }
    }
}

import MapKit
import SwiftUI

// RadarMapView renders the radar frames as animated tile overlays on a dark
// map, looping through past and forecast frames.
struct RadarMapView: UIViewRepresentable {
    let host: String
    let frames: [RadarFrame]
    // tileColor is the RainViewer path segment for the color scheme and options,
    // "2/1_1" for radar and "0/0_0" for the infrared satellite view.
    let tileColor: String
    let center: CLLocationCoordinate2D
    let playing: Bool
    // recenterToken recenters the map whenever it changes.
    let recenterToken: Int
    @Binding var frameIndex: Int

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.overrideUserInterfaceStyle = .dark
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        map.delegate = context.coordinator
        map.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 5.5, longitudeDelta: 5.5))
        let pin = MKPointAnnotation()
        pin.coordinate = center
        map.addAnnotation(pin)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.sync(
            map: map, host: host, frames: frames, tileColor: tileColor, playing: playing,
            index: $frameIndex, center: center, recenterToken: recenterToken)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.stop()
    }

    // Coordinator drives the frame loop and swaps tile overlays without
    // flicker: the next frame is added beneath, then the old one removed.
    final class Coordinator: NSObject, MKMapViewDelegate {
        private var timer: Timer?
        private var host = ""
        private var frames: [RadarFrame] = []
        private var tileColor = "2/1_1"
        private var current: MKTileOverlay?
        private weak var map: MKMapView?
        private var index: Binding<Int>?
        private var shown = -1
        private var lastRecenterToken = 0

        // sync applies the latest SwiftUI state to the map.
        func sync(
            map: MKMapView, host: String, frames: [RadarFrame], tileColor: String,
            playing: Bool, index: Binding<Int>, center: CLLocationCoordinate2D, recenterToken: Int
        ) {
            self.map = map
            self.index = index
            self.tileColor = tileColor
            if self.host != host || self.frames.map(\.path) != frames.map(\.path) {
                self.host = host
                self.frames = frames
                shown = -1
                show(frame: min(index.wrappedValue, max(0, frames.count - 1)))
            }
            if index.wrappedValue != shown {
                show(frame: index.wrappedValue)
            }
            if recenterToken != lastRecenterToken {
                lastRecenterToken = recenterToken
                map.setRegion(
                    MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: 5.5, longitudeDelta: 5.5)),
                    animated: true)
            }
            if playing, timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                    self?.advance()
                }
            } else if !playing {
                timer?.invalidate()
                timer = nil
            }
        }

        // advance steps to the next frame, looping.
        private func advance() {
            guard !frames.isEmpty else { return }
            let next = ((index?.wrappedValue ?? 0) + 1) % frames.count
            index?.wrappedValue = next
            show(frame: next)
        }

        // show swaps the visible overlay to the given frame.
        func show(frame i: Int) {
            guard let map, frames.indices.contains(i) else { return }
            shown = i
            let f = frames[i]
            let overlay = MKTileOverlay(
                urlTemplate: "\(host)\(f.path)/512/{z}/{x}/{y}/\(tileColor).png")
            overlay.tileSize = CGSize(width: 512, height: 512)
            map.addOverlay(overlay, level: .aboveLabels)
            if let old = current {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    map.removeOverlay(old)
                }
            }
            current = overlay
        }

        // stop tears the loop down.
        func stop() {
            timer?.invalidate()
            timer = nil
        }

        // mapView renders tile overlays at radar opacity.
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: tiles)
                r.alpha = 0.7
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // mapView styles the location pin as an accent dot.
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "loc"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            let size: CGFloat = 14
            UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
            UIColor(Theme.accent).setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: size - 4, height: size - 4)).fill()
            view.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return view
        }
    }
}

// RadarTimeline is the scrubber under the radar: a track that turns accent where
// the forecast frames begin, a draggable thumb, and the span's start and end.
struct RadarTimeline: View {
    let frames: [RadarFrame]
    @Binding var index: Int
    @Binding var playing: Bool

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                let steps = max(1, frames.count - 1)
                let clamped = CGFloat(min(max(0, index), steps))
                let thumbX = width * clamped / CGFloat(steps)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.muted.opacity(0.25)).frame(height: 4)
                    if let nowFrac = nowFraction {
                        Capsule().fill(Theme.accent.opacity(0.45))
                            .frame(width: max(0, width * (1 - nowFrac)), height: 4)
                            .offset(x: width * nowFrac)
                        Rectangle().fill(Theme.text.opacity(0.6))
                            .frame(width: 2, height: 16)
                            .offset(x: min(max(0, width * nowFrac - 1), width - 2))
                    }
                    Circle().fill(Theme.accent)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .offset(x: min(max(0, thumbX - 8), width - 16))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            playing = false
                            let frac = max(0, min(1, value.location.x / max(1, width)))
                            let i = Int((frac * CGFloat(steps)).rounded())
                            if i != index { index = i; Haptics.tick() }
                        }
                )
            }
            .frame(height: 22)
            HStack {
                Text(timeText(frames.first))
                Spacer()
                Text(timeText(frames.last))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.muted)
        }
    }

    // nowFraction is where the forecast frames begin, from zero to one, or nil
    // when there are none, as with satellite.
    private var nowFraction: CGFloat? {
        guard let first = frames.firstIndex(where: { $0.future }) else { return nil }
        return CGFloat(first) / CGFloat(max(1, frames.count - 1))
    }

    // timeText formats a frame's time, or empty when absent.
    private func timeText(_ frame: RadarFrame?) -> String {
        frame?.time.formatted(date: .omitted, time: .shortened) ?? ""
    }
}

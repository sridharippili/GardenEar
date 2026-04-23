import SwiftUI
import AVFoundation

// MARK: - Public interface (unchanged — RecordView calls WaveformView(recorder:))

struct WaveformView: View {
    let recorder: AVAudioRecorder?

    /// 0…1 live amplitude read from the recorder's metering.
    @State private var amplitude: Double = 0.0
    @State private var meterTimer: Timer?

    var body: some View {
        SonicWaveCanvas(amplitude: amplitude)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear  { startMetering() }
            .onDisappear { stopMetering() }
    }

    // MARK: - Metering

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            recorder?.updateMeters()
            // averagePower: –160…0 dB → map –60…0 to 0…1
            let dB    = Double(recorder?.averagePower(forChannel: 0) ?? -60)
            amplitude = min(max((dB + 60.0) / 60.0, 0), 1)
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        amplitude = 0
    }
}

// MARK: - Animated canvas

/// Translates the React/Canvas sonic-wave reference into SwiftUI.
///
/// Web reference parameters:
///   lines    = 60     (horizontal wave lines)
///   segments = 80     (points per line)
///   noise    = sin(j * 0.1 + time + i * 0.2) * 20
///   spike    = cos(j * 0.2 + time + i * 0.1) * sin(j * 0.05 + time) * 50
///   color    = rgba(0, 255, 192, sin(progress * PI) * 0.5)
///   dt       = 0.02 per frame  →  60 fps via TimelineView
private struct SonicWaveCanvas: View {

    /// 0 = idle, 1 = loudest recording
    var amplitude: Double

    private let lineCount  = 60
    private let segCount   = 80
    private let idleAmp    = 0.15   // gentle waves when not recording
    private let liveAmpMax = 1.0    // full spike when loud

    var body: some View {
        TimelineView(.animation) { timeline in
            // Convert wall-clock seconds → wave time so animation is smooth
            // regardless of when the view first appears.
            let t = timeline.date.timeIntervalSinceReferenceDate * 0.02 * 60
            // ^— multiply by 60 so one second of real time equals 60 web frames
            //    matching the reference's 0.02 * 60fps cadence exactly.

            Canvas { ctx, size in
                drawBackground(ctx: ctx, size: size)
                drawWaves(ctx: ctx, size: size, time: t)
            }
        }
        .background(Color.black)
    }

    // MARK: - Background fill
    // Web: ctx.fillStyle = "rgba(0,0,0,0.1)" — trails fade naturally.
    // In SwiftUI Canvas we redraw the whole frame each tick, so we
    // layer a semi-transparent dark rect over a solid black background.
    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.black.opacity(0.85))
        )
    }

    // MARK: - Wave lines
    private func drawWaves(ctx: GraphicsContext, size: CGSize, time: Double) {
        let effectiveAmp = idleAmp + amplitude * (liveAmpMax - idleAmp)

        for i in 0 ..< lineCount {
            let progress  = Double(i) / Double(lineCount - 1)   // 0…1
            // Web: colorIntensity = sin(progress * PI) * 0.5
            let colorIntensity = sin(progress * .pi) * 0.5

            // Teal: rgba(0, 255, 192, …) → SwiftUI Color(red:green:blue:opacity:)
            let lineColor = Color(
                red:     0.0,
                green:   1.0,
                blue:    0.75,
                opacity: max(colorIntensity, 0.05)   // keep faint lines visible
            )

            // Build the path for this wave line
            var path = Path()
            var firstPoint = true

            for j in 0 ... segCount {
                let x = size.width * Double(j) / Double(segCount)

                // Web formulas, translated 1-to-1:
                let noise = sin(Double(j) * 0.1 + time + Double(i) * 0.2) * 20.0
                let spike = cos(Double(j) * 0.2 + time + Double(i) * 0.1)
                         * sin(Double(j) * 0.05 + time)
                         * 50.0

                // Centre each line vertically, then offset by noise + spike,
                // scaled by effective amplitude so idle mode stays gentle.
                let baseY    = size.height * progress
                let deflect  = (noise + spike * effectiveAmp) * colorIntensity
                let y        = baseY + deflect

                let point = CGPoint(x: x, y: y)
                if firstPoint {
                    path.move(to: point)
                    firstPoint = false
                } else {
                    path.addLine(to: point)
                }
            }

            ctx.stroke(
                path,
                with: .color(lineColor),
                lineWidth: 1.0
            )
        }
    }
}

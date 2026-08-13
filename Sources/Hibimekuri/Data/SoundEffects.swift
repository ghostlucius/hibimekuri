import AVFoundation

/// Plays a short procedurally-generated "paper rustle" sound. Synthesized
/// rather than bundled: there's no licensed tear/rip sound asset available
/// here, so this shapes filtered noise into a soft rustle instead of
/// shipping an unlicensed downloaded file.
final class SoundEffects {
    static let shared = SoundEffects()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var tearBuffer: AVAudioPCMBuffer?

    private init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        tearBuffer = Self.makeTearBuffer(format: format)
        try? engine.start()
    }

    func playTearOff() {
        guard let tearBuffer else { return }
        if !engine.isRunning { try? engine.start() }
        player.stop()
        player.scheduleBuffer(tearBuffer, at: nil, options: .interrupts)
        player.play()
    }

    /// Heavily low-passed noise (two cascaded leaky integrators, for a
    /// muffled "shh" rather than bright hiss) with a slow random-walk
    /// amplitude wobble layered on top, so it reads as an organic paper
    /// rustle instead of static or a sharp rip. No sharp transients —
    /// gentle attack, soft undulating body, long fade.
    private static func makeTearBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration = 0.65
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        var stage1: Float = 0
        var stage2: Float = 0
        var wobble: Float = 0.7

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Float(t / duration)

            let white = Float.random(in: -1...1)
            stage1 = stage1 * 0.90 + white * 0.10
            stage2 = stage2 * 0.90 + stage1 * 0.10

            wobble += Float.random(in: -0.015...0.015)
            wobble = min(max(wobble, 0.45), 1.0)

            let envelope: Float
            if progress < 0.18 {
                envelope = progress / 0.18
            } else if progress < 0.7 {
                envelope = 1.0
            } else {
                envelope = max(0, 1 - (progress - 0.7) / 0.3)
            }

            channel[i] = stage2 * envelope * wobble * 0.16
        }
        return buffer
    }
}

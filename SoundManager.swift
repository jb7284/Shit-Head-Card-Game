import AVFoundation

@MainActor
enum SoundManager {
    private static var engine: AVAudioEngine?
    private static var playerNode: AVAudioPlayerNode?
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private static func ensureEngine() {
        guard engine == nil else { return }
        let eng = AVAudioEngine()
        let node = AVAudioPlayerNode()
        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        try? eng.start()
        engine = eng
        playerNode = node
    }

    static func play(_ sound: GameSound) {
        ensureEngine()
        guard let node = playerNode else { return }

        let buffer = sound.generate(format: format)
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }
}

enum GameSound {
    case burn
    case pickup
    case skipped
    case reverse
    case joker

    func generate(format: AVAudioFormat) -> AVAudioPCMBuffer {
        switch self {
        case .burn: return Self.makeBurn(format: format)
        case .pickup: return Self.makePickup(format: format)
        case .skipped: return Self.makeSkipped(format: format)
        case .reverse: return Self.makeReverse(format: format)
        case .joker: return Self.makeJoker(format: format)
        }
    }

    // Descending sweep with noise burst — dramatic "whoosh"
    private static func makeBurn(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.45
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Frequency sweeps down from 1200 Hz to 200 Hz
            let freq = 1200.0 - progress * 1000.0
            let phase = 2.0 * .pi * freq * t
            let tone = sin(phase) * 0.4

            // Add noise burst that fades
            let noise = Double.random(in: -1...1) * 0.25 * (1.0 - progress)

            // Envelope: quick attack, gradual fade
            let envelope = min(t / 0.01, 1.0) * pow(1.0 - progress, 1.5)

            samples[i] = Float((tone + noise) * envelope * 0.7)
        }
        return buffer
    }

    // Low thud with rumble — heavy, negative
    private static func makePickup(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.35
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Low fundamental at 80 Hz with a sub-harmonic
            let tone1 = sin(2.0 * .pi * 80.0 * t) * 0.5
            let tone2 = sin(2.0 * .pi * 50.0 * t) * 0.3
            // Brief click at the start
            let click = (t < 0.008) ? Double.random(in: -1...1) * 0.6 : 0.0

            // Quick exponential decay
            let envelope = exp(-progress * 6.0) * min(t / 0.005, 1.0)

            samples[i] = Float((tone1 + tone2 + click) * envelope * 0.8)
        }
        return buffer
    }

    // Wobbling sweep — "direction change" feel
    private static func makeReverse(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            let wobble = sin(2.0 * .pi * 6.0 * t) * 200.0
            let freq = 800.0 + wobble
            let tone = sin(2.0 * .pi * freq * t) * 0.35
            let harmonic = sin(2.0 * .pi * freq * 1.5 * t) * 0.12

            let envelope = min(t / 0.008, 1.0) * pow(1.0 - progress, 1.8)

            samples[i] = Float((tone + harmonic) * envelope * 0.7)
        }
        return buffer
    }

    // Rising laugh-like trill — mischievous, chaotic
    private static func makeJoker(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            let trill = sin(2.0 * .pi * 18.0 * t) * 300.0
            let freq = 600.0 + progress * 800.0 + trill
            let tone = sin(2.0 * .pi * freq * t) * 0.3
            let harmonic = sin(2.0 * .pi * freq * 1.5 * t) * 0.15

            let envelope = min(t / 0.008, 1.0) * pow(1.0 - progress, 1.2)

            samples[i] = Float((tone + harmonic) * envelope * 0.7)
        }
        return buffer
    }

    // Sharp two-tone ding — alerting, attention-grabbing
    private static func makeSkipped(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Two-tone: starts at 880 Hz, jumps to 1320 Hz at halfway
            let freq = t < (duration / 2) ? 880.0 : 1320.0
            let tone = sin(2.0 * .pi * freq * t) * 0.35

            // Add a shimmer harmonic
            let harmonic = sin(2.0 * .pi * freq * 2.5 * t) * 0.1

            // Envelope with slight re-attack at the second note
            let noteStart = t < (duration / 2) ? t : t - (duration / 2)
            let envelope = min(noteStart / 0.005, 1.0) * pow(1.0 - progress, 2.0)

            samples[i] = Float((tone + harmonic) * envelope * 0.7)
        }
        return buffer
    }
}

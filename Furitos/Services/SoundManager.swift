import AVFoundation
import Foundation

class SoundManager {
    static let shared = SoundManager()

    private var audioEngine = AVAudioEngine()
    private var mixerNode = AVAudioMixerNode()
    var volume: Float = 0.8

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        audioEngine.attach(mixerNode)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: nil)
        try? audioEngine.start()
    }

    private func playTone(frequency: Float, duration: Float, waveform: WaveformType = .sine,
                          volume: Float? = nil, attack: Float = 0.01, decay: Float = 0.1) {
        let vol = volume ?? self.volume
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }
        buffer.frameLength = frameCount

        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            var sample: Float
            switch waveform {
            case .sine:
                sample = sin(2 * Float.pi * frequency * t)
            case .square:
                sample = sin(2 * Float.pi * frequency * t) > 0 ? 1.0 : -1.0
            case .sawtooth:
                sample = 2 * (t * frequency - floor(t * frequency + 0.5))
            case .noise:
                sample = Float.random(in: -1...1)
            }
            // Envelope
            let envAttack = Float(i) / (sampleRate * attack)
            let envDecay = 1.0 - max(0, (Float(i) / sampleRate - attack) / decay)
            let envelope = min(envAttack, max(0, envDecay))
            channelData[i] = sample * envelope * vol
        }

        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mixerNode, format: buffer.format)
        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.audioEngine.detach(playerNode)
            }
        }
        if !audioEngine.isRunning { try? audioEngine.start() }
        playerNode.play()
    }

    func playClick() {
        playTone(frequency: 800, duration: 0.05, waveform: .sine, volume: 0.3, attack: 0.005, decay: 0.04)
    }

    func playWhoosh() {
        playTone(frequency: 400, duration: 0.12, waveform: .noise, volume: 0.25, attack: 0.01, decay: 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.playTone(frequency: 600, duration: 0.08, waveform: .sine, volume: 0.15, attack: 0.005, decay: 0.07)
        }
    }

    func playThud() {
        playTone(frequency: 120, duration: 0.15, waveform: .sine, volume: 0.5, attack: 0.005, decay: 0.12)
        playTone(frequency: 80, duration: 0.2, waveform: .sine, volume: 0.4, attack: 0.005, decay: 0.18)
    }

    func playChime() {
        let notes: [(Float, Double)] = [(523, 0), (659, 0.08), (784, 0.16), (1047, 0.24)]
        for (freq, delay) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(frequency: freq, duration: 0.3, waveform: .sine, volume: 0.6, attack: 0.01, decay: 0.25)
            }
        }
    }

    func playExplosion() {
        // Multi-layered epic explosion for fever
        playTone(frequency: 60, duration: 0.8, waveform: .noise, volume: 0.7, attack: 0.01, decay: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.playTone(frequency: 150, duration: 0.5, waveform: .sawtooth, volume: 0.5, attack: 0.01, decay: 0.45)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 800, duration: 0.3, waveform: .sine, volume: 0.4, attack: 0.01, decay: 0.25)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 1200, duration: 0.2, waveform: .sine, volume: 0.3, attack: 0.01, decay: 0.15)
        }
        // Rising arpeggio
        let notes: [(Float, Double)] = [(261, 0.3), (329, 0.38), (392, 0.46), (523, 0.54), (659, 0.62), (784, 0.70)]
        for (freq, delay) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(frequency: freq, duration: 0.15, waveform: .square, volume: 0.35, attack: 0.005, decay: 0.12)
            }
        }
    }

    func playDoubleLineClear() {
        let notes: [(Float, Double)] = [(440, 0), (554, 0.07), (659, 0.14), (880, 0.21)]
        for (freq, delay) in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playTone(frequency: freq, duration: 0.25, waveform: .sine, volume: 0.55, attack: 0.01, decay: 0.22)
            }
        }
    }
}

enum WaveformType {
    case sine, square, sawtooth, noise
}

// MARK: - Heavy Metal BGM Engine (Pre-rendered loop)
class BGMManager {
    static let shared = BGMManager()

    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var isPlaying = false
    private let sampleRate: Float = 44100
    private let bpm: Float = 180

    private init() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode,
                           format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!)
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true

        let buffer = renderLoop()
        try? audioEngine.start()
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.volume = 0.5
        playerNode.play()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        playerNode.stop()
        audioEngine.stop()
    }

    // Pre-render the entire 2-bar loop into one buffer
    private func renderLoop() -> AVAudioPCMBuffer {
        let beatDuration = 60.0 / bpm / 2.0 // 16th note
        let totalBeats = 32
        let totalDuration = beatDuration * Float(totalBeats)
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Zero fill
        for i in 0..<Int(frameCount) { data[i] = 0 }

        // Melody pattern: Korobeiniki (Tetris theme)
        let melodyPattern: [(Float, Bool)] = [
            (329.63, true), (0, false), (246.94, true), (0, false),
            (261.63, true), (0, false), (293.66, true), (293.66, true),
            (261.63, true), (0, false), (246.94, true), (0, false),
            (220.00, true), (0, false), (220.00, true), (0, false),
            (220.00, true), (0, false), (261.63, true), (0, false),
            (329.63, true), (0, false), (293.66, true), (293.66, true),
            (261.63, true), (0, false), (246.94, true), (0, false),
            (246.94, true), (0, false), (261.63, true), (0, false),
        ]

        for beat in 0..<totalBeats {
            let beatStart = Int(Float(beat) * beatDuration * sampleRate)
            let noteDuration = Int(beatDuration * sampleRate * 0.8)

            let (freq, play) = melodyPattern[beat]

            // Distorted power chord melody
            if play {
                mixDistorted(into: data, at: beatStart, duration: noteDuration, frequency: freq, volume: 0.35)
                mixDistorted(into: data, at: beatStart, duration: noteDuration, frequency: freq * 1.5, volume: 0.2)
            }

            // Kick on every 4th
            if beat % 4 == 0 {
                mixDrum(into: data, at: beatStart, duration: Int(0.1 * sampleRate), frequency: 55, volume: 0.6)
            }

            // Snare on every 4th offset 2
            if beat % 4 == 2 {
                mixSnare(into: data, at: beatStart, duration: Int(0.08 * sampleRate), volume: 0.4)
            }

            // Double bass
            if beat % 2 == 0 {
                mixDrum(into: data, at: beatStart, duration: Int(0.05 * sampleRate), frequency: 45, volume: 0.3)
            }

            // Hi-hat every beat
            mixNoise(into: data, at: beatStart, duration: Int(0.03 * sampleRate), volume: 0.15)
        }

        // Clamp to prevent clipping
        for i in 0..<Int(frameCount) {
            data[i] = max(-1.0, min(1.0, data[i]))
        }

        return buffer
    }

    private func mixDistorted(into data: UnsafeMutablePointer<Float>, at offset: Int, duration: Int, frequency: Float, volume: Float) {
        for i in 0..<duration {
            let idx = offset + i
            guard idx < Int(sampleRate * 60.0 / bpm / 2.0 * 32) else { break }
            let t = Float(i) / sampleRate
            var sample = sin(2 * Float.pi * frequency * t)
            sample += 0.5 * (2 * (t * frequency - floor(t * frequency + 0.5)))
            sample += 0.3 * (sin(2 * Float.pi * frequency * 2 * t) > 0 ? 1.0 : -1.0)
            sample = max(-0.8, min(0.8, sample * 2.5))
            let env = min(Float(i) / (sampleRate * 0.005), 1.0 - max(0, (Float(i) / sampleRate - 0.005) / (Float(duration) / sampleRate - 0.005)))
            data[idx] += sample * max(0, env) * volume
        }
    }

    private func mixDrum(into data: UnsafeMutablePointer<Float>, at offset: Int, duration: Int, frequency: Float, volume: Float) {
        for i in 0..<duration {
            let idx = offset + i
            guard idx < Int(sampleRate * 60.0 / bpm / 2.0 * 32) else { break }
            let t = Float(i) / sampleRate
            let dur = Float(duration) / sampleRate
            let pitchDrop = frequency * (1.0 - t / dur * 0.8)
            let sample = sin(2 * Float.pi * pitchDrop * t)
            let env = 1.0 - t / dur
            data[idx] += sample * env * env * volume
        }
    }

    private func mixSnare(into data: UnsafeMutablePointer<Float>, at offset: Int, duration: Int, volume: Float) {
        for i in 0..<duration {
            let idx = offset + i
            guard idx < Int(sampleRate * 60.0 / bpm / 2.0 * 32) else { break }
            let t = Float(i) / sampleRate
            let dur = Float(duration) / sampleRate
            let noise = Float.random(in: -1...1)
            let tone = sin(2 * Float.pi * 200 * t)
            let env = 1.0 - t / dur
            data[idx] += (noise * 0.7 + tone * 0.3) * env * env * volume
        }
    }

    private func mixNoise(into data: UnsafeMutablePointer<Float>, at offset: Int, duration: Int, volume: Float) {
        for i in 0..<duration {
            let idx = offset + i
            guard idx < Int(sampleRate * 60.0 / bpm / 2.0 * 32) else { break }
            let t = Float(i) / sampleRate
            let dur = Float(duration) / sampleRate
            let noise = Float.random(in: -1...1)
            let env = 1.0 - t / dur
            data[idx] += noise * env * env * env * volume
        }
    }
}

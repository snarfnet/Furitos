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

// MARK: - Heavy Metal BGM Engine
class BGMManager {
    static let shared = BGMManager()

    private var audioEngine = AVAudioEngine()
    private var mixerNode = AVAudioMixerNode()
    private var isPlaying = false
    private var bgmTimer: Timer?
    private let bpm: Double = 180 // Fast heavy metal tempo
    private var beatIndex = 0

    private init() {
        audioEngine.attach(mixerNode)
        mixerNode.outputVolume = 0.5
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: nil)
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        try? audioEngine.start()
        beatIndex = 0
        let interval = 60.0 / bpm / 2.0 // 16th note speed
        bgmTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playBeat()
        }
    }

    func stop() {
        isPlaying = false
        bgmTimer?.invalidate()
        bgmTimer = nil
        audioEngine.stop()
    }

    private func playBeat() {
        let beat = beatIndex % 32

        // Heavy metal Korobeiniki (Tetris theme) - power chord version
        // E minor pentatonic riff pattern
        let melodyPattern: [(Float, Bool)] = [
            // Bar 1: E4-B3-C4-D4-C4-B3-A3-A3
            (329.63, true), (0, false), (246.94, true), (0, false),
            (261.63, true), (0, false), (293.66, true), (293.66, true),
            (261.63, true), (0, false), (246.94, true), (0, false),
            (220.00, true), (0, false), (220.00, true), (0, false),
            // Bar 2: A3-C4-E4-D4-C4-B3-B3-C4
            (220.00, true), (0, false), (261.63, true), (0, false),
            (329.63, true), (0, false), (293.66, true), (293.66, true),
            (261.63, true), (0, false), (246.94, true), (0, false),
            (246.94, true), (0, false), (261.63, true), (0, false),
        ]

        let (freq, play) = melodyPattern[beat]

        // Distorted power chord melody
        if play {
            playDistorted(frequency: freq, duration: 0.08, volume: 0.35)
            // Power chord: add fifth
            playDistorted(frequency: freq * 1.5, duration: 0.08, volume: 0.2)
        }

        // Kick drum on every 4th beat
        if beat % 4 == 0 {
            playDrum(frequency: 55, duration: 0.1, volume: 0.6)
        }

        // Snare on every 4th beat offset by 2
        if beat % 4 == 2 {
            playSnare(volume: 0.4)
        }

        // Double bass drum pattern (every other 16th note for heaviness)
        if beat % 2 == 0 {
            playDrum(frequency: 45, duration: 0.05, volume: 0.3)
        }

        // Hi-hat on every beat
        playHiHat(volume: 0.15)

        beatIndex += 1
    }

    private func playDistorted(frequency: Float, duration: Float, volume: Float) {
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            // Layered distortion: square + sawtooth + overtones
            var sample = sin(2 * Float.pi * frequency * t)
            sample += 0.5 * (2 * (t * frequency - floor(t * frequency + 0.5))) // sawtooth
            sample += 0.3 * (sin(2 * Float.pi * frequency * 2 * t) > 0 ? 1.0 : -1.0) // octave square
            // Hard clip distortion
            sample = max(-0.8, min(0.8, sample * 2.5))
            // Envelope
            let env = min(Float(i) / (sampleRate * 0.005), 1.0 - max(0, (Float(i) / sampleRate - 0.005) / (duration - 0.005)))
            data[i] = sample * max(0, env) * volume
        }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: mixerNode, format: buffer.format)
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.audioEngine.detach(player)
            }
        }
        if !audioEngine.isRunning { try? audioEngine.start() }
        player.play()
    }

    private func playDrum(frequency: Float, duration: Float, volume: Float) {
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let pitchDrop = frequency * (1.0 - t / duration * 0.8)
            let sample = sin(2 * Float.pi * pitchDrop * t)
            let env = 1.0 - t / duration
            data[i] = sample * env * env * volume
        }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: mixerNode, format: buffer.format)
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.audioEngine.detach(player)
            }
        }
        if !audioEngine.isRunning { try? audioEngine.start() }
        player.play()
    }

    private func playSnare(volume: Float) {
        let sampleRate: Float = 44100
        let duration: Float = 0.08
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let noise = Float.random(in: -1...1)
            let tone = sin(2 * Float.pi * 200 * t)
            let env = 1.0 - t / duration
            data[i] = (noise * 0.7 + tone * 0.3) * env * env * volume
        }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: mixerNode, format: buffer.format)
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.audioEngine.detach(player)
            }
        }
        if !audioEngine.isRunning { try? audioEngine.start() }
        player.play()
    }

    private func playHiHat(volume: Float) {
        let sampleRate: Float = 44100
        let duration: Float = 0.03
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let noise = Float.random(in: -1...1)
            let env = 1.0 - t / duration
            data[i] = noise * env * env * env * volume
        }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: mixerNode, format: buffer.format)
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.audioEngine.detach(player)
            }
        }
        if !audioEngine.isRunning { try? audioEngine.start() }
        player.play()
    }
}

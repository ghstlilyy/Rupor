import AVFoundation
import SwiftUI

@MainActor
final class AudioEngine: ObservableObject {
    enum State { case idle, recording, playing }

    @Published private(set) var state: State = .idle
    @Published private(set) var level: Float = 0
    @Published var permissionDenied = false
    @Published var settings = VoiceSettings() { didSet { applySettings() } }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private let distortion = AVAudioUnitDistortion()
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var playbackID = 0
    private let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("rupor.caf")

    init() {
        configureSession()
        buildGraph()
        applySettings()
    }

    // MARK: Setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default,
                                 options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setActive(true)
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in self.permissionDenied = !granted }
        }
    }

    private func buildGraph() {
        [player, timePitch, eq, distortion, delay, reverb].forEach { engine.attach($0) }

        let hp = eq.bands[0]
        hp.filterType = .highPass
        hp.frequency = 600
        let lp = eq.bands[1]
        lp.filterType = .lowPass
        lp.frequency = 3200

        distortion.loadFactoryPreset(.speechRadioTower)
        reverb.loadFactoryPreset(.largeHall)
        delay.delayTime = 0.25
        delay.feedback = 45

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: eq, format: format)
        engine.connect(eq, to: distortion, format: format)
        engine.connect(distortion, to: delay, format: format)
        engine.connect(delay, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    private func applySettings() {
        timePitch.pitch = settings.pitch
        timePitch.rate = settings.rate
        eq.bands.forEach { $0.bypass = !settings.megaphone }
        eq.globalGain = settings.megaphone ? 8 : 0
        distortion.wetDryMix = settings.distortion
        delay.wetDryMix = settings.echo
        reverb.wetDryMix = settings.reverb
        engine.mainMixerNode.outputVolume = settings.volume
    }

    // MARK: Record / Play

    func startRecording() {
        guard state != .recording, !permissionDenied else { return }
        stopPlayback()

        let recordSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let rec = try AVAudioRecorder(url: fileURL, settings: recordSettings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec
            state = .recording
            startMetering()
        } catch {
            state = .idle
        }
    }

    func stopRecordingAndPlay() {
        guard state == .recording, let rec = recorder else { return }
        let duration = rec.currentTime
        rec.stop()
        recorder = nil
        stopMetering()

        guard duration > 0.15, let file = try? AVAudioFile(forReading: fileURL) else {
            state = .idle
            return
        }
        play(file)
    }

    func replay() {
        guard state == .idle, let file = try? AVAudioFile(forReading: fileURL) else { return }
        play(file)
    }

    var hasRecording: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    private func play(_ file: AVAudioFile) {
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            state = .idle
            return
        }
        playbackID += 1
        let id = playbackID
        player.stop()
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.playbackID == id else { return }
                // let echo / reverb tails ring out
                try? await Task.sleep(for: .milliseconds(Int(self.tailSeconds * 1000)))
                guard self.playbackID == id else { return }
                self.state = .idle
                self.level = 0
            }
        }
        player.play()
        state = .playing
    }

    private var tailSeconds: Double {
        (settings.echo > 0 ? 1.2 : 0) + (settings.reverb > 0 ? 0.8 : 0)
    }

    func stopPlayback() {
        playbackID += 1
        player.stop()
        if state == .playing { state = .idle }
    }

    // MARK: Metering

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let rec = self.recorder else { return }
                rec.updateMeters()
                let db = rec.averagePower(forChannel: 0)
                self.level = max(0, min(1, (db + 50) / 50))
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }
}

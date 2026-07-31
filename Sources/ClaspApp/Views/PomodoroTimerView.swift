import AppKit
import AVFoundation
import Combine
import SwiftUI

@MainActor
private final class BreakAudioGuide: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let ambiencePlayer = AVAudioPlayerNode()
    private let ambienceReverb = AVAudioUnitReverb()
    private let calmVoice: AVSpeechSynthesisVoice?
    private var ambienceBuffer: AVAudioPCMBuffer?
    private var speechTask: Task<Void, Never>?

    init() {
        calmVoice = Self.bestAvailableCalmVoice()
        audioEngine.attach(ambiencePlayer)
        audioEngine.attach(ambienceReverb)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        ambienceReverb.loadFactoryPreset(.largeHall2)
        ambienceReverb.wetDryMix = 48
        audioEngine.connect(ambiencePlayer, to: ambienceReverb, format: format)
        audioEngine.connect(ambienceReverb, to: audioEngine.mainMixerNode, format: format)
        ambienceBuffer = Self.makeAmbientBuffer(format: format)
        ambiencePlayer.volume = 0.30
    }

    func speakBreathing(direction: String) {
        stopSpeech()
        speechTask = Task { [weak self] in
            guard let self else { return }
            speakFragment("Breathe")
            try? await Task.sleep(for: .seconds(1.15))
            guard !Task.isCancelled else { return }
            speakFragment(direction)
        }
    }

    func speakCompletion() {
        stopSpeech()
        speakFragment("Nice work. Your break with Mochi is complete.")
    }

    private func speakFragment(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = calmVoice
        utterance.rate = 0.40
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.25
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.25
        synthesizer.speak(utterance)
    }

    func startAmbience() {
        guard !ambiencePlayer.isPlaying, let ambienceBuffer else { return }
        ambiencePlayer.scheduleBuffer(ambienceBuffer, at: nil, options: .loops)
        do {
            audioEngine.prepare()
            try audioEngine.start()
            ambiencePlayer.play()
        } catch {
            audioEngine.stop()
        }
    }

    func stopAmbience() {
        ambiencePlayer.stop()
        audioEngine.stop()
    }

    func stopAll() {
        stopSpeech()
        stopAmbience()
    }

    private func stopSpeech() {
        speechTask?.cancel()
        speechTask = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func bestAvailableCalmVoice() -> AVSpeechSynthesisVoice? {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }

        return englishVoices.first { $0.quality == .premium }
            ?? englishVoices.first { $0.quality == .enhanced }
            ?? englishVoices.first { $0.name == "Samantha" }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func makeAmbientBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let duration = 24.0
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = frameCount

        // A spacious original soundscape centered on 528 Hz and its lower harmonics.
        let droneFrequencies = [66.0, 132.0, 198.0, 264.0, 528.0]
        let droneWeights = [0.42, 0.34, 0.20, 0.12, 0.025]
        let chimeFrequencies = [264.0, 396.0, 528.0, 330.0]
        let fadeFrames = Int(format.sampleRate * 1.5)

        for frame in 0 ..< Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let slowPulse = 0.76
                + (0.16 * sin(2 * .pi * time / 12.0))
                + (0.08 * sin(2 * .pi * time / 20.0))
            let edgeFade = min(1.0, Double(min(frame, Int(frameCount) - frame - 1)) / Double(fadeFrames))

            for channel in 0 ..< Int(format.channelCount) {
                let stereoOffset = channel == 0 ? 0.0 : 0.035
                let drone = droneFrequencies.enumerated().reduce(0.0) { value, note in
                    value + (sin(2 * .pi * note.element * time + stereoOffset)
                        * droneWeights[note.offset])
                }
                let chimeIndex = Int(time / 6.0) % chimeFrequencies.count
                let chimeTime = time.truncatingRemainder(dividingBy: 6.0)
                let chimeEnvelope = exp(-chimeTime * 0.85)
                let chime = (
                    sin(2 * .pi * chimeFrequencies[chimeIndex] * time + stereoOffset)
                    + (0.16 * sin(4 * .pi * chimeFrequencies[chimeIndex] * time + stereoOffset))
                ) * chimeEnvelope
                let sample = (drone * 0.22 * slowPulse) + (chime * 0.045)
                channels[channel][frame] = Float(sample * edgeFade)
            }
        }

        return buffer
    }
}

struct PomodoroTimerView: View {
    private enum TimerMode: String, CaseIterable, Identifiable {
        case focus
        case shortBreak

        var id: String { rawValue }

        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Break"
            }
        }

        var duration: Int {
            switch self {
            case .focus: 25 * 60
            case .shortBreak: 5 * 60
            }
        }
    }

    @State private var mode: TimerMode = .focus
    @State private var remainingSeconds = TimerMode.focus.duration
    @State private var isRunning = false
    @State private var catIsInhaling = false
    @State private var audioInstructionsEnabled = true
    @StateObject private var audioGuide = BreakAudioGuide()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    private var progress: Double {
        1 - Double(remainingSeconds) / Double(mode.duration)
    }

    private var tint: Color {
        mode == .focus ? ClaspBrand.accent : .green
    }

    private var breakHasStarted: Bool {
        mode == .shortBreak && (isRunning || remainingSeconds < mode.duration)
    }

    private var breathingCue: String {
        if remainingSeconds == 0 { return "Nice work — your break with Mochi is complete" }
        if !isRunning { return "Breathing paused" }
        let elapsed = mode.duration - remainingSeconds
        return elapsed % 8 < 4 ? "Breathe … in" : "Breathe … out"
    }

    private var spokenBreathingDirection: String? {
        switch breathingCue {
        case "Breathe … in":
            "in"
        case "Breathe … out":
            "out"
        default:
            nil
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Picker("Timer mode", selection: $mode) {
                    ForEach(TimerMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(Color.secondary.opacity(0.38))
                .frame(width: 132)
                .accessibilityLabel("Pomodoro mode")

                Text(timeText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(mode.title) time remaining, \(timeText)")

                Spacer(minLength: 8)

                Button {
                    if remainingSeconds == 0 {
                        remainingSeconds = mode.duration
                    }
                    isRunning.toggle()
                } label: {
                    Label(
                        isRunning ? "Pause" : "Start",
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(ClaspBrand.accent)
                .controlSize(.small)

                Button {
                    isRunning = false
                    remainingSeconds = mode.duration
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reset Pomodoro")
                .accessibilityLabel("Reset Pomodoro")
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            if breakHasStarted {
                Divider()
                    .opacity(0.45)

                HStack(spacing: 14) {
                    Group {
                        if let cat = ClaspBrand.breakBreathingCat {
                            Image(nsImage: cat)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                        } else {
                            Image(systemName: "cat")
                                .resizable()
                                .scaledToFit()
                                .padding(18)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 104, height: 104)
                    .scaleEffect(catIsInhaling ? 1.035 : 0.965)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("Breathe with Mochi")
                                .font(.headline)

                            Button {
                                audioInstructionsEnabled.toggle()
                            } label: {
                                Image(systemName: audioInstructionsEnabled
                                    ? "speaker.wave.2.fill"
                                    : "speaker.slash.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(audioInstructionsEnabled ? ClaspBrand.accent : .secondary)
                            .help(audioInstructionsEnabled
                                ? "Mute Mochi's voice and background music"
                                : "Play Mochi's voice and background music")
                            .accessibilityLabel(audioInstructionsEnabled
                                ? "Mute break audio"
                                : "Enable break audio")
                        }
                        Text(breathingCue)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                        Text("Relax your shoulders and breathe gently with Mochi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.065), lineWidth: 1)
        }
        .onChange(of: mode) { _, newMode in
            isRunning = false
            remainingSeconds = newMode.duration
            audioGuide.stopAll()
        }
        .onChange(of: isRunning) { _, running in
            guard running, mode == .shortBreak else {
                catIsInhaling = false
                audioGuide.stopAll()
                if remainingSeconds == 0, audioInstructionsEnabled {
                    audioGuide.speakCompletion()
                }
                return
            }
            if audioInstructionsEnabled {
                audioGuide.startAmbience()
            }
            catIsInhaling = false
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                catIsInhaling = true
            }
        }
        .onChange(of: breathingCue) { _, _ in
            guard mode == .shortBreak,
                  breakHasStarted,
                  audioInstructionsEnabled,
                  let direction = spokenBreathingDirection else {
                if !isRunning, remainingSeconds != 0 {
                    audioGuide.stopAll()
                }
                return
            }
            audioGuide.speakBreathing(direction: direction)
        }
        .onChange(of: audioInstructionsEnabled) { _, enabled in
            guard enabled, isRunning, let direction = spokenBreathingDirection else {
                audioGuide.stopAll()
                return
            }
            audioGuide.startAmbience()
            audioGuide.speakBreathing(direction: direction)
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            if remainingSeconds > 1 {
                remainingSeconds -= 1
            } else {
                remainingSeconds = 0
                isRunning = false
                NSSound.beep()
            }
        }
        .onDisappear {
            audioGuide.stopAll()
        }
    }
}

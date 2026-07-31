import AppKit
import Combine
import SwiftUI

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
        if remainingSeconds == 0 { return "Nice work — break complete" }
        if !isRunning { return "Breathing paused" }
        let elapsed = mode.duration - remainingSeconds
        return elapsed % 8 < 4 ? "Breathe in slowly" : "Breathe out slowly"
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
                        Text("Deep breath break")
                            .font(.headline)
                        Text(breathingCue)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                        Text("Relax your shoulders and breathe gently with the cat.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
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
        }
        .onChange(of: isRunning) { _, running in
            guard running, mode == .shortBreak else {
                catIsInhaling = false
                return
            }
            catIsInhaling = false
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                catIsInhaling = true
            }
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
    }
}

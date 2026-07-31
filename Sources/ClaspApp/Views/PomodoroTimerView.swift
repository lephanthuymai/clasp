import AppKit
import Combine
import SwiftUI

struct PomodoroTimerView: View {
    private static let focusDuration = 25 * 60

    @State private var remainingSeconds = focusDuration
    @State private var isRunning = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    private var progress: Double {
        1 - Double(remainingSeconds) / Double(Self.focusDuration)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Label("Focus", systemImage: "timer")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ClaspBrand.accent)

                Text(timeText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("Pomodoro time remaining, \(timeText)")

                Spacer(minLength: 8)

                Button {
                    if remainingSeconds == 0 {
                        remainingSeconds = Self.focusDuration
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
                    remainingSeconds = Self.focusDuration
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
                        .fill(ClaspBrand.accent)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.065), lineWidth: 1)
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

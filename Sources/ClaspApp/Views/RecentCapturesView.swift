import AppKit
import ClaspCore
import SwiftUI

struct RecentCapturesView: View {
    @ObservedObject var model: AppModel
    @State private var captureToDelete: Capture?

    var body: some View {
        ZStack {
            ClaspBackdrop()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    ClaspLogoView(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recent captures")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Local delivery history and retry status")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { try? await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Group {
                    if model.captures.isEmpty {
                        ContentUnavailableView {
                            Label("No captures yet", systemImage: "paperclip")
                        } description: {
                            Text("Select text in another app and invoke Clasp to create your first item.")
                        }
                    } else {
                        List(model.captures) { capture in
                            CaptureRow(model: model, capture: capture) {
                                captureToDelete = capture
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.075), lineWidth: 1)
                }

                if let message = model.statusMessage {
                    ClaspStatusBanner(message: message)
                }
            }
            .padding(20)
        }
        .navigationTitle("Recent Captures")
        .task { await model.load() }
        .confirmationDialog(
            "Delete this local capture?",
            isPresented: Binding(
                get: { captureToDelete != nil },
                set: { if !$0 { captureToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Local Capture", role: .destructive) {
                if let capture = captureToDelete {
                    Task { await model.delete(capture) }
                }
                captureToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                captureToDelete = nil
            }
        } message: {
            Text("This does not delete an item already delivered to Notion.")
        }
    }
}

private struct CaptureRow: View {
    @ObservedObject var model: AppModel
    let capture: Capture
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: capture.type == .task ? "checkmark.circle" : "bookmark")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(capture.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Text(capture.type.displayName)
                    Text("•")
                        .accessibilityHidden(true)
                    Text(capture.source.applicationName)
                    Text("•")
                        .accessibilityHidden(true)
                    Text(capture.createdAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            deliveryLabel

            if capture.delivery == .pending || capture.delivery == .failed {
                Button("Retry") {
                    Task { await model.retry(capture) }
                }
                .disabled(model.isBusy)
            }

            if capture.delivery == .delivered, let url = capture.remotePageURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open in Notion", systemImage: "arrow.up.right.square")
                        .labelStyle(.iconOnly)
                }
                .help("Open in Notion")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete local capture", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private var deliveryLabel: some View {
        Label(deliveryText, systemImage: deliverySymbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(deliveryColor)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel("Delivery status: \(deliveryText)")
    }

    private var deliveryText: String {
        switch capture.delivery {
        case .pending: "Pending"
        case .delivering: "Sending"
        case .delivered: "Delivered"
        case .failed: "Failed"
        }
    }

    private var deliverySymbol: String {
        switch capture.delivery {
        case .pending: "clock"
        case .delivering: "arrow.triangle.2.circlepath"
        case .delivered: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }

    private var deliveryColor: Color {
        switch capture.delivery {
        case .pending, .delivering: .orange
        case .delivered: .green
        case .failed: .red
        }
    }
}

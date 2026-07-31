import AppKit
import SwiftUI

enum ClaspBrand {
    static let logo: NSImage? = {
        guard let url = Bundle.main.url(
            forResource: "ClaspLogo",
            withExtension: "png"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    static let menuBarIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(
                    x: rect.minX + (rect.width * x),
                    y: rect.maxY - (rect.height * y)
                )
            }

            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 2.4
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            path.move(to: point(0.72, 0.50))
            path.line(to: point(0.72, 0.30))
            path.curve(
                to: point(0.28, 0.30),
                controlPoint1: point(0.72, 0.12),
                controlPoint2: point(0.28, 0.12)
            )
            path.line(to: point(0.28, 0.70))
            path.curve(
                to: point(0.72, 0.70),
                controlPoint1: point(0.28, 0.90),
                controlPoint2: point(0.72, 0.90)
            )

            path.move(to: point(0.28, 0.52))
            path.curve(
                to: point(0.72, 0.50),
                controlPoint1: point(0.43, 0.36),
                controlPoint2: point(0.56, 0.66)
            )
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Clasp"
        return image
    }()
}

struct ClaspLogoView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let logo = ClaspBrand.logo {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "paperclip")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct ClaspMenuBarIcon: View {
    var body: some View {
        Image(nsImage: ClaspBrand.menuBarIcon)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .accessibilityLabel("Clasp")
    }
}

struct ClaspBrandHeader: View {
    let subtitle: String
    var logoSize: CGFloat = 38

    var body: some View {
        HStack(spacing: 12) {
            ClaspLogoView(size: logoSize)
            VStack(alignment: .leading, spacing: 1) {
                Text("Clasp")
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

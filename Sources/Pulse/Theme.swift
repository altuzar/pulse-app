import SwiftUI

enum Theme {
    // MARK: - Core palette
    static let bgDeep      = Color(red: 0.055, green: 0.043, blue: 0.133)   // #0E0B22
    static let bgMid       = Color(red: 0.078, green: 0.063, blue: 0.180)   // #14102E
    static let surface     = Color(red: 0.102, green: 0.075, blue: 0.188)   // #1A1330
    static let surfaceHi   = Color(red: 0.137, green: 0.106, blue: 0.243)   // #23193E
    static let hairline    = Color.white.opacity(0.08)

    // Accents
    static let accent      = Color(red: 0.133, green: 0.827, blue: 0.933)   // #22D3EE  cyan
    static let accentHi    = Color(red: 0.498, green: 0.969, blue: 0.984)   // #7FF7FB
    static let accent2     = Color(red: 0.925, green: 0.282, blue: 0.600)   // #EC4899  magenta
    static let accent3     = Color(red: 0.341, green: 0.808, blue: 0.498)   // #57CE7F  green

    // Status
    static let statusOnline  = Color(red: 0.137, green: 0.961, blue: 0.510)  // #23F582
    static let statusWarn    = Color(red: 1.000, green: 0.808, blue: 0.298)  // #FFCE4C
    static let statusOffline = Color(red: 1.000, green: 0.310, blue: 0.392)  // #FF4F64

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary  = Color.white.opacity(0.40)

    // MARK: - Gradients

    static var bgGradient: LinearGradient {
        LinearGradient(
            colors: [bgDeep, bgMid, Color(red: 0.043, green: 0.027, blue: 0.110)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heartbeatGradient: LinearGradient {
        LinearGradient(
            colors: [accentHi, accent, accent2],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [surface, Color.white.opacity(0.02), surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func ringGradient(for tint: Color) -> AngularGradient {
        AngularGradient(
            colors: [tint.opacity(0.0), tint.opacity(0.6), tint, tint.opacity(0.6), tint.opacity(0.0)],
            center: .center
        )
    }
}

// MARK: - Reusable view modifiers

struct PulseCard: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.cardBorderGradient, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func pulseCard(padding: CGFloat = 14) -> some View {
        modifier(PulseCard(padding: padding))
    }
}

// MARK: - Animated pulse dot

struct PulseDot: View {
    let color: Color
    let size: CGFloat
    @State private var animate = false

    init(color: Color, size: CGFloat = 12) {
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(animate ? 1.0 : 0.6)
                .opacity(animate ? 0.0 : 0.85)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: animate)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.85), radius: size * 0.7)
        }
        .onAppear { animate = true }
    }
}

// MARK: - Section header

struct SectionLabel: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Metric chip

struct MetricChip: View {
    let label: String
    let value: String
    let tint: Color
    var alignment: HorizontalAlignment = .trailing
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

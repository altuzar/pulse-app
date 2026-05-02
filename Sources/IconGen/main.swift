import SwiftUI
import AppKit

@MainActor
struct PulseIcon: View {
    let size: CGFloat
    var bleed: Bool = true     // when true, fill the canvas (squircle done by macOS at runtime is not used; we draw our own squircle)

    var body: some View {
        ZStack {
            // Background squircle gradient
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.094, green: 0.067, blue: 0.235),  // top  #18113C
                            Color(red: 0.043, green: 0.027, blue: 0.110)   // bot  #0B071C
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // subtle radial highlight
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.10), .clear],
                                center: UnitPoint(x: 0.3, y: 0.0),
                                startRadius: 0,
                                endRadius: size * 0.7
                            )
                        )
                )
                .overlay(
                    // inner border
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: max(1, size * 0.005))
                )

            // Heartbeat path with glow
            HeartbeatShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.498, green: 0.969, blue: 0.984),  // accentHi
                            Color(red: 0.133, green: 0.827, blue: 0.933),  // accent (cyan)
                            Color(red: 0.925, green: 0.282, blue: 0.600)   // accent2 (magenta)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: size * 0.04)
                .opacity(0.65)

            HeartbeatShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.498, green: 0.969, blue: 0.984),
                            Color(red: 0.133, green: 0.827, blue: 0.933),
                            Color(red: 0.925, green: 0.282, blue: 0.600)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round, lineJoin: .round)
                )

            // Leading ping dot
            Circle()
                .fill(Color(red: 0.498, green: 0.969, blue: 0.984))
                .frame(width: size * 0.085, height: size * 0.085)
                .shadow(color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.9),
                        radius: size * 0.06)
                .position(x: size * 0.16, y: size * 0.5)

            // Trailing ping dot (magenta)
            Circle()
                .fill(Color(red: 0.925, green: 0.282, blue: 0.600))
                .frame(width: size * 0.07, height: size * 0.07)
                .shadow(color: Color(red: 0.925, green: 0.282, blue: 0.600).opacity(0.9),
                        radius: size * 0.05)
                .position(x: size * 0.84, y: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

struct HeartbeatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let mid = h * 0.5
        // Classic ECG: flat → small dip → big spike up → big spike down → small bump → flat
        var p = Path()
        p.move(to: CGPoint(x: w * 0.16, y: mid))
        p.addLine(to: CGPoint(x: w * 0.30, y: mid))
        p.addLine(to: CGPoint(x: w * 0.36, y: mid - h * 0.04))
        p.addLine(to: CGPoint(x: w * 0.41, y: mid + h * 0.06))
        p.addLine(to: CGPoint(x: w * 0.47, y: mid - h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.55, y: mid + h * 0.32))
        p.addLine(to: CGPoint(x: w * 0.62, y: mid - h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.70, y: mid))
        p.addLine(to: CGPoint(x: w * 0.84, y: mid))
        return p
    }
}

@MainActor
func render(size: CGFloat, scale: CGFloat = 1.0, to url: URL) throws {
    let renderer = ImageRenderer(content: PulseIcon(size: size))
    renderer.scale = scale
    guard let cg = renderer.cgImage else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "ImageRenderer returned nil"])
    }
    let bitmap = NSBitmapImageRep(cgImage: cg)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try data.write(to: url, options: .atomic)
    print("wrote \(url.lastPathComponent) (\(Int(size * scale))×\(Int(size * scale)))")
}

// MARK: - OG / social card view

@MainActor
struct PulseOGCard: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.094, green: 0.067, blue: 0.235),
                    Color(red: 0.043, green: 0.027, blue: 0.110),
                    Color(red: 0.078, green: 0.063, blue: 0.180)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Aurora blobs
            Circle()
                .fill(Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.32))
                .frame(width: width * 0.55, height: width * 0.55)
                .blur(radius: width * 0.10)
                .offset(x: -width * 0.30, y: -height * 0.45)
            Circle()
                .fill(Color(red: 0.925, green: 0.282, blue: 0.600).opacity(0.28))
                .frame(width: width * 0.50, height: width * 0.50)
                .blur(radius: width * 0.10)
                .offset(x: width * 0.35, y: height * 0.40)

            HStack(alignment: .center, spacing: width * 0.04) {
                // Icon
                PulseIcon(size: width * 0.24)
                    .shadow(color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.35),
                            radius: width * 0.04)

                VStack(alignment: .leading, spacing: width * 0.012) {
                    Text("Pulse")
                        .font(.system(size: width * 0.085, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your internet,\nin real time.")
                        .font(.system(size: width * 0.044, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.498, green: 0.969, blue: 0.984),
                                    Color(red: 0.133, green: 0.827, blue: 0.933),
                                    Color(red: 0.925, green: 0.282, blue: 0.600)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineSpacing(width * 0.005)
                    Text("A native macOS menu bar network monitor · MIT")
                        .font(.system(size: width * 0.020, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, width * 0.012)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, width * 0.06)

            // Bottom-right hairline + tag
            HStack {
                Spacer()
                HStack(spacing: width * 0.010) {
                    Circle()
                        .fill(Color(red: 0.137, green: 0.961, blue: 0.510))
                        .frame(width: width * 0.012, height: width * 0.012)
                        .shadow(color: Color(red: 0.137, green: 0.961, blue: 0.510).opacity(0.7),
                                radius: width * 0.012)
                    Text("Native · macOS 13+ · Apple Silicon")
                        .font(.system(size: width * 0.018, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.horizontal, width * 0.022)
                .padding(.vertical, width * 0.012)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .padding(.horizontal, width * 0.04)
            .padding(.bottom, width * 0.04)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width, height: height)
    }
}

@MainActor
func renderOG(width: CGFloat, height: CGFloat, to url: URL) throws {
    let renderer = ImageRenderer(content: PulseOGCard(width: width, height: height))
    renderer.scale = 1
    guard let cg = renderer.cgImage else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "OG render returned nil"])
    }
    let bitmap = NSBitmapImageRep(cgImage: cg)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try data.write(to: url, options: .atomic)
    print("wrote \(url.lastPathComponent) (\(Int(width))×\(Int(height)))")
}

@main
@MainActor
struct IconGen {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            FileHandle.standardError.write(Data("usage: icongen <output-folder> [--og <og-folder>]\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let entries: [(name: String, pt: CGFloat, scale: CGFloat)] = [
            ("icon_16x16.png",      16,  1),
            ("icon_16x16@2x.png",   16,  2),
            ("icon_32x32.png",      32,  1),
            ("icon_32x32@2x.png",   32,  2),
            ("icon_128x128.png",   128,  1),
            ("icon_128x128@2x.png",128,  2),
            ("icon_256x256.png",   256,  1),
            ("icon_256x256@2x.png",256,  2),
            ("icon_512x512.png",   512,  1),
            ("icon_512x512@2x.png",512,  2),
        ]
        for e in entries {
            try render(size: e.pt, scale: e.scale, to: outDir.appendingPathComponent(e.name))
        }
        try render(size: 1024, scale: 1, to: outDir.appendingPathComponent("icon_1024.png"))

        // Optional: --og <folder> generates social cards too
        if let ogIdx = args.firstIndex(of: "--og"), ogIdx + 1 < args.count {
            let ogDir = URL(fileURLWithPath: args[ogIdx + 1], isDirectory: true)
            try FileManager.default.createDirectory(at: ogDir, withIntermediateDirectories: true)
            try renderOG(width: 1200, height: 675, to: ogDir.appendingPathComponent("og.png"))
            try renderOG(width: 1200, height: 600, to: ogDir.appendingPathComponent("twitter-card.png"))
        }

        print("done.")
    }
}

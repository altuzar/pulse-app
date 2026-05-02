import SwiftUI

struct TracerouteView: View {
    let text: String?
    let host: String
    let onRun: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.brandGradient)
                            .frame(width: 22, height: 22)
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Traceroute")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("to \(host)")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Button("Run again") { onRun() }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                ScrollView {
                    Text(text ?? "Click ‘Run again’ to start a traceroute.\nIt may take 10–30 seconds.")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(14)
                }
                .frame(minWidth: 580, minHeight: 360)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            }
            .padding(20)
        }
        .frame(width: 680, height: 500)
        .preferredColorScheme(.dark)
    }
}

import SwiftUI
import SubstratalKit

/// GLB-03 "Update available" / "Update required", driven by the API's
/// `Deprecation` / `Sunset` headers and `400 unsupported_api_version`
/// (CLIENT-ARCHITECTURE §4.1).
struct VersionBanner: View {
    let status: APIVersionStatus
    @Environment(\.palette) private var palette

    var body: some View {
        switch status {
        case .current:
            EmptyView()
        case .deprecated(let sunset):
            banner(
                icon: "arrow.down.circle",
                text: sunset.map { "Update available. This version of Substratal Hub stops working on \($0.formatted(date: .long, time: .omitted))." }
                    ?? "Update available. This version of Substratal Hub will stop working soon.",
                tint: palette.accentSubtle
            )
        case .unsupported:
            banner(
                icon: "exclamationmark.octagon",
                text: "Update required. This version of Substratal Hub is no longer supported by the Substratal API.",
                tint: .orange.opacity(0.25)
            )
        }
    }

    private func banner(icon: String, text: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(tint)
    }
}

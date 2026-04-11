import SwiftUI

// MARK: - Liquid Glass helper
//
// Uses .glassEffect() on macOS 26+ (Tahoe) and gracefully falls back to
// .regularMaterial on older systems.

extension View {
    /// Applies the macOS 26 Liquid Glass effect. Falls back to .regularMaterial.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 10) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
    }

    /// Glass for bar/strip shapes (no corner radius clip needed – caller clips).
    @ViewBuilder
    func liquidGlassBar() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: Rectangle())
        } else {
            self.background(.regularMaterial)
        }
    }
}

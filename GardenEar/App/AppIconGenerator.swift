/// AppIconGenerator.swift
/// Reference-only file — not used at runtime.
///
/// HOW TO USE:
/// 1. Run the app in Simulator or on device.
/// 2. Add `AppIconPreview()` temporarily to any SwiftUI preview or live view.
/// 3. Screenshot at 1024×1024 (use Simulator's "Save Screen" at the correct resolution).
/// 4. In Xcode → Assets.xcassets → AppIcon → drag the PNG into the "App Store" 1024pt slot.
/// 5. Set "Single Size" in the AppIcon inspector — Xcode 14+ auto-generates all required sizes.

import SwiftUI

struct AppIconPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.primary, Theme.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: -8) {
                Image(systemName: "ear.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundColor(.white)

                HStack {
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.trailing, 18)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#if DEBUG
struct AppIconPreview_Previews: PreviewProvider {
    static var previews: some View {
        AppIconPreview()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

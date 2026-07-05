//
//  SiteImage.swift
//  LarioGo
//
//  Created by user on 29.6.26.
//


//
//  SiteImage.swift
//  LarioGo
//

import SwiftUI

/// Displays a bundled site image, gracefully falling back to a themed
/// gradient + glyph when the asset has not been generated yet. Uses the
/// Color-as-anchor + overlay pattern so the fill image never breaks layout.
struct SiteImage: View {
    let imageName: String
    let symbol: String
    var cornerRadius: CGFloat = 0

    private var bundledImage: UIImage? { UIImage(named: imageName) }

    var body: some View {
        Group {
            if let bundledImage {
                Color.clear
                    .overlay {
                        Image(uiImage: bundledImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipped()
            } else {
                placeholder
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        ZStack {
            Theme.deepGradient
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

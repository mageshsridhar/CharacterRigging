import SwiftUI

struct ExpressionThumbnail: View {
    let library: ExpressionLibrary
    let expression: Expression
    let isColor: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ExpressionPicture(library: library, expression: expression, isColor: isColor)
                .aspectRatio(1, contentMode: .fit)
                .padding(3)
                .background(.white)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.ink : Color.ink.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                }
            Text(expression.name)
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(expression.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// One look of an expression. Both are only on screen while one fades into the other.
private struct ExpressionPicture: View {
    let library: ExpressionLibrary
    let expression: Expression
    let isColor: Bool
    /// The look the last fade ended on.
    @State private var settled: Bool

    init(library: ExpressionLibrary, expression: Expression, isColor: Bool) {
        self.library = library
        self.expression = expression
        self.isColor = isColor
        _settled = State(initialValue: isColor)
    }

    var body: some View {
        ZStack {
            // Stays opaque underneath until the fade ends, so nothing shows through.
            if !isColor || settled != isColor {
                picture(isColor: false).transition(.identity)
            }
            if isColor {
                // Pinned on top, or it drops behind while it fades out.
                picture(isColor: true).transition(.opacity).zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isColor)
        .task(id: isColor) {
            guard settled != isColor else { return }
            try? await Task.sleep(for: .seconds(0.6))
            if !Task.isCancelled { settled = isColor }
        }
    }

    @ViewBuilder private func picture(isColor: Bool) -> some View {
        if let image = library.thumbnail(for: expression, isColor: isColor) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "face.smiling").font(.title).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

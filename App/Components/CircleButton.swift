import SwiftUI

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .frame(width: 44, height: 44)
                .background(Color.ink.opacity(0.06), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

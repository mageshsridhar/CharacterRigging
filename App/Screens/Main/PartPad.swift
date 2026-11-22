import SwiftUI

/// A dotted 2D pad for one part of the face. The knob stays where you leave it;
/// the ghost dot marks the expression's own value, and double-tapping returns to it.
struct PartPad: View {
    let part: FacePart
    let position: CGPoint
    let home: CGPoint
    let onMove: (CGPoint) -> Void

    private let columns = 7, rows = 9
    private let inset = CGSize(width: 22, height: 24)
    @State private var cell = 0
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, _ in draw(context, size) }
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.ink)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: unit, startRadius: 0, endRadius: size.width * 0.6))
                        }
                }
                .overlay { hints }
                .overlay {
                    Circle().fill(.white)
                        .frame(width: 20, height: 20)
                        .scaleEffect(isDragging ? 1.3 : 1)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .position(point(position, size))
                        .animation(.spring(duration: 0.25), value: isDragging)
                        .animation(isDragging ? nil : .spring(duration: 0.4), value: position)
                }
                .contentShape(.rect)
                .gesture(drag(size))
                .simultaneousGesture(TapGesture(count: 2).onEnded { onMove(home) })
        }
        .sensoryFeedback(.selection, trigger: cell)
        .accessibilityElement()
        .accessibilityLabel(part.rawValue)
        .accessibilityValue(spoken)
        .accessibilityAction(named: part.axes.left) { nudge(-0.25, 0) }
        .accessibilityAction(named: part.axes.right) { nudge(0.25, 0) }
        .accessibilityAction(named: part.axes.up) { nudge(0, 0.25) }
        .accessibilityAction(named: part.axes.down) { nudge(0, -0.25) }
        .accessibilityAction(named: "Reset") { onMove(home) }
    }

    /// What each direction does, shown while dragging.
    private var hints: some View {
        ZStack {
            Text(part.axes.up).frame(maxHeight: .infinity, alignment: .top)
            Text(part.axes.down).frame(maxHeight: .infinity, alignment: .bottom)
            Text(part.axes.left).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
            Text(part.axes.right).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 8)
        }
        .font(.caption2.weight(.medium))
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .opacity(isDragging ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isDragging)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var spoken: String {
        let x = position.x < 0 ? part.axes.left : part.axes.right
        let y = position.y < 0 ? part.axes.down : part.axes.up
        return "\(x) \(Int(abs(position.x) * 100)), \(y) \(Int(abs(position.y) * 100))"
    }

    private var unit: UnitPoint { .init(x: (position.x + 1) / 2, y: (1 - position.y) / 2) }

    private func point(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: inset.width + (p.x + 1) / 2 * (size.width - 2 * inset.width),
                y: inset.height + (1 - p.y) / 2 * (size.height - 2 * inset.height))
    }

    private func drag(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($isDragging) { _, isDragging, _ in isDragging = true }
            .onChanged { value in
                let x = (value.location.x - inset.width) / (size.width - 2 * inset.width) * 2 - 1
                let y = 1 - (value.location.y - inset.height) / (size.height - 2 * inset.height) * 2
                let p = CGPoint(x: min(max(x, -1), 1), y: min(max(y, -1), 1))
                onMove(p)
                let column = Int(((p.x + 1) / 2 * CGFloat(columns - 1)).rounded())
                let row = Int(((1 - p.y) / 2 * CGFloat(rows - 1)).rounded())
                cell = row * columns + column
            }
    }

    private func nudge(_ dx: Double, _ dy: Double) {
        onMove(CGPoint(x: min(max(position.x + dx, -1), 1), y: min(max(position.y + dy, -1), 1)))
    }

    private func draw(_ context: GraphicsContext, _ size: CGSize) {
        let knob = point(position, size)
        let dx = (size.width - 2 * inset.width) / CGFloat(columns - 1)
        let dy = (size.height - 2 * inset.height) / CGFloat(rows - 1)
        for row in 0..<rows {
            for column in 0..<columns {
                let c = CGPoint(x: inset.width + CGFloat(column) * dx, y: inset.height + CGFloat(row) * dy)
                // Dots on the knob's row and column light up, like a crosshair.
                let line = max(0, 1 - min(abs(c.x - knob.x) / dx, abs(c.y - knob.y) / dy) / 0.8)
                let near = max(0, 1 - hypot(c.x - knob.x, c.y - knob.y) / (dx * 2.5))
                fill(context, c, radius: 1.3 + max(line * 0.7, near), opacity: 0.25 + 0.6 * max(line * 0.8, near * 0.8))
            }
        }
        fill(context, point(home, size), radius: 3.5, opacity: 0.9)
    }

    private func fill(_ context: GraphicsContext, _ c: CGPoint, radius: CGFloat, opacity: Double) {
        context.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                     with: .color(.white.opacity(opacity)))
    }
}

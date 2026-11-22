import SwiftUI

/// A snapping carousel of faces. The one in the middle is on the character, and changes live as you scroll.
/// Family names above it jump between groups.
struct ExpressionCarousel: View {
    let library: ExpressionLibrary
    let studio: Studio
    @State private var centered: String?
    @State private var phase = ScrollPhase.idle
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let itemWidth: CGFloat = 76

    /// Neutral sits between the upbeat families and the rest, so there are faces either side at launch.
    private var items: [Expression] {
        var items = library.all
        items.insert(.neutral, at: items.firstIndex { $0.family > .bold } ?? items.endIndex)
        return items
    }
    private var selectedID: String { studio.selected?.id ?? Expression.neutral.id }
    private var family: ExpressionFamily? { studio.selected?.family }

    var body: some View {
        VStack(spacing: 2) {
            families
            carousel
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private var families: some View {
        HStack(spacing: 0) {
            ForEach(library.families, id: \.self) { item in
                if item != library.families.first { Spacer(minLength: 0) }
                Button { select(library.expressions(in: item).first) } label: {
                    Text(item.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .foregroundStyle(item == family ? .white : Color.ink.opacity(0.65))
                        .background(Color.ink.opacity(item == family ? 1 : 0), in: .capsule)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == family ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        // Six names share one line.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .animation(.easeOut(duration: 0.15), value: family)
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(items) { expression in
                    ExpressionThumbnail(library: library, expression: expression, isColor: studio.isColor,
                                        isSelected: expression.id == selectedID)
                        .padding(.horizontal, 3)
                        .frame(width: itemWidth)
                        // One layer, so dimming doesn't show both looks while they fade.
                        .compositingGroup()
                        .visualEffect { content, proxy in
                            let viewport = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? 0
                            let offset = proxy.frame(in: .scrollView(axis: .horizontal)).midX - viewport / 2
                            let distance = min(1, abs(offset) / (proxy.size.width * 1.5))
                            return content.scaleEffect(1 - 0.22 * distance).opacity(1 - 0.35 * distance)
                        }
                        .contentShape(.rect)
                        .onTapGesture { select(expression) }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (width - itemWidth) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollPosition(id: $centered, anchor: .center)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onScrollPhaseChange { _, new in
            phase = new
            if new == .idle { selectCentered() }
        }
        .onChange(of: centered) {
            // Ignore positions passed on the way to a tapped face or family.
            if phase != .animating, phase != .idle { selectCentered() }
        }
        .onChange(of: selectedID, initial: true) {
            recenter()
        }
        .onChange(of: studio.isEditing) { _, isEditing in
            if !isEditing { recenter() }
        }
        .accessibilityElement()
        .accessibilityLabel("Expression")
        .accessibilityValue(studio.selected?.name ?? Expression.neutral.name)
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            guard let index = items.firstIndex(where: { $0.id == selectedID }), items.indices.contains(index + step) else { return }
            select(items[index + step])
        }
    }

    private func recenter() {
        guard centered != selectedID else { return }
        withAnimation(reduceMotion ? nil : .snappy) { centered = selectedID }
    }

    private func selectCentered() {
        guard let centered, centered != selectedID else { return }
        select(items.first { $0.id == centered })
    }

    private func select(_ expression: Expression?) {
        // The carousel may still be coasting when the editor opens.
        guard let expression, !studio.isEditing else { return }
        studio.select(expression.id == Expression.neutral.id ? nil : expression)
    }
}

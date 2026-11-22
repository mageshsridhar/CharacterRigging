import RiveRuntime
import SwiftUI

struct ContentView: View {
    @State private var studio = Studio()
    @State private var library = ExpressionLibrary()
    @State private var showsLibrary = false
    @State private var showsEditor = false
    @State private var canvasWidth: CGFloat = 1
    @GestureState private var isLooking = false

    var body: some View {
        VStack(spacing: 12) {
            topBar.disabled(showsEditor)
            canvas
            ExpressionCarousel(library: library, studio: studio).disabled(showsEditor)
            pads.disabled(showsEditor)
        }
        .padding(.bottom, 8)
        // This screen has to fit without scrolling. The sheets scale all the way.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(Color.ink)
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .task { await studio.rig.load() }
        .sheet(isPresented: $showsLibrary) { LibraryView(library: library, studio: studio) }
        .sheet(isPresented: $showsEditor) {
            EditorView(studio: studio, library: library)
                .presentationDetents([.fraction(0.46), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.46)))
                .presentationContentInteraction(.scrolls)
                .presentationBackground(.white)
        }
    }

    private var topBar: some View {
        HStack {
            CircleButton(symbol: "square.grid.2x2", label: "Expression library") { showsLibrary = true }
            Spacer()
            HStack(spacing: 6) {
                Text(studio.title)
                    .font(.headline)
                    .contentTransition(.opacity)
                    .animation(.default, value: studio.title)
                if studio.isModified {
                    Button { studio.resetKnobs() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset all parts")
                }
            }
            Spacer()
            CircleButton(symbol: "plus", label: "Create an expression") {
                studio.beginEditing()
                showsEditor = true
            }
        }
        .padding(.horizontal, 16)
    }

    private var canvas: some View {
        ZStack {
            switch studio.rig.state {
            case .loading:
                ProgressView().accessibilityLabel("Loading the character")
            case .ready(let rive):
                character(rive)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load the character", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await studio.rig.load() } }
                        .buttonStyle(.bordered)
                        .tint(.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) { colorToggle.padding(.trailing, 16) }
    }

    private func character(_ rive: Rive) -> some View {
        RiveUIViewRepresentable(rive: rive)
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { canvasWidth = max($0, 1) }
            .gesture(lookGesture)
            // Runs when a drag is interrupted too, unlike onEnded.
            .onChange(of: isLooking) { if !isLooking { studio.look = .zero } }
            .accessibilityElement()
            .accessibilityLabel("Character, \(studio.title)")
            .accessibilityHint("Drag to make the character look around")
    }

    private var colorToggle: some View {
        CircleButton(symbol: studio.isColor ? "paintpalette.fill" : "paintpalette", label: "Color") {
            studio.isColor.toggle()
        }
        .contentTransition(.symbolEffect(.replace))
        .sensoryFeedback(.selection, trigger: studio.isColor)
        .accessibilityValue(studio.isColor ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isLooking) { _, isLooking, _ in isLooking = true }
            .onChanged { value in
                let half = canvasWidth / 2
                let x = (value.location.x - half) / half, y = 1 - value.location.y / half
                studio.look = CGPoint(x: min(max(x * 1.2, -1), 1), y: min(max(y * 1.2, -1), 1))
            }
    }

    private var pads: some View {
        HStack(spacing: 10) {
            ForEach(FacePart.allCases) { part in
                VStack(spacing: 6) {
                    PartPad(part: part, position: studio.knob(part), home: studio.home(part)) {
                        studio.move(part, to: $0)
                    }
                    .frame(minHeight: 104, maxHeight: 156)
                    Text(part.rawValue)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

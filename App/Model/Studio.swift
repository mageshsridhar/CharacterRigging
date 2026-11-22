import CoreGraphics
import Foundation
import Observation

/// The screen's state: chosen expression, the part knobs and the gaze.
@MainActor @Observable
final class Studio {
    let rig = FaceRig()

    /// Color or black and white. Remembered between launches.
    var isColor: Bool {
        didSet {
            defaults.set(isColor, forKey: "isColor")
            rig.colorTarget = isColor ? 1 : 0
        }
    }

    private(set) var selected: Expression?
    private(set) var homes: [FacePart: CGPoint] = [:]
    private(set) var knobs: [FacePart: CGPoint] = [:]
    private let defaults: UserDefaults
    private var base = FaceParameters.neutral
    private var beforeEditing: Saved?
    var look = CGPoint.zero { didSet { push() } }

    private struct Saved {
        let selected: Expression?, base: FaceParameters, knobs: [FacePart: CGPoint]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isColor = defaults.bool(forKey: "isColor")
        rig.colorTarget = isColor ? 1 : 0
        resetKnobs()
    }

    /// The face as the pads and sliders set it, without the temporary drag-to-look.
    var parameters: FaceParameters {
        FacePart.allCases.reduce(base) { face, part in
            part.apply(to: face, home: home(part), knob: knob(part))
        }
    }

    var isModified: Bool { knobs != homes }
    var isEditing: Bool { beforeEditing != nil }

    var title: String {
        if isEditing { return "New expression" }
        guard let selected else { return isModified ? "Custom" : "Neutral" }
        return isModified ? "\(selected.name), edited" : selected.name
    }

    func knob(_ part: FacePart) -> CGPoint { knobs[part] ?? .zero }
    func home(_ part: FacePart) -> CGPoint { homes[part] ?? .zero }

    func move(_ part: FacePart, to position: CGPoint) {
        knobs[part] = position
        push()
    }

    func select(_ expression: Expression?) {
        beforeEditing = nil
        selected = expression
        setBase(expression?.parameters ?? .neutral)
    }

    /// Keeps the title right when the selected expression is renamed.
    func renamed(_ expression: Expression, to name: String) {
        if selected?.id == expression.id { selected?.name = name }
    }

    func resetKnobs() { setBase(base) }

    /// Folds the knobs into the base so individual sliders can take over.
    func beginEditing() {
        guard !isEditing else { return }
        beforeEditing = Saved(selected: selected, base: base, knobs: knobs)
        setBase(parameters)
    }

    func cancelEditing() {
        guard let saved = beforeEditing else { return }
        beforeEditing = nil
        selected = saved.selected
        setBase(saved.base)
        knobs = saved.knobs
        push()
    }

    func set(_ parameter: FaceParameter, to value: Double) {
        var edited = base
        edited[parameter] = value
        setBase(edited)
    }

    private func setBase(_ parameters: FaceParameters) {
        base = parameters
        homes = Dictionary(uniqueKeysWithValues: FacePart.allCases.map { ($0, $0.position(for: parameters)) })
        knobs = homes
        push()
    }

    private func push() {
        rig.target = parameters.adding([
            .headTurn: look.x, .headNod: look.y, .gazeX: look.x * 0.8, .gazeY: look.y * 0.8,
        ])
    }
}

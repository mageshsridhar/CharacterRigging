import CoreGraphics

/// A region of the face driven by one pad. Both axes run -1 to 1, with y up.
enum FacePart: String, CaseIterable, Identifiable {
    case brows = "Brows", eyes = "Eyes", mouth = "Mouth"

    var id: Self { self }

    struct AxisLabels { let left, right, up, down: String }

    var axes: AxisLabels {
        switch self {
        case .brows: .init(left: "Angry", right: "Sad", up: "Raised", down: "Lowered")
        case .eyes: .init(left: "Stern", right: "Happy", up: "Wide", down: "Closed")
        case .mouth: .init(left: "Closed", right: "Open", up: "Smile", down: "Frown")
        }
    }

    /// Parameter values this pad calls for at a position.
    func response(at p: CGPoint) -> [FaceParameter: Double] {
        let left = max(0, -p.x), right = max(0, p.x), up = max(0, p.y), down = max(0, -p.y)
        switch self {
        case .brows:
            return [.browTilt: p.x, .browLift: p.y, .browPinch: 0.9 * left, .sneer: 0.6 * left]
        case .eyes:
            return [.lidTilt: -left, .smileEyes: right, .eyelid: down, .eyeSize: up, .sparkle: up]
        case .mouth:
            let open = (p.x + 1) / 2
            let wide = min(max((open - 0.5) / 0.45, 0), 1)
            return [.smile: p.y, .mouthOpen: open, .teeth: 1 - 0.65 * wide, .tongue: wide, .mouthRound: 0]
        }
    }

    /// Where the knob sits for a set of parameters.
    func position(for f: FaceParameters) -> CGPoint {
        let p = switch self {
        case .brows:
            CGPoint(x: f[.browTilt], y: f[.browLift])
        case .eyes:
            CGPoint(x: f[.smileEyes] > 0 ? f[.smileEyes] : min(0, f[.lidTilt]),
                    y: f[.eyelid] > 0 ? -f[.eyelid] : max(0, f[.eyeSize]))
        case .mouth:
            CGPoint(x: 2 * f[.mouthOpen] - 1, y: f[.smile])
        }
        return CGPoint(x: min(max(p.x, -1), 1), y: min(max(p.y, -1), 1))
    }

    /// The face with this part's knob moved from its home. At home the face is untouched.
    /// Whatever the expression had beyond the pad's own values fades out as the knob
    /// leaves, so the pad's edges mean the same thing from any expression.
    func apply(to face: FaceParameters, home: CGPoint, knob: CGPoint) -> FaceParameters {
        let own = 1 - min(1, hypot(knob.x - home.x, knob.y - home.y))
        let atHome = response(at: home)
        var result = face
        for (parameter, value) in response(at: knob) {
            result[parameter] = value + (face[parameter] - (atHome[parameter] ?? 0)) * own
        }
        return result
    }
}

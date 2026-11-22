/// One control on the face. Raw values match the Rive view model property names.
enum FaceParameter: String, CaseIterable, Codable {
    case browLift, browTilt, browPinch, browAsym
    case eyeSize, eyelid, lidTilt, smileEyes, sparkle, gazeX, gazeY
    case smile, mouthOpen, mouthWidth, mouthRound, mouthSkew, teeth, tongue
    case headTurn, headNod, headTilt
    case sneer, blush

    enum Group: String, CaseIterable {
        case mouth = "Mouth", eyes = "Eyes", brows = "Brows", head = "Head", details = "Details"

        var parameters: [FaceParameter] { FaceParameter.allCases.filter { $0.group == self } }
    }

    var group: Group {
        switch self {
        case .browLift, .browTilt, .browPinch, .browAsym: .brows
        case .eyeSize, .eyelid, .lidTilt, .smileEyes, .sparkle, .gazeX, .gazeY: .eyes
        case .smile, .mouthOpen, .mouthWidth, .mouthRound, .mouthSkew, .teeth, .tongue: .mouth
        case .headTurn, .headNod, .headTilt: .head
        case .sneer, .blush: .details
        }
    }

    var label: String {
        switch self {
        case .browLift: "Height"
        case .browTilt: "Angry to sad"
        case .browPinch: "Furrow"
        case .browAsym: "Raise one brow"
        case .eyeSize: "Pupil size"
        case .eyelid: "Close eyelids"
        case .lidTilt: "Eyelid angle"
        case .smileEyes: "Smiling eyes"
        case .sparkle: "Sparkle"
        case .gazeX: "Look left or right"
        case .gazeY: "Look down or up"
        case .smile: "Frown to smile"
        case .mouthOpen: "Open"
        case .mouthWidth: "Width"
        case .mouthRound: "Round"
        case .mouthSkew: "Lopsided"
        case .teeth: "Teeth"
        case .tongue: "Tongue"
        case .headTurn: "Turn"
        case .headNod: "Nod"
        case .headTilt: "Tilt"
        case .sneer: "Nose wrinkle"
        case .blush: "Blush"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .browPinch, .eyelid, .smileEyes, .sparkle, .mouthOpen, .mouthRound, .teeth, .tongue, .sneer, .blush:
            0...1
        default:
            -1...1
        }
    }

    var neutral: Double {
        switch self {
        case .smile: 0.5
        case .mouthOpen: 0.45
        case .teeth: 1
        default: 0
        }
    }
}

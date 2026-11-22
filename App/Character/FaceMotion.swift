/// Springs every facial control toward a target.
struct FaceMotion {
    private(set) var values = Dictionary(uniqueKeysWithValues: FaceParameter.allCases.map { ($0, $0.neutral) })
    private var velocities: [FaceParameter: Double] = [:]

    /// Moves one frame and returns the controls that changed. None means everything has arrived.
    mutating func step(toward target: FaceParameters, by dt: Double, reduceMotion: Bool) -> [FaceParameter] {
        FaceParameter.allCases.filter { move($0, toward: target[$0], by: dt, reduceMotion: reduceMotion) }
    }

    private mutating func move(_ p: FaceParameter, toward goal: Double, by dt: Double, reduceMotion: Bool) -> Bool {
        let start = values[p] ?? p.neutral
        var x = start, v = velocities[p] ?? 0
        guard x != goal || v != 0 else { return false }
        // Eyes lead, the face follows, the head arrives last.
        let (stiffness, damping): (Double, Double) = switch p.group {
        case .eyes: (320, 30)
        case .head: (120, 17)
        default: (210, 22)
        }
        v += ((goal - x) * stiffness - v * damping) * dt
        x += v * dt
        if reduceMotion || (abs(goal - x) < 0.0005 && abs(v) < 0.0005) {
            x = goal
            v = 0
        }
        values[p] = x
        velocities[p] = v
        return true
    }
}

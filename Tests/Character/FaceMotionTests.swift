import Testing
@testable import CharacterRigging

struct FaceMotionTests {
    private func target(_ p: FaceParameter, _ value: Double) -> FaceParameters {
        var face = FaceParameters.neutral
        face[p] = value
        return face
    }

    @Test func restsAtNeutral() {
        var motion = FaceMotion()
        #expect(motion.step(toward: .neutral, by: 1 / 60, reduceMotion: false).isEmpty)
    }

    @Test(arguments: FaceParameter.allCases, [1.0 / 120, 1.0 / 60, 1.0 / 30]) func arrivesExactlyAndStops(p: FaceParameter, dt: Double) {
        var motion = FaceMotion()
        let goal = target(p, p.range.upperBound == p.neutral ? p.range.lowerBound : p.range.upperBound)
        var frames = 0
        while !motion.step(toward: goal, by: dt, reduceMotion: false).isEmpty, frames < 1000 { frames += 1 }
        #expect(Double(frames) * dt < 2)
        #expect(motion.values[p] == goal[p])
    }

    @Test func reduceMotionJumps() {
        var motion = FaceMotion()
        _ = motion.step(toward: target(.headTurn, 1), by: 1 / 60, reduceMotion: true)
        #expect(motion.values[.headTurn] == 1)
        #expect(motion.step(toward: target(.headTurn, 1), by: 1 / 60, reduceMotion: true).isEmpty)
    }
}

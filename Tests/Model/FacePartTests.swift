import CoreGraphics
import Foundation
import Testing
@testable import CharacterRigging

@MainActor
struct FacePartTests {
    private let builtIn = ExpressionLibrary(folder: .temporaryDirectory.appending(path: UUID().uuidString)).builtIn

    @Test(arguments: FacePart.allCases) func aKnobAtHomeChangesNothing(part: FacePart) {
        for expression in builtIn {
            let face = expression.parameters, home = part.position(for: face)
            let result = part.apply(to: face, home: home, knob: home)
            for p in FaceParameter.allCases { #expect(abs(result[p] - face[p]) < 1e-9, "\(expression.id) \(p)") }
        }
    }

    /// Far from home, the pad's corners mean the same thing whatever the expression.
    @Test(arguments: FacePart.allCases) func cornersMatchAcrossExpressions(part: FacePart) {
        for (x, y) in [(-1.0, -1.0), (-1, 1), (1, -1), (1, 1)] {
            let corner = CGPoint(x: x, y: y)
            for expression in builtIn {
                let home = part.position(for: expression.parameters)
                guard hypot(home.x - x, home.y - y) >= 1 else { continue }
                let result = part.apply(to: expression.parameters, home: home, knob: corner)
                for (p, value) in part.response(at: corner) { #expect(abs(result[p] - value) < 1e-9, "\(expression.id) \(p)") }
            }
        }
    }

    @Test func partsDoNotShareControls() {
        let controls = FacePart.allCases.flatMap { $0.response(at: .zero).keys }
        #expect(Set(controls).count == controls.count)
    }
}

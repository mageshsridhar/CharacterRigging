import CoreGraphics
import Foundation
import Testing
@testable import CharacterRigging

@MainActor
struct StudioTests {
    private let studio = Studio(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    private let library = ExpressionLibrary(folder: .temporaryDirectory.appending(path: UUID().uuidString))
    private var joy: Expression { library.builtIn.first { $0.id == "joy" }! }

    @Test func cancelRestoresTheFace() {
        studio.select(joy)
        studio.move(.mouth, to: CGPoint(x: -1, y: -1))
        let before = studio.parameters
        studio.beginEditing()
        studio.set(.smile, to: 0.9)
        studio.beginEditing()
        studio.cancelEditing()
        #expect(studio.parameters == before)
        #expect(studio.title == "Joy, edited")
        #expect(!studio.isEditing)
    }

    @Test func editingStartsFromWhatIsOnScreen() {
        studio.select(joy)
        studio.move(.brows, to: CGPoint(x: -1, y: -1))
        let before = studio.parameters
        studio.beginEditing()
        for p in FaceParameter.allCases { #expect(abs(studio.parameters[p] - before[p]) < 1e-9) }
        #expect(!studio.isModified)
    }

    @Test func renamingTheSelectedExpressionUpdatesTheTitle() {
        studio.select(joy)
        studio.renamed(joy, to: "Delight")
        #expect(studio.title == "Delight")
    }

    @Test func lookingAroundIsNotPartOfTheExpression() {
        studio.select(joy)
        studio.look = CGPoint(x: 1, y: 1)
        #expect(studio.parameters[.headTurn] == joy.parameters[.headTurn])
        #expect(studio.rig.target[.headTurn] == 1)
    }
}

import Foundation
import Testing
@testable import CharacterRigging

@MainActor
struct FaceParametersTests {
    @Test func valuesStayInRange() {
        var face = FaceParameters.neutral
        face[.eyelid] = 5
        face[.smile] = -5
        #expect(face[.eyelid] == 1)
        #expect(face[.smile] == -1)
    }

    @Test func codingRoundTrips() throws {
        var face = FaceParameters.neutral
        for p in FaceParameter.allCases { face[p] = p.range.upperBound * 0.3 }
        let decoded = try JSONDecoder().decode(FaceParameters.self, from: JSONEncoder().encode(face))
        for p in FaceParameter.allCases { #expect(decoded[p] == face[p]) }
    }

    /// Faces saved before a control was removed still load.
    @Test func retiredControlsAreIgnored() throws {
        let face = try JSONDecoder().decode(FaceParameters.self, from: Data(#"{"tear": 1, "smile": 0.2}"#.utf8))
        #expect(face[.smile] == 0.2)
        #expect(face[.mouthOpen] == FaceParameter.mouthOpen.neutral)
    }
}

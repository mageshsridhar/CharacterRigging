import Foundation
import RiveRuntime
import Testing
import UIKit
@testable import CharacterRigging

/// The JSON, the code, the rig and the thumbnails have to agree by name, and nothing else checks that they do.
@MainActor
struct CharacterTests {
    private let builtIn = ExpressionLibrary(folder: .temporaryDirectory.appending(path: UUID().uuidString)).builtIn

    @Test func expressionsUseOnlyRealControlsInRange() throws {
        let url = try #require(Bundle.main.url(forResource: "expressions", withExtension: "json"))
        let entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        for entry in entries {
            let id = try #require(entry["id"] as? String)
            for (key, value) in try #require(entry["parameters"] as? [String: Double]) {
                let p = try #require(FaceParameter(rawValue: key), "\(id) has an unknown control: \(key)")
                #expect(p.range.contains(value), "\(id) \(key) is \(value)")
            }
        }
    }

    @Test func builtInExpressionsAreComplete() {
        #expect(Set(builtIn.map(\.id)).count == builtIn.count)
        for expression in builtIn {
            #expect(expression.group != nil && expression.group != .mine, "\(expression.id) needs a group")
        }
        for id in builtIn.map(\.id) + [Expression.neutral.id] {
            #expect(UIImage(named: "thumb_\(id)") != nil, "\(id) has no thumbnail")
            #expect(UIImage(named: "thumb_\(id)_painted") != nil, "\(id) has no color thumbnail")
        }
    }

    @Test func rigHasEveryControlAndTheSameNeutral() async throws {
        let file = try await File(source: .local("head", .main), worker: Worker())
        let artboard = try await file.createArtboard()
        let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
        for p in FaceParameter.allCases {
            let value = try await instance.value(of: NumberProperty(path: p.rawValue))
            #expect(abs(Double(value) - p.neutral) < 1e-6, "\(p) starts at \(value) in the rig")
        }
        #expect(try await instance.value(of: NumberProperty(path: "color")) == 0)
    }

    @Test func picturesAreRepeatableAndInTheRightLook() async throws {
        let file = try await File(source: .local("head", .main), worker: Worker())
        let face = try #require(builtIn.first { $0.id == "joy" }).parameters
        let first = try await FacePicture(file: file).thumbnails(of: face)
        // Long enough to be mid-blink, if the live character's clock were involved.
        try await Task.sleep(for: .seconds(2.9))
        let second = try await FacePicture(file: file).thumbnails(of: face)
        #expect(first.plain?.pngData() == second.plain?.pngData())
        #expect(first.color?.pngData() == second.color?.pngData())
        #expect(try colorfulness(of: first.plain) < 0.001)
        #expect(try colorfulness(of: first.color) > 0.1)
    }

    /// The share of pixels that aren't gray.
    private func colorfulness(of image: UIImage?) throws -> Double {
        let data = try #require(image?.cgImage?.dataProvider?.data) as Data
        let pixels = stride(from: 0, to: data.count, by: 4)
        let colorful = pixels.filter { i in
            let p = data[i..<i + 3]
            return Int(p.max()!) - Int(p.min()!) > 30
        }
        return Double(colorful.count) / Double(data.count / 4)
    }

    @Test func rigRestsOnceItArrives() async throws {
        let rig = FaceRig()
        await rig.load()
        guard case .ready = rig.state else { Issue.record("didn't load"); return }
        try await Task.sleep(for: .seconds(0.5))
        #expect(rig.isResting)
        var face = FaceParameters.neutral
        face[.smile] = -1
        rig.target = face
        #expect(!rig.isResting)
        try await Task.sleep(for: .seconds(3))
        #expect(rig.isResting)
    }
}

import Foundation
import Testing
import UIKit
@testable import CharacterRigging

@MainActor
final class ExpressionLibraryTests {
    private let folder = URL.temporaryDirectory.appending(path: "ExpressionLibraryTests-\(UUID().uuidString)")
    private var index: URL { folder.appending(path: "expressions.json") }
    private var names: [String] { (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] }
    private var backups: [String] { names.filter { $0.contains("backup") } }

    deinit { try? FileManager.default.removeItem(at: folder) }

    private func picture() -> UIImage {
        UIGraphicsImageRenderer(size: .init(width: 4, height: 4)).image { $0.fill(.init(x: 0, y: 0, width: 4, height: 4)) }
    }

    @discardableResult
    private func save(_ name: String, in library: ExpressionLibrary) throws -> Expression {
        var face = FaceParameters.neutral
        face[.smile] = -0.5
        return try library.save(name: name, parameters: face, thumbnails: Thumbnails(plain: picture(), color: picture()))
    }

    @Test func savedExpressionsSurviveAReload() throws {
        let saved = try save("One", in: ExpressionLibrary(folder: folder))
        let reloaded = ExpressionLibrary(folder: folder)
        #expect(reloaded.custom == [saved])
        #expect(reloaded.custom.first?.parameters[.smile] == -0.5)
        #expect(reloaded.custom.first?.family == .mine)
        #expect(reloaded.thumbnail(for: saved, isColor: true) != nil)
        #expect(backups.isEmpty)
    }

    @Test func renameAndDelete() throws {
        let library = ExpressionLibrary(folder: folder)
        let one = try save("One", in: library), two = try save("Two", in: library)
        try library.rename(one, to: "Uno")
        #expect(library.custom.map(\.name) == ["Uno", "Two"])
        try library.delete(two)
        #expect(ExpressionLibrary(folder: folder).custom.map(\.name) == ["Uno"])
        #expect(!names.contains { $0.hasPrefix(two.id) })
    }

    @Test func oneBadEntryDoesNotLoseTheRest() throws {
        try save("Good", in: ExpressionLibrary(folder: folder))
        var entries = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [[String: Any]])
        var bad = entries[0]
        bad["id"] = "bad"
        bad["group"] = "unknown"
        entries.insert(bad, at: 0)
        let original = try JSONSerialization.data(withJSONObject: entries)
        try original.write(to: index)

        let library = ExpressionLibrary(folder: folder)
        #expect(library.custom.map(\.name) == ["Good"])
        #expect(backups.isEmpty, "nothing is copied until it would be overwritten")
        try save("New", in: library)
        try save("Newer", in: library)
        #expect(library.custom.map(\.name) == ["Good", "New", "Newer"])
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: folder.appending(path: #require(backups.first))) == original)
    }

    @Test func anUnreadableFileIsKept() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: index)
        let library = ExpressionLibrary(folder: folder)
        #expect(library.custom.isEmpty)
        try save("New", in: library)
        #expect(try String(contentsOf: folder.appending(path: #require(backups.first)), encoding: .utf8) == "not json")
    }

    @Test func aFailedSaveLeavesNothingBehind() throws {
        let library = ExpressionLibrary(folder: folder)
        // A folder where the file should go makes the write fail.
        try FileManager.default.createDirectory(at: index.appending(path: "blocked"), withIntermediateDirectories: true)
        #expect(throws: (any Error).self) { try save("New", in: library) }
        #expect(library.custom.isEmpty)
        #expect(!names.contains { $0.hasSuffix(".png") })
    }
}

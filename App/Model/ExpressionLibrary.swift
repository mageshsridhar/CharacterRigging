import Observation
import UIKit

/// The built-in expressions plus the ones the user saves.
@MainActor @Observable
final class ExpressionLibrary {
    let builtIn: [Expression]
    private(set) var custom: [Expression] = []

    private var thumbnails: [String: UIImage] = [:]
    private let folder: URL
    /// Some of the saved file couldn't be read, so it's copied aside before it's next written over.
    private var needsBackup = false

    init(folder: URL = .applicationSupportDirectory.appending(path: "Expressions")) {
        self.folder = folder
        guard let url = Bundle.main.url(forResource: "expressions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let expressions = try? JSONDecoder().decode([Expression].self, from: data)
        else { fatalError("expressions.json is missing or invalid") }
        builtIn = expressions
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: indexURL.path) {
            let saved = (try? Data(contentsOf: indexURL)).flatMap { try? JSONDecoder().decode([Readable].self, from: $0) }
            custom = saved?.compactMap(\.expression) ?? []
            needsBackup = custom.count != saved?.count
        }
        // Read once here, because the carousel redraws on every step.
        for expression in custom {
            for isColor in [false, true] {
                thumbnails[key(expression.id, isColor)] = UIImage(contentsOfFile: thumbnailURL(expression.id, isColor).path)
            }
        }
    }

    var all: [Expression] { builtIn + custom }

    /// Families that have at least one expression.
    var families: [ExpressionFamily] { ExpressionFamily.allCases.filter { !expressions(in: $0).isEmpty } }

    func expressions(in family: ExpressionFamily) -> [Expression] { all.filter { $0.family == family } }

    func isCustom(_ expression: Expression) -> Bool { custom.contains { $0.id == expression.id } }

    @discardableResult
    func save(name: String, parameters: FaceParameters, thumbnails images: Thumbnails) throws -> Expression {
        let expression = Expression(id: UUID().uuidString, name: name, detail: "My expression", parameters: parameters)
        do {
            for (image, isColor) in [(images.plain, false), (images.color, true)] {
                guard let image else { continue }
                try image.pngData()?.write(to: thumbnailURL(expression.id, isColor), options: .atomic)
                thumbnails[key(expression.id, isColor)] = image
            }
            try write(custom + [expression])
        } catch {
            removeThumbnails(expression.id)
            throw error
        }
        return expression
    }

    func rename(_ expression: Expression, to name: String) throws {
        try write(custom.map { item in
            var item = item
            if item.id == expression.id { item.name = name }
            return item
        })
    }

    func delete(_ expression: Expression) throws {
        try write(custom.filter { $0.id != expression.id })
        removeThumbnails(expression.id)
    }

    private func removeThumbnails(_ id: String) {
        for isColor in [false, true] {
            thumbnails[key(id, isColor)] = nil
            try? FileManager.default.removeItem(at: thumbnailURL(id, isColor))
        }
    }

    /// Falls back to the other look for expressions saved with only one.
    func thumbnail(for expression: Expression, isColor: Bool) -> UIImage? {
        image(expression.id, isColor) ?? image(expression.id, !isColor)
    }

    private func image(_ id: String, _ isColor: Bool) -> UIImage? {
        thumbnails[key(id, isColor)] ?? UIImage(named: "thumb_\(key(id, isColor))")
    }

    private func key(_ id: String, _ isColor: Bool) -> String { isColor ? "\(id)_painted" : id }
    private var indexURL: URL { folder.appending(path: "expressions.json") }
    private func thumbnailURL(_ id: String, _ isColor: Bool) -> URL { folder.appending(path: "\(key(id, isColor)).png") }

    private func write(_ expressions: [Expression]) throws {
        if needsBackup {
            let name = "expressions.backup-\(Int(Date.now.timeIntervalSince1970)).json"
            try FileManager.default.copyItem(at: indexURL, to: folder.appending(path: name))
            needsBackup = false
        }
        try JSONEncoder().encode(expressions).write(to: indexURL, options: .atomic)
        custom = expressions
    }
}

/// A saved expression, or nil if that one entry can't be read.
private struct Readable: Decodable {
    let expression: Expression?
    init(from decoder: Decoder) { expression = try? Expression(from: decoder) }
}

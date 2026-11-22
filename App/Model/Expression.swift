import UIKit

struct Expression: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var detail: String
    /// Set for built-in expressions only.
    var group: ExpressionFamily?
    var parameters: FaceParameters

    var family: ExpressionFamily { group ?? .mine }

    static let neutral = Expression(id: "neutral", name: "Neutral", detail: "", parameters: .neutral)
}

/// Groups of related feelings, in the order they appear.
enum ExpressionFamily: String, Codable, CaseIterable, Comparable {
    case happy, bold, surprised, low, tense, mine

    static func < (a: Self, b: Self) -> Bool { allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)! }

    var label: String { rawValue.capitalized }
}

/// A picture of an expression in each look.
struct Thumbnails {
    var plain: UIImage?
    var color: UIImage?
}

import Foundation

struct FaceParameters: Equatable, Codable {
    /// Every control is always present, so equal faces compare equal.
    private var values = Dictionary(uniqueKeysWithValues: FaceParameter.allCases.map { ($0, $0.neutral) })

    static let neutral = FaceParameters()

    init() {}

    subscript(_ parameter: FaceParameter) -> Double {
        get { values[parameter] ?? parameter.neutral }
        set { values[parameter] = min(max(newValue, parameter.range.lowerBound), parameter.range.upperBound) }
    }

    func adding(_ offsets: [FaceParameter: Double]) -> FaceParameters {
        var result = self
        for (p, delta) in offsets { result[p] = self[p] + delta }
        return result
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Double].self)
        for (key, value) in raw {
            if let p = FaceParameter(rawValue: key) { self[p] = value }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: FaceParameter.allCases.map { ($0.rawValue, self[$0]) }))
    }
}

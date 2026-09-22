//
//  VariableReader.swift
//  WarpSyntax
//

import Foundation
import Warp

// A module variable's entry: its start written as an expression, or a record
// `{ type, value }` saying what the variable holds beside the start. A
// record carrying `type` at the top is read as that form, so a record literal
// with such a field is written under `{ value: ... }` the way one carrying a
// form key is.
public struct VariableReader: Decodable {
    // MARK: - Property
    public let variable: ModuleVariable

    static let typeKey = StatementReader.typeKey
    static let valueKey = StatementReader.valueKey

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        guard
            let container = try? decoder.container(keyedBy: AnyCodingKey.self),
            container.contains(AnyCodingKey(stringValue: Self.typeKey.spelling))
        else {
            self.variable = ModuleVariable(try ExpressionReader(from: decoder).expression)
            return
        }

        let keys = Set(container.allKeys.map(\.stringValue))

        guard keys == [Self.typeKey.spelling, Self.valueKey.spelling] else {
            throw ReadingError(
                "a variable that says what it holds is written { type, value } and nothing else"
                    + " (found keys: \(keys.sorted()))",
                at: decoder.steps
            )
        }

        let declared = try container.decode(TypeReader.self, forKey: AnyCodingKey(stringValue: Self.typeKey.spelling)).type
        let start = try container.decode(ExpressionReader.self, forKey: AnyCodingKey(stringValue: Self.valueKey.spelling)).expression

        self.variable = ModuleVariable(start, declared: declared)
    }

    // MARK: - Public
    // MARK: - Private
}

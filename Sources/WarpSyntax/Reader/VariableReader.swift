//
//  VariableReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Warp

// A module variable's entry: exactly `{ type, value }`, the type the
// variable holds and its start. A struct is written under `struct`, so a
// struct never meets this form.
struct VariableReader: Decodable {
    // MARK: - Property
    let variable: ModuleVariable

    static let typeKey = StatementReader.typeKey
    static let valueKey = StatementReader.valueKey

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        guard
            let container = try? decoder.container(keyedBy: AnyCodingKey.self),
            Set(container.allKeys.map(\.stringValue)) == [Self.typeKey.spelling, Self.valueKey.spelling]
        else {
            throw ReadingError(
                "a module variable writes `{ \(Self.typeKey), \(Self.valueKey) }`: the type it holds and its start",
                at: try decoder.steps
            )
        }

        let typeKey = AnyCodingKey(stringValue: Self.typeKey.spelling)
        let valueKey = AnyCodingKey(stringValue: Self.valueKey.spelling)
        let declared = try container.decode(TypeReader.Written.self, forKey: typeKey)
        let start = try container.decode(ExpressionReader.self, forKey: valueKey)

        self.variable = ModuleVariable(start.expression, declared: try declared.unbounded())
    }

    // MARK: - Public
    // MARK: - Private
}

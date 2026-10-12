//
//  VariableReader.swift
//  WarpSyntax
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Warp

// A module variable's entry: its start written as an expression, or exactly
// `{ type, value }` saying what the variable holds beside the start. A
// record is written under `record`, so a record never meets this form.
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
            self.variable = ModuleVariable(try ExpressionReader(from: decoder).expression)
            return
        }

        let typeKey = AnyCodingKey(stringValue: Self.typeKey.spelling)
        let valueKey = AnyCodingKey(stringValue: Self.valueKey.spelling)
        let declared = try container.decode(TypeReader.self, forKey: typeKey)
        let start = try container.decode(ExpressionReader.self, forKey: valueKey)

        self.variable = ModuleVariable(start.expression, declared: declared.type)
    }

    // MARK: - Public
    // MARK: - Private
}

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
// document writes a record under `record`, so a record never meets this
// form there; a notation that reads a bare mapping as a record writes one of
// exactly those two fields under `record` too.
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

        let declared = try container.decode(TypeReader.self, forKey: AnyCodingKey(stringValue: Self.typeKey.spelling)).type
        let start = try container.decode(ExpressionReader.self, forKey: AnyCodingKey(stringValue: Self.valueKey.spelling)).expression

        self.variable = ModuleVariable(start, declared: declared)
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  TypeDeclaration+Lowering.swift
//  Warp
//
//  Created by JSilver on 10/11/26.
//

import Foundation

extension TypeDeclaration {
    // What a declared name stands for as the run reads it: a struct as the
    // layout its values are built on, under the name, beside the type of each
    // field, and an alias as the type it stands for.
    func lowered(as label: Name, in table: LoweredTypeTable) -> LoweredType {
        switch self {
        case let .struct(fields):
            let ordered = fields.sorted { left, right in left.key < right.key }

            return .struct(
                LoweredStruct(name: label, names: ordered.map(\.key), fields: ordered.map { _, field in field.lowered(in: table) })
            )

        case let .alias(type):
            return type.lowered(in: table)
        }
    }
}

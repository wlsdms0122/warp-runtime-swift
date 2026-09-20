//
//  Value+Reading.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // The part a path names, in a record by the place the link put the field
    // at, in a dictionary by key and in an array by position. Every index was
    // read to a position before this, and the link judged the path against
    // the value's declared type, so a part not held is refused as what it
    // is: an entry not written yet, or a type with no such part.
    func reading(at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return self }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' reads '\(name)' past the fields this record holds")
            }

            return try record.values[position].reading(at: rest, under: rendered)

        case let (.record(record), .key(name)):
            guard let field = record[name] else {
                throw ExecutionError("'\(rendered)' reads '\(name)', which is not written yet")
            }

            return try field.reading(at: rest, under: rendered)

        case let (.array(elements), .index(index)):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' reads element \(index) of an array holding \(elements.count)"
                )
            }

            return try elements[index].reading(at: rest, under: rendered)

        default:
            throw ExecutionError(
                "'\(rendered)' reads \([step.spelled].rendered) of \(type), which has no such part"
            )
        }
    }
}

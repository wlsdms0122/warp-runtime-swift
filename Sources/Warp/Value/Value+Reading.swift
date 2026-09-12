//
//  Value+Reading.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // The part a path names, in a record by key and in an array by position.
    // Every index was read to a position before this, and the link judged the
    // path against the value's declared type, so a part not held is refused
    // as what it is: an entry not written yet, or a type with no such part.
    func reading(at path: [PathSegment], under rendered: String) throws -> Value {
        guard let segment = path.first else { return self }

        let rest = Array(path.dropFirst())

        switch (self, segment) {
        case let (.record(record), .key(name, _)):
            guard let field = record[name] else {
                throw ExecutionError("'\(rendered)' reads '\(name)', which is not written yet")
            }

            return try field.reading(at: rest, under: rendered)

        case let (.array(elements), .index(index, _)):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' reads element \(index) of an array holding \(elements.count)"
                )
            }

            return try elements[index].reading(at: rest, under: rendered)

        default:
            throw ExecutionError(
                "'\(rendered)' reads \([segment].rendered) of \(type), which has no such part"
            )
        }
    }
}

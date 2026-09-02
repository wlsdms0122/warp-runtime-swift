//
//  Value+Writing.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // This value with one part replaced: the part the path names, in a record
    // by key and in an array by position. The rest is kept as it was. The
    // link judged the path against the value's declared shape, and the run
    // resolved every index to a position before coming here, so a key not yet
    // held is an entry of an object and is made, and a path that lands
    // nowhere is one the link did not see.
    func writing(_ value: Value, at path: [PathSegment], under rendered: String) throws -> Value {
        guard let segment = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, segment) {
        case let (.object(fields), .key(name, _)):
            var written = fields
            written[name] = try (fields[name] ?? .null).writing(value, at: rest, under: rendered)
            return .object(written)

        case let (.array(elements), .index(index, _)):
            guard elements.indices.contains(index) else {
                throw ExecutionError(
                    "'\(rendered)' writes element \(index) of an array holding \(elements.count)"
                )
            }

            var written = elements
            written[index] = try elements[index].writing(value, at: rest, under: rendered)
            return .array(written)

        default:
            throw ExecutionError(
                "'\(rendered)' writes into \(type) at \([segment].rendered), which the link did not judge"
            )
        }
    }
}

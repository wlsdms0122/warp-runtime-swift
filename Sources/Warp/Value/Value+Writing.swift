//
//  Value+Writing.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // This value with one part replaced: the part the path names, in a record
    // by key and in an array by position. The rest is kept as it was. A path
    // that names no part of this value refuses, naming the write it was part
    // of, because a write that lands nowhere is a write the link should have
    // refused.
    func writing(_ value: Value, at path: [PathSegment], under rendered: String) throws -> Value {
        guard let segment = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, segment) {
        case let (.object(fields), .key(name, _)):
            guard let current = fields[name] else {
                throw ExecutionError(
                    "'\(rendered)' writes through '\(name)', which \(type) does not hold"
                )
            }

            var written = fields
            written[name] = try current.writing(value, at: rest, under: rendered)
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

        case (_, .word), (_, .indexRef):
            throw ExecutionError(
                "'\(rendered)' writes through a segment that is not a field or an index"
            )

        default:
            throw ExecutionError(
                "'\(rendered)' writes into \(type), which has no part named \([segment].rendered)"
            )
        }
    }
}

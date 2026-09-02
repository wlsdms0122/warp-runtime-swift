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
    // link judged the path against the value's declared shape, and every
    // index was read to a position before this, so a key not yet held is an
    // entry of an object and is made. A part the value does not hold below
    // that is refused as what it is: an entry not written yet, or a shape
    // with no such part.
    func writing(_ value: Value, at path: [PathSegment], under rendered: String) throws -> Value {
        guard let segment = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, segment) {
        case let (.record(_, fields), .key(name, _)):
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

        case (.null, _):
            throw ExecutionError(
                "'\(rendered)' writes through \([segment].rendered), which holds nothing yet"
                    + " — write the whole entry first"
            )

        default:
            throw ExecutionError(
                "'\(rendered)' writes \([segment].rendered) into \(type), which has no such part"
            )
        }
    }
}

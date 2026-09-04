//
//  Value+Writing.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // This value with one part replaced: the part the path names, in a record
    // and a dictionary by name and in an array by position. The rest is kept
    // as it was. The link judged the path against the value's declared shape,
    // and every index was read to a position before this. A record's fields
    // are its layout's, so a name it does not hold is refused; a dictionary's
    // names are its own, so one not held yet is made.
    func writing(_ value: Value, at path: [PathSegment], under rendered: String) throws -> Value {
        guard let segment = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, segment) {
        // A field the layout names is written where it stands; any other name
        // makes an entry, and what holds it holds its names as data. The link
        // judged the path, so a name that reaches here is one it allowed.
        case let (.record(record), .key(name, _)):
            if let held = record[name] {
                return .record(try record.writing(name, with: try held.writing(value, at: rest, under: rendered)))
            }

            return .dictionary(
                record.asDictionary.writing(name, with: try Value.null.writing(value, at: rest, under: rendered))
            )

        case let (.dictionary(dictionary), .key(name, _)):
            return .dictionary(
                dictionary.writing(name, with: try (dictionary[name] ?? .null).writing(value, at: rest, under: rendered))
            )

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

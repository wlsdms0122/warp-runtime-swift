//
//  Value+Writing.swift
//  Warp
//
//  Created by JSilver on 9/3/26.
//

import Foundation

extension Value {
    // This value with one part replaced: the part the path names, in a record
    // by the place the link put the field at, in a dictionary by name and in
    // an array by position. The rest is kept as it was. The link judged the
    // path against the value's declared type, and every index was read to a
    // position before this. A dictionary's names are its own, so one not
    // held yet is made.
    func writing(_ value: Value, at path: [Projection], under rendered: String) throws -> Value {
        guard let step = path.first else { return value }

        let rest = Array(path.dropFirst())

        switch (self, step) {
        case let (.record(record), .field(position, name)):
            guard record.values.indices.contains(position) else {
                throw ExecutionError("'\(rendered)' writes '\(name)' past the fields this record holds")
            }

            var values = record.values
            values[position] = try values[position].writing(value, at: rest, under: rendered)
            return .record(Record(layout: record.layout, values: values))

        // A name written into what holds its names as data. The link judged
        // the path, so a name that reaches here is one it allowed.
        case let (_, .key(name)) where holdsFields:
            do {
                return try writing(name, with: try (self[name] ?? .null).writing(value, at: rest, under: rendered))
            } catch let refused as ValueRefused {
                throw ExecutionError("'\(rendered)' writes '\(name)', and \(refused.message)")
            }

        case let (.array(elements), .index(index)):
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
                "'\(rendered)' writes through \([step.spelled].rendered), which holds nothing yet."
                    + " Write the whole entry first"
            )

        default:
            throw ExecutionError(
                "'\(rendered)' writes \([step.spelled].rendered) into \(type), which has no such part"
            )
        }
    }
}

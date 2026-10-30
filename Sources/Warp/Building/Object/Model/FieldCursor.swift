//
//  FieldCursor.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// The fields of one written part, handed back in the order they were written.
//
// A writing lays a part down as an array and says nothing about what each
// place holds, so a reading that runs short or finds the wrong kind is
// refused here rather than further in, where the sentence would be about
// something else. What each field is, is read through `Field`.
struct FieldCursor {
    // MARK: - Property
    private let part: String
    private let written: [Value]
    private var position: Int = 0

    // Whether every field written has been read: what a part writing its
    // last fields only where they say something asks before it reads them.
    var isAtEnd: Bool {
        position == written.count
    }

    // MARK: - Initializer
    init(_ value: Value, of part: String) throws {
        guard case let .array(written) = value else {
            throw ObjectRefused("'\(part)' is not written as an array")
        }

        self.part = part
        self.written = written
    }

    // MARK: - Public
    mutating func next() throws -> Value {
        guard position < written.count else {
            throw ObjectRefused(
                "'\(part)' writes \(written.count) field(s) and one more was read"
            )
        }

        defer { position += 1 }

        return written[position]
    }

    // The next field, read as the kind that stands there.
    mutating func field() throws -> Field {
        Field(try next(), of: part)
    }
    // That every field written has been read. A writing this reading does not
    // understand the whole of is a writing of something else.
    func end() throws {
        guard isAtEnd else {
            throw ObjectRefused("'\(part)' writes \(written.count) fields and \(position) were read")
        }
    }

    // MARK: - Private
}

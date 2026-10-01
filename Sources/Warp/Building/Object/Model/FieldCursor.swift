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

    mutating func integer() throws -> Int {
        try field().integer()
    }

    mutating func double() throws -> Double {
        try field().double()
    }

    mutating func count() throws -> Int {
        try field().count()
    }

    mutating func text() throws -> String {
        try field().text()
    }

    mutating func flag() throws -> Bool {
        try field().flag()
    }

    mutating func name() throws -> Name {
        try field().name()
    }

    mutating func bytes() throws -> [UInt8] {
        try field().bytes()
    }

    mutating func list<T>(_ read: (Value) throws -> T) throws -> [T] {
        try field().list(read)
    }

    mutating func maybe<T>(_ read: (Value) throws -> T) throws -> T? {
        try field().maybe(read)
    }

    // Which of a kind's cases was written. The tag stands first, so this is
    // read before the fields the case carries.
    mutating func tag() throws -> Int {
        try integer()
    }

    // That every field written has been read. A writing this reading does not
    // understand the whole of is a writing of something else.
    func end() throws {
        guard position == written.count else {
            throw ObjectRefused("'\(part)' writes \(written.count) fields and \(position) were read")
        }
    }

    // MARK: - Private
    private mutating func field() throws -> Field {
        Field(try next(), of: part)
    }
}

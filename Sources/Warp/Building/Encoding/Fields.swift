//
//  Fields.swift
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
// something else.
struct Fields {
    // MARK: - Property
    private let of: String
    private let written: [Value]
    private var at: Int = 0

    // MARK: - Initializer
    init(_ value: Value, of part: String) throws {
        guard case let .array(written) = value else {
            throw ArtifactRefused("'\(part)' is not written as an array")
        }

        self.of = part
        self.written = written
    }

    // MARK: - Internal
    mutating func next() throws -> Value {
        guard at < written.count else {
            throw ArtifactRefused("'\(of)' ends before its \(at + 1)th field")
        }

        defer { at += 1 }

        return written[at]
    }

    mutating func integer() throws -> Int {
        guard case let .int(integer) = try next() else {
            throw ArtifactRefused("'\(of)' writes something other than a number where one stands")
        }

        return integer
    }

    mutating func double() throws -> Double {
        switch try next() {
        case let .double(double):
            return double

        case let .int(integer):
            return Double(integer)

        default:
            throw ArtifactRefused("'\(of)' writes something other than a number where one stands")
        }
    }

    // A number that counts or stands somewhere: a slot, a row, a position, a
    // size. Below zero is refused here because further in it is not a number
    // that is wrong but an array subscripted out of itself, and the sentence
    // there would be about something else.
    mutating func count() throws -> Int {
        let read = try integer()

        guard read >= 0 else {
            throw ArtifactRefused("'\(of)' writes \(read) where a count stands")
        }

        return read
    }

    mutating func text() throws -> String {
        guard case let .string(text) = try next() else {
            throw ArtifactRefused("'\(of)' writes something other than a text where one stands")
        }

        return text
    }

    mutating func flag() throws -> Bool {
        guard case let .bool(flag) = try next() else {
            throw ArtifactRefused("'\(of)' writes something other than a yes or no where one stands")
        }

        return flag
    }

    mutating func name() throws -> Name {
        Name(normal: try text())
    }

    mutating func bytes() throws -> [UInt8] {
        guard case let .bytes(bytes) = try next() else {
            throw ArtifactRefused("'\(of)' writes something other than bytes where they stand")
        }

        return bytes
    }

    // The next field as a written list, and the one in hand. Two ways to reach
    // one reading: a part reads its own fields in order, and what a reading is
    // handed is sometimes the list itself.
    mutating func list<T>(_ read: (Value) throws -> T) throws -> [T] {
        try Fields.list(try next(), of: of, read)
    }

    mutating func maybe<T>(_ read: (Value) throws -> T) throws -> T? {
        try Fields.maybe(try next(), of: of, read)
    }

    // Which of a kind's cases was written. The tag stands first, so this is
    // read before the fields the case carries.
    mutating func tag() throws -> Int {
        try integer()
    }

    // That every field written has been read. A writing this reading does not
    // understand the whole of is a writing of something else.
    func end() throws {
        guard at == written.count else {
            throw ArtifactRefused("'\(of)' writes \(written.count) fields and \(at) were read")
        }
    }
}

extension Fields {
    // What a writing lays down for a field that may hold nothing.
    static func maybe<T>(_ value: T?, _ write: (T) -> Value) -> Value {
        value.map { held in .array([write(held)]) } ?? .array([])
    }

    // Each element of a written list, read the same way. The reading of one
    // element is handed the element rather than reaching for it, so a list of
    // lists nests without either reading holding the other's place.
    static func list<T>(_ value: Value, of part: String, _ read: (Value) throws -> T) throws -> [T] {
        guard case let .array(written) = value else {
            throw ArtifactRefused("'\(part)' writes something other than a list where one stands")
        }

        return try written.map(read)
    }

    // A writing that may hold nothing: a list of none or one, so a value that
    // is itself null is told from no value at all.
    static func maybe<T>(_ value: Value, of part: String, _ read: (Value) throws -> T) throws -> T? {
        let written = try list(value, of: part) { held in held }

        switch written.count {
        case 0:
            return nil

        case 1:
            return try read(written[0])

        default:
            throw ArtifactRefused("'\(part)' writes \(written.count) values where at most one stands")
        }
    }
}

//
//  Field.swift
//  Warp
//
//  Created by JSilver on 10/1/26.
//

import Foundation

// One written value of an object, read as the kind that stands there.
//
// What a value is, is judged here once: a part's cursor reads its next field
// through this and a list reads each of its elements through this, so one
// damaged writing is answered the same way whichever way it was reached.
struct Field {
    // MARK: - Property
    private let written: Value
    private let part: String

    // MARK: - Initializer
    init(_ written: Value, of part: String) {
        self.written = written
        self.part = part
    }

    // MARK: - Public
    func integer() throws -> Int {
        guard case let .int(integer) = written else {
            throw ObjectRefused("'\(part)' writes something other than a number where one stands")
        }

        return integer
    }

    // A number that counts or stands somewhere: a slot, a row, a position, a
    // size. Below zero is refused here because further in it is not a number
    // that is wrong but an array subscripted out of itself, and the sentence
    // there would be about something else.
    func count() throws -> Int {
        let read = try integer()

        guard read >= 0 else {
            throw ObjectRefused("'\(part)' writes \(read) where a count stands")
        }

        return read
    }

    func double() throws -> Double {
        guard case let .double(double) = written else {
            throw ObjectRefused("'\(part)' writes something other than a fraction where one stands")
        }

        return double
    }

    func text() throws -> String {
        guard case let .string(text) = written else {
            throw ObjectRefused("'\(part)' writes something other than a text where one stands")
        }

        return text
    }

    // Through the door every spelling from outside comes through. The bytes
    // an object was kept in are not the build's own: a spelling that is not
    // in normal form makes two names that read alike and compare apart, and
    // every order and lookup built on them goes quiet.
    func name() throws -> Name {
        let spelling = try text()

        do {
            return try Name(spelling)
        } catch let refused as NameRefused {
            throw ObjectRefused(refused.message)
        }
    }

    func flag() throws -> Bool {
        guard case let .bool(flag) = written else {
            throw ObjectRefused("'\(part)' writes something other than a yes or no where one stands")
        }

        return flag
    }

    func bytes() throws -> [UInt8] {
        guard case let .bytes(bytes) = written else {
            throw ObjectRefused("'\(part)' writes something other than bytes where they stand")
        }

        return bytes
    }

    // The declaration that wrote a closure, its kind before its name. What
    // lays one down is `ObjectWriter.declaration`.
    func declaration() throws -> Closure.Declaration {
        var fields = try Fields(written, of: part)
        let tag = try fields.tag()
        let declared = try fields.name()

        try fields.end()

        switch ObjectLayout.DeclarationTag(rawValue: tag) {
        case .procedure: return .procedure(declared)
        case .binding: return .binding(declared)
        case nil: throw ObjectRefused("'\(part)' writes a declaration of kind \(tag), which this reads none of")
        }
    }

    // Each element of a written list, read the same way. The reading of one
    // element is handed the element rather than reaching for it, so a list of
    // lists nests without either reading holding the other's place.
    func list<T>(_ read: (Value) throws -> T) throws -> [T] {
        guard case let .array(elements) = written else {
            throw ObjectRefused("'\(part)' writes something other than a list where one stands")
        }

        return try elements.map(read)
    }

    // A written list that stands in order, none of it twice. The writing puts
    // every list of names in order, so a reading that took any order would let
    // two writings say one object. Every list of names this reads comes
    // through this door, `gathered` or `led`.
    func ordered<T: Comparable>(_ read: (Value) throws -> T) throws -> [T] {
        try judged(try list(read))
    }

    // A written list of entries, each read as a key and what stands over it,
    // the keys in order and none twice, gathered into what a key answers.
    func gathered<Key: Hashable & Comparable, T>(_ read: (Value) throws -> (Key, T)) throws -> [Key: T] {
        let entries = try list(read)

        try judged(entries.map(\.0))

        return entries.reduce(into: [Key: T]()) { gathered, entry in
            gathered[entry.0] = entry.1
        }
    }

    // A written list of entries each led by a name, the names in order and none
    // twice, where what follows the name is read beside it and kept in order.
    func led<T>(_ read: (Value) throws -> (name: Name, value: T)) throws -> [(name: Name, value: T)] {
        let entries = try list(read)

        try judged(entries.map(\.name))

        return entries
    }

    // A writing that may hold nothing: a list of none or one, so a value that
    // is itself null is told from no value at all. What lays one down is
    // `ObjectWriter.maybe`.
    func maybe<T>(_ read: (Value) throws -> T) throws -> T? {
        let elements = try list { element in element }

        switch elements.count {
        case 0:
            return nil

        case 1:
            return try read(elements[0])

        default:
            throw ObjectRefused("'\(part)' writes \(elements.count) values where at most one stands")
        }
    }

    // MARK: - Private
    @discardableResult
    private func judged<T: Comparable>(_ written: [T]) throws -> [T] {
        guard written.ordered else {
            throw ObjectRefused("'\(part)' writes its names out of order, or one of them twice")
        }

        return written
    }
}

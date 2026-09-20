//
//  Fields.swift
//  Warp
//
//  Created by JSilver on 9/13/26.
//

import Foundation

// The fields of one written part, handed back in the order they were written.
//
// Its vocabulary is the value model's: one reading to each kind a value can
// be, so a part reaching for its next field never has to step around the
// cursor to get at one. Which of them an object happens to write today is
// not what decides that.
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
            throw ObjectRefused("'\(part)' is not written as an array")
        }

        self.of = part
        self.written = written
    }

    // MARK: - Internal
    mutating func next() throws -> Value {
        guard at < written.count else {
            throw ObjectRefused(
                "'\(of)' writes \(written.count) field(s) and one more was read"
            )
        }

        defer { at += 1 }

        return written[at]
    }

    mutating func integer() throws -> Int {
        try Fields.integer(try next(), of: of)
    }

    mutating func double() throws -> Double {
        try Fields.double(try next(), of: of)
    }

    mutating func count() throws -> Int {
        try Fields.count(try next(), of: of)
    }

    mutating func text() throws -> String {
        try Fields.text(try next(), of: of)
    }

    mutating func flag() throws -> Bool {
        try Fields.flag(try next(), of: of)
    }

    mutating func name() throws -> Name {
        try Fields.name(try next(), of: of)
    }

    mutating func bytes() throws -> [UInt8] {
        try Fields.bytes(try next(), of: of)
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
            throw ObjectRefused("'\(of)' writes \(written.count) fields and \(at) were read")
        }
    }
}

extension Fields {
    // What one written value is, said once. The cursor reads the next field
    // and a list reads each of its elements, and both ask these: one judgement
    // to a kind, so one damaged writing is answered the same way whichever way
    // it was reached.
    static func integer(_ value: Value, of part: String) throws -> Int {
        guard case let .int(integer) = value else {
            throw ObjectRefused("'\(part)' writes something other than a number where one stands")
        }

        return integer
    }

    // A number that counts or stands somewhere: a slot, a row, a position, a
    // size. Below zero is refused here because further in it is not a number
    // that is wrong but an array subscripted out of itself, and the sentence
    // there would be about something else.
    static func count(_ value: Value, of part: String) throws -> Int {
        let read = try integer(value, of: part)

        guard read >= 0 else {
            throw ObjectRefused("'\(part)' writes \(read) where a count stands")
        }

        return read
    }

    static func double(_ value: Value, of part: String) throws -> Double {
        guard case let .double(double) = value else {
            throw ObjectRefused("'\(part)' writes something other than a fraction where one stands")
        }

        return double
    }

    static func text(_ value: Value, of part: String) throws -> String {
        guard case let .string(text) = value else {
            throw ObjectRefused("'\(part)' writes something other than a text where one stands")
        }

        return text
    }

    // Through the door every spelling from outside comes through. An object
    // is this runtime's own writing, but the bytes it was kept in are not: a
    // spelling that is not in normal form makes two names that read alike and
    // compare apart, and every order and lookup built on them goes quiet.
    static func name(_ value: Value, of part: String) throws -> Name {
        let spelling = try text(value, of: part)

        do {
            return try Name(spelling)
        } catch let refused as NameRefused {
            throw ObjectRefused(refused.message)
        }
    }

    static func flag(_ value: Value, of part: String) throws -> Bool {
        guard case let .bool(flag) = value else {
            throw ObjectRefused("'\(part)' writes something other than a yes or no where one stands")
        }

        return flag
    }

    static func bytes(_ value: Value, of part: String) throws -> [UInt8] {
        guard case let .bytes(bytes) = value else {
            throw ObjectRefused("'\(part)' writes something other than bytes where they stand")
        }

        return bytes
    }

    // Each element of a written list, read the same way. The reading of one
    // element is handed the element rather than reaching for it, so a list of
    // lists nests without either reading holding the other's place.
    static func list<T>(_ value: Value, of part: String, _ read: (Value) throws -> T) throws -> [T] {
        guard case let .array(written) = value else {
            throw ObjectRefused("'\(part)' writes something other than a list where one stands")
        }

        return try written.map(read)
    }

    // A written list that stands in order, none of it twice. The writing puts
    // every list of names in order, so a reading that took any order would let
    // two writings say one object.
    //
    // Here rather than at each place that reads one, because a rule applied by
    // hand is a rule left out by hand: every list of names this reads comes
    // through this door or through the one below it.
    static func ordered<T: Comparable>(
        _ value: Value,
        of part: String,
        _ read: (Value) throws -> T
    ) throws -> [T] {
        try judged(try list(value, of: part, read), of: part)
    }

    // The same, where what a name stands over is read beside it and the whole
    // is gathered into what a name answers.
    static func gathered<Key: Hashable & Comparable, T>(
        _ entries: [(Key, T)],
        of part: String
    ) throws -> [Key: T] {
        try judged(entries.map(\.0), of: part)

        return entries.reduce(into: [Key: T]()) { gathered, entry in
            gathered[entry.0] = entry.1
        }
    }

    @discardableResult
    private static func judged<T: Comparable>(_ written: [T], of part: String) throws -> [T] {
        guard written.ordered else {
            throw ObjectRefused("'\(part)' writes its names out of order, or one of them twice")
        }

        return written
    }

    // A writing that may hold nothing: a list of none or one, so a value that
    // is itself null is told from no value at all. What lays one down is
    // `ObjectWriter.maybe`, and the two are one rule said from each side.
    static func maybe<T>(_ value: Value, of part: String, _ read: (Value) throws -> T) throws -> T? {
        let written = try list(value, of: part) { held in held }

        switch written.count {
        case 0:
            return nil

        case 1:
            return try read(written[0])

        default:
            throw ObjectRefused("'\(part)' writes \(written.count) values where at most one stands")
        }
    }
}

// The parts of an object, each under its key. A part is asked for by name
// and once, and a key nothing asked for is a writing of something else.
struct Keyed {
    // MARK: - Property
    private let of: String
    private let written: Value.Dictionary
    private var taken: Set<Name> = []

    // MARK: - Initializer
    init(_ value: Value, of part: String) throws {
        guard case let .dictionary(written) = value else {
            throw ObjectRefused("'\(part)' is not written as a record")
        }

        self.of = part
        self.written = written
    }

    // MARK: - Internal
    mutating func take(_ key: Name) throws -> Value {
        guard let held = written[key] else {
            throw ObjectRefused("'\(of)' writes no '\(key)'")
        }

        guard taken.insert(key).inserted else {
            throw ObjectRefused("'\(of)' had '\(key)' read twice")
        }

        return held
    }

    // That every key written has been read, for the reason a part's fields
    // are counted.
    func end() throws {
        guard let left = written.names.first(where: { name in !taken.contains(name) }) else { return }

        throw ObjectRefused("'\(of)' writes '\(left)', which this reads none of")
    }
}

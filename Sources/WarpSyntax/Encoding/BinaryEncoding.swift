//
//  BinaryEncoding.swift
//  WarpSyntax
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The encoding a document travels in, and what it promises:
//
// - **A whole number and a fraction are different bytes.** They are different
//   tags.
// - **The same document is the same bytes, both ways.** The writer writes
//   record keys in byte order and every number minimally, and the reader
//   refuses bytes the writer would not have written, so byte equality and
//   document equality are the same question, which is what makes a document
//   signable and cacheable.
// - **What cannot arrive is refused before it arrives.** Truncation, trailing
//   bytes, an unknown tag, a key out of order. Each is a refusal with a name,
//   not a value somebody guessed.
//
// The header carries the *encoding's* version, not the language's. What the
// program needs of its reader is said inside the document (`warp`, `imports`),
// because it is true in every encoding; this byte only says how the bytes
// themselves are laid out.
public struct BinaryEncoding {
    private enum Tag: UInt8 {
        case null = 0x00
        case `false` = 0x01
        case `true` = 0x02
        case int = 0x03
        case double = 0x04
        case string = 0x05
        case array = 0x06
        case record = 0x07
        case bytes = 0x08
        case namedRecord = 0x09
    }

    // A container being put back together: what it still expects, what it holds
    // so far, and (for a record) the key the next value belongs to and the last
    // key seen, so order is held against the one before. A sum rather
    // than two optionals, so "neither" and "both" are not states the code has
    // to promise never to reach.
    private enum Opened {
        case array(expecting: Int, held: [Value])
        case record(expecting: Int, held: [(name: Name, value: Value)], key: Name, previous: [UInt8], name: Name?)
    }

    // A place in the bytes.
    private struct Cursor {
        // MARK: - Property
        private let bytes: [UInt8]
        private var index = 0

        // What the document's claims may still spend, together. Every approved
        // claim charges what it would minimally cost to write, so the total
        // that can ever be set aside is bounded by the bytes that arrived.
        private var budget: Int

        var remaining: Int { bytes.count - index }
        var isDone: Bool { remaining == 0 }

        // MARK: - Initializer
        init(_ data: Data) {
            bytes = [UInt8](data)
            budget = bytes.count
        }

        // MARK: - Public
        mutating func claim(_ count: Int, costing cost: Int) -> Bool {
            let charged = count.multipliedReportingOverflow(by: cost)

            guard !charged.overflow, charged.partialValue <= budget else { return false }

            budget -= charged.partialValue

            return true
        }

        mutating func byte() -> UInt8? {
            guard index < bytes.count else { return nil }

            defer { index += 1 }

            return bytes[index]
        }

        // The next `count` bytes, or nil where fewer remain.
        mutating func take(_ count: Int) -> ArraySlice<UInt8>? {
            guard count <= remaining else { return nil }

            defer { index += count }

            return bytes[index..<index + count]
        }

        // MARK: - Private
    }

    // MARK: - Property
    // "WARP", and then how the bytes are laid out. The version moves when this
    // file's layout does, and for no other reason.
    public static let magic: [UInt8] = [0x57, 0x41, 0x52, 0x50]
    public static let format: UInt8 = 1

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func data(from value: Value) throws -> Data {
        var bytes = Data(Self.magic)

        bytes.append(Self.format)

        try write(value, into: &bytes)

        return bytes
    }

    public func value(from data: Data) throws -> Value {
        var reading = Cursor(data)

        guard let head = reading.take(Self.magic.count), head.elementsEqual(Self.magic) else {
            throw EncodingRefused("the bytes do not begin as a warp document begins")
        }

        guard let version = reading.byte() else {
            throw EncodingRefused("the bytes end before saying how they are laid out")
        }

        guard version == Self.format else {
            throw EncodingRefused(
                version > Self.format
                    ? "the document is laid out as format \(version), and this reader lays out \(Self.format)"
                    : "format \(version) never existed"
            )
        }

        let value = try read(from: &reading)

        guard reading.isDone else {
            throw EncodingRefused("the document ended and the bytes did not")
        }

        return value
    }

    // MARK: - Private
    private func write(_ value: Value, into bytes: inout Data) throws {
        var walk = ValueWalk(value)

        while let step = try walk.next() {
            switch step {
            case .null:
                bytes.append(Tag.null.rawValue)

            case let .bool(bool):
                bytes.append((bool ? Tag.true : Tag.false).rawValue)

            case let .int(int):
                bytes.append(Tag.int.rawValue)

                write(zigzagged(int), into: &bytes)

            case let .double(double):
                bytes.append(Tag.double.rawValue)

                withUnsafeBytes(of: double.bitPattern.bigEndian) { bytes.append(contentsOf: $0) }

            case let .string(string):
                bytes.append(Tag.string.rawValue)

                write(Array(string.utf8), into: &bytes)

            case let .bytes(raw):
                bytes.append(Tag.bytes.rawValue)

                write(raw, into: &bytes)

            case let .array(count):
                bytes.append(Tag.array.rawValue)

                write(UInt64(count), into: &bytes)

            // A record under a name is written under its own tag with the name
            // in front, so a reader that met the tag knows a name follows.
            case let .record(name, count):
                if let name {
                    bytes.append(Tag.namedRecord.rawValue)

                    write(Array(name.spelling.utf8), into: &bytes)
                } else {
                    bytes.append(Tag.record.rawValue)
                }

                write(UInt64(count), into: &bytes)

            case let .key(name):
                write(Array(name.spelling.utf8), into: &bytes)

            // A count said how much was held, so nothing marks the end.
            case .arrayClose, .recordClose:
                break
            }
        }
    }

    private func write(_ utf8: [UInt8], into bytes: inout Data) {
        write(UInt64(utf8.count), into: &bytes)

        bytes.append(contentsOf: utf8)
    }

    // Unsigned LEB128: seven bits a byte, low bits first, high bit says another
    // byte follows. The writer never writes a leading zero group, which is what
    // lets the reader treat one as a lie rather than a style.
    private func write(_ unsigned: UInt64, into bytes: inout Data) {
        var rest = unsigned

        repeat {
            let low = UInt8(rest & 0x7f)

            rest >>= 7

            bytes.append(rest == 0 ? low : low | 0x80)
        } while rest != 0
    }

    // One pass over the bytes with an explicit stack, because the depth of a
    // document must never be the depth of the host's call stack. The bytes are
    // the arriving side's, and the stack is ours. The limit that remains is the
    // format's own, and it bounds memory rather than saving the process.
    private func read(from reading: inout Cursor) throws -> Value {
        var opened: [Opened] = []

        while true {
            guard let raw = reading.byte() else {
                throw EncodingRefused("the bytes end where a value should begin")
            }

            guard let tag = Tag(rawValue: raw) else {
                throw EncodingRefused("nothing in this format begins with \(raw)")
            }

            var settled: Value?

            switch tag {
            case .null:
                settled = .null

            case .false:
                settled = .bool(false)

            case .true:
                settled = .bool(true)

            case .int:
                settled = .int(unzigzagged(try unsigned(from: &reading)))

            case .double:
                guard let raw = reading.take(8) else {
                    throw EncodingRefused("the bytes end inside a fraction")
                }

                let bits = raw.reduce(UInt64(0)) { held, byte in held << 8 | UInt64(byte) }
                let double = Double(bitPattern: bits)

                guard double.isFinite else {
                    throw EncodingRefused("a document has no way to carry \(double)")
                }

                settled = .double(double)

            case .string:
                settled = .string(try text(from: &reading))

            case .bytes:
                let count = try length(from: &reading, of: "bytes", costing: 1)
                guard let raw = reading.take(count) else {
                    throw EncodingRefused("the bytes end inside bytes")
                }

                settled = .bytes(Array(raw))

            case .array:
                try opening(opened)

                let count = try length(from: &reading, of: "an array", costing: 1)

                if count == 0 {
                    settled = .array([])
                } else {
                    var held: [Value] = []

                    held.reserveCapacity(count)

                    opened.append(.array(expecting: count, held: held))
                }

            case .record, .namedRecord:
                try opening(opened)

                let name = try tag == .namedRecord ? name(from: &reading) : nil
                let count = try length(from: &reading, of: "a record", costing: 2)

                if count == 0 {
                    settled = try record([], named: name)
                } else {
                    var held: [(name: Name, value: Value)] = []

                    held.reserveCapacity(count)

                    let (key, raw) = try field(from: &reading, after: nil)

                    opened.append(.record(expecting: count, held: held, key: key, previous: raw, name: name))
                }
            }

            // Hand what settled to whatever is waiting for it, closing every
            // container it completes on the way up.
            while let value = settled {
                guard let open = opened.popLast() else { return value }

                settled = nil

                switch open {
                case let .array(expecting, held):
                    var held = held
                    held.append(value)

                    if expecting == 1 {
                        settled = .array(held)
                    } else {
                        opened.append(.array(expecting: expecting - 1, held: held))
                    }

                case let .record(expecting, held, key, previous, name):
                    var held = held
                    // Ordered and unique because the keys arrived strictly
                    // ascending and in NFC: byte order refuses a byte-equal
                    // duplicate, and NFC leaves one name one byte spelling to
                    // be equal in. The record's sort meets them in order.
                    held.append((name: key, value: value))

                    if expecting == 1 {
                        settled = try record(held, named: name)
                    } else {
                        let (next, raw) = try field(from: &reading, after: previous)

                        opened.append(
                            .record(expecting: expecting - 1, held: held, key: next, previous: raw, name: name)
                        )
                    }
                }
            }
        }
    }

    // The next field a record waits for. Strictly ascending, which refuses a
    // duplicate and a shuffle with the same sentence: these are bytes the
    // writer would not write. NFC, so that byte order is an order on names. A
    // name with a second byte spelling would sort to a second place.
    private func field(
        from reading: inout Cursor,
        after previous: [UInt8]?
    ) throws -> (Name, [UInt8]) {
        let key = try text(from: &reading)
        let raw = Array(key.utf8)

        if let previous, !previous.lexicographicallyPrecedes(raw) {
            throw EncodingRefused("the record's keys are not written in order")
        }

        do {
            return (try Name(key), raw)
        } catch let refusal as NameRefused {
            throw EncodingRefused(refusal.message)
        }
    }

    // A record of these fields under that name, or the refusal the value
    // model makes of one said in this reading's words.
    private func record(_ held: [(name: Name, value: Value)], named name: Name?) throws -> Value {
        do {
            return try .holding(held, named: name)
        } catch let refusal as ValueRefused {
            throw EncodingRefused(refusal.message)
        }
    }

    // A record's own name, as the bytes wrote it.
    private func name(from reading: inout Cursor) throws -> Name {
        let spelling = try text(from: &reading)

        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw EncodingRefused(refusal.message)
        }
    }

    private func text(from reading: inout Cursor) throws -> String {
        let count = try length(from: &reading, of: "text", costing: 1)

        guard let bytes = reading.take(count) else {
            throw EncodingRefused("the bytes end inside text")
        }

        guard let string = String(utf8: bytes) else {
            throw EncodingRefused("the text is not UTF-8")
        }

        return string
    }

    // A claimed length, charged against the one budget all claims share: the
    // bytes of the document itself. Each claimed thing costs at least `cost`
    // bytes to actually write, so however deeply the claimants nest, their
    // claims cannot sum past the document.
    private func length(
        from reading: inout Cursor,
        of what: String,
        costing cost: Int
    ) throws -> Int {
        let claimed = try unsigned(from: &reading)

        guard claimed <= UInt64(Int.max), reading.claim(Int(claimed), costing: cost) else {
            throw EncodingRefused("\(what) claims more than the document holds")
        }

        return Int(claimed)
    }

    private func unsigned(from reading: inout Cursor) throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var last: UInt8 = 0

        while true {
            guard let byte = reading.byte() else {
                throw EncodingRefused("the bytes end inside a number")
            }

            guard shift < 64, shift < 63 || byte <= 0x01 else {
                throw EncodingRefused("the number does not fit in 64 bits")
            }

            value |= UInt64(byte & 0x7f) << shift
            last = byte

            guard byte & 0x80 != 0 else { break }

            shift += 7
        }

        // A trailing zero group is a longer spelling of the same number, and a
        // canonical wire has one spelling.
        guard shift == 0 || last != 0 else {
            throw EncodingRefused("the number is written longer than it is")
        }

        return value
    }

    // ZigZag: small magnitudes of either sign become small unsigned numbers, so
    // the varint stays short for the numbers programs actually hold.
    private func zigzagged(_ int: Int) -> UInt64 {
        UInt64(bitPattern: Int64(int) << 1 ^ (Int64(int) >> 63))
    }

    // `unsigned(from:)` already held the 64-bit line, so the exact conversion
    // to `Int` cannot miss. A truncating one here would say otherwise.
    private func unzigzagged(_ unsigned: UInt64) -> Int {
        Int(Int64(bitPattern: unsigned >> 1 ^ (0 &- (unsigned & 1))))
    }

    // The same count the writer keeps: containers open on the path, and the
    // one about to open is one more of them.
    private func opening(_ opened: [Opened]) throws {
        guard opened.count < Value.nestingBound else {
            throw EncodingRefused("the document nests deeper than a reader must follow")
        }
    }
}

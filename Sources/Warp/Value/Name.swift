//
//  Name.swift
//  Warp
//
//  Created by JSilver on 8/21/26.
//

import Foundation

// What being a name costs: one spelling. Unicode writes `é` two ways (one
// scalar, or `e` plus a combining mark) and the two look identical while
// comparing as different bytes. A name is normal form C or it is refused, so a
// declaration and a reference can only meet by being the same bytes.
//
// One door rather than one check per checker, because the rule is the
// language's and not any checker's own: the encodings hold record keys to it,
// and validation holds every name a program writes as a value to it, and both
// have to mean the same thing by "normal". A `Name` in hand has been through
// it, and so has been through the other half of the rule: a name is written,
// and nothing written is no name.
public struct Name: Sendable, Hashable, Comparable {
    // MARK: - Property
    public let spelling: String

    // The spelling's bytes folded to a word, worked out where the name is
    // written. Every table a link keeps is keyed by a name, so the bytes would
    // otherwise be walked again at each probe.
    private let digest: Int

    // The words the text encoding reads bare as values, and what each one
    // is. A name is never one of them: a bare `true` in front of a record
    // would otherwise be read as the record's name, and the value would be
    // gone.
    public static let scalarWords: [String: Value] = [
        "null": .null,
        "true": .bool(true),
        "false": .bool(false)
    ]

    // An identifier as every encoding writes one bare: ASCII on purpose, since
    // "is this a letter" for the rest of Unicode is answered by whatever
    // tables a host language shipped, and a canonical layout cannot depend
    // on whose tables were newer. A name outside this set is quoted where a
    // key stands, and is no type's name. ASCII is its own normal form.
    public var isIdentifier: Bool {
        Name.isIdentifier(spelling.utf8[...])
    }

    // Whether this is spelled the way a declaration, a notation's prefix and a
    // record's name all spell one: identifiers joined by dots, and not a
    // scalar's word.
    public var isDeclarable: Bool {
        let bytes = spelling.utf8

        guard Name.scalarWords[spelling] == nil else { return false }

        var end: String.UTF8View.Index? = bytes.endIndex

        while let at = end {
            let (segment, rest) = Name.segment(of: bytes, endingAt: at)

            guard Name.isIdentifier(bytes[segment]) else { return false }

            end = rest
        }

        return true
    }

    // This name without whatever qualified it: `std.logic.equal` is `equal`.
    // A dotted name is where a declaration sits, and the last segment is what
    // it is called.
    //
    // Read as bytes, the way every other reading of a name is. A dot is a dot
    // wherever it stands, including where the scalar after it combines with it
    // into one character.
    public var unqualified: Name {
        let bytes = spelling.utf8
        var end = bytes.endIndex

        while true {
            let (segment, rest) = Name.segment(of: bytes, endingAt: end)

            guard segment.isEmpty else {
                guard segment.lowerBound > bytes.startIndex || segment.upperBound < bytes.endIndex else {
                    return self
                }

                // Cut in the view it was scanned in. A dot is a starter and
                // combines with nothing, so a segment of a spelling in normal
                // form is normal.
                return Name(normal: String(decoding: bytes[segment], as: UTF8.self))
            }

            guard let rest else { return self }

            end = rest
        }
    }

    // MARK: - Initializer
    public init(_ spelling: String) throws {
        // A name with nothing in it is no name: it is what a declaration is
        // called and what a reference writes, and neither is written by
        // writing nothing.
        guard !spelling.isEmpty else {
            throw NameRefused("a name is written, and this one is empty")
        }

        // ASCII combines with nothing, so a spelling made of it is normal and
        // the general form has nothing to find. Names are written by hand and
        // are nearly all ASCII, and the general form composes a whole second
        // string to answer.
        guard spelling.utf8.contains(where: { byte in byte >= 0x80 }) else {
            self.spelling = spelling
            self.digest = Name.digested(spelling)

            return
        }

        guard spelling.precomposedStringWithCanonicalMapping.utf8.elementsEqual(spelling.utf8) else {
            throw NameRefused("the name '\(spelling)' is not in normal form C")
        }

        self.spelling = spelling
        self.digest = Name.digested(spelling)
    }

    // A spelling this package built out of parts that are already normal. A
    // segment of a name, or ASCII written in this source. The door above is the
    // one every spelling from outside comes through, and this one is not
    // reachable from outside the package.
    public init(normal spelling: String) {
        self.spelling = spelling
        self.digest = Name.digested(spelling)
    }

    // MARK: - Public
    // Ordered as bytes. Every place that puts names in order reads this: a
    // record's entries, a signature's parameter positions, a canonical
    // writer's keys. Swift's `<` orders under canonical equivalence and would
    // put two spellings of one name in one place.
    public static func < (lhs: Name, rhs: Name) -> Bool {
        Name.compared(lhs.spelling, rhs.spelling) < 0
    }

    // Two names are one name by their bytes, for the same reason.
    public static func == (lhs: Name, rhs: Name) -> Bool {
        lhs.digest == rhs.digest && Name.compared(lhs.spelling, rhs.spelling) == 0
    }

    // Hashed over what the bytes folded to, which is what `==` reads before
    // it reads the bytes.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(digest)
    }

    // MARK: - Private
    private static let dot = UInt8(ascii: ".")

    // The segment of a dotted spelling ending where the caller says, beside
    // where the one before it ends. Nothing where that segment is the first,
    // so a caller steps from the end until it stops.
    //
    // Every reading of a name reads its bytes, and where a name breaks into
    // segments is one of those readings: a dot is a dot wherever it stands,
    // including where the scalar after it combines with it into one character.
    // A dot at either end stands for an empty segment, which is no identifier
    // and no name.
    private static func segment(
        of bytes: String.UTF8View,
        endingAt end: String.UTF8View.Index
    ) -> (segment: Range<String.UTF8View.Index>, rest: String.UTF8View.Index?) {
        var start = end

        while start > bytes.startIndex, bytes[bytes.index(before: start)] != dot {
            start = bytes.index(before: start)
        }

        guard start > bytes.startIndex else { return (start ..< end, nil) }

        return (start ..< end, bytes.index(before: start))
    }

    // Fowler-Noll-Vo, folded over the bytes once. What it is for is telling
    // two spellings apart before they are compared, so what it needs is to
    // spread and to be cheap to work out.
    private static func digested(_ spelling: String) -> Int {
        withBytes(spelling) { bytes in
            var folded: UInt64 = 0xcbf2_9ce4_8422_2325

            for byte in bytes {
                folded = (folded ^ UInt64(byte)) &* 0x100_0000_01b3
            }

            return Int(bitPattern: UInt(folded))
        }
    }

    // Two spellings ordered by their bytes: negative, zero or positive the
    // way `memcmp` answers, with the shorter first where one is a prefix of
    // the other. Both orders a name is read in come through here, over the
    // whole buffer at once rather than a byte at a time.
    private static func compared(_ left: String, _ right: String) -> Int {
        withBytes(left) { first in
            withBytes(right) { second in
                let shared = Swift.min(first.count, second.count)

                guard let head = first.baseAddress, let other = second.baseAddress, shared > 0 else {
                    return first.count - second.count
                }

                let ordered = memcmp(head, other, shared)

                return ordered != 0 ? Int(ordered) : first.count - second.count
            }
        }
    }

    // A spelling as the bytes both readings of a name run over. Held as
    // written wherever it is already contiguous, which every spelling this
    // package builds is; a spelling that arrived as something else is made
    // contiguous on a copy, which is the one case that costs anything.
    private static func withBytes<T>(_ spelling: String, _ read: (UnsafeRawBufferPointer) -> T) -> T {
        let held = spelling.utf8.withContiguousStorageIfAvailable { bytes in
            read(UnsafeRawBufferPointer(bytes))
        }

        if let held { return held }

        var spelling = spelling

        return spelling.withUTF8 { bytes in read(UnsafeRawBufferPointer(bytes)) }
    }

    private static func isIdentifier(_ bytes: String.UTF8View.SubSequence) -> Bool {
        func letter(_ byte: UInt8) -> Bool {
            (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) || byte == 0x5F
        }

        func digit(_ byte: UInt8) -> Bool {
            byte >= 0x30 && byte <= 0x39
        }

        guard let first = bytes.first, letter(first) else { return false }

        return bytes.allSatisfy { byte in letter(byte) || digit(byte) }
    }
}

// A name written in Swift. The spelling is source an author typed, so a
// spelling that is not a name is a mistake being made where it can be read, and
// there is nothing to answer with. The same reaction a duplicate key in a value
// literal gets. A spelling that arrived from anywhere else goes through the
// throwing door.
extension Name: ExpressibleByStringLiteral {
    public init(stringLiteral spelling: String) {
        do {
            try self.init(spelling)
        } catch {
            preconditionFailure("'\(spelling)' cannot be a name: \(error)")
        }
    }
}

extension Name: CustomStringConvertible {
    public var description: String { spelling }
}

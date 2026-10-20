//
//  DatumReader.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A text as the elements it is: atoms, and lists in parentheses. A token's
// first characters say its kind. A digit, or `-` or `+` before a digit, begins
// a number; `x"` begins bytes; `"` begins text; a backtick begins a name; and
// anything else is `null`, `true`, `false` or a name.
//
// One value, one spelling. A number, text and bytes are taken only in the
// spelling the writer gives them, since `1.50` for `1.5` is a second text for
// one value rather than a second layout of one text. A name in backticks is
// the same name as one written bare.
struct DatumReader {
    // MARK: - Property
    // How deep lists may nest: as deep as a tree within the bound writes. A
    // document's first level is written in no list and each level after it
    // in two at most, a dictionary and its entry or a procedure type and its
    // parameters, and one level on a way down holds a third, the key a value
    // stands under: 2 × 128 − 1. A case writes the documents beside its
    // program two lists further down.
    static let nestingBound = 2 * Value.nestingBound + 1

    static let whiteSpace = Set(" \n\r\t".unicodeScalars)

    // What may stand right after a token, besides the text ending.
    private static let delimiters = whiteSpace.union("()".unicodeScalars)

    // What ends a bare token.
    private static let enders = delimiters.union(["\"", "`"])

    // MARK: - Initializer
    // MARK: - Public
    func data(of scalars: [Unicode.Scalar]) throws -> [Datum] {
        var reading = scalars[...]
        var top: [Datum] = []
        var opened: [(held: [Datum], at: Int)] = []

        while let character = reading.first {
            let start = reading.startIndex
            let read: Datum

            switch character {
            case _ where Self.whiteSpace.contains(character):
                reading.removeFirst()

                continue

            case "(":
                guard opened.count < Self.nestingBound else {
                    throw Unplaced("the text nests deeper than a reader must follow", at: start)
                }

                reading.removeFirst()
                opened.append(([], start))

                continue

            case ")":
                guard let (held, at) = opened.popLast() else {
                    throw Unplaced("nothing here is a list to close", at: start)
                }

                reading.removeFirst()
                read = Datum(.list(held), at: at)

            case "\"":
                reading.removeFirst()
                read = Datum(.text(try quoted(from: &reading, closing: "\"")), at: start)

            case "`":
                reading.removeFirst()

                let name = try quoted(from: &reading, closing: "`")

                guard !name.isEmpty else {
                    throw Unplaced("a name in backticks holds at least one character", at: start)
                }

                read = Datum(.name(name), at: start)

            default:
                var bare = ""

                while let character = reading.first, !Self.enders.contains(character) {
                    bare.unicodeScalars.append(character)
                    reading.removeFirst()
                }

                if bare == "x", reading.first == "\"" {
                    reading.removeFirst()
                    read = Datum(.bytes(try hexed(from: &reading)), at: start)
                } else {
                    read = Datum(try atom(bare, at: start), at: start)
                }
            }

            try separated(reading)

            if opened.isEmpty {
                top.append(read)
            } else {
                opened[opened.count - 1].held.append(read)
            }
        }

        if let (_, at) = opened.last {
            throw Unplaced("a list opened here is never closed", at: at)
        }

        return top
    }

    // MARK: - Private
    // What a bare token is: a scalar, or a name.
    private func atom(_ bare: String, at offset: Int) throws -> Datum.Form {
        switch bare {
        case "null": return .null
        case "true": return .bool(true)
        case "false": return .bool(false)
        default: break
        }

        let scalars = Array(bare.unicodeScalars)
        let digits: ClosedRange<Unicode.Scalar> = "0"..."9"

        if digits.contains(scalars[0]) || ["-", "+"].contains(scalars[0]) && scalars.count > 1 && digits.contains(scalars[1]) {
            return try number(bare, at: offset)
        }

        if let control = scalars.first(where: { scalar in scalar.value < 0x20 }) {
            throw Unplaced("a name holds \(shown(control)) written raw, and is written in backticks", at: offset)
        }

        return .name(bare)
    }

    // A number in its one writing, whole or a fraction by grammar: a point or
    // an exponent makes a fraction.
    private func number(_ bare: String, at offset: Int) throws -> Datum.Form {
        guard bare.contains(where: { character in ".eE".contains(character) }) else {
            switch IntSpelling(bare) {
            case let .int(int):
                return .int(int)

            case .notOneSpelling:
                throw Unplaced("\(bare) is not a whole number's one writing", at: offset)

            case .overflow:
                throw Unplaced("\(bare) is a whole number past what an Int holds", at: offset)
            }
        }

        guard let double = Double(spelling: bare) else {
            throw Unplaced("\(bare) is not a fraction's one writing", at: offset)
        }

        return .double(double)
    }

    // A delimiter follows a token, or nothing does.
    private func separated(_ reading: ArraySlice<Unicode.Scalar>) throws {
        guard let next = reading.first, !Self.delimiters.contains(next) else { return }

        throw Unplaced(
            "a token runs straight into \(shown(next)), and white space or a parenthesis separates the two",
            at: reading.startIndex
        )
    }

    // Text up to its closing quote, or a name up to its closing backtick. A
    // name escapes its backtick and takes a quote as itself.
    private func quoted(
        from reading: inout ArraySlice<Unicode.Scalar>,
        closing: Unicode.Scalar
    ) throws -> String {
        var string = ""

        while let character = reading.first {
            let at = reading.startIndex

            reading.removeFirst()

            switch character {
            case closing:
                return string

            case "\\":
                string.unicodeScalars.append(try escaped(from: &reading, closing: closing))

            default:
                guard character.value >= 0x20 else {
                    throw Unplaced("\(shown(character)) is written raw, and is escaped", at: at)
                }

                string.unicodeScalars.append(character)
            }
        }

        throw Unplaced(
            closing == "`" ? "the text ends inside a name" : "the text ends inside text",
            at: reading.startIndex
        )
    }

    private func escaped(
        from reading: inout ArraySlice<Unicode.Scalar>,
        closing: Unicode.Scalar
    ) throws -> Unicode.Scalar {
        guard let character = reading.first else {
            throw Unplaced("the text ends inside an escape", at: reading.startIndex)
        }

        let at = reading.startIndex

        reading.removeFirst()

        switch character {
        case closing: return closing
        case "\\": return "\\"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"

        case "u":
            // The writer escapes a control character this way and nothing
            // else, so an escape for a character written raw, or one with a
            // shorter escape, is a second text for one value.
            let value = try hexadecimal(from: &reading)

            guard value < 0x20 else {
                throw Unplaced("the escape spells a character that is written as itself", at: at)
            }

            guard let scalar = Unicode.Scalar(value), !["\n", "\r", "\t"].contains(scalar) else {
                throw Unplaced("the escape spells a character that has a shorter escape", at: at)
            }

            return scalar

        default:
            throw Unplaced("nothing is written \\\(shown(character))", at: at)
        }
    }

    // The body of `x"…"`: lowercase hex, two digits a byte, nothing else.
    private func hexed(from reading: inout ArraySlice<Unicode.Scalar>) throws -> [UInt8] {
        var digits: [UInt8] = []

        while let character = reading.first, character != "\"" {
            let at = reading.startIndex

            reading.removeFirst()

            switch character {
            case "0"..."9":
                digits.append(UInt8(character.value - 0x30))

            case "a"..."f":
                digits.append(UInt8(character.value - 0x61 + 10))

            default:
                throw Unplaced("bytes are written as lowercase hex", at: at)
            }
        }

        guard reading.first == "\"" else {
            throw Unplaced("the text ends inside bytes", at: reading.startIndex)
        }

        reading.removeFirst()

        guard digits.count % 2 == 0 else {
            throw Unplaced("bytes are written two digits each", at: reading.startIndex)
        }

        return stride(from: 0, to: digits.count, by: 2)
            .map { index in digits[index] << 4 | digits[index + 1] }
    }

    private func hexadecimal(from reading: inout ArraySlice<Unicode.Scalar>) throws -> UInt32 {
        var value: UInt32 = 0

        for _ in 0..<4 {
            guard
                let character = reading.first,
                character.isASCII,
                !("A"..."F").contains(character),
                let digit = UInt32(String(character), radix: 16)
            else {
                throw Unplaced("the escape is not four lowercase hexadecimal digits", at: reading.startIndex)
            }

            value = value << 4 | digit

            reading.removeFirst()
        }

        return value
    }

    // A character as a person reads it in a refusal: itself, or a control
    // character the way the writer spells one.
    private func shown(_ scalar: Unicode.Scalar) -> String {
        scalar.value < 0x20 ? String(format: "\\u%04x", scalar.value) : String(scalar)
    }
}

//
//  TextEncoding.swift
//  WarpSyntax
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The encoding a document is read in. By a person. The binary is what a
// document travels as; this is the same document laid out for eyes. A dump, not
// a syntax: machines write it, people read it, and composing by hand is a front
// end's job in a front end's notation, which is why there are no comments to
// lose on the way back.
//
// A whole number and a fraction are different tokens here by grammar. `1` is
// whole and `1.0` is a fraction. And there is nothing else: no commas to
// forget, no colons; a record is `{ key value … }` and an array is `[ value …
// ]`.
//
// One value, one spelling. The writer lays a text out one way (sorted keys,
// two spaces an indent), so a text that has been through it is the same bytes
// everywhere. Layout is free on the way in: the reader takes keys in any order
// and any whitespace between tokens, and a key written bare or quoted is one
// key either way. What it does not take is a second
// spelling of a value, `1.50` for `1.5` or `\u0041` for `A`, since those are
// two texts for one value rather than two layouts of one text.
public enum TextEncoding {
    // MARK: - Property
    // The first tokens of every document: which encoding, laid out how. The
    // version moves when this file's grammar does, and for no other reason.
    // What the *program* needs of its reader is said inside the document.
    public static let name = "warpt"
    public static let format = 1

    // MARK: - Public
    public static func text(from value: Value) throws -> String {
        var written = "\(name) \(format)\n"

        try write(value, at: 0, into: &written, within: Envelope.nesting)

        written += "\n"

        return written
    }

    public static func data(from value: Value) throws -> Data {
        Data(try text(from: value).utf8)
    }

    public static func value(from data: Data) throws -> Value {
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw refused("the text is not UTF-8")
        }

        return try value(from: text)
    }

    public static func value(from text: String) throws -> Value {
        // The first line is read on its own and before the rest: whether
        // this is a document at all, and laid out how, is answered before
        // anything in it is, so a later format is refused as that and not
        // as whatever its body says that this reader has no name for.
        let scalars = text.unicodeScalars
        let end = scalars.firstIndex(of: "\n") ?? scalars.endIndex
        let header = String(scalars[..<end])

        guard header.hasPrefix(name) else {
            throw refused("the text does not begin as a warp document begins")
        }

        var head = try tokenized(header)[...]

        guard case .bare(name) = head.popFirst(), case let .bare(version) = head.popFirst(), head.isEmpty else {
            throw refused("the text does not say how it is laid out")
        }

        // The one spelling of a whole number, here as in a value: `warpt 01`
        // would be a second text for a document the reader already has one for.
        let claimed: Int

        switch Int.reading(spelling: version) {
        case let .int(read):
            claimed = read

        case .notOneSpelling:
            throw refused("\(version) is not a format's one writing")

        case .overflow:
            throw refused("\(version) is a format past what an int holds")
        }

        guard claimed == format else {
            throw refused(
                claimed > format
                    ? "the document is laid out as format \(claimed), and this reader lays out \(format)"
                    : "format \(claimed) never existed"
            )
        }

        var tokens = try tokenized(String(scalars[end...]))[...]
        let value = try read(from: &tokens)

        guard tokens.isEmpty else {
            throw refused("the document ended and the text did not")
        }

        return value
    }

    // MARK: - Private
    private enum Token: Equatable {
        case arrayOpen
        case arrayClose
        case recordOpen
        case recordClose
        case string(String)
        case bytes([UInt8])
        case bare(String)
    }

    // A container being put back together, exactly as in the binary reader. One
    // reader per encoding would be two chances to differ. A sum rather
    // than two optionals, so "neither" and "both" are not states the code has
    // to promise never to reach; a record with no key is one waiting for its
    // next field name.
    private enum Opened {
        case array([Value])
        case record(held: [Name: Value], key: Name?, name: Name?)
    }

    private static func tokenized(_ text: String) throws -> [Token] {
        var tokens: [Token] = []
        var reading = Array(text.unicodeScalars)[...]

        while let character = reading.first {
            switch character {
            case " ", "\n", "\r", "\t":
                reading.removeFirst()

            case "[":
                reading.removeFirst()
                tokens.append(.arrayOpen)

            case "]":
                reading.removeFirst()
                tokens.append(.arrayClose)

            case "{":
                reading.removeFirst()
                tokens.append(.recordOpen)

            case "}":
                reading.removeFirst()
                tokens.append(.recordClose)

            case "\"":
                reading.removeFirst()
                tokens.append(.string(try quoted(from: &reading)))
                try separated(reading)

            default:
                var bare = ""

                while let character = reading.first, !Self.enders.contains(character) {
                    bare.unicodeScalars.append(character)
                    reading.removeFirst()
                }

                // `x` straight into a quote is the bytes spelling. One token,
                // because the quote is a delimiter and not text. Any other
                // bare token ends at whitespace or a bracket.
                if bare == "x", reading.first == "\"" {
                    reading.removeFirst()
                    tokens.append(.bytes(try hexed(from: &reading)))
                } else {
                    tokens.append(.bare(bare))
                }

                try separated(reading)
            }
        }

        return tokens
    }

    // What may stand between two tokens, besides the text ending.
    private static let delimiters = Set(" \n\r\t[]{}".unicodeScalars)

    // What ends a bare token: a delimiter, or a quote.
    private static let enders = delimiters.union(["\""])

    // A character as a person reads it in a refusal: itself, or a control
    // character the way the writer spells one.
    private static func shown(_ scalar: Unicode.Scalar) -> String {
        scalar.value < 0x20 ? String(format: "\\u%04x", scalar.value) : String(scalar)
    }

    // A delimiter follows a token, or nothing does.
    private static func separated(_ reading: ArraySlice<Unicode.Scalar>) throws {
        guard let next = reading.first, !delimiters.contains(next) else { return }

        throw refused("a token runs straight into \(shown(next)), and whitespace or a bracket separates the two")
    }

    private static func quoted(from reading: inout ArraySlice<Unicode.Scalar>) throws -> String {
        var string = ""

        while let character = reading.first {
            reading.removeFirst()

            switch character {
            case "\"":
                return string

            case "\\":
                string.unicodeScalars.append(try escaped(from: &reading))

            default:
                guard character.value >= 0x20 else {
                    throw refused("text holds a control character written raw")
                }

                string.unicodeScalars.append(character)
            }
        }

        throw refused("the text ends inside text")
    }

    private static func escaped(from reading: inout ArraySlice<Unicode.Scalar>) throws -> Unicode.Scalar {
        guard let character = reading.first else {
            throw refused("the text ends inside an escape")
        }

        reading.removeFirst()

        switch character {
        case "\"": return "\""
        case "\\": return "\\"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"

        case "u":
            // A value has one spelling. The writer escapes a control
            // character this way and nothing else, so an escape for a character
            // that is written raw, or that has a shorter escape, is a second
            // text for one value. That rules out surrogate pairs as well: a
            // character past the basic plane is written as itself.
            let value = try hexadecimal(from: &reading)

            guard value < 0x20 else {
                throw refused("the escape spells a character that is written as itself")
            }

            guard let scalar = Unicode.Scalar(value), !["\n", "\r", "\t"].contains(scalar) else {
                throw refused("the escape spells a character that has a shorter escape")
            }

            return scalar

        default:
            throw refused("nothing is written \\\(shown(character))")
        }
    }

    // The body of `x"…"`: lowercase hex, two digits a byte, nothing else.
    // Uppercase or odd length would be a second spelling for the same bytes.
    private static func hexed(from reading: inout ArraySlice<Unicode.Scalar>) throws -> [UInt8] {
        var digits: [UInt8] = []

        while let character = reading.first, character != "\"" {
            reading.removeFirst()

            switch character {
            case "0"..."9":
                digits.append(UInt8(character.value - 0x30))

            case "a"..."f":
                digits.append(UInt8(character.value - 0x61 + 10))

            default:
                throw refused("bytes are written as lowercase hex")
            }
        }

        guard reading.first == "\"" else {
            throw refused("the text ends inside bytes")
        }

        reading.removeFirst()

        guard digits.count % 2 == 0 else {
            throw refused("bytes are written two digits each")
        }

        return stride(from: 0, to: digits.count, by: 2)
            .map { index in digits[index] << 4 | digits[index + 1] }
    }

    private static func hexadecimal(from reading: inout ArraySlice<Unicode.Scalar>) throws -> UInt32 {
        var value: UInt32 = 0

        for _ in 0..<4 {
            guard let character = reading.first,
                  character.isASCII,
                  !("A"..."F").contains(character),
                  let digit = UInt32(String(character), radix: 16) else {
                throw refused("the escape is not four lowercase hexadecimal digits")
            }

            value = value << 4 | digit

            reading.removeFirst()
        }

        return value
    }

    private static func read(from tokens: inout ArraySlice<Token>) throws -> Value {
        var opened: [Opened] = []

        while true {
            guard let token = tokens.popFirst() else {
                throw refused("the text ends where a value should begin")
            }

            var settled: Value?

            // A record waits for a key where everything else waits for a value,
            // and a closing brace is only honest in that position
            if case .record(let held, .none, let name) = opened.last {
                switch token {
                case .recordClose:
                    opened.removeLast()

                    settled = try .holding(held.map { field in (name: field.key, value: field.value) }, named: name)

                case let .bare(spelling):
                    let key = try key(spelling)

                    guard key.isIdentifier else {
                        throw refused("a record writes a field name here")
                    }

                    try expect(key, in: held)

                    opened[opened.count - 1] = .record(held: held, key: key, name: name)

                    continue

                case let .string(spelling):
                    let key = try key(spelling)

                    try expect(key, in: held)

                    opened[opened.count - 1] = .record(held: held, key: key, name: name)

                    continue

                default:
                    throw refused("a record writes a field name here")
                }
            } else {
                switch token {
                case .arrayOpen:
                    try opening(opened)
                    opened.append(.array([]))

                    continue

                case .recordOpen:
                    try opening(opened)
                    opened.append(.record(held: [:], key: nil, name: nil))

                    continue

                case .arrayClose:
                    guard case let .array(held) = opened.last else {
                        throw refused("nothing here is an array to close")
                    }

                    opened.removeLast()

                    settled = .array(held)

                case .recordClose:
                    throw refused("nothing here is a record to close")

                case let .string(string):
                    settled = .string(string)

                case let .bytes(bytes):
                    settled = .bytes(bytes)

                // A bare token in front of a record is the record's name: the
                // declared type the value settled to.
                case let .bare(bare):
                    if tokens.first == .recordOpen, let name = try? Name(bare), name.isDeclarable {
                        try opening(opened)
                        tokens.removeFirst()
                        opened.append(.record(held: [:], key: nil, name: name))

                        continue
                    }

                    settled = try scalar(from: bare)
                }
            }

            // Closing is a token here, not a count, so a settled value climbs
            // one step at most: into whatever holds it, or out
            if let value = settled {
                guard let open = opened.popLast() else { return value }

                switch open {
                case .array(var held):
                    held.append(value)

                    opened.append(.array(held))

                case .record(var held, let key?, let name):
                    // Unique: the key was refused where it was read if the
                    // record already held it.
                    held[key] = value

                    opened.append(.record(held: held, key: nil, name: name))

                // A record with no key is waiting for a field name, and every
                // token it could meet in that state was answered above
                case .record(_, .none, _):
                    throw refused("a record writes a field name here")
                }
            }
        }
    }

    // What a bare token names. Everything unquoted is one of five things, and a
    // number is whole or a fraction by grammar. A point or an exponent, not a
    // reader's guess.
    private static func scalar(from bare: String) throws -> Value {
        if let scalar = Name.scalarKeywords[bare] { return scalar }

        do {
            guard let first = bare.first, first == "-" || first.isNumber else {
                throw refused("nothing is written \(bare)")
            }

            // One value, one writing. The reader takes exactly the spelling the
            // writer produces, for the values as for the containers, so `007`
            // and `1e0` are not documents even though a looser parse would read
            // a number out of them.
            guard bare.contains(where: { character in ".eE".contains(character) }) else {
                switch Int.reading(spelling: bare) {
                case let .int(int):
                    return .int(int)

                case .notOneSpelling:
                    throw refused("\(bare) is not a whole number's one writing")

                case .overflow:
                    throw refused("\(bare) is a whole number past what an int holds")
                }
            }

            guard let double = Double(spelling: bare) else {
                throw refused("\(bare) is not a fraction's one writing")
            }

            return .double(double)
        }
    }

    // A key's spelling as the name it stands for, said in this reader's own
    // procedures.
    private static func key(_ spelling: String) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw refused(refusal.message)
        }
    }

    // A field name is read in any position, since layout is the writer's, and
    // refused where the record already holds it: two values under one key are
    // two documents, not one document twice.
    private static func expect(_ key: Name, in held: [Name: Value]) throws {
        guard held[key] == nil else {
            throw refused("the record writes '\(key)' twice")
        }
    }

    // Fields under names, with the name of the layout they stood on where
    // there was one.
    private static func write(
        _ held: Value.Dictionary,
        named name: Name?,
        at indent: Int,
        into text: inout String,
        within depth: Int
    ) throws {
        if let name {
            guard name.isDeclarable else {
                throw EncodingError.invalidValue(
                    Value.string(name.spelling),
                    .init(codingPath: [], debugDescription: "the record's name is not a type's name")
                )
            }

            text += name.spelling + " "
        }

        guard !held.isEmpty else {
            text += "{}"

            return
        }

        text += "{\n"

        // Both spellings hold their fields in byte order, the order written.
        for (key, value) in held.entries {
            text += String(repeating: "  ", count: indent + 1)

            if key.isIdentifier {
                text += key.spelling
            } else {
                write(key.spelling, into: &text)
            }

            text += " "

            try write(value, at: indent + 1, into: &text, within: depth - 1)

            text += "\n"
        }

        text += String(repeating: "  ", count: indent) + "}"
    }

    private static func write(
        _ value: Value,
        at indent: Int,
        into text: inout String,
        within depth: Int
    ) throws {
        switch value {
        case .null:
            text += "null"

        case let .bool(bool):
            text += bool ? "true" : "false"

        case let .int(int):
            text += "\(int)"

        // "Has a spelling" and "a document carries it" are one fact, asked
        // once. The spelling itself is the judge.
        case let .double(double):
            guard let spelling = double.spelling else {
                throw EncodingError.invalidValue(
                    value,
                    .init(
                        codingPath: [],
                        debugDescription: "a document has no way to carry \(double)"
                    )
                )
            }

            text += spelling

        case let .string(string):
            write(string, into: &text)

        case let .bytes(bytes):
            text += "x\""
            text += bytes.spelling
            text += "\""

        case let .array(array):
            try opening(value, within: depth)

            guard !array.isEmpty else {
                text += "[]"

                break
            }

            text += "[\n"

            for element in array {
                text += String(repeating: "  ", count: indent + 1)

                try write(element, at: indent + 1, into: &text, within: depth - 1)

                text += "\n"
            }

            text += String(repeating: "  ", count: indent) + "]"

        case let .record(record):
            try opening(value, within: depth)
            try write(record.asDictionary, named: record.name, at: indent, into: &text, within: depth)

        case let .dictionary(held):
            try opening(value, within: depth)
            try write(held, named: nil, at: indent, into: &text, within: depth)

        case .procedure:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: [],
                    debugDescription: "a procedure is code, and data is what a document spells"
                )
            )
        }
    }

    private static func write(_ string: String, into text: inout String) {
        text += "\""

        for character in string.unicodeScalars {
            switch character {
            case "\"": text += "\\\""
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"

            default:
                guard character.value < 0x20 else {
                    text.unicodeScalars.append(character)

                    continue
                }

                text += String(format: "\\u%04x", character.value)
            }
        }

        text += "\""
    }

    // The same count the writer keeps: containers open on the path, and the
    // one about to open is one more of them.
    private static func opening(_ opened: [Opened]) throws {
        guard opened.count < Envelope.nesting else {
            throw refused("the document nests deeper than a reader must follow")
        }
    }

    // A container opens within the bound or not at all, and what it holds is
    // written one container deeper.
    private static func opening(_ value: Value, within depth: Int) throws {
        guard depth > 0 else {
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: [],
                    debugDescription: "the value nests deeper than a document may"
                )
            )
        }
    }

    private static func refused(_ said: String) -> Error {
        DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: said))
    }
}

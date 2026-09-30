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
public struct TextEncoding {
    private enum Token: Equatable {
        case arrayOpen
        case arrayClose
        case recordOpen
        case recordClose
        case string(String)
        case bytes([UInt8])
        case bare(String)
    }

    // A token and where it began, counted in scalars from the start of the
    // text, which is what a refusal turns into a line and a column.
    private struct Placed {
        // MARK: - Property
        let token: Token
        let offset: Int

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // A refusal that knows where it happened and not yet how to say it. The
    // line and column are worked out once, at the door, from the whole text.
    private struct Unplaced: Error {
        // MARK: - Property
        let said: String
        let offset: Int

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
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

    // MARK: - Property
    // The first tokens of every document: which encoding, laid out how. The
    // version moves when this file's grammar does, and for no other reason.
    // What the *program* needs of its reader is said inside the document.
    public static let name = "warpt"
    public static let format = 1

    // What may stand between two tokens, besides the text ending.
    private static let delimiters = Set(" \n\r\t[]{}".unicodeScalars)

    // What ends a bare token: a delimiter, or a quote.
    private static let enders = delimiters.union(["\""])

    // MARK: - Initializer
    public init() { }

    // MARK: - Public
    public func text(from value: Value) throws -> String {
        var written = "\(Self.name) \(Self.format)\n"

        try write(value, at: 0, into: &written, within: Envelope.nesting)

        written += "\n"

        return written
    }

    // The same writing on one line and without the envelope, for a sentence
    // that quotes a value.
    func line(from value: Value) throws -> String {
        var written = ""

        try write(value, at: 0, into: &written, within: Envelope.nesting)

        return written
            .split(separator: "\n")
            .map { line in line.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    public func data(from value: Value) throws -> Data {
        Data(try text(from: value).utf8)
    }

    public func value(from data: Data) throws -> Value {
        guard let text = String(utf8: data) else {
            throw refused("the text is not UTF-8")
        }

        return try value(from: text)
    }

    public func value(from text: String) throws -> Value {
        let scalars = Array(text.unicodeScalars)

        do {
            return try read(scalars)
        } catch let unplaced as Unplaced {
            throw refused(unplaced.said, at: unplaced.offset, in: scalars)
        }
    }

    // MARK: - Private
    private func read(_ scalars: [Unicode.Scalar]) throws -> Value {
        // The first two tokens are read on their own and before the rest:
        // whether this is a document at all, and laid out how, is answered
        // before anything in it is, so a later format is refused as that and
        // not as whatever its body says that this reader has no name for.
        var reading = scalars[...]

        guard bareToken(from: &reading) == Self.name else {
            throw refused("the text does not begin as a warp document begins", at: 0)
        }

        let start = reading.startIndex
        let version = bareToken(from: &reading)

        guard !version.isEmpty else {
            throw refused("the text does not say how it is laid out", at: start)
        }

        // The one spelling of a whole number, here as in a value: `warpt 01`
        // would be a second text for a document the reader already has one for.
        let claimed: Int

        switch Int.reading(spelling: version) {
        case let .int(read):
            claimed = read

        case .notOneSpelling:
            throw refused("\(version) is not a format's one writing", at: start)

        case .overflow:
            throw refused("\(version) is a format past what an int holds", at: start)
        }

        guard claimed == Self.format else {
            throw refused(
                claimed > Self.format
                    ? "the document is laid out as format \(claimed), and this reader lays out \(Self.format)"
                    : "format \(claimed) never existed",
                at: start
            )
        }

        var tokens = try tokenized(reading)[...]
        let value = try read(from: &tokens, ending: scalars.count)

        guard let left = tokens.first else { return value }

        throw refused("the document ended and the text did not", at: left.offset)
    }

    // A bare token past any whitespace, or nothing where the text has none
    // there. The header is read this way, since a header is two of them.
    private func bareToken(from reading: inout ArraySlice<Unicode.Scalar>) -> String {
        while let character = reading.first, " \n\r\t".unicodeScalars.contains(character) {
            reading.removeFirst()
        }

        var bare = ""

        while let character = reading.first, !Self.enders.contains(character) {
            bare.unicodeScalars.append(character)
            reading.removeFirst()
        }

        return bare
    }

    private func tokenized(_ reading: ArraySlice<Unicode.Scalar>) throws -> [Placed] {
        var tokens: [Placed] = []
        var reading = reading

        while let character = reading.first {
            let start = reading.startIndex

            switch character {
            case " ", "\n", "\r", "\t":
                reading.removeFirst()

            case "[":
                reading.removeFirst()
                tokens.append(Placed(token: .arrayOpen, offset: start))

            case "]":
                reading.removeFirst()
                tokens.append(Placed(token: .arrayClose, offset: start))

            case "{":
                reading.removeFirst()
                tokens.append(Placed(token: .recordOpen, offset: start))

            case "}":
                reading.removeFirst()
                tokens.append(Placed(token: .recordClose, offset: start))

            case "\"":
                reading.removeFirst()
                tokens.append(Placed(token: .string(try quoted(from: &reading)), offset: start))
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
                    tokens.append(Placed(token: .bytes(try hexed(from: &reading)), offset: start))
                } else {
                    tokens.append(Placed(token: .bare(bare), offset: start))
                }

                try separated(reading)
            }
        }

        return tokens
    }

    // A character as a person reads it in a refusal: itself, or a control
    // character the way the writer spells one.
    private func shown(_ scalar: Unicode.Scalar) -> String {
        scalar.value < 0x20 ? String(format: "\\u%04x", scalar.value) : String(scalar)
    }

    // A delimiter follows a token, or nothing does.
    private func separated(_ reading: ArraySlice<Unicode.Scalar>) throws {
        guard let next = reading.first, !Self.delimiters.contains(next) else { return }

        throw refused("a token runs straight into \(shown(next)), and whitespace or a bracket separates the two", at: reading.startIndex)
    }

    private func quoted(from reading: inout ArraySlice<Unicode.Scalar>) throws -> String {
        var string = ""

        while let character = reading.first {
            let at = reading.startIndex

            reading.removeFirst()

            switch character {
            case "\"":
                return string

            case "\\":
                string.unicodeScalars.append(try escaped(from: &reading))

            default:
                guard character.value >= 0x20 else {
                    throw refused("text holds a control character written raw", at: at)
                }

                string.unicodeScalars.append(character)
            }
        }

        throw refused("the text ends inside text", at: reading.startIndex)
    }

    private func escaped(from reading: inout ArraySlice<Unicode.Scalar>) throws -> Unicode.Scalar {
        guard let character = reading.first else {
            throw refused("the text ends inside an escape", at: reading.startIndex)
        }

        let at = reading.startIndex

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
                throw refused("the escape spells a character that is written as itself", at: at)
            }

            guard let scalar = Unicode.Scalar(value), !["\n", "\r", "\t"].contains(scalar) else {
                throw refused("the escape spells a character that has a shorter escape", at: at)
            }

            return scalar

        default:
            throw refused("nothing is written \\\(shown(character))", at: at)
        }
    }

    // The body of `x"…"`: lowercase hex, two digits a byte, nothing else.
    // Uppercase or odd length would be a second spelling for the same bytes.
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
                throw refused("bytes are written as lowercase hex", at: at)
            }
        }

        guard reading.first == "\"" else {
            throw refused("the text ends inside bytes", at: reading.startIndex)
        }

        reading.removeFirst()

        guard digits.count % 2 == 0 else {
            throw refused("bytes are written two digits each", at: reading.startIndex)
        }

        return stride(from: 0, to: digits.count, by: 2)
            .map { index in digits[index] << 4 | digits[index + 1] }
    }

    private func hexadecimal(from reading: inout ArraySlice<Unicode.Scalar>) throws -> UInt32 {
        var value: UInt32 = 0

        for _ in 0..<4 {
            guard let character = reading.first,
                  character.isASCII,
                  !("A"..."F").contains(character),
                  let digit = UInt32(String(character), radix: 16) else {
                throw refused("the escape is not four lowercase hexadecimal digits", at: reading.startIndex)
            }

            value = value << 4 | digit

            reading.removeFirst()
        }

        return value
    }

    private func read(from tokens: inout ArraySlice<Placed>, ending: Int) throws -> Value {
        var opened: [Opened] = []

        while true {
            guard let placed = tokens.popFirst() else {
                throw refused("the text ends where a value should begin", at: ending)
            }

            let token = placed.token
            let at = placed.offset

            var settled: Value?

            // A record waits for a key where everything else waits for a value,
            // and a closing brace is only honest in that position
            if case let .record(held, .none, name) = opened.last {
                switch token {
                case .recordClose:
                    opened.removeLast()

                    settled = try .holding(held.map { field in (name: field.key, value: field.value) }, named: name)

                case let .bare(spelling):
                    let key = try key(spelling, at: at)

                    guard key.isIdentifier else {
                        throw refused("a record writes a field name here", at: at)
                    }

                    try expect(key, in: held, at: at)

                    opened[opened.count - 1] = .record(held: held, key: key, name: name)

                    continue

                case let .string(spelling):
                    let key = try key(spelling, at: at)

                    try expect(key, in: held, at: at)

                    opened[opened.count - 1] = .record(held: held, key: key, name: name)

                    continue

                default:
                    throw refused("a record writes a field name here", at: at)
                }
            } else {
                switch token {
                case .arrayOpen:
                    try opening(opened, at: at)
                    opened.append(.array([]))

                    continue

                case .recordOpen:
                    try opening(opened, at: at)
                    opened.append(.record(held: [:], key: nil, name: nil))

                    continue

                case .arrayClose:
                    guard case let .array(held) = opened.last else {
                        throw refused("nothing here is an array to close", at: at)
                    }

                    opened.removeLast()

                    settled = .array(held)

                case .recordClose:
                    throw refused("nothing here is a record to close", at: at)

                case let .string(string):
                    settled = .string(string)

                case let .bytes(bytes):
                    settled = .bytes(bytes)

                // A bare token in front of a record is the record's name: the
                // declared type the value settled to.
                case let .bare(bare):
                    if tokens.first?.token == .recordOpen, let name = try? Name(bare), name.isDeclarable {
                        try opening(opened, at: at)
                        tokens.removeFirst()
                        opened.append(.record(held: [:], key: nil, name: name))

                        continue
                    }

                    settled = try scalar(from: bare, at: at)
                }
            }

            // Closing is a token here, not a count, so a settled value climbs
            // one step at most: into whatever holds it, or out
            if let value = settled {
                guard let open = opened.popLast() else { return value }

                switch open {
                case let .array(held):
                    var held = held
                    held.append(value)

                    opened.append(.array(held))

                case let .record(held, key?, name):
                    var held = held
                    // Unique: the key was refused where it was read if the
                    // record already held it.
                    held[key] = value

                    opened.append(.record(held: held, key: nil, name: name))

                // A record with no key is waiting for a field name, and every
                // token it could meet in that state was answered above
                case .record(_, .none, _):
                    throw refused("a record writes a field name here", at: at)
                }
            }
        }
    }

    // What a bare token names. Everything unquoted is one of five things, and a
    // number is whole or a fraction by grammar. A point or an exponent, not a
    // reader's guess.
    private func scalar(from bare: String, at offset: Int) throws -> Value {
        if let scalar = Name.scalarKeywords[bare] { return scalar }

        do {
            guard let first = bare.first, first == "-" || first.isNumber else {
                throw refused("nothing is written \(bare)", at: offset)
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
                    throw refused("\(bare) is not a whole number's one writing", at: offset)

                case .overflow:
                    throw refused("\(bare) is a whole number past what an int holds", at: offset)
                }
            }

            guard let double = Double(spelling: bare) else {
                throw refused("\(bare) is not a fraction's one writing", at: offset)
            }

            return .double(double)
        }
    }

    // A key's spelling as the name it stands for, said in this reader's own
    // words.
    private func key(_ spelling: String, at offset: Int) throws -> Name {
        do {
            return try Name(spelling)
        } catch let refusal as NameRefused {
            throw refused(refusal.message, at: offset)
        }
    }

    // A field name is read in any position, since layout is the writer's, and
    // refused where the record already holds it: two values under one key are
    // two documents, not one document twice.
    private func expect(_ key: Name, in held: [Name: Value], at offset: Int) throws {
        guard held[key] == nil else {
            throw refused("the record writes '\(key)' twice", at: offset)
        }
    }

    // Fields under names, with the name of the layout they stood on where
    // there was one.
    private func write(
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

    private func write(
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

    private func write(_ string: String, into text: inout String) {
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
    private func opening(_ opened: [Opened], at offset: Int) throws {
        guard opened.count < Envelope.nesting else {
            throw refused("the document nests deeper than a reader must follow", at: offset)
        }
    }

    // A container opens within the bound or not at all, and what it holds is
    // written one container deeper.
    private func opening(_ value: Value, within depth: Int) throws {
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

    private func refused(_ said: String) -> Error {
        DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: said))
    }

    private func refused(_ said: String, at offset: Int) -> Error {
        Unplaced(said: said, offset: offset)
    }

    // Said with the line and column the offset stands at, both counted from
    // one, the column in scalars.
    private func refused(_ said: String, at offset: Int, in scalars: [Unicode.Scalar]) -> Error {
        var line = 1
        var column = 1

        for scalar in scalars.prefix(offset) {
            if scalar == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return refused("\(said), at line \(line) column \(column)")
    }
}

//
//  Rendering.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// A value on its way into a template. JSON is the shape a list or a mapping
// shows as, and this is the one thing in the package that writes one — by
// hand, so what a value shows as is this file's own decision rather than a
// general-purpose encoder's.
//
// It is a wrapper rather than a conformance on `Value` because the two are not
// the same job. `Value` is the language's data type and knows nothing about
// being written down — what a document spells is `WarpSyntax`'s, and it round-trips.
// This does not: a procedure has no data form, and what goes out for one is a
// marker saying so, which is right for something a person reads and wrong for
// anything that means to read it back.
struct Rendering {
    private struct Unwritable: Error {
    }

    // MARK: - Property
    let value: Value

    // MARK: - Initializer
    init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    // The value as text. One implementation, because `text` the word and an
    // effect settling an argument are asking the same question. A scalar
    // reads as its document spelling — a host's infinity, which has none,
    // in this file's own vocabulary; only the container shapes go through
    // `written`, where JSON's own rules apply, and what JSON cannot write
    // stays a visible marker — an answer, not a failure.
    func text() -> String {
        switch value {
        case .null:
            return ""

        case let .bool(bool):
            return bool ? "true" : "false"

        case let .int(integer):
            return String(integer)

        // The document's own spelling, so what a template shows is what a
        // document would say — and what has no spelling shows in this file's
        // own vocabulary, the way a procedure does, rather than in whatever
        // the host's formatter says today.
        case let .double(double):
            return double.shown

        case let .string(string):
            return string

        // The document's spelling is `x` and the hex digits, and `text` spells
        // a value the way a document writes it — the bare digits this used to
        // show are a form nothing reads back.
        case let .bytes(bytes):
            return "x\"\(bytes.spelling)\""

        // A body has no text an author wrote it to produce, so what shows is
        // what it is.
        case .procedure:
            return "<procedure>"

        case .array, .record, .dictionary:
            // `Unwritable` is the only thing `written` throws, so the fallback
            // is the whole failure story.
            return (try? Self.written(value)) ?? "<unencodable>"
        }
    }

    // MARK: - Private
    // One value in JSON position. What JSON cannot say — bytes, a procedure —
    // shows as the reading `text` gives it, quoted because it is text about
    // the value; what JSON could say and this value breaks — a fraction that
    // is not a number, or past every number — throws, and the whole rendering
    // shows as unencodable rather than as almost-JSON.
    //
    // A value's spelling does not change with how deep it sits. The document
    // writer is one recursive function and writes `x"6869"` at every depth, so
    // this shows the same spelling at every depth and the quotes are the
    // position's, exactly as they are for a string.
    //
    // What the Codable projection writes instead — the array the equation says
    // bytes are — is not this answer and is not meant to be. That projection
    // is read back; this one is read by a person.
    private static func written(_ value: Value) throws -> String {
        switch value {
        case .null:
            return "null"

        case let .bool(bool):
            return bool ? "true" : "false"

        case let .int(integer):
            return String(integer)

        // "Has a spelling" and "JSON can say it" are one fact — the document's
        // spelling is the judge, and JSON reads it back as the same number.
        case let .double(double):
            guard let spelling = double.spelling else { throw Unwritable() }

            return spelling

        case let .string(string):
            return quoted(string)

        case let .bytes(bytes):
            return quoted("x\"\(bytes.spelling)\"")

        case .procedure:
            return quoted("<procedure>")

        case let .array(array):
            return "[" + (try array.map(written)).joined(separator: ",") + "]"

        case let .record(record):
            let fields = try zip(record.names, record.values).map { name, value in
                "\(quoted(name.spelling)):\(try written(value))"
            }

            return (record.name.map { name in "\(name) " } ?? "") + "{" + fields.joined(separator: ",") + "}"

        case let .dictionary(dictionary):
            let entries = try dictionary.entries.map { name, value in
                "\(quoted(name.spelling)):\(try written(value))"
            }

            return "{" + entries.joined(separator: ",") + "}"
        }
    }

    private static func quoted(_ string: String) -> String {
        var quoted = "\""

        for character in string.unicodeScalars {
            switch character {
            case "\"":
                quoted += "\\\""

            case "\\":
                quoted += "\\\\"

            case "\n":
                quoted += "\\n"

            case "\r":
                quoted += "\\r"

            case "\t":
                quoted += "\\t"

            case let control where control.value < 0x20:
                quoted += String(format: "\\u%04x", control.value)

            default:
                quoted.unicodeScalars.append(character)
            }
        }

        return quoted + "\""
    }
}

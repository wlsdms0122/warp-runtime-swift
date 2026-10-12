//
//  Rendering.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// A value in its own spelling, the type's and not a document's, for a person
// to read: what `text` answers under the standard vocabulary. Written by hand,
// so what a value shows as is this file's and not a general-purpose
// encoder's. It is not read back: a procedure shows as a marker.
public struct Rendering {
    private struct Unwritable: Error {
    }

    // MARK: - Property
    public let value: Value

    // MARK: - Initializer
    public init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    // The value as text. One implementation, because `text` the procedure and an
    // effect turning an argument into text are asking the same question.
    public func text() -> String {
        switch value {
        case .null:
            return "null"

        case let .bool(bool):
            return bool ? "true" : "false"

        case let .int(integer):
            return String(integer)

        // What has no spelling shows in the language's own markers, the way a
        // procedure does, rather than in the host's formatter.
        case let .double(double):
            return double.shown

        case let .string(string):
            return string

        case let .bytes(bytes):
            return "x\"\(bytes.spelling)\""

        // A body has no text an author wrote it to produce, so what shows is
        // what it is.
        case .procedure:
            return "<procedure>"

        case .array, .struct, .dictionary:
            // `written` throws only `Unwritable`.
            return (try? Self.written(value)) ?? "<unencodable>"
        }
    }

    // MARK: - Private
    // One value inside a container. Bytes and a procedure show as the reading
    // `text` gives them, quoted, since a value's spelling does not change with
    // how deep it sits and the quotes are the position's, as a string's are. A
    // fraction with no spelling throws, and the whole rendering shows as
    // unencodable.
    private static func written(_ value: Value) throws -> String {
        switch value {
        case .null:
            return "null"

        case let .bool(bool):
            return bool ? "true" : "false"

        case let .int(integer):
            return String(integer)

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

        case let .struct(instance):
            let fields = try zip(instance.names, instance.values).map { name, value in
                "\(quoted(name.spelling)):\(try written(value))"
            }

            return "\(instance.name) {" + fields.joined(separator: ",") + "}"

        case let .dictionary(dictionary):
            let entries = try dictionary.entries.map { key, value in
                "\(try written(key)):\(try written(value))"
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

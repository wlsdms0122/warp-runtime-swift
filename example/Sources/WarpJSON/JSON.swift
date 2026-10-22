//
//  JSON.swift
//  WarpJSON
//

import Foundation
import Warp

// Between JSON text and a value. An object reads as a map keyed by text, a
// whole number as int, any other number as double; a value writes back the
// same way, a struct as an object of its fields, and a map only where every
// key is text.
public enum JSON {
    public static func value(from text: String) throws -> Value {
        let object: Any

        do {
            object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch {
            throw JSONFailed("not JSON: \(error.localizedDescription)")
        }

        return try value(from: object)
    }

    public static func text(from value: Value) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: try object(from: value), options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])

        return String(decoding: data, as: UTF8.self)
    }

    private static func value(from object: Any) throws -> Value {
        switch object {
        case is NSNull:
            return .null

        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }

            return String(cString: number.objCType) == "d" ? .double(number.doubleValue) : .int(number.intValue)

        case let string as String:
            return .string(string)

        case let array as [Any]:
            return .array(try array.map(value(from:)))

        case let dictionary as [String: Any]:
            return .dictionary(try Value.Dictionary(dictionary.map { key, inner in (key: .string(key), value: try value(from: inner)) }))

        default:
            throw JSONFailed("not JSON: \(type(of: object))")
        }
    }

    private static func object(from value: Value) throws -> Any {
        switch value {
        case .null:
            return NSNull()

        case let .bool(bool):
            return bool

        case let .int(int):
            return int

        case let .double(double):
            return double

        case let .string(string):
            return string

        case let .bytes(bytes):
            return bytes.map { byte in Int(byte) }

        case let .array(array):
            return try array.map(object(from:))

        case let .struct(instance):
            var object: [String: Any] = [:]

            for name in instance.names {
                object[name.spelling] = try Self.object(from: instance[name] ?? .null)
            }

            return object

        case let .dictionary(dictionary):
            var object: [String: Any] = [:]

            for entry in dictionary.entries {
                guard case let .string(key) = entry.key else {
                    throw JSONFailed("a map holds the key \(Rendering(entry.key).text()), and a JSON object is keyed by text")
                }

                object[key] = try Self.object(from: entry.value)
            }

            return object

        case .procedure:
            throw JSONFailed("a procedure is not JSON")
        }
    }
}

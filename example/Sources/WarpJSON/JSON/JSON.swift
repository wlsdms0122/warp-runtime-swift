//
//  JSON.swift
//  WarpJSON
//

import Foundation
import Warp

// Between JSON text and a value. An object reads as a dictionary keyed by strings,
// an integer as int, any other number as double; a value writes back the
// same way, a struct as an object of its fields, and a dictionary only where every
// key is a string.
public struct JSON {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func value(from text: String) throws -> Value {
        let object: Any

        do {
            object = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch {
            throw JSONFailed("not JSON: \(error.localizedDescription)")
        }

        return try value(from: object)
    }

    public func text(from value: Value) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: try object(from: value), options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])

        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Private
    private func value(from object: Any) throws -> Value {
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

    private func object(from value: Value) throws -> Any {
        switch value {
        case let .existential(existential):
            return try object(from: existential.value)

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
                object[name.spelling] = try self.object(from: instance[name] ?? .null)
            }

            return object

        case let .dictionary(dictionary):
            var object: [String: Any] = [:]

            for entry in dictionary.entries {
                guard case let .string(key) = entry.key else {
                    throw JSONFailed("a dictionary holds the key \(Rendering(entry.key).text()), and a JSON object is keyed by strings")
                }

                object[key] = try self.object(from: entry.value)
            }

            return object

        case .procedure:
            throw JSONFailed("a procedure is not JSON")
        }
    }
}

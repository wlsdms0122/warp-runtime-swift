//
//  ValueDecoder.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Decodes Codable types directly from a Value tree. Serializing through JSON text
// would collapse the scalar typing the loader fixed — `3.0` re-reads as int — so
// the loader's Value is the decoding source itself, with no round trip.
struct ValueDecoder: Decoder {
    private struct AnyKey: CodingKey {
        // MARK: - Property
        let stringValue: String
        let intValue: Int?

        // MARK: - Initializer
        init(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }

        // MARK: - Public
        // MARK: - Private
    }

    private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        // MARK: - Property
        let object: [String: Value]
        let codingPath: [CodingKey]
        let steps: [Place.Step]
        let userInfo: [CodingUserInfoKey: Any]

        var allKeys: [Key] {
            object.keys.compactMap { key in Key(stringValue: key) }
        }

        // MARK: - Initializer
        // MARK: - Public
        func contains(_ key: Key) -> Bool {
            object[key.stringValue] != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            try value(forKey: key) == .null
        }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            try decoder(forKey: key).decode(type)
        }

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> {
            try decoder(forKey: key).container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            try decoder(forKey: key).unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            guard let key = Key(stringValue: "super") else {
                throw ReadingError("no super key", at: steps)
            }

            return try decoder(forKey: key)
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            try decoder(forKey: key)
        }

        // MARK: - Private
        private func value(forKey key: Key) throws -> Value {
            guard let value = object[key.stringValue] else {
                throw ReadingError(
                    "no value for key '\(key.stringValue)'",
                    at: steps + [.key(key.stringValue)]
                )
            }

            return value
        }

        private func decoder(forKey key: Key) throws -> ValueDecoder {
            ValueDecoder(
                value: try value(forKey: key),
                codingPath: codingPath + [key],
                steps: steps + [.key(key.stringValue)],
                userInfo: userInfo
            )
        }
    }

    private struct UnkeyedContainer: UnkeyedDecodingContainer {
        // MARK: - Property
        // The projection, not a copy of it — the same shape every other
        // walker of elements in this library holds, so a compact spelling is
        // not made into a boxed element apiece before the first is read.
        let elements: AnyRandomAccessCollection<Value>
        let codingPath: [CodingKey]
        let steps: [Place.Step]
        let userInfo: [CodingUserInfoKey: Any]

        var count: Int? { elements.count }

        var isAtEnd: Bool { currentIndex >= elements.count }

        private(set) var currentIndex = 0

        // MARK: - Initializer
        // MARK: - Public
        mutating func decodeNil() throws -> Bool {
            guard try current() == .null else { return false }

            currentIndex += 1

            return true
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let decoded = try ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            ).decode(type)

            currentIndex += 1

            return decoded
        }

        mutating func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> {
            let container = try ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            ).container(keyedBy: type)

            currentIndex += 1

            return container
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let container = try ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            ).unkeyedContainer()

            currentIndex += 1

            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let decoder = ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            )

            currentIndex += 1

            return decoder
        }

        // MARK: - Private
        private func current() throws -> Value {
            guard !isAtEnd else {
                throw ReadingError(
                    "unkeyed container is at end",
                    at: steps + [.index(currentIndex)]
                )
            }

            return elements[elements.index(elements.startIndex, offsetBy: currentIndex)]
        }
    }

    private struct SingleContainer: SingleValueDecodingContainer {
        // MARK: - Property
        let value: Value
        let codingPath: [CodingKey]
        let steps: [Place.Step]
        let userInfo: [CodingUserInfoKey: Any]

        // MARK: - Initializer
        // MARK: - Public
        func decodeNil() -> Bool {
            value == .null
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            guard case let .bool(bool) = value else { throw mismatch(type) }

            return bool
        }

        func decode(_ type: String.Type) throws -> String {
            guard case let .string(string) = value else { throw mismatch(type) }

            return string
        }

        func decode(_ type: Int.Type) throws -> Int {
            guard case let .int(integer) = value else { throw mismatch(type) }

            return integer
        }

        func decode(_ type: Double.Type) throws -> Double {
            switch value {
            case let .double(double):
                return double

            case let .int(integer):
                return Double(integer)

            default:
                throw mismatch(type)
            }
        }

        func decode(_ type: Float.Type) throws -> Float {
            Float(try decode(Double.self))
        }

        func decode(_ type: Int8.Type) throws -> Int8 { try narrowed(type) }

        func decode(_ type: Int16.Type) throws -> Int16 { try narrowed(type) }

        func decode(_ type: Int32.Type) throws -> Int32 { try narrowed(type) }

        func decode(_ type: Int64.Type) throws -> Int64 { try narrowed(type) }

        func decode(_ type: UInt.Type) throws -> UInt { try narrowed(type) }

        func decode(_ type: UInt8.Type) throws -> UInt8 { try narrowed(type) }

        func decode(_ type: UInt16.Type) throws -> UInt16 { try narrowed(type) }

        func decode(_ type: UInt32.Type) throws -> UInt32 { try narrowed(type) }

        func decode(_ type: UInt64.Type) throws -> UInt64 { try narrowed(type) }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try ValueDecoder(
                value: value,
                codingPath: codingPath,
                steps: steps,
                userInfo: userInfo
            ).decode(type)
        }

        // MARK: - Private
        private func narrowed<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
            guard
                case let .int(integer) = value,
                let narrowed = T(exactly: integer)
            else {
                throw mismatch(type)
            }

            return narrowed
        }

        private func mismatch(_ type: Any.Type) -> ReadingError {
            ReadingError("expected \(type), found \(value.type)", at: steps)
        }
    }

    // MARK: - Property
    let value: Value
    let codingPath: [CodingKey]

    // Where the reading has reached, said in the document's own words.
    //
    // `codingPath` is the same walk in `Codable`'s terms, and it cannot answer
    // this: a coding key carries a number whenever its spelling reads as one,
    // so a procedure declared under `"12"` is indistinguishable from the
    // twelfth element of an array. Here the two are never confused, because
    // this is built where the walk descends, by the container that knows which
    // of the two it just did.
    let steps: [Place.Step]

    let userInfo: [CodingUserInfoKey: Any]

    // MARK: - Initializer
    // MARK: - Public
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case let .object(object) = value else {
            throw ReadingError("expected object, found \(value.type)", at: steps)
        }

        return KeyedDecodingContainer(KeyedContainer(
            object: object,
            codingPath: codingPath,
            steps: steps,
            userInfo: userInfo
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // Through the one projection that owns the `bytes = array<byte>`
        // equation, so a compact spelling is walked where a long one is —
        // the same equation the writer puts them out through. Asking for
        // `Data` is still answered by `decode` below, which holds bytes to
        // their own spelling so an int array cannot quietly become them.
        guard let elements = value.elements else {
            throw ReadingError("expected array, found \(value.type)", at: steps)
        }

        return UnkeyedContainer(
            elements: elements,
            codingPath: codingPath,
            steps: steps,
            userInfo: userInfo
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleContainer(value: value, codingPath: codingPath, steps: steps, userInfo: userInfo)
    }

    // The one place a Codable type is made from a value, shared by all three
    // containers so a special case cannot hold in one and not another.
    //
    // Bytes have no container to walk — the one binary kind is handed over
    // whole, and `Data` is the shape it is asked for as. Anything else asking
    // for `Data` is refused here rather than allowed to fall through to Data's
    // own decoding, which reads an unkeyed list of small numbers and would
    // quietly turn an int array into bytes.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Data.self {
            guard case let .bytes(bytes) = value, let data = Data(bytes) as? T else {
                throw ReadingError("expected \(type), found \(value.type)", at: steps)
            }

            return data
        }

        // The boundary a reader's own refusal crosses, and where it is given
        // the address this walk knows and the reader does not. A refusal that
        // already carries one passes through: the innermost boundary it crossed
        // is the deepest anybody reached, and a step further out would be a
        // shallower answer written over a truer one.
        do {
            return try T(from: self)
        } catch let refusal as DecodingError {
            throw ReadingError(refusal, at: steps)
        }
    }
}

extension Decoder {
    // Where this reading has reached, in the document's own words — nothing
    // where the reading is not this package's, which is the honest answer for a
    // decoder whose descent nobody here watched.
    var steps: [Place.Step] { (self as? ValueDecoder)?.steps ?? [] }

    // Read what is written here, standing on it.
    //
    // For a reader that has to judge a value after reading it: what is judged
    // and what is refused are then one place, and the address is where the
    // reading is rather than a key the guard below remembered to name. An
    // address assembled from a remembered key is a second answer to a question
    // the walk already answers, and the two go apart the first time a reader
    // is written that forgets to assemble one.
    //
    // The boundary is not a second one. This is the same door
    // `ValueDecoder.decode` is, reached from a decoder handed over as the
    // protocol — and where the decoder is somebody else's there is no door of
    // ours to go through.
    func read<T: Decodable>(_ type: T.Type) throws -> T {
        guard let decoder = self as? ValueDecoder else { return try T(from: self) }

        return try decoder.decode(type)
    }

    // A record of readers, read in the order the names sort in.
    //
    // `Dictionary` reads its keys in hash order, and the seed for that changes
    // from one process to the next. Two entries that are both wrong would then
    // be refused in either order, and the one line an author is given would not
    // be the same line twice — which is the whole of what an address is for.
    // Sorted rather than as-written because a document is a value by then and a
    // value's record has no order to have kept.
    func read<T: Decodable>(_ type: [String: T].Type) throws -> [String: T] {
        let container = try container(keyedBy: AnyCodingKey.self)

        return try container.allKeys
            .map(\.stringValue)
            .sorted()
            .reduce(into: [String: T]()) { read, key in
                read[key] = try container.decode(T.self, forKey: AnyCodingKey(stringValue: key))
            }
    }
}

//
//  ValueDecoder.swift
//  WarpSyntax
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Decodes Codable types directly from a Value tree. A `Value` asked of it is
// the one the tree holds, so its kinds (`3.0` a double, `3` an int) are the
// ones read; a `Double` asked of an int is that int's worth.
struct ValueDecoder: Decoder {
    private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        // MARK: - Property
        let mapping: Value.Dictionary
        let codingPath: [CodingKey]
        let steps: [Place.Step]
        let userInfo: [CodingUserInfoKey: Any]

        var allKeys: [Key] {
            mapping.keys.compactMap { key in
                guard case let .string(text) = key else { return nil }

                return Key(stringValue: text)
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        func contains(_ key: Key) -> Bool {
            (try? Name(key.stringValue)).flatMap { name in mapping[name] } != nil
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
            guard let name = try? Name(key.stringValue), let value = mapping[name] else {
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
        // The projection, not a copy of it. The same type every other walker
        // of elements in this library holds, so a compact spelling is not made
        // into a boxed element apiece before the first is read.
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
                codingPath: codingPath + [AnyCodingKey(intValue: currentIndex)],
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
                codingPath: codingPath + [AnyCodingKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            ).container(keyedBy: type)

            currentIndex += 1

            return container
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let container = try ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyCodingKey(intValue: currentIndex)],
                steps: steps + [.index(currentIndex)],
                userInfo: userInfo
            ).unkeyedContainer()

            currentIndex += 1

            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let decoder = ValueDecoder(
                value: try current(),
                codingPath: codingPath + [AnyCodingKey(intValue: currentIndex)],
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
            ReadingError("expected \(type), found \(value.nominal)", at: steps)
        }
    }

    // MARK: - Property
    let value: Value
    let codingPath: [CodingKey]

    // Where the reading has reached, said in the document's own terms.
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
    init(value: Value, codingPath: [CodingKey], steps: [Place.Step], userInfo: [CodingUserInfoKey: Any]) {
        self.value = value
        self.codingPath = codingPath
        self.steps = steps
        self.userInfo = userInfo
    }

    // A decoder one key below another, standing on a value the reader above
    // already holds and at the steps that reader has walked.
    init(below decoder: Decoder, key: String, holding held: Value, at steps: [Place.Step]) {
        self.init(
            value: held,
            codingPath: decoder.codingPath + [AnyCodingKey(stringValue: key)],
            steps: steps + [.key(key)],
            userInfo: decoder.userInfo
        )
    }

    // A decoder standing on a value a walk reached below another, at the
    // steps the walk took. The walk descended on its own, so the steps are
    // its; the coding path is the decoder's, which is as far as a coding path
    // knows.
    init(standing held: Value, at steps: [Place.Step], in decoder: Decoder) {
        self.init(
            value: held,
            codingPath: decoder.codingPath,
            steps: steps,
            userInfo: decoder.userInfo
        )
    }

    // MARK: - Public
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case let .dictionary(mapping) = value else {
            throw ReadingError("expected \(TypeSpelling.dictionary), found \(value.nominal)", at: steps)
        }

        return KeyedDecodingContainer(KeyedContainer(
            mapping: mapping,
            codingPath: codingPath,
            steps: steps,
            userInfo: userInfo
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // Through the one projection that owns the `bytes = Array<Int>`
        // equation, so a compact spelling is walked where a long one is. The
        // same equation the writer puts them out through. Asking for `Data` is
        // still answered by `decode` below, which holds bytes to their own
        // spelling so an int array cannot quietly become them.
        guard let elements = value.elements else {
            throw ReadingError("expected \(TypeSpelling.array), found \(value.nominal)", at: steps)
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

    // The reading under a key, standing on it. A keyed container answers the
    // same question through a box and a protocol extension apiece, and a
    // reading nested as deep as the wire admits spends its stack on those
    // before it spends it on the document.
    func descending(to key: String) throws -> ValueDecoder {
        guard let held = try held(key) else {
            throw ReadingError("no value for key '\(key)'", at: steps + [.key(key)])
        }

        return descending(to: key, holding: held)
    }

    // The same, and nothing where the key is not written or holds null.
    func descendingIfPresent(to key: String) throws -> ValueDecoder? {
        guard let held = try held(key), held != .null else { return nil }

        return descending(to: key, holding: held)
    }

    // Every element, read where it stands.
    func read<T: Decodable>(_ type: [T].Type) throws -> [T] {
        guard let elements = value.elements else {
            throw ReadingError("expected \(TypeSpelling.array), found \(value.nominal)", at: steps)
        }

        return try elements.enumerated().map { index, element in
            try ValueDecoder(
                value: element,
                codingPath: codingPath + [AnyCodingKey(intValue: index)],
                steps: steps + [.index(index)],
                userInfo: userInfo
            )
            .decode(T.self)
        }
    }

    // A record of readers, read in the order the names sort in.
    //
    // `Dictionary` reads its keys in hash order, and the seed for that changes
    // from one process to the next. Two entries that are both wrong would then
    // be refused in either order, and the one line an author is given would not
    // be the same line twice, which is the whole of what an address is for.
    // Sorted rather than as-written because a document is a value by then and a
    // value's record has no order to have kept.
    func read<T: Decodable>(_ type: [Name: T].Type) throws -> [Name: T] {
        guard case let .dictionary(mapping) = value else {
            throw ReadingError("expected \(TypeSpelling.dictionary), found \(value.nominal)", at: steps)
        }

        return try mapping.named()
            .sorted { left, right in left.name.spelling < right.name.spelling }
            .reduce(into: [Name: T]()) { read, entry in
                read[entry.name] = try descending(to: entry.name.spelling, holding: entry.value).decode(T.self)
            }
    }

    // The one place a Codable type is made from a value, shared by all three
    // containers so a special case cannot hold in one and not another.
    //
    // Bytes have no container to walk. The one binary kind is handed over
    // whole, and `Data` is the type it is asked for as. Anything else asking
    // for `Data` is refused here rather than allowed to fall through to Data's
    // own decoding, which reads an unkeyed list of small numbers and would
    // quietly turn an int array into bytes.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Data.self {
            guard case let .bytes(bytes) = value, let data = Data(bytes) as? T else {
                throw ReadingError(
                    "expected \(TypeSpelling.array)<\(TypeSpelling.int)> written as bytes, found \(value.nominal)",
                    at: steps
                )
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

    // MARK: - Private
    // Looked up where the map keeps it, under the key's text.
    private func held(_ key: String) throws -> Value? {
        guard case let .dictionary(held) = value else {
            throw ReadingError("expected \(TypeSpelling.dictionary), found \(value.nominal)", at: steps)
        }

        return held[key: .string(key)]
    }

    private func descending(to key: String, holding held: Value) -> ValueDecoder {
        ValueDecoder(
            value: held,
            codingPath: codingPath + [AnyCodingKey(stringValue: key)],
            steps: steps + [.key(key)],
            userInfo: userInfo
        )
    }
}

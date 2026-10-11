//
//  ValueWalk.swift
//  WarpSyntax
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Warp

// A value tree in the order both encodings write it, one step at a time.
//
// What no document carries is refused here, where the walk meets it, so an
// encoding writes the steps it is handed and asks nothing. The walk keeps its
// own stack: a writer is handed a value a caller built, and the depth of a
// document must never be the depth of the host's call stack.
struct ValueWalk {
    // One step of the walk. A container that holds something is followed by
    // what it holds and then its close; an empty one is closed where it opens.
    enum Step {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case bytes([UInt8])
        case array(count: Int)
        case record(name: Name?, count: Int)
        case key(Name)
        case arrayClose
        case recordClose
    }

    // A container being written into: what of it is still to go.
    private enum Opened {
        case elements(ArraySlice<Value>)
        case fields(ArraySlice<(name: Name, value: Value)>)
    }

    // MARK: - Property
    // The value to take apart next: the whole tree first, and then each
    // field's value after its key.
    private var pending: Value?

    private var opened: [Opened] = []

    // MARK: - Initializer
    init(_ value: Value) {
        self.pending = value
    }

    // MARK: - Public
    mutating func next() throws -> Step? {
        if let value = pending {
            pending = nil

            return try step(value)
        }

        guard let container = opened.popLast() else { return nil }

        switch container {
        case var .elements(rest):
            guard let element = rest.popFirst() else { return .arrayClose }

            opened.append(.elements(rest))

            return try step(element)

        case var .fields(rest):
            guard let field = rest.popFirst() else { return .recordClose }

            opened.append(.fields(rest))
            pending = field.value

            return .key(field.name)
        }
    }

    // MARK: - Private
    private mutating func step(_ value: Value) throws -> Step {
        switch value {
        case .null:
            return .null

        case let .bool(bool):
            return .bool(bool)

        case let .int(int):
            return .int(int)

        // The bytes could carry these and the value model cannot, in any
        // encoding, so they are refused rather than becoming a document only
        // one encoding reads.
        case let .double(double):
            guard double.isFinite else {
                throw EncodingRefused("a document has no way to carry \(double)")
            }

            return .double(double)

        case let .string(string):
            return .string(string)

        case let .bytes(bytes):
            return .bytes(bytes)

        case let .array(elements):
            try opening()

            if !elements.isEmpty {
                opened.append(.elements(elements[...]))
            }

            return .array(count: elements.count)

        case let .record(record):
            return try opening(Array(zip(record.names, record.values)).map { name, value in (name: name, value: value) }, named: record.name)

        case let .dictionary(held):
            do {
                return try opening(try held.named(), named: nil)
            } catch let refused as ValueRefused {
                throw EncodingRefused(refused.message)
            }

        case .procedure:
            throw EncodingRefused("a procedure is code, and data is what a document spells")
        }
    }

    // Fields under names, with the name of the layout they stood on where
    // there was one. Held in byte order, the order written.
    private mutating func opening(_ fields: [(name: Name, value: Value)], named name: Name?) throws -> Step {
        try opening()

        if !fields.isEmpty {
            opened.append(.fields(fields[...]))
        }

        return .record(name: name, count: fields.count)
    }

    // The same count a reader keeps: containers open around this one, and
    // this one is one more of them. Counted where a container opens, so an
    // empty one past the bound is refused the same as a full one.
    private func opening() throws {
        guard opened.count < Value.nestingBound else {
            throw EncodingRefused("the value nests deeper than a document may")
        }
    }
}

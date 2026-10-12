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
    // A map's entry is `key`, the key's own steps, then the value's; a
    // record's field is `field` and then the value's steps.
    enum Step {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case bytes([UInt8])
        case array(count: Int)
        case map(count: Int)
        case record(name: Name, count: Int)
        case key
        case field(Name)
        case arrayClose
        case mapClose
        case recordClose
    }

    // What is still to go: what a container holds, or the value of an entry
    // whose key is being walked.
    private enum Opened {
        case elements(ArraySlice<Value>)
        case entries(ArraySlice<(key: Value, value: Value)>)
        case fields(ArraySlice<(name: Name, value: Value)>)
        case value(Value)
    }

    // MARK: - Property
    // The value to take apart next: the whole tree first, and then each
    // field's value after its name and each entry's key after its mark.
    private var pending: Value?

    private var opened: [Opened] = []

    // How many containers are open around the next step.
    private var containers = 0

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
            guard let element = rest.popFirst() else { return closing(.arrayClose) }

            opened.append(.elements(rest))

            return try step(element)

        // The value waits beneath the key, so a key that is a container is
        // walked whole before the value it stands for.
        case var .entries(rest):
            guard let entry = rest.popFirst() else { return closing(.mapClose) }

            opened.append(.entries(rest))
            opened.append(.value(entry.value))
            pending = entry.key

            return .key

        case var .fields(rest):
            guard let field = rest.popFirst() else { return closing(.recordClose) }

            opened.append(.fields(rest))
            pending = field.value

            return .field(field.name)

        case let .value(value):
            return try step(value)
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
            try opening(elements.isEmpty ? nil : .elements(elements[...]))

            return .array(count: elements.count)

        // In the key order the map holds them in, which is the order written.
        case let .dictionary(held):
            try opening(held.isEmpty ? nil : .entries(held.entries[...]))

            return .map(count: held.count)

        // In the order the layout holds the names in, which is their bytes'.
        case let .record(record):
            let fields = zip(record.names, record.values).map { name, value in (name: name, value: value) }

            try opening(fields.isEmpty ? nil : .fields(fields[...]))

            return .record(name: record.name, count: fields.count)

        case .procedure:
            throw EncodingRefused("a procedure is code, and data is what a document spells")
        }
    }

    // The same count a reader keeps: containers open around this one, and
    // this one is one more of them. Counted where a container opens, so an
    // empty one past the bound is refused the same as a full one, which
    // closes where it opens and leaves nothing to walk.
    private mutating func opening(_ held: Opened?) throws {
        guard containers < Value.nestingBound else {
            throw EncodingRefused("the value nests deeper than a document may")
        }

        guard let held else { return }

        opened.append(held)
        containers += 1
    }

    private mutating func closing(_ step: Step) -> Step {
        containers -= 1

        return step
    }
}

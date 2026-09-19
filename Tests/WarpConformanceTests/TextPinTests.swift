//
//  TextPinTests.swift
//  WarpConformanceTests
//
//  Created by JSilver
//

import Foundation
import Testing
import Warp
import WarpSyntax

// A text case is read by one reader on both sides, so a reader taking a
// spelling for the wrong value would agree with itself. What breaks that
// circle is a bytes case holding the same value: the specification says every
// value a text case reads appears in some bytes case, and this asks.
@Suite("Every value a text case reads is pinned by bytes")
struct TextPinTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every scalar and every record name a text case reads appears in a bytes case")
    func everyTextValueIsPinned() throws {
        var pinned: [Value] = []
        var pinnedNames: Set<Name> = []
        var unpinned: [String] = []

        for sut in try Case.all() {
            guard case let .encoded(.binary, .spells(value)) = sut.asked else { continue }

            Self.walk(value) { scalar, name in
                if let scalar { pinned.append(scalar) }
                if let name { pinnedNames.insert(name) }
            }
        }

        for sut in try Case.all() {
            guard case let .encoded(.text, reading) = sut.asked else { continue }

            let value: Value

            switch reading {
            case let .reads(read), let .spells(read): value = read
            case .refuses: continue
            }

            Self.walk(value) { scalar, name in
                if let scalar, !pinned.contains(scalar) { unpinned.append("\(sut.name) reads \(scalar)") }
                if let name, !pinnedNames.contains(name) { unpinned.append("\(sut.name) reads a record named \(name)") }
            }
        }

        #expect(unpinned.isEmpty, "no bytes case pins: \(unpinned.joined(separator: ", "))")
    }

    // MARK: - Private
    // Every scalar in a value, and every name a record carries.
    private static func walk(_ value: Value, _ visit: (Value?, Name?) -> Void) {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            visit(value, nil)

        case let .array(elements):
            elements.forEach { element in walk(element, visit) }

        case let .dictionary(entries):
            entries.entries.forEach { entry in walk(entry.value, visit) }

        case let .record(record):
            visit(nil, record.name)
            record.values.forEach { held in walk(held, visit) }
        }
    }
}

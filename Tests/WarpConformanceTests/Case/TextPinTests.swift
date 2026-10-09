//
//  TextPinTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 9/20/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// A text case is read by one reader on both sides, so a reader taking a
// spelling for the wrong value would agree with itself. What breaks that
// circle is a bytes case holding the same spelling: the specification says
// every scalar and every name a text case reads appears in some bytes case,
// and this asks. A container's structure is not a spelling.
@Suite("Every scalar and every name a text case reads is pinned by bytes")
struct TextPinTests {
    // What a text spells and a reader could take wrongly: a scalar, or a
    // name, whether a record's or a field's.
    private enum Spelling: Equatable, CustomStringConvertible {
        case scalar(Value)
        case name(Name)

        // MARK: - Property
        var description: String {
            switch self {
            case let .scalar(value): "\(value)"
            case let .name(name): "the name \(name)"
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every scalar and every name a text case reads appears in a bytes case")
    func everyTextValueIsPinned() throws {
        let cases = try Case.all()
        var pinned: [Spelling] = []
        var unpinned: [String] = []

        for sut in cases {
            guard case let .encoded(.binary, .spells(value)) = sut.asked else { continue }

            Self.walk(value) { spelling in pinned.append(spelling) }
        }

        for sut in cases {
            guard case let .encoded(.text, reading) = sut.asked else { continue }

            let value: Value

            switch reading {
            case let .reads(read), let .spells(read): value = read
            case .refuses: continue
            }

            Self.walk(value) { spelling in
                if !pinned.contains(spelling) { unpinned.append("\(sut.name) reads \(spelling)") }
            }
        }

        #expect(unpinned.isEmpty, "no bytes case pins: \(unpinned.joined(separator: ", "))")
    }

    // MARK: - Public
    // MARK: - Private
    private static func walk(_ value: Value, _ visit: (Spelling) -> Void) {
        switch value {
        case .null, .bool, .int, .double, .string, .bytes, .procedure:
            visit(.scalar(value))

        case let .array(elements):
            elements.forEach { element in walk(element, visit) }

        case let .dictionary(entries):
            entries.entries.forEach { entry in
                visit(.name(entry.name))
                walk(entry.value, visit)
            }

        case let .record(record):
            if let name = record.name { visit(.name(name)) }
            record.names.forEach { name in visit(.name(name)) }
            record.values.forEach { held in walk(held, visit) }
        }
    }
}

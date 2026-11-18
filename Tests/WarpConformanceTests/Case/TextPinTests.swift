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
    // What a text spells and a reader could take wrongly: a scalar, a dictionary's
    // keys among them, or a name, whether a struct's or a field's. Two
    // scalars are one spelling where the binary writes them alike, since a
    // value's sameness takes `-0.0` for `0.0` and a decomposed string for the
    // composed one, and those are two spellings.
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
        static func == (lhs: Spelling, rhs: Spelling) -> Bool {
            switch (lhs, rhs) {
            case let (.scalar(left), .scalar(right)):
                (try? BinaryEncoding().data(from: left)) == (try? BinaryEncoding().data(from: right))

            case let (.name(left), .name(right)):
                left == right

            case (.scalar, .name), (.name, .scalar):
                false
            }
        }

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

        case let .dictionary(dictionary):
            dictionary.entries.forEach { entry in
                walk(entry.key, visit)
                walk(entry.value, visit)
            }

        case let .struct(instance):
            visit(.name(instance.name))
            instance.names.forEach { name in visit(.name(name)) }
            instance.values.forEach { held in walk(held, visit) }

        case let .existential(existential):
            walk(existential.value, visit)
        }
    }
}

//
//  NumberSpellingTests.swift
//  WarpTests
//
//  Created by JSilver on 8/24/26.
//

import Foundation
import Testing
@testable import Warp

// The spellings of a number: every judge that meets a spelled number reads
// through these, so the edges are pinned here once.
@Suite("Number spellings")
struct NumberSpellingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a Double's spelling follows the document's form rule")
    func doubleSpellingFollowsTheFormRule() {
        // When / Then. The point form inside -5 < k < 16, the exponent form
        // outside, and the exponent signed with two digits at least.
        #expect(Double(1e15).spelling == "1000000000000000.0")
        #expect(Double(1e16).spelling == "1e+16")
        #expect(Double(1e-4).spelling == "0.0001")
        #expect(Double(1e-5).spelling == "1e-05")
        #expect(Double(1e300).spelling == "1e+300")
        #expect(Double(5e-324).spelling == "5e-324")
        #expect(Double(-0.0).spelling == "-0.0")
        #expect(Double(0.0).spelling == "0.0")
        #expect(Double(12345.678).spelling == "12345.678")
        #expect(Double.infinity.spelling == nil)
        #expect(Double.nan.spelling == nil)

        // The digits are the host's shortest round-trip rendering, so where the
        // host already writes the document's form the two agree. A drift here
        // would be this file re-deciding the digits.
        for value in [
            0.1, 1.5, -2.25, 1.0 / 3.0, 6.02214076e23, -1.7976931348623157e308,
            9007199254740993.0, 0.30000000000000004, 2.2250738585072014e-308
        ] {
            #expect(value.spelling == "\(value)", "\(value)")
        }
    }

    @Test("one value, one spelling")
    func spellingIsCanonical() {
        // When / Then
        #expect(Int(spelling: "0") == 0)
        #expect(Int(spelling: "-1") == -1)
        #expect(Int(spelling: "9223372036854775807") == Int.max)
        #expect(Int(spelling: "-9223372036854775808") == Int.min)

        // Aliases of numbers that already have a spelling, and spellings of
        // numbers no int holds.
        #expect(Int(spelling: "+1") == nil)
        #expect(Int(spelling: "007") == nil)
        #expect(Int(spelling: "-0") == nil)
        #expect(Int(spelling: "") == nil)
        #expect(Int(spelling: "-") == nil)
        #expect(Int(spelling: "1_0") == nil)
        #expect(Int(spelling: "9223372036854775808") == nil)

        // The reading behind the door tells the two misses apart: an alias
        // is not the one spelling, and the one spelling of a number past the
        // int is exactly that.
        #expect({ if case .notOneSpelling = IntSpelling("-0") { true } else { false } }())
        #expect({ if case .notOneSpelling = IntSpelling("007") { true } else { false } }())
        #expect({ if case .overflow = IntSpelling("9223372036854775808") { true } else { false } }())
        #expect({ if case .overflow = IntSpelling("-9223372036854775809") { true } else { false } }())

        // The `Double` door holds the same line.
        #expect(Double(spelling: "1.5") == 1.5)
        #expect(Double(spelling: "1e-05") == 1e-5)
        #expect(Double(spelling: "1") == nil)
        #expect(Double(spelling: "1e0") == nil)
        #expect(Double(spelling: "1.50") == nil)
        #expect(Double(spelling: "inf") == nil)
    }

    // MARK: - Public
    // MARK: - Private
}

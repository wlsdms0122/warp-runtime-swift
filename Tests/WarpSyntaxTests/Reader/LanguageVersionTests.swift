//
//  LanguageVersionTests.swift
//  WarpSyntaxTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Testing
@testable import WarpSyntax

@Suite("The version a document is written for")
struct LanguageVersionTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a version is its major and its minor", arguments: [
        ("0.1", 0, 1),
        ("0.0", 0, 0),
        ("1.4", 1, 4),
        ("10.20", 10, 20)
    ])
    func readsMajorAndMinor(spelling: String, major: Int, minor: Int) throws {
        // When
        let sut = try #require(LanguageVersion(spelling))

        // Then
        #expect(sut == LanguageVersion(major: major, minor: minor))
        #expect(sut.description == spelling)
    }

    @Test("any other spelling is no version", arguments: [
        "", "1", "0.1.0", "v0.1", "0.01", "01.1", "+0.1", "-0.1", "0.", ".1", "0..1", " 0.1", "0.1 ", "١.٢", "0.99999999999999999999"
    ])
    func refusesAnyOtherSpelling(spelling: String) {
        // When
        let sut = LanguageVersion(spelling)

        // Then
        #expect(sut == nil)
    }

    @Test("a reader reads its major up to its own minor", arguments: [
        ("1.0", true),
        ("1.4", true),
        ("1.5", false),
        ("2.0", false),
        ("0.4", false)
    ])
    func readsItsMajorUpToItsMinor(spelling: String, reads: Bool) throws {
        // Given
        let sut = LanguageVersion(major: 1, minor: 4)

        // When
        let read = sut.reads(try #require(LanguageVersion(spelling)))

        // Then
        #expect(read == reads)
    }

    @Test("under major 0 a reader reads its major up to its own minor too", arguments: [
        ("0.0", true),
        ("0.1", true),
        ("0.2", false),
        ("1.1", false)
    ])
    func readsUpToItsMinorUnderMajorZero(spelling: String, reads: Bool) throws {
        // Given
        let sut = LanguageVersion(major: 0, minor: 1)

        // When
        let read = sut.reads(try #require(LanguageVersion(spelling)))

        // Then
        #expect(read == reads)
    }

    // MARK: - Public
    // MARK: - Private
}

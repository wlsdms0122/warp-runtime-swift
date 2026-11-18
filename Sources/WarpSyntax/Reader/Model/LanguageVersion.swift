//
//  LanguageVersion.swift
//  WarpSyntax
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// The version a document says it is written for: the major and the minor of
// the release of the language it was written to, spelled `<major>.<minor>`.
struct LanguageVersion: Equatable, Sendable, CustomStringConvertible {
    // MARK: - Property
    let major: Int
    let minor: Int

    var description: String { "\(major).\(minor)" }

    // MARK: - Initializer
    init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    // Each part in decimal digits with no sign and no leading zero, and
    // nothing for any other spelling.
    init?(_ spelling: String) {
        let parts = spelling.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 2, let major = Self.part(parts[0]), let minor = Self.part(parts[1]) else {
            return nil
        }

        self.init(major: major, minor: minor)
    }

    // MARK: - Public
    // Whether a reader of this version reads a document written for
    // `version`: one of its major and a minor no later than its own.
    func reads(_ version: LanguageVersion) -> Bool {
        version.major == major && version.minor <= minor
    }

    // MARK: - Private
    private static func part(_ digits: Substring) -> Int? {
        guard !digits.isEmpty, digits.utf8.allSatisfy({ byte in (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) }) else {
            return nil
        }

        guard digits == "0" || digits.first != "0" else { return nil }

        return Int(digits)
    }
}

//
//  RuntimeVersionTests.swift
//  WarpTests
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Testing
@testable import Warp

// Whether the stamp an object carries says the release this is.
//
// The number lives in one file a person edits and the stamp is written from it,
// so the two can differ. This is what stops them differing quietly: a stamp
// that fell behind is a build handing out objects under a release it is not.
@Suite("The stamp an object carries")
struct RuntimeVersionTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("says the release this package is")
    func saysTheRelease() throws {
        // Given. The number as the one file holding it writes it.
        let package = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let release = try String(contentsOf: package.appending(path: "version"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // When / Then. The commit beside it is the release script's and is only
        // there where one was cut, so what is held is the opening.
        #expect(
            Compiled.runtime.hasPrefix("warp-swift \(release)"),
            "the object stamp is '\(Compiled.runtime)' and this package is \(release)"
        )
    }
}

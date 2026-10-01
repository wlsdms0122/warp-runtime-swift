//
//  CaseTests.swift
//  WarpConformanceTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
import Testing
import Warp
import WarpSyntax

// What a runner refuses as a case. No case can ask this, since a file the
// runner refuses stops the suite, so it is asked here of a case written for it.
@Suite("A case the runner refuses")
struct CaseTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("is refused where a document laid beside its program does not read")
    func aLaidDocumentThatDoesNotRead() throws {
        // Given. A case expecting the build to refuse, beside a document that
        // writes a key no document has.
        let sut = try TextEncoding().value(from: """
            warpt 1
            {
              documents [
                {
                  bogus 1
                  imports []
                  procedures {}
                  warp 1
                }
              ]
              expect {
                refuses "build"
              }
              name "broken"
              note "a document beside the program that does not read"
              program {
                imports []
                procedures {
                  entry {
                    access "public"
                    result 1
                  }
                }
                warp 1
              }
              test 1
            }
            """)

        // When / Then.
        #expect {
            try Case(from: sut, in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains("a document laid beside the program does not read")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

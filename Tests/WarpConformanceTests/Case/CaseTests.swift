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

    @Test("is refused where a procedure it asks for declares a place other than first and second")
    func aBroughtProcedureNamingAnotherPlace() async throws {
        // Given. A procedure the runner brings whose one parameter is not
        // called `first`.
        let sut = try Case(from: try TextEncoding().value(from: """
            warpt 1
            {
              expect {
                answers 1
              }
              name "broken"
              note "a brought procedure naming a place no runner has"
              program {
                imports [
                  "app.one"
                ]
                procedures {
                  entry {
                    access "public"
                    result {
                      call {
                        arguments [
                          1
                        ]
                        procedure "app.one"
                      }
                    }
                  }
                }
                warp 1
              }
              test 1
              vocabulary {
                procedures {
                  "app.one" {
                    access "public"
                    answers 1
                    parameters [
                      {
                        name "it"
                        type "int"
                      }
                    ]
                    returns "int"
                  }
                }
              }
            }
            """), in: "broken")

        guard case let .program(program) = sut.asked else {
            Issue.record("a case with a program asks about a program")

            return
        }

        // When / Then.
        await #expect {
            try await program.brought
        } throws: { error in
            error is ConformanceError && "\(error)".contains("the places a case may name are `first` and `second`")
        }
    }

    @Test("is refused where it writes a key its subject cannot use", arguments: [
        ("object {}", "documents [\n    {}\n  ]", "a case about an object writes `documents`"),
        ("bytes x\"57415250010700\"", "documents [\n    {}\n  ]", "a case about an encoding writes `documents`"),
        ("text \"warpt 1\\n{}\\n\"", "document x\"00\"", "a case about an encoding writes `document`"),
        ("program {\n    imports []\n    procedures {}\n    warp 1\n  }", "document x\"00\"", "a case about a program writes `document`")
    ])
    func aKeyItsSubjectCannotUse(subject: String, key: String, refusal: String) throws {
        // Given. A case whose subject is read and nothing more, beside a key
        // only another subject is asked with.
        let sut = try TextEncoding().value(from: """
            warpt 1
            {
              \(key)
              expect {
                refuses "load"
              }
              name "broken"
              note "a key its subject cannot use"
              \(subject)
              test 1
            }
            """)

        // When / Then.
        #expect {
            try Case(from: sut, in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains(refusal)
        }
    }

    @Test("is failed where a failure escapes the entry, and a refusal still matches", arguments: [
        ("std.control.abort", "\"on purpose\"", Case.Stage?.none),
        ("std.math.dividedBy", "1\n                          0", Case.Stage.run)
    ])
    func aFailureThatEscapes(procedure: String, arguments: String, reached: Case.Stage?) async throws {
        // Given. A case expecting the run to refuse, whose entry either raises
        // a failure nothing rescues or is refused by the run.
        let sut = try Case(from: try TextEncoding().value(from: """
            warpt 1
            {
              expect {
                refuses "run"
              }
              name "escaping"
              note "a failure escaping the entry"
              program {
                imports [
                  "\(procedure)"
                ]
                procedures {
                  entry {
                    access "public"
                    result {
                      call {
                        arguments [
                          \(arguments)
                        ]
                        procedure "\(procedure)"
                      }
                    }
                  }
                }
                warp 1
              }
              test 1
            }
            """), in: "escaping")

        guard case let .program(program) = sut.asked else {
            Issue.record("a case with a program asks about a program")

            return
        }

        // When / Then. A failure matches no stage, and a refusal is the run's.
        guard let reached else {
            await #expect {
                try await ConformanceTests().reached(program)
            } throws: { error in
                error is ConformanceError && "\(error)".contains("a failure escaped the entry: aborted: on purpose")
            }

            return
        }

        #expect(try await ConformanceTests().reached(program) == reached)
    }

    // MARK: - Public
    // MARK: - Private
}

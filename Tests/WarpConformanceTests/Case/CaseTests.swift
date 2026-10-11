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

// What a runner refuses as a case, and a case it fails. No case can ask this,
// since a file the runner refuses stops the suite, so it is asked here of a
// case written for it.
@Suite("A case the runner refuses or fails")
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

        // When / Then
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
                  "App.one"
                ]
                procedures {
                  entry {
                    access "public"
                    result {
                      call {
                        arguments [
                          1
                        ]
                        procedure "App.one"
                      }
                    }
                  }
                }
                warp 1
              }
              test 1
              vocabulary {
                procedures {
                  "App.one" {
                    access "public"
                    answers 1
                    parameters [
                      {
                        name "it"
                        type "Int"
                      }
                    ]
                    returns "Int"
                  }
                }
              }
            }
            """), in: "broken")

        guard case let .program(program) = sut.asked else {
            Issue.record("a case with a program asks about a program")

            return
        }

        // When / Then
        await #expect {
            try await program.brought
        } throws: { error in
            error is ConformanceError && "\(error)".contains("the places a case may name are `first` and `second`")
        }
    }

    @Test("is refused where its vocabulary writes what a vocabulary does not declare", arguments: [
        "warp 1", "imports []", "const {\n      k 1\n    }", "var {\n      v 2\n    }", "description \"d\""
    ])
    func aVocabularyKeyItDoesNotDeclare(key: String) throws {
        // When / Then. The runner builds the host's module from what a
        // vocabulary declares, so a key it would not read is refused rather
        // than dropped
        #expect {
            try Case(from: try TextEncoding().value(from: """
                warpt 1
                {
                  expect {
                    answers 1
                  }
                  name "broken"
                  note "a vocabulary writing a key it does not declare"
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
                  vocabulary {
                    \(key)
                    procedures {}
                  }
                }
                """), in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains("A vocabulary declares `types`")
        }
    }

    @Test("is refused where it writes a key its subject cannot use", arguments: [
        ("object {}", "documents [\n    {}\n  ]", "a case about an object writes `documents`"),
        ("bytes x\"57415250010700\"", "documents [\n    {}\n  ]", "a case about an encoding writes `documents`"),
        ("text \"warpt 1\\n{}\\n\"", "document x\"00\"", "a case about an encoding writes `document`"),
        ("program {\n    imports []\n    warp 1\n  }", "document x\"00\"", "a case about a program writes `document`"),
        ("program {\n    imports []\n    warp 1\n  }", "argument {}", "a case about a program writes `argument`")
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

        // When / Then
        #expect {
            try Case(from: sut, in: "broken")
        } throws: { error in
            error is ConformanceError && "\(error)".contains(refusal)
        }
    }

    @Test("is failed where a failure escapes the entry, and a refusal still matches", arguments: [
        ("Standard.Control.abort", "\"on purpose\"", Case.Stage?.none),
        ("Standard.Numeric.dividedBy", "1\n                          0", Case.Stage.run)
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

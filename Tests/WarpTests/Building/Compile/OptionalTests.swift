//
//  OptionalTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// `T?`, the Optional of the declared type, and the `?.` that reads through it.
@Suite("An Optional")
struct OptionalTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an Optional reading is refused where the plain type is declared")
    func anOptionalReadingIsRefusedAtACall() async throws {
        // Given. The `?.` path gives `Int?`, and the callee declares `Int`
        let sut = try Module(
            types: ["App.Task": .struct(["size": .int])],
            procedures: [
                "half": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "of", type: .int)],
                        returns: .int
                    ),
                    body: [returning(.literal(.int(0)))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .optional(.named("App.Task")))
                        ],
                        returns: .int
                    ),
                    body: [
                        Statement(binding: .constant("read"), expression: .reference([.name("task"), .name("size", optional: true)])),
                        returning(.call(Call(selector: "half", arguments: [.reference([.name("read")])])))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("holds Int?")
        }
    }

    @Test("the optional dot on a struct field reads it, and its value may be null")
    func anOptionalDotOverAnOptional() async throws {
        // Given. The struct may be null, so `?.` is the only spelling that
        // builds; what it gives is the field or null
        let sut = try Module(
            types: ["App.Task": .struct(["size": .int])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .optional(.named("App.Task")))
                        ],
                        returns: .optional(.int)
                    ),
                    body: [returning(.reference([.name("task"), .name("size", optional: true)]))]
                )
            ]
        )

        // When / Then. The value that arrived reads its field, and the null the
        // host handed gives null
        #expect(try await run(sut, arguments: ["task": .struct(Struct(name: "App.Task", ["size": .int(7)]))]) == .int(7))
        #expect(try await run(sut, arguments: ["task": .null]) == .null)
    }

    @Test("a name that is statically null is not read through")
    func aStaticNullRefusesTheRead() async throws {
        // Given. The binding holds null and nothing else, so every dot after it
        // reads through null and the build says so
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [
                        Statement(binding: .constant("gone"), expression: .literal(.null)),
                        returning(.reference([.name("gone"), .name("name")]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("reads through null")
        }
    }

    @Test("an Optional parameter takes null, and nothing given is refused")
    func anOptionalParameterTakesNullByType() async throws {
        // Given. `T?` says null is a value, so the door lets it in the way
        // the build does
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "limit", type: .optional(.int))],
                        returns: .optional(.int)
                    ),
                    body: [returning(.reference([.name("limit")]))]
                )
            ]
        )

        // When / Then. A value arrives as itself and a null as null. A
        // parameter given nothing is refused, Optional or not
        #expect(try await run(sut, arguments: ["limit": .int(5)]) == .int(5))
        #expect(try await run(sut, arguments: ["limit": .null]) == .null)
        await #expect {
            try await run(sut)
        } throws: { error in
            "\(error)".contains("entry 'entry' was given nothing for 'limit'")
        }

        // A plain typed parameter still means "give me something".
        let plain = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "limit", type: .int)],
                        returns: .int
                    ),
                    body: [returning(.reference([.name("limit")]))]
                )
            ]
        )

        await #expect {
            try await run(plain)
        } throws: { error in
            error is ArgumentError && "\(error)".contains("entry 'entry' was given nothing for 'limit'")
        }
    }

    @Test("a written call leaving out an Optional argument is refused")
    func anOptionalArgumentLeftOutIsRefused() async throws {
        // Given
        let sut = try Module(
            procedures: [
                "labelled": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "of", type: .string),
                            Parameter(name: "limit", type: .optional(.int))
                        ],
                        returns: .string
                    ),
                    body: [returning(.reference([.name("of")]))]
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "text", type: .string)],
                        returns: .string
                    ),
                    body: [
                        Statement(binding: .constant("called"), expression: .call(Call(
                            selector: "labelled",
                            arguments: [.reference([.name("text")])]
                        ))),
                        returning(.reference([.name("called")]))
                    ]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("sending 'labelled' with 1 arguments, and it takes 2")
        }
    }

    @Test("a constant's dots are judged like a body's")
    func aConstantPathIsJudged() async throws {
        // Given. The constant is a struct, so a field it does not carry is the
        // build's refusal, not a run's surprise
        let sut = try Module(
            types: ["App.Config": .struct(["host": .string])],
            constants: ["config": .cast(.struct(["host": .literal(.string("a"))]), as: .named("App.Config"), optional: false)],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [returning(.reference([.name("config"), .name("port")]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("does not declare")
        }
    }

    @Test("what an Optional unwraps to is judged like any other type")
    func anUnwrapIsJudgedAgain() async throws {
        // Given. `Task?` unwraps to a declared struct through its name, and the
        // struct's rules hold after the unwrap: the declared field reads, the
        // undeclared one refuses
        let sut = try Module(
            types: ["Task": .struct(["name": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .optional(.named("Task")))
                        ],
                        returns: .optional(.string)
                    ),
                    body: [returning(.reference([.name("task"), .name("name", optional: true)]))]
                )
            ]
        )

        // When / Then
        #expect(
            try await run(sut, arguments: ["task": .struct(Struct(name: "Task", ["name": .string("a")]))])
                == .string("a")
        )
        #expect(try await run(sut, arguments: ["task": .null]) == .null)
    }

    @Test("a ?. that could not have read past anything is refused")
    func aNeedlessOptionalDotIsRefused() async throws {
        // Given. The field is proven present, so the spelling that expects
        // absence says nothing, the way `Int??` says nothing on a type
        let onAField = try Module(
            types: ["App.Task": .struct(["id": .string])],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "task", type: .named("App.Task"))
                        ]
                    ),
                    body: [returning(.reference([.name("task"), .name("id", optional: true)]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([onAField] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("read with `.`")
        }
    }

    @Test("a plain index into an Optional refuses toward the optional bracket")
    func aPlainIndexIntoAnOptionalRefuses() async throws {
        // Given. The array may be null, and `[` does not read absence; the
        // refusal points at the spelling that does
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .optional(.array(.string)))
                        ]
                    ),
                    body: [returning(.reference([.name("items"), .index(0)]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("Absence is read with `?[`")
        }
    }

    @Test("the optional index reads an Optional array")
    func anOptionalIndexOverAnOptional() async throws {
        // Given. An array or null; `?[0]` reads the element that arrived and
        // gives null for the null, so the path's type is an Optional
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .optional(.array(.string)))
                        ],
                        returns: .optional(.string)
                    ),
                    body: [returning(.reference([.name("items"), .index(0, optional: true)]))]
                )
            ]
        )

        // When / Then
        #expect(try await run(
            sut,
            arguments: ["items": .array([.string("first")])]
        ) == .string("first"))
        #expect(try await run(sut, arguments: ["items": .null]) == .null)
    }

    @Test("the optional index does not read past the end")
    func anOptionalIndexStillRefusesPastTheEnd() async throws {
        // Given. `?[` expects the array's absence, not the element's: past the
        // end is a defect the array's own length proves, `?[` or not
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .optional(.array(.string)))
                        ],
                        returns: .optional(.string)
                    ),
                    body: [returning(.reference([.name("items"), .index(5, optional: true)]))]
                )
            ]
        )

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await run(sut, arguments: ["items": .array([.string("only")])])
        }
    }

    @Test("a needless optional index is refused at the build")
    func aNeedlessOptionalIndexRefuses() async throws {
        // Given. The array is proven non-null, so `?[` claims an absence the
        // types rule out, the way a needless `?.` does
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "items", type: .array(.string))
                        ]
                    ),
                    body: [returning(.reference([.name("items"), .index(0, optional: true)]))]
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("never null")
        }
    }

    @Test("an optional index reference reads its name at the exit that indexes")
    func anOptionalIndexReferenceOverAnOptional() async throws {
        // Given. `items?[i]`: the index is a name the run reads, and the null
        // that short-circuits before it never reads the name at all
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [
                            Parameter(name: "i", type: .int),
                            Parameter(name: "items", type: .optional(.array(.string)))
                        ],
                        returns: .optional(.string)
                    ),
                    body: [
                        returning(.reference([
                            .name("items"),
                            .indexRef([.name("i")], optional: true)
                        ]))
                    ]
                )
            ]
        )

        // When / Then
        #expect(try await run(
            sut,
            arguments: ["i": .int(1), "items": .array([.string("a"), .string("b")])]
        ) == .string("b"))
        #expect(try await run(sut, arguments: ["i": .int(1), "items": .null]) == .null)
    }

    // MARK: - Public
    // MARK: - Private
}

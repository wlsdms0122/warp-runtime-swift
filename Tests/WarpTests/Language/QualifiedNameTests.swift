//
//  QualifiedNameTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp

// Type and constraint names carry their module the way procedure names do, and
// a mention is the declared spelling, written out: `store.Task` inside `store`
// too, and `Task` only for a declaration in the shared space. These are the
// places that rule decides something, and the places it refuses, because a
// spelling no module declares names nothing.
@Suite("A type name carries its module")
struct QualifiedNameTests {
    // MARK: - Property
    private let linker = Linker()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a type name is its qualified spelling, in the declaring module too")
    func aTypeNameIsItsQualifiedSpelling() async throws {
        // Given — `store` declares `Task`, and both `store` and the entry
        // module mention it as `store.Task`
        let store = try Module(
            namespace: "store",
            types: ["Task": .record(["id": .string])],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: ["value": Parameter(type: .named("store.Task"))],
                        returns: .named("store.Task")
                    ),
                    body: [],
                    result: reference("value")
                )
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("store.Task")),
                    body: [],
                    result: .dispatch(Dispatch(
                        selector: "store.keep",
                        arguments: ["value": .literal(.object(["id": .string("a")]))]
                    ))
                )
            ]
        )

        // When
        let image = try linker.link([sut, store] + Module.standard, entry: entryName)

        // Then — the declaration is under the qualified spelling alone
        #expect(image.types.resolve("store.Task") == .record(["id": .string]))
        #expect(image.types.resolve("Task") == nil)
    }

    @Test("a module names its own type by its qualified spelling")
    func ownTypeIsNamedQualified() async throws {
        // Given — two modules declare `Limit`, and `mine` mentions its own as
        // `mine.Limit` from inside: an int, where the other module's is a string
        let mine = try Module(
            namespace: "mine",
            types: ["Limit": .int],
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("mine.Limit")),
                    body: [],
                    result: .literal(.int(3))
                )
            ]
        )
        let theirs = try Module(
            namespace: "theirs",
            types: ["Limit": .string],
            procedures: [
                "unrelated": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then — `mine.entry` answers an int, which `mine.Limit` admits
        let answer = try await run([mine, theirs], entry: "mine.\(entryName)")

        #expect(answer == .int(3))
    }

    @Test("a bare name is not a spelling of any qualified declaration")
    func aBareNameSpellsNoQualifiedDeclaration() throws {
        // Given — two modules declare `one.Limit` and `two.Limit`, and a third
        // mentions `Limit`, which neither of those spellings is
        let one = try Module(
            namespace: "one",
            types: ["Limit": .int],
            procedures: [
                "a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            namespace: "two",
            types: ["Limit": .string],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("Limit")),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        #expect {
            try linker.link([sut, one, two], entry: entryName)
        } throws: { error in
            error is LinkError
                && "\(error)".contains("names type 'Limit', which no module in this link declares")
        }
    }

    @Test("the qualified spelling says which, where the bare one cannot")
    func theQualifiedSpellingResolvesTheTie() async throws {
        // Given — the same link, with the mention spelled out
        let one = try Module(
            namespace: "one",
            types: ["Limit": .int],
            procedures: [
                "a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            namespace: "two",
            types: ["Limit": .string],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("one.Limit")),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        let answer = try await run([sut, one, two], vocabulary: [])

        #expect(answer == .int(1))
    }

    @Test("two modules declaring one qualified name still refuse")
    func oneQualifiedNameDeclaredTwiceRefuses() throws {
        // Given — two unnamed modules declare into the shared space, so the
        // qualified names collide the way two `.c` files' symbols do
        let one = try Module(
            types: ["Limit": .int],
            procedures: [
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            types: ["Limit": .string],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then
        #expect {
            try linker.link([one, two], entry: entryName)
        } throws: { error in
            error is LinkError && "\(error)".contains("declared more than once")
        }
    }

    @Test("a constraint is named by its qualified spelling")
    func aConstraintIsNamedQualified() async throws {
        // Given — `std` declares `Comparable`, and a document-shaped module
        // bounds its own parameter with that spelling, `std.Comparable`
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "value": Parameter(type: .variable(name: "T", constraint: "std.Comparable"))
                        ],
                        returns: .variable(name: "T", constraint: "std.Comparable")
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .dispatch(Dispatch(
                        selector: "keep",
                        arguments: ["value": .literal(.int(3))]
                    ))
                )
            ]
        )

        // When / Then
        let answer = try await run(sut)

        #expect(answer == .int(3))
    }

    @Test("sorting what Comparable does not admit refuses at the link")
    func sortingTheUnorderableRefuses() throws {
        // Given — `sorted` is bounded by the shared ground's `Comparable`,
        // and booleans are a reading the link can see
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.array([.bool(true), .bool(false)])),
                        selector: "std.collection.sorted"
                    ))
                )
            ]
        )

        // When / Then
        #expect {
            try linker.link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is LinkError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("a shared-space declaration's bare name is its qualified spelling")
    func aSharedSpaceDeclarationAnswersExactly() async throws {
        // Given — an unnamed module declares `Limit` into the shared space, a
        // named module declares `one.Limit`, and a third module mentions
        // `Limit`: the shared declaration's spelling, and nothing else's
        let shared = try Module(
            types: ["Limit": .int],
            procedures: [
                "a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let named = try Module(
            namespace: "one",
            types: ["Limit": .string],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .named("Limit")),
                    body: [],
                    result: .literal(.int(3))
                )
            ]
        )

        // When / Then — an int answers, which only the shared `Limit` admits
        let answer = try await run([sut, shared, named], vocabulary: [])

        #expect(answer == .int(3))
    }

    @Test("min without a receiver refuses in its own words")
    func minWithoutAReceiverRefusesInItsOwnWords() async throws {
        // Given — the receiver is a reference that reads null, which a word
        // is sent as nothing
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["absent": Parameter(type: .any, default: .null)]
                    ),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: reference("absent"),
                        selector: "std.math.min",
                        arguments: ["value": .literal(.int(1))]
                    ))
                )
            ]
        )

        // When / Then — the refusal is the ordering word's own, not
        // arithmetic's
        await #expect {
            try await run(sut)
        } throws: { error in
            "\(error)".contains("nothing arrived to order")
        }
    }

    @Test("a name declared as a type and a constraint refuses in either order")
    func aCrossSpaceCollisionRefusesInEitherOrder() throws {
        // Given — one module declares `Limit` as a constraint, another as a
        // type, both into the shared space
        let membership = try Module(
            constraints: ["Limit": [.int]],
            procedures: [
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let shape = try Module(
            types: ["Limit": .int],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then — the link sees its whole world at once, so the order
        // the caller listed the modules cannot change the conclusion
        for modules in [[membership, shape], [shape, membership]] {
            #expect {
                try linker.link(modules, entry: entryName)
            } throws: { error in
                error is LinkError && "\(error)".contains("both a type and a constraint")
            }
        }
    }

    @Test("a document's bare constraint does not capture what std meant")
    func aBareDeclarationDoesNotCaptureTheStandardName() async throws {
        // Given — an unnamed module declares its own `Numeric`, admitting
        // text, and still leans on std.math for arithmetic
        let sut = try Module(
            constraints: ["Numeric": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "value": Parameter(type: .variable(name: "T", constraint: "Numeric"))
                        ],
                        returns: .variable(name: "T", constraint: "Numeric")
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(returns: .string),
                    body: [
                        Statement(
                            id: "kept",
                            expression: .dispatch(Dispatch(
                                selector: "keep",
                                arguments: ["value": .literal(.string("a"))]
                            ))
                        )
                    ],
                    result: reference("kept")
                )
            ]
        )

        // When / Then — the module's own bound reads its own declaration, and
        // text passes it
        let answer = try await run(sut)

        #expect(answer == .string("a"))

        // And std.math's arithmetic still reads std's declaration: two pieces
        // of text refuse exactly as they do without the document's `Numeric`
        let arithmetic = try Module(
            constraints: ["Numeric": [.string]],
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.string("a")),
                        selector: "std.math.plus",
                        arguments: ["value": .literal(.string("b"))]
                    ))
                )
            ]
        )

        #expect {
            try linker.link([arithmetic] + Module.standard, entry: entryName)
        } throws: { error in
            error is LinkError && "\(error)".contains("'std.Numeric' does not admit")
        }
    }

    @Test("min and max order the way the comparison words do")
    func minAndMaxOrderLikeTheComparisons() async throws {
        // Given — strings order lexicographically under Comparable, which
        // bounds `min` the way it bounds `lessThan`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .string),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.string("b")),
                        selector: "std.math.min",
                        arguments: ["value": .literal(.string("a"))]
                    ))
                )
            ]
        )

        // When / Then
        let answer = try await run(sut)

        #expect(answer == .string("a"))
    }

    @Test("a bundle mentioning the shared constraints needs std in the link")
    func aBundleNeedsTheSharedGround() throws {
        // Given — collection's `sorted` mentions `Comparable`, which only the
        // foundation module declares
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: .literal(.array([.int(2), .int(1)])),
                        selector: "std.collection.sorted"
                    ))
                )
            ]
        )

        // When / Then — without the foundation the constraint name resolves to
        // nothing, and the declaration that mentions it is refused
        #expect {
            try linker.link([sut, .collection], entry: entryName)
        } throws: { error in
            error is LinkError && "\(error)".contains("names constraint 'std.Comparable'")
        }

        #expect(throws: Never.self) {
            try linker.link([sut, .collection, .foundation], entry: entryName)
        }
    }
}

//
//  DeclaredSpellingTests.swift
//  WarpTests
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Testing
@testable import Warp
import WarpStandard

// A type or constraint name is the spelling it was declared under, dot and
// all, and a mention is that spelling written out. These are the places that
// rule decides something, and the places it refuses, because a spelling no
// module declares names nothing.
@Suite("A type name is its declared spelling")
struct DeclaredSpellingTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a type name is its declared spelling, in the declaring module too")
    func aTypeNameIsItsQualifiedSpelling() async throws {
        // Given. `store` declares `Task`, and both `store` and the entry module
        // mention it as `store.Task`
        let store = try Module(
            types: ["store.Task": .record(["id": .string])],
            procedures: [
                "store.keep": Procedure(
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
                    result: .call(Call(
                        selector: "store.keep",
                        arguments: ["value": .literal(.dictionary(["id": .string("a")]))]
                    ))
                )
            ]
        )

        // When
        let image = try await builder.build([sut, store] + Module.standard, entry: entryName)

        // Then. The declaration is under the declared spelling alone
        #expect(image.types.resolve("store.Task") == .record(["id": .string]))
        #expect(image.types.resolve("Task") == nil)
    }

    @Test("a module names its own type by its declared spelling")
    func ownTypeIsNamedByItsSpelling() async throws {
        // Given. Two modules declare a `Limit`, and `mine` mentions its own as
        // `mine.Limit` from inside: an int, where the other module's is a
        // string
        let mine = try Module(
            types: ["mine.Limit": .int],
            procedures: [
                try Name("mine.\(entryName)"): Procedure(
                    signature: Signature(returns: .named("mine.Limit")),
                    body: [],
                    result: .literal(.int(3))
                )
            ]
        )
        let theirs = try Module(
            types: ["theirs.Limit": .string],
            procedures: [
                "theirs.unrelated": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then. `mine.entry` answers an int, which `mine.Limit` admits
        let answer = try await run([mine, theirs], entry: try Name("mine.\(entryName)"))

        #expect(answer == .int(3))
    }

    @Test("a bare name is not a spelling of any dotted declaration")
    func aBareNameSpellsNoDottedDeclaration() async throws {
        // Given. Two modules declare `one.Limit` and `two.Limit`, and a third
        // mentions `Limit`, which neither of those spellings is
        let one = try Module(
            types: ["one.Limit": .int],
            procedures: [
                "one.a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            types: ["two.Limit": .string],
            procedures: [
                "two.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
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
        await #expect {
            try await builder.build([sut, one, two], entry: entryName)
        } throws: { error in
            error is BuildError
                && "\(error)".contains("names type 'Limit', which no module in this link declares")
        }
    }

    @Test("the dotted spelling says which, where the bare one cannot")
    func theDottedSpellingResolvesTheTie() async throws {
        // Given. The same link, with the mention spelled out
        let one = try Module(
            types: ["one.Limit": .int],
            procedures: [
                "one.a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            types: ["two.Limit": .string],
            procedures: [
                "two.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
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

    @Test("two modules declaring one name refuse")
    func oneNameDeclaredTwiceRefuses() async throws {
        // Given. Two modules declare one spelling, which collide the way two
        // `.c` files' symbols do
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
        await #expect {
            try await builder.build([one, two], entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("declared more than once")
        }
    }

    @Test("a constraint is named by its declared spelling")
    func aConstraintIsNamedByItsSpelling() async throws {
        // Given. `std` declares `Comparable`, and a document-shaped module
        // bounds its own parameter with that spelling, `std.Comparable`
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "value": Parameter(type: .parameter(name: "T", constraints: ["std.Comparable"]))
                        ],
                        returns: .parameter(name: "T", constraints: ["std.Comparable"])
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(
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

    @Test("sorting what Comparable does not admit refuses at the build")
    func sortingTheUnorderableRefuses() async throws {
        // Given. `sorted` is bounded by the shared ground's `Comparable`, and
        // booleans are a reading the build can see
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.array([.bool(true), .bool(false)])),
                        selector: "std.collection.sorted"
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Comparable' does not admit")
        }
    }

    @Test("a bare spelling names only the bare declaration")
    func aBareSpellingNamesTheBareDeclaration() async throws {
        // Given. One module declares `Limit`, another declares `one.Limit`, and
        // a third mentions `Limit`: the first declaration's spelling, and
        // nothing else's
        let shared = try Module(
            types: ["Limit": .int],
            procedures: [
                "a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let dotted = try Module(
            types: ["one.Limit": .string],
            procedures: [
                "one.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
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

        // When / Then. An int answers, which only the bare `Limit` admits
        let answer = try await run([sut, shared, dotted], vocabulary: [])

        #expect(answer == .int(3))
    }

    @Test("min sent null is held to the receiver it declares")
    func minSentNullIsHeldToItsReceiver() async throws {
        // Given. The receiver is a reference that reads null. Null is a value,
        // and `some T: Comparable` does not admit one, so the boundary refuses
        // before the ordering procedure is asked anything
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["absent": Parameter(type: .any, default: .null)]
                    ),
                    body: [],
                    result: .call(Call(
                        receiver: reference("absent"),
                        selector: "std.math.min",
                        arguments: ["value": .literal(.int(1))]
                    ))
                )
            ]
        )

        // When / Then
        await #expect {
            try await run(sut)
        } throws: { error in
            "\(error)".contains("the receiver of 'std.math.min': expected some T: std.Comparable, got null")
        }
    }

    @Test("a name declared as a type and a constraint refuses in either order")
    func aCrossSpaceCollisionRefusesInEitherOrder() async throws {
        // Given. One module declares `Limit` as a constraint, another as a type
        let membership = try Module(
            constraints: ["Limit": [.int]],
            procedures: [
                entryName: Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let type = try Module(
            types: ["Limit": .int],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then. The build sees its whole graph at once, so the order the
        // caller listed the modules cannot change the conclusion
        for modules in [[membership, type], [type, membership]] {
            await #expect {
                try await builder.build(modules, entry: entryName)
            } throws: { error in
                error is BuildError && "\(error)".contains("both a type and a constraint")
            }
        }
    }

    @Test("a document's bare constraint does not capture what std meant")
    func aBareDeclarationDoesNotCaptureTheStandardName() async throws {
        // Given. A module declares its own `Numeric`, admitting text, and still
        // leans on std.math for arithmetic
        let sut = try Module(
            constraints: ["Numeric": [.string]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            "value": Parameter(type: .parameter(name: "T", constraints: ["Numeric"]))
                        ],
                        returns: .parameter(name: "T", constraints: ["Numeric"])
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .constant("kept"), expression: .call(Call(
                                selector: "keep",
                                arguments: ["value": .literal(.string("a"))]
                            ))
                        )
                    ],
                    result: reference("kept")
                )
            ]
        )

        // When / Then. The module's own bound reads its own declaration, and
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
                    result: .call(Call(
                        receiver: .literal(.string("a")),
                        selector: "std.math.plus",
                        arguments: ["value": .literal(.string("b"))]
                    ))
                )
            ]
        )

        await #expect {
            try await builder.build([arithmetic] + Module.standard, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("'std.Numeric' does not admit")
        }
    }

    @Test("min and max order the way the comparison procedures do")
    func minAndMaxOrderLikeTheComparisons() async throws {
        // Given. Strings order lexicographically under Comparable, which bounds
        // `min` the way it bounds `lessThan`
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(returns: .string),
                    body: [],
                    result: .call(Call(
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
    func aBundleNeedsTheSharedGround() async throws {
        // Given. Collection's procedures mention `Collection` and
        // `Comparable`, which only the foundation module declares
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        receiver: .literal(.array([.int(2), .int(1)])),
                        selector: "std.collection.sorted"
                    ))
                )
            ]
        )

        // When / Then, without the foundation the constraint name resolves to
        // nothing, and the declaration that mentions it is refused
        await #expect {
            try await builder.build([sut] + Module.collection, entry: entryName)
        } throws: { error in
            error is BuildError && "\(error)".contains("which no module in this link declares")
        }

        await #expect(throws: Never.self) {
            try await builder.build([sut] + Module.collection + Module.logic + Module.math + Module.foundation, entry: entryName)
        }
    }
}

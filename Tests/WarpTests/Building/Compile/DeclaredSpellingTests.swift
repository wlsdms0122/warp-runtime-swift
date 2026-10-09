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
import WarpTestSupport

// A type or contract name is the spelling it was declared under, dot and
// all, and a mention is that spelling written out. These are the places that
// rule decides something, and the places it refuses, because a spelling no
// module declares names nothing.
@Suite("A type name is its declared spelling")
struct DeclaredSpellingTests {
    // MARK: - Property
    private let builder = Builder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a type name is its declared spelling, in the declaring module too")
    func aTypeNameIsItsQualifiedSpelling() async throws {
        // Given. `store` declares `Task`, and both `store` and the entry module
        // mention it as `Store.Task`
        let store = try Module(
            types: ["Store.Task": .record(["id": .string])],
            procedures: [
                "Store.keep": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "value", type: .named("Store.Task"))],
                        returns: .named("Store.Task")
                    ),
                    body: [],
                    result: reference("value")
                )
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .named("Store.Task")),
                    body: [],
                    result: .call(Call(
                        selector: "Store.keep",
                        arguments: [.literal(.record(Record(name: nil, ["id": .string("a")])))]
                    ))
                )
            ]
        )

        // When
        let image = try await builder.build([sut, store] + Module.standard)

        // Then. The declaration is under the declared spelling alone
        #expect(image.types.types["Store.Task"] == .record(["id": .string]))
        #expect(image.types.types["Task"] == nil)
    }

    @Test("a module names its own type by its declared spelling")
    func ownTypeIsNamedByItsSpelling() async throws {
        // Given. Two modules declare a `Limit`, and `mine` mentions its own as
        // `Mine.Limit` from inside: an int, where the other module's is a
        // string
        let mine = try Module(
            types: ["Mine.Limit": .int],
            procedures: [
                try Name("mine.\(entryName)"): Procedure(
                    signature: Signature(returns: .named("Mine.Limit")),
                    body: [],
                    result: .literal(.int(3))
                )
            ]
        )
        let theirs = try Module(
            types: ["Theirs.Limit": .string],
            procedures: [
                "Theirs.unrelated": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then. `Mine.entry` answers an int, which `Mine.Limit` admits
        let answer = try await run([mine, theirs], entry: try Name("mine.\(entryName)"))

        #expect(answer == .int(3))
    }

    @Test("a bare name is not a spelling of any dotted declaration")
    func aBareNameSpellsNoDottedDeclaration() async throws {
        // Given. Two modules declare `One.Limit` and `Two.Limit`, and a third
        // mentions `Limit`, which neither of those spellings is
        let one = try Module(
            types: ["One.Limit": .int],
            procedures: [
                "One.a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            types: ["Two.Limit": .string],
            procedures: [
                "Two.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .named("Limit")),
                    body: [],
                    result: .literal(.int(1))
                )
            ]
        )

        // When / Then
        await #expect {
            try await builder.build([sut, one, two])
        } throws: { error in
            error is BuildError
                && "\(error)".contains("names type 'Limit', which no module in this link declares")
        }
    }

    @Test("the dotted spelling says which, where the bare one cannot")
    func theDottedSpellingResolvesTheTie() async throws {
        // Given. The same link, with the mention spelled out
        let one = try Module(
            types: ["One.Limit": .int],
            procedures: [
                "One.a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let two = try Module(
            types: ["Two.Limit": .string],
            procedures: [
                "Two.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .named("One.Limit")),
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
        // Given. Two modules declare one spelling
        let one = try Module(
            types: ["Limit": .int],
            procedures: [
                entryName: Procedure(access: .public, signature: Signature(), body: [], result: .literal(.null))
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
            try await builder.build([one, two])
        } throws: { error in
            error is BuildError && "\(error)".contains("Two declarations of a name have no way to be told apart")
        }
    }

    @Test("a contract is named by its declared spelling")
    func aContractIsNamedByItsSpelling() async throws {
        // Given. `Standard` declares `Comparable`, and a document-shaped module
        // bounds its own parameter with that spelling, `Standard.Comparable`
        let sut = try Module(
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "value", type: .parameter(name: "T"))
                        ],
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["Standard.Comparable"]]
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [],
                    result: .call(Call(selector: "keep", arguments: [.literal(.int(3))]))
                )
            ]
        )

        // When / Then
        let answer = try await run(sut)

        #expect(answer == .int(3))
    }

    @Test("a bare spelling names only the bare declaration")
    func aBareSpellingNamesTheBareDeclaration() async throws {
        // Given. One module declares `Limit`, another declares `One.Limit`, and
        // a third mentions `Limit`: the first declaration's spelling, and
        // nothing else's
        let shared = try Module(
            types: ["Limit": .int],
            procedures: [
                "a": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let dotted = try Module(
            types: ["One.Limit": .string],
            procedures: [
                "One.b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let sut = try Module(
            procedures: [
                entryName: Procedure(
                    access: .public,
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

    @Test("a name declared as a type and a contract refuses in either order", arguments: [false, true])
    func aCrossSpaceCollisionRefusesInEitherOrder(typeFirst: Bool) async throws {
        // Given. One module declares `Limit` as a contract, another as a type
        let contract = try Module(
            contracts: ["Limit": [Name: Signature]()],
            procedures: [
                entryName: Procedure(access: .public, signature: Signature(), body: [], result: .literal(.null))
            ]
        )
        let type = try Module(
            types: ["Limit": .int],
            procedures: [
                "b": Procedure(signature: Signature(), body: [], result: .literal(.null))
            ]
        )

        // When / Then. The build sees its whole graph at once, so the order the
        // host listed the modules cannot change the conclusion
        await #expect {
            try await builder.build(typeFirst ? [type, contract] : [contract, type])
        } throws: { error in
            error is BuildError && "\(error)".contains("both a type and a contract")
        }
    }

    @Test("a document's bare contract does not capture what Standard meant")
    func aBareDeclarationDoesNotCaptureTheStandardName() async throws {
        // Given. A module declares its own `Numeric`, which text answers, and
        // still leans on Standard for arithmetic
        let sut = try Module(
            contracts: ["Numeric": [Name: Signature]()],
            claims: ["String": ["Numeric"]],
            procedures: [
                "keep": Procedure(
                    signature: Signature(
                        parameters: [
                            Parameter(name: "value", type: .parameter(name: "T"))
                        ],
                        returns: .parameter(name: "T"),
                        bounds: ["T": ["Numeric"]]
                    ),
                    body: [],
                    result: reference("value")
                ),
                entryName: Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        Statement(binding: .constant("kept"), expression: .call(Call(
                            selector: "keep",
                            arguments: [.literal(.string("a"))]
                        )))
                    ],
                    result: reference("kept")
                )
            ]
        )

        // When / Then. The module's own bound reads its own declaration, and
        // text passes it
        let answer = try await run(sut)

        #expect(answer == .string("a"))

        // And Standard's arithmetic still reads Standard's declaration: two
        // pieces of text refuse exactly as they do without the document's
        // `Numeric`
        let arithmetic = try Module(
            contracts: ["Numeric": [Name: Signature]()],
            claims: ["String": ["Numeric"]],
            procedures: [
                entryName: Procedure(
                    access: .public,
                    signature: Signature(),
                    body: [],
                    result: .call(Call(
                        selector: "Standard.Numeric.plus",
                        arguments: [.literal(.string("a")), .literal(.string("b"))]
                    ))
                )
            ]
        )

        await #expect {
            try await builder.build([arithmetic] + Module.standard)
        } throws: { error in
            error is BuildError && "\(error)".contains("no document in this link says 'String' answers it")
        }
    }

    // MARK: - Public
    // MARK: - Private
}

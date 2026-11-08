//
//  CachedCompilationTests.swift
//  WarpTests
//
//  Created by JSilver on 11/4/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// A compile handed the objects a host cached: which it reads back and which
// it compiles again.
@Suite("A compile reads back what the host cached where it is still true")
struct CachedCompilationTests {
    // MARK: - Property
    // Keyed over the interface, so a change to a body alone leaves the
    // documents leaning on it standing.
    private let builder = Builder { compiled in Fingerprint(Array("\(try compiled.interface())".utf8)) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("reads back a document whose dependency changed only a body that is not const")
    func readsBackPastABodyChange() async throws {
        // Given
        let cached = try await caching([try library(returning: 1, constness: .unstated, identity: 0x01), try program])

        // When
        let sut = try await builder.compile(
            [try library(returning: 2, constness: .unstated, identity: 0x02), try program],
            against: [],
            supplying: .none
        ) { identity, _ in cached[identity] }

        // Then
        #expect(kinds(of: sut) == ["compiled", "read"])

        let image = try builder.link(sut.map(\.object), supplying: .none)

        #expect(try await Executor().run(image, entry: "App.main") == .int(2))
    }

    @Test("compiles again a document whose dependency changed what it reads")
    func compilesAgainPastAConstBodyChange() async throws {
        // Given
        let cached = try await caching([try library(returning: 1, constness: .const, identity: 0x01), try program])

        // When
        let sut = try await builder.compile(
            [try library(returning: 2, constness: .const, identity: 0x02), try program],
            against: [],
            supplying: .none
        ) { identity, _ in cached[identity] }

        // Then
        #expect(kinds(of: sut) == ["compiled", "compiled"])
    }

    @Test("compiles again a document whose dependency's body names something new")
    func compilesAgainPastANewName() async throws {
        // Given
        let cached = try await caching([
            try helper,
            try library(returning: 1, constness: .unstated, identity: 0x01),
            try program
        ])
        let calling = try Module(
            Draft(
                procedures: [
                    "A.foo": Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [returning(.call(Call(selector: "B.bar")))]
                    )
                ]
            ),
            identity: Identity([0x03])
        )

        // When
        let sut = try await builder.compile([try helper, calling, try program], against: [], supplying: .none) {
            identity, _ in cached[identity]
        }

        // Then
        #expect(kinds(of: sut) == ["read", "compiled", "compiled"])
    }

    @Test("reads back every document where nothing changed")
    func readsBackWhatIsUnchanged() async throws {
        // Given
        let modules = [try library(returning: 1, constness: .unstated, identity: 0x01), try program]
        let cached = try await caching(modules)

        // When
        let sut = try await builder.compile(modules, against: [], supplying: .none) { identity, _ in cached[identity] }

        // Then
        #expect(kinds(of: sut) == ["read", "read"])
    }

    @Test("refuses a cached object that does not read")
    func refusesAnObjectThatDoesNotRead() async throws {
        // Given
        let modules = [try library(returning: 1, constness: .unstated, identity: 0x01)]

        // When, Then
        await #expect(throws: ObjectRefused.self) {
            try await builder.compile(modules, against: [], supplying: .none) { _, _ in .int(1) }
        }
    }

    @Test("refuses a document handed over twice where its object would be read back")
    func refusesADocumentTwice() async throws {
        // Given
        let cached = try await caching([try library(returning: 1, constness: .unstated, identity: 0x01)])
        let modules = [
            try library(returning: 1, constness: .unstated, identity: 0x01),
            try library(returning: 1, constness: .unstated, identity: 0x01)
        ]

        // When, Then
        await #expect(throws: BuildRefused.self) {
            try await builder.compile(modules, against: [], supplying: .none) { identity, _ in cached[identity] }
        }
    }

    @Test("compiles a document against one read back in the same compile, folding through what was read")
    func foldsThroughWhatWasReadBack() async throws {
        // Given. A document whose const procedures hand on a closure its
        // constant holds and call one another, and one folding a constant
        // through each.
        let cached = try await caching([try giving, try folding(identity: 0x01)])

        // When. Only the folding document changed, so the giving one is read
        // back and the folding one folds through its rows.
        let sut = try await builder.compile([try giving, try folding(identity: 0x02)], against: [], supplying: .none) {
            identity, _ in cached[identity]
        }

        // Then
        #expect(kinds(of: sut) == ["read", "compiled"])

        let image = try builder.link(sut.map(\.object), supplying: .none)

        #expect(try await Executor().run(image, entry: "App.entry") == .int(5))
        #expect(try await Executor().run(image, entry: "App.count") == .int(5))
    }

    @Test("refuses a name a document laid before declares, where every document would be read back")
    func refusesANameLaidBefore() async throws {
        // Given
        let laid = try await builder.compile([try library(returning: 1, constness: .unstated, identity: 0x01)])
        let modules = [try library(returning: 2, constness: .unstated, identity: 0x02)]
        let cached = try await caching(modules)

        // When, Then
        await #expect(throws: BuildRefused.self) {
            try await builder.compile(modules, against: laid, supplying: .none) { identity, _ in cached[identity] }
        }
    }

    // MARK: - Private
    private var giving: Module {
        get throws {
            try Module(
                Draft(
                    constants: [
                        "made": .closure(Procedure(signature: Signature(returns: .int), body: [returning(.literal(.int(5)))]))
                    ],
                    procedures: [
                        "App.five": Procedure(
                            access: .public,
                            signature: Signature(returns: .int, constness: .const),
                            body: [returning(.literal(.int(5)))]
                        ),
                        "App.number": Procedure(
                            access: .public,
                            signature: Signature(returns: .int, constness: .const),
                            body: [returning(.call(Call(selector: "App.five")))]
                        ),
                        "App.give": Procedure(
                            access: .public,
                            signature: Signature(
                                returns: .procedure(ProcedureType(returns: .int, failing: .anything)),
                                constness: .const
                            ),
                            body: [returning(reference("made"))]
                        )
                    ]
                ),
                identity: Identity([0x0c])
            )
        }
    }

    private func folding(identity: UInt8) throws -> Module {
        try Module(
            Draft(
                constants: ["got": .call(Call(selector: "App.give")), "number": .call(Call(selector: "App.number"))],
                procedures: [
                    "App.entry": Procedure(
                        access: .public,
                        signature: Signature(returns: .int, failing: .anything),
                        body: [returning(.apply(reference("got"), arguments: []))]
                    ),
                    "App.count": Procedure(
                        access: .public,
                        signature: Signature(returns: .int),
                        body: [returning(reference("number"))]
                    )
                ]
            ),
            identity: Identity([0x0d, identity])
        )
    }

    private var program: Module {
        get throws {
            try Module(
                Draft(
                    procedures: [
                        "App.main": Procedure(
                            access: .public,
                            signature: Signature(returns: .int),
                            body: [returning(.call(Call(selector: "A.foo")))]
                        )
                    ]
                ),
                identity: Identity([0x0a])
            )
        }
    }

    private var helper: Module {
        get throws {
            try Module(
                Draft(
                    procedures: [
                        "B.bar": Procedure(
                            access: .public,
                            signature: Signature(returns: .int),
                            body: [returning(.literal(.int(3)))]
                        )
                    ]
                ),
                identity: Identity([0x0b])
            )
        }
    }

    private func library(returning number: Int, constness: Constness, identity: UInt8) throws -> Module {
        try Module(
            Draft(
                procedures: [
                    "A.foo": Procedure(
                        access: .public,
                        signature: Signature(returns: .int, constness: constness),
                        body: [returning(.literal(.int(number)))]
                    )
                ]
            ),
            identity: Identity([identity])
        )
    }

    // The objects of the documents compiled with nothing cached, by identity.
    private func caching(_ modules: [Module]) async throws -> [Identity: Value] {
        let compiled = try await builder.compile(modules, against: [], supplying: .none) { _, _ in nil }

        return try compiled.reduce(into: [Identity: Value]()) { cached, compilation in
            guard case let .compiled(document) = compilation else { return }

            cached[try #require(document.identity)] = try document.object()
        }
    }

    private func kinds(of compilations: [Compilation]) -> [String] {
        compilations.map { compilation in
            switch compilation {
            case .read: "read"
            case .compiled: "compiled"
            }
        }
    }
}

//
//  HostDoorTests.swift
//  WarpTests
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

@Suite("A host settles a value against a declaration the build holds")
struct HostDoorTests {
    // A procedure the host answers handing the closure it was given what it
    // is built holding.
    private struct HandingQuery: Query {
        enum Parameters: Int, ParameterSet {
            case body

            // MARK: - Property
            var declared: Parameter {
                Parameter(
                    name: "body",
                    type: .procedure(ProcedureType(parameters: [.named("App.Ticket")], returns: .string, failing: .anything), .const)
                )
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let handed: Value

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            guard case let .procedure(closure) = question[.body] else {
                throw ExecutionError("App.handing asks a procedure")
            }

            return try await question.call(closure, handing: [handed])
        }

        // MARK: - Private
    }

    // A procedure the host answers writing what it is built holding into the
    // variable it was handed in place, which declares a whole number.
    private struct WritingEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case box

            // MARK: - Property
            var declared: Parameter {
                Parameter(name: "box", type: .inout(.int))
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let written: Value

        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            try invocation.write(.box, written)

            return .null
        }

        // MARK: - Private
    }

    // A procedure the host answers with what it is built holding.
    private struct AnsweringQuery: Query {
        typealias Parameters = NoParameters

        // MARK: - Property
        let held: Value

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            held
        }

        // MARK: - Private
    }

    // A procedure the host answers sending `App.take` what it is built
    // holding.
    private struct SendingQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case take

            // MARK: - Property
            var selector: Name { "App.take" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let held: Value

        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.take, handing: [held])
        }

        // MARK: - Private
    }

    // A failure carrying a struct under a name, the way a procedure the host
    // answers fills `details` with whatever it holds.
    private struct CarryingFailure: RecoverableFailure {
        // MARK: - Property
        let message = "carried"

        let held: Value

        let trace: Trace? = nil

        var type: String { Self.type }

        static let type = "carried"

        var details: Value.Dictionary { Value.Dictionary(["held": held]) }

        // MARK: - Initializer
        // MARK: - Public
        func tracing(_ trace: Trace) -> CarryingFailure { self }

        // MARK: - Private
    }

    // A procedure the host answers failing with what it is built holding.
    private struct CarryingEffect: Effect {
        typealias Parameters = NoParameters

        // MARK: - Property
        let held: Value

        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            throw CarryingFailure(held: held)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private var sut: Module {
        get throws {
            try Module(
                imports: [],
                types: ["Bank.Account": .struct(["balance": .int])],
                procedures: ["entry": Procedure(access: .public, body: [])]
            )
        }
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("settling against a declared type builds the value on that type's layout")
    func settlingByDeclarationNamesTheValue() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When
        let settled = try image.settling(.struct(Struct(name: "Bank.Account", ["balance": .int(1)])), as: "Bank.Account")

        // Then
        guard case let .struct(instance) = settled else {
            Issue.record("the value did not settle to a struct")

            return
        }

        #expect(instance.name == "Bank.Account")
        #expect(instance.names == ["balance"])
    }

    @Test("a declaration the build does not have refuses")
    func anUndeclaredNameIsRefused() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When / Then
        #expect(throws: ValueRefused.self) {
            try image.settling(.dictionary(["balance": .int(1)]), as: "Bank.Vault")
        }
    }

    @Test("a value the declaration does not admit refuses at the door")
    func aValueOutsideTheDeclarationIsRefused() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When / Then
        #expect {
            try image.settling(.struct(Struct(name: "Bank.Account", ["balance": .string("much")])), as: "Bank.Account")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected Int, got String")
        }
    }

    @Test("a fraction with no finite value refuses at the door, wherever it stands")
    func aNonFiniteNumberIsRefused() async throws {
        // Given. No document and no encoding carries one, so a run never
        // holds one: the door says so before the slot is asked
        let image = try await Builder().build([sut])

        // When / Then
        for number in [Double.nan, .infinity, -.infinity] {
            #expect {
                try image.settling(.struct(Struct(name: "Bank.Account", ["balance": .double(number)])), as: "Bank.Account")
            } throws: { error in
                error is ArgumentError && "\(error)".contains("holds a fraction with no finite value")
            }
        }
    }

    @Test("a fraction with no finite value refuses at every door a value from outside comes through")
    func aNonFiniteNumberIsRefusedAtEveryDoor() async throws {
        // Given. An entry taking anything, and procedures the host answers
        // bringing one in: failing with it, answering it, writing it in place,
        // handing it to a closure and sending it
        let entry = try Module(
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(parameters: [Parameter(name: "x")], returns: .any),
                    body: [returning(.reference([.name("x")]))]
                )
            ]
        )
        let taking = try await Builder().build([entry] + Module.standard)
        let doors = [
            try carrying(.array([.double(.nan)])) + Module.standard,
            try answering(.double(-.infinity)),
            try writing(.double(.nan)),
            try handing(.struct(Struct(name: "App.Ticket", ["id": .double(.infinity)]))),
            try sending(.double(.nan))
        ]

        // When / Then
        await #expect {
            try await Executor().run(taking, arguments: ["x": .double(.infinity)])
        } throws: { error in
            "\(error)".contains("holds a fraction with no finite value")
        }

        for door in doors {
            let image = try await Builder().build(door)

            await #expect {
                try await Executor().run(image)
            } throws: { error in
                "\(error)".contains("holds a fraction with no finite value")
            }
        }
    }

    @Test("a field the declaration never named is not carried past the door")
    func anUndeclaredFieldDoesNotRideThrough() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When
        let settled = try image.settling(
            .struct(Struct(name: "Bank.Account", ["balance": .int(1), "note": .string("x")])),
            as: "Bank.Account"
        )

        // Then
        #expect(settled["note"] == nil)
        #expect(settled["balance"] == .int(1))
    }

    @Test("a value a host hands a closure is fitted at the door")
    func aValueHandedToAClosureIsFitted() async throws {
        // Given. A field the closure's parameter never names
        let image = try await Builder().build(
            try handing(.struct(Struct(name: "App.Ticket", ["id": .string("a"), "extra": .int(1)])))
        )

        // When / Then
        #expect(try await Executor().run(image) == .string("a"))
    }

    @Test("a value a host writes through a parameter handed in place is judged at the door")
    func aValueWrittenInPlaceIsJudged() async throws {
        // Given
        let image = try await Builder().build(try writing(.string("s")))

        // When / Then. The text never reaches the variable
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("'box'") && "\(error)".contains("expected Int, got String")
        }
    }

    @Test("what a failure carries comes in through the door, a struct under an alias's name as its struct")
    func aFailuresPayloadComesInThroughTheDoor() async throws {
        // Given. `App.carry` fails carrying `App.Q { a: 1 }`, `App.Q` an alias
        // of the struct `App.P`, and the rescue keeps what it carried
        let image = try await Builder().build(try carrying(.struct(Struct(name: "App.Q", ["a": .int(1)]))))

        // When
        let answer = try await Executor().run(image)

        // Then
        guard case let .struct(instance) = answer else {
            Issue.record("the rescue answered \(answer), not the struct")

            return
        }

        #expect(instance.name == "App.P")
    }

    @Test("what a failure carries under a name no document declares refuses at the door")
    func aFailuresPayloadUnderAnUndeclaredNameRefuses() async throws {
        // Given
        let image = try await Builder().build(try carrying(.struct(Struct(name: "App.Z", ["a": .int(1)]))))

        // When / Then. The rescue never reads it
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            error is ArgumentError && "\(error)".contains("'failed'.details[\"held\"]: is a App.Z, which no document declares as a struct")
        }
    }

    @Test("what the entry answers reaches the host as the build held it, a closure over a type parameter its call filled included")
    func theEntrysAnswerLeavesAsItIs() async throws {
        // Given. `App.mk` answers a closure over its own `some T`, and the
        // entry answers `App.mk(5)` as the procedure type the call filled
        let document = try Module(
            procedures: [
                "App.mk": Procedure(
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .parameter(name: "T"))],
                        returns: .procedure(ProcedureType(parameters: [.parameter(name: "T")], returns: .parameter(name: "T"), failing: .anything))
                    ),
                    body: [
                        returning(.closure(Procedure(
                            signature: Signature(parameters: [Parameter(name: "y", type: .parameter(name: "T"))], returns: .parameter(name: "T")),
                            body: [returning(.reference([.name("y")]))]
                        )))
                    ]
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .procedure(ProcedureType(parameters: [.int], returns: .int, failing: .anything))),
                    body: [returning(.call(Call(selector: "App.mk", arguments: [.literal(.int(5))])))]
                )
            ]
        )
        let image = try await Builder().build([document])

        // When
        let answer = try await Executor().run(image)

        // Then
        guard case .procedure = answer else {
            Issue.record("the entry answered \(answer), not the closure")

            return
        }
    }

    @Test("a parameter declaring Any takes anything at the entry's door")
    func anAnyParameterTakesAnything() throws {
        // Given
        let sut = Signature(parameters: [Parameter(name: "subject", type: .any)])

        // When / Then
        #expect(try settled(sut, given: ["subject": .int(1)])["subject"] == .int(1))
    }

    @Test("a missing required input is rejected")
    func missingRequiredInputRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "name", type: .string)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: [:])
        }
    }

    @Test("a type mismatch is rejected")
    func typeMismatchRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "count", type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["count": .string("three")])
        }
    }

    @Test("a fraction is not a whole number, whatever it is worth")
    func aFractionDoesNotNarrow() throws {
        // Given. A slot asking for a whole number. Taking a fraction that
        // happened to be whole would make the answer to "does this fit" depend
        // on the value rather than the type: `3.0` accepted where `3.5` is
        // refused, by a declaration that names neither.
        let sut = Signature(parameters: [Parameter(name: "count", type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["count": .double(3)])
        }

        // And a whole number is no fraction either
        let ratio = Signature(parameters: [Parameter(name: "ratio", type: .double)])

        #expect(throws: ArgumentError.self) {
            try settled(ratio, given: ["ratio": .int(3)])
        }
    }

    @Test("an undeclared input name is rejected")
    func undeclaredInputRejected() {
        // Given
        let sut = Signature(parameters: [Parameter(name: "a", type: .string)])

        // When / Then. An extra name is a typo surfaced, not a value smuggled
        // in
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["a": .string("x"), "sneaky": .int(9)])
        }
    }

    @Test("a signature declaring no parameters takes no name")
    func strayInputRejectedOnEmptySignature() {
        // Given. No parameters is a closed signature: every name given is
        // one it does not declare
        let sut = Signature()

        // When / Then
        #expect(throws: ArgumentError.self) {
            try settled(sut, given: ["stray": .string("leaked")])
        }
    }

    @Test("every parameter is given, and one declaring null takes null")
    func everyParameterIsGiven() throws {
        // Given
        let sut = Signature(parameters: [
            Parameter(name: "dir", type: .nullable(.string)),
            Parameter(name: "file", type: .string)
        ])

        // When / Then
        #expect(try settled(sut, given: ["dir": .null, "file": "a"]) == ["dir": .null, "file": "a"])
        #expect {
            try settled(sut, given: ["file": "a"])
        } throws: { error in
            "\(error)".contains("was given nothing for 'dir'")
        }
    }

    // MARK: - Public
    // MARK: - Private
    // A link whose entry rescues `App.carry` failing with `held` in its
    // details and answers what the failure carried there.
    private func carrying(_ held: Value) throws -> [Module] {
        let carry = try Module(
            types: ["App.P": .struct(["a": .int]), "App.Q": .alias(.named("App.P"))],
            procedures: [
                "App.carry": Procedure(
                    signature: Signature(of: CarryingEffect.self, failing: .these([CarryingFailure.type])),
                    implementation: .effect(CarryingEffect(held: held))
                )
            ]
        )
        let document = try Module(
            imports: ["App.carry"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .any),
                    body: [
                        Statement(binding: .variable("carried"), expression: .literal(.null)),
                        Statement(
                            binding: .constant("failed"),
                            expression: .attempt(
                                [Statement(expression: .call(Call(selector: "App.carry")))],
                                rescue: [
                                    Statement(
                                        binding: .assignment([.name("carried")]),
                                        expression: .reference([.name("failed"), .name("details"), .index("held")])
                                    )
                                ]
                            )
                        ),
                        returning(.reference([.name("carried")]))
                    ]
                )
            ]
        )

        return [document, carry]
    }

    // A document answering what a procedure the host answers brings in.
    private func answering(_ held: Value) throws -> [Module] {
        let answer = try Module(
            procedures: [
                "App.answer": Procedure(
                    signature: Signature(of: AnsweringQuery.self, returns: .double),
                    implementation: .query(AnsweringQuery(held: held))
                )
            ]
        )
        let document = try Module(
            imports: ["App.answer"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .double),
                    body: [returning(.call(Call(selector: "App.answer")))]
                )
            ]
        )

        return [document, answer]
    }

    // A document handing a variable declaring a whole number in place to a
    // procedure the host answers writing `written` into it.
    private func writing(_ written: Value) throws -> [Module] {
        let writing = try Module(
            procedures: [
                "App.writing": Procedure(
                    signature: Signature(of: WritingEffect.self),
                    implementation: .effect(WritingEffect(written: written))
                )
            ]
        )
        let document = try Module(
            imports: ["App.writing"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .int),
                    body: [
                        Statement(binding: .variable("n", declared: .int), expression: .literal(.int(1))),
                        Statement(expression: .call(Call(selector: "App.writing", arguments: [.reference([.name("n")])]))),
                        returning(.reference([.name("n")]))
                    ]
                )
            ]
        )

        return [document, writing]
    }

    // A document handing a closure reading an `App.Ticket`'s id to a
    // procedure the host answers handing it `handed`.
    private func handing(_ handed: Value) throws -> [Module] {
        let handing = try Module(
            types: ["App.Ticket": .struct(["id": .string])],
            procedures: [
                "App.handing": Procedure(
                    signature: Signature(of: HandingQuery.self, returns: .string),
                    implementation: .query(HandingQuery(handed: handed))
                )
            ]
        )
        let document = try Module(
            imports: ["App.handing", "App.Ticket"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .string),
                    body: [
                        returning(.call(Call(
                            selector: "App.handing",
                            arguments: [
                                .closure(Procedure(
                                    signature: Signature(parameters: [Parameter(name: "x", type: .named("App.Ticket"))], returns: .string, constness: .const),
                                    body: [returning(.reference([.name("x"), .name("id")]))]
                                ))
                            ]
                        )))
                    ]
                )
            ]
        )

        return [document, handing]
    }

    // A document calling a procedure the host answers, which sends `held` to
    // `App.take`, answering what it is handed.
    private func sending(_ held: Value) throws -> [Module] {
        let take = try Module(
            procedures: [
                "App.take": Procedure(
                    access: .public,
                    signature: Signature(
                        parameters: [Parameter(name: "x", type: .double)],
                        returns: .double,
                        constness: .const,
                        isolation: .isolated
                    ),
                    body: [returning(.reference([.name("x")]))]
                )
            ]
        )
        let sending = try Module(
            procedures: [
                "App.sending": Procedure(
                    signature: Signature(of: SendingQuery.self, returns: .double),
                    implementation: .query(SendingQuery(held: held))
                )
            ]
        )
        let document = try Module(
            imports: ["App.sending"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .double),
                    body: [returning(.call(Call(selector: "App.sending")))]
                )
            ]
        )

        return [document, sending, take]
    }

    // The entry's door over no table, answered by name.
    private func settled(_ signature: Signature, given: [Name: Value]) throws -> [Name: Value] {
        let entry = Linked.unlowered(
            label: "entry",
            origin: 0,
            procedure: Procedure(signature: signature, body: []),
            builtin: false,
            sends: [],
            in: .empty
        )
        let settled = try entry.settle(given, in: .empty)

        return settled.enumerated().reduce(into: [Name: Value]()) { named, value in
            named[entry.slots[value.offset].name] = value.element
        }
    }
}

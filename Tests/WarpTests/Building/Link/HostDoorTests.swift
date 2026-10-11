//
//  HostDoorTests.swift
//  WarpTests
//
//  Created by JSilver on 9/5/26.
//

import Foundation
import Testing
@testable import Warp

@Suite("A host settles a value against a declaration the build holds")
struct HostDoorTests {
    // A procedure the host answers handing the closure it was given a record
    // holding a field the closure's parameter never names.
    private struct HandingQuery: Query {
        enum Parameters: Int, ParameterSet {
            case body

            // MARK: - Property
            var declared: Parameter {
                Parameter(
                    name: "body",
                    type: .procedure(ProcedureType(parameters: [.named("App.Ticket")], returns: .string), .const)
                )
            }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            guard case let .procedure(closure) = question[.body] else {
                throw ExecutionError("App.handing asks a procedure")
            }

            return try await question.call(
                closure,
                handing: [.record(Record(name: "App.Ticket", ["id": .string("a"), "extra": .int(1)]))]
            )
        }

        // MARK: - Private
    }

    // A procedure the host answers writing text into the variable it was
    // handed in place, which declares a whole number.
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
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            try invocation.write(.box, .string("s"))

            return .null
        }

        // MARK: - Private
    }

    // A failure carrying a record under a name, the way a procedure the host
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

        let failing = Failing.these([CarryingFailure.type])

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
                types: ["Bank.Account": .record(["balance": .int])],
                procedures: ["entry": Procedure(access: .public, implementation: .body(Block(body: [], result: .literal(.null))))]
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
        let settled = try image.settling(.record(Record(name: "Bank.Account", ["balance": .int(1)])), as: "Bank.Account")

        // Then
        guard case let .record(record) = settled else {
            Issue.record("the value did not settle to a record")

            return
        }

        #expect(record.name == "Bank.Account")
        #expect(record.names == ["balance"])
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
            try image.settling(.record(Record(name: "Bank.Account", ["balance": .string("much")])), as: "Bank.Account")
        } throws: { error in
            error is ArgumentError && "\(error)".contains("expected Int, got String")
        }
    }

    @Test("a field the declaration never named is not carried past the door")
    func anUndeclaredFieldDoesNotRideThrough() async throws {
        // Given
        let image = try await Builder().build([sut])

        // When
        let settled = try image.settling(
            .record(Record(name: "Bank.Account", ["balance": .int(1), "note": .string("x")])),
            as: "Bank.Account"
        )

        // Then
        #expect(settled["note"] == nil)
        #expect(settled["balance"] == .int(1))
    }

    @Test("a value a host hands a closure is fitted at the door")
    func aValueHandedToAClosureIsFitted() async throws {
        // Given
        let handing = try Module(
            types: ["App.Ticket": .record(["id": .string])],
            procedures: [
                "App.handing": Procedure(
                    signature: Signature(of: HandingQuery.self, returns: .string),
                    implementation: .query(HandingQuery())
                )
            ]
        )
        let document = try Module(
            imports: ["App.handing", "App.Ticket"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [],
                    result: .call(Call(
                        selector: "App.handing",
                        arguments: [
                            .closure(Procedure(
                                signature: Signature(parameters: [Parameter(name: "x", type: .named("App.Ticket"))], returns: .string),
                                body: [],
                                result: .reference([.name("x"), .name("id")])
                            ))
                        ]
                    ))
                )
            ]
        )
        let image = try await Builder().build([document, handing])

        // When / Then
        #expect(try await Executor().run(image) == .string("a"))
    }

    @Test("a value a host writes through a parameter handed in place is judged at the door")
    func aValueWrittenInPlaceIsJudged() async throws {
        // Given
        let writing = try Module(
            procedures: [
                "App.writing": Procedure(
                    signature: Signature(of: WritingEffect.self),
                    implementation: .effect(WritingEffect())
                )
            ]
        )
        let document = try Module(
            imports: ["App.writing"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(binding: .variable("n", declared: .int), expression: .literal(.int(1))),
                        Statement(expression: .call(Call(selector: "App.writing", arguments: [.reference([.name("n")])])))
                    ],
                    result: .reference([.name("n")])
                )
            ]
        )
        let image = try await Builder().build([document, writing])

        // When / Then. The text never reaches the variable
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            "\(error)".contains("'box'") && "\(error)".contains("expected Int, got String")
        }
    }

    @Test("what a failure carries comes in through the door, a record under an alias's name as its record")
    func aFailuresPayloadComesInThroughTheDoor() async throws {
        // Given. `App.carry` fails carrying `App.Q { a: 1 }`, `App.Q` an alias
        // of the record `App.P`, and the rescue answers what it carried
        let image = try await Builder().build(try carrying(.record(Record(name: "App.Q", ["a": .int(1)]))))

        // When
        let answer = try await Executor().run(image)

        // Then
        guard case let .record(record) = answer else {
            Issue.record("the rescue answered \(answer), not the record")

            return
        }

        #expect(record.name == "App.P")
    }

    @Test("what a failure carries under a name no document declares refuses at the door")
    func aFailuresPayloadUnderAnUndeclaredNameRefuses() async throws {
        // Given
        let image = try await Builder().build(try carrying(.record(Record(name: "App.Z", ["a": .int(1)]))))

        // When / Then. The rescue never reads it
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            error is ArgumentError && "\(error)".contains("'failed'.details[\"held\"]: is a App.Z, which no document declares as a record")
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
                        returns: .procedure(ProcedureType(parameters: [.parameter(name: "T")], returns: .parameter(name: "T")))
                    ),
                    body: [],
                    result: .closure(Procedure(
                        signature: Signature(parameters: [Parameter(name: "y", type: .parameter(name: "T"))], returns: .parameter(name: "T")),
                        body: [],
                        result: .reference([.name("y")])
                    ))
                ),
                "entry": Procedure(
                    access: .public,
                    signature: Signature(returns: .procedure(ProcedureType(parameters: [.int], returns: .int))),
                    body: [],
                    result: .call(Call(selector: "App.mk", arguments: [.literal(.int(5))]))
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
            types: ["App.P": .record(["a": .int]), "App.Q": .alias(.named("App.P"))],
            procedures: [
                "App.carry": Procedure(
                    signature: Signature(of: CarryingEffect.self),
                    implementation: .effect(CarryingEffect(held: held))
                )
            ]
        )
        let document = try Module(
            imports: ["App.carry"],
            procedures: [
                "entry": Procedure(
                    access: .public,
                    body: [
                        Statement(
                            binding: .constant("failed"),
                            expression: .attempt(
                                Block(body: [Statement(expression: .call(Call(selector: "App.carry")))]),
                                rescue: Block(body: [], result: .reference([.name("failed"), .name("details"), .index("held")]))
                            )
                        )
                    ],
                    result: .reference([.name("failed")])
                )
            ]
        )

        return [document, carry]
    }

    // The entry's door over no table, answered by name.
    private func settled(_ signature: Signature, given: [Name: Value]) throws -> [Name: Value] {
        let entry = Linked.unlowered(
            label: "entry",
            origin: 0,
            procedure: Procedure(signature: signature, body: []),
            const: false,
            isolated: false,
            failing: .these([]),
            builtin: false,
            sends: [],
            in: .empty
        )
        let settled = try entry.settle(given)

        return settled.enumerated().reduce(into: [Name: Value]()) { named, value in
            named[entry.slots[value.offset].name] = value.element
        }
    }
}

//
//  ProcedureSendsTests.swift
//  WarpTests
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Testing
@testable import Warp

// What a native procedure sending another procedure answers, and what the build refuses
// before anything runs. A procedure declares the procedures it sends the way it declares
// the arguments it reads, so both are the build's to resolve.
@Suite("A procedure sends a procedure the build resolved")
struct ProcedureSendsTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a procedure answers through the procedure it declared it sends")
    func aProcedureReachesWhatItDeclared() async throws {
        // Given
        let image = try Builder().build(
            [try Module(procedures: ["entry": Procedure(
                body: [],
                result: .call(Call(receiver: .literal(.int(2)), selector: "app.twice"))
            )])] + [.sending, .shouting] + Module.standard,
            entry: "entry"
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(4))
    }

    @Test("an effect reaches a procedure that runs")
    func anEffectReachesAProcedureThatRuns() async throws {
        // Given
        let image = try Builder().build(
            [try Module(procedures: ["entry": Procedure(
                body: [],
                result: .call(Call(receiver: .literal(.string("hi")), selector: "app.announce"))
            )])] + [.sending, .shouting] + Module.standard,
            entry: "entry"
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .string("HI"))
    }

    @Test("a procedure sending a spelling nothing declares is refused at the build")
    func anUndeclaredSendIsRefused() {
        // Given / When / Then
        #expect(throws: BuildError.self) {
            try Builder().build(
                [try Module(procedures: ["entry": Procedure(body: [])])] + [.strayed],
                entry: "entry"
            )
        }
    }

    @Test("a query sending something that answers only by running is refused")
    func aQuerySendingAnEffectIsRefused() {
        // Given. `app.shouting` claims it answers without running and sends
        // `app.shout`, which does not
        #expect(throws: BuildError.self) {
            try Builder().build(
                [try Module(procedures: ["entry": Procedure(body: [])])] + [.contradicting, .shouting],
                entry: "entry"
            )
        }
    }

    @Test("an isolated procedure sending one that keeps state is refused")
    func anIsolatedProcedureSendingSharedStateIsRefused() {
        // Given / When / Then. `app.counting` says it touches nothing shared
        // and sends `app.ticket`, which answers from a box it keeps between
        // calls
        #expect(throws: BuildError.self) {
            try Builder().build(
                [try Module(procedures: ["entry": Procedure(body: [])])] + [.claims, .ticketing],
                entry: "entry"
            )
        }
    }

    @Test("a procedure that says it touches shared state may send one that does")
    func aSharedProcedureSendingSharedStateStands() async throws {
        // Given
        let image = try Builder().build(
            [try Module(procedures: ["entry": Procedure(
                body: [],
                result: .call(Call(selector: "app.counted"))
            )])] + [.counting, .ticketing],
            entry: "entry"
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(1))
    }

    @Test("what a native procedure sends counts in the module's disclosure")
    func nativeSendsAreDisclosed() throws {
        // Given / When / Then. The list is what a caller reads to decide what
        // to grant, so a procedure's own sends are in it
        #expect(Module.sending.imports == ["std.math.times", "app.shout"])
    }

    @Test("a module claiming a list its procedures contradict is refused")
    func aDriftedDisclosureIsRefused() {
        // Given / When / Then
        #expect(throws: ValidationError.self) {
            try Module(
                imports: [],
                procedures: [
                    "app.twice": Procedure(
                        signature: Signature(of: TwiceQuery.self, receiver: .of, returns: .int),
                        implementation: .query(TwiceQuery())
                    )
                ]
            )
        }
    }

    @Test("a procedure whose sends stand apart is refused where the module is made")
    func aProcedureSendingFromScatteredPlacesIsRefused() {
        // Given / When / Then. A run reaches a sent procedure by the place the procedure
        // names it at, so a place nothing stands at reaches nothing.
        #expect(throws: ValidationError.self) {
            try Module(
                procedures: [
                    "app.scattered": Procedure(
                        signature: Signature(returns: .int),
                        implementation: .query(ScatteredQuery())
                    )
                ]
            )
        }
    }

    @Test("what a procedure hands over stands where the callee keeps it, not where the procedure wrote it")
    func handedArgumentsStandWhereTheCalleeKeepsThem() async throws {
        // Given. `app.picking` hands `z` before `a`, and the callee keeps them
        // the other way round
        let image = try Builder().build(
            [try Module(procedures: ["entry": Procedure(
                body: [],
                result: .call(Call(selector: "app.picking"))
            )])] + [.picking, .picked],
            entry: "entry"
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(9))
    }

    @Test("a procedure handing a name the callee never declared is refused at the build")
    func anUnknownHandedNameIsRefused() {
        // Given / When / Then
        #expect(throws: BuildError.self) {
            try Builder().build(
                [try Module(procedures: ["entry": Procedure(body: [])])] + [.misnaming, .picked],
                entry: "entry"
            )
        }
    }

    @Test("a procedure handing more than it declared it hands is refused when it sends")
    func handingMoreThanDeclaredIsRefused() async throws {
        // Given. How many a Swift body builds is the body's, so this is the one
        // thing about a send the build cannot read
        let image = try Builder().build(
            [try Module(procedures: ["entry": Procedure(
                body: [],
                result: .call(Call(selector: "app.overhanding"))
            )])] + [.overhanding, .picked],
            entry: "entry"
        )

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await Executor().run(image)
        }
    }

    // MARK: - Private
}

// MARK: - Procedures a test brings
// Doubling by sending the procedure that multiplies, rather than multiplying here.
// What it sends is its own declaration, so the build resolves the row and this
// reads it.
private struct TwiceQuery: Query {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .int) }
    }

    enum Imports: Int, ImportSet {
        case times

        var selector: Name { "std.math.times" }

        var offers: [Name] { ["value"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try question.send(.times, to: question.receiver, offering: [.int(2)])
    }

    // MARK: - Private
}

// Announcing by sending the procedure that shouts. An effect, so what it sends may
// run too.
private struct AnnounceEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case of

        var name: Name { "of" }

        var declared: Parameter { Parameter(type: .string) }
    }

    enum Imports: Int, ImportSet {
        case shout

        var selector: Name { "app.shout" }

        var offers: [Name] { ["text"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.shout, offering: [invocation.receiver ?? .null])
    }

    // MARK: - Private
}

// Answers what the ticketing procedure answers. Two declarations over one procedure: one
// says it touches nothing shared and is refused for sending this, and one says
// it does and stands.
private struct CountedQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case ticket

        var selector: Name { "app.ticket" }

        var offers: [Name] { [] }
    }

    // MARK: - Property
    let isolated: Bool

    // MARK: - Initializer
    init(isolated: Bool) {
        self.isolated = isolated
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try question.send(.ticket)
    }

    // MARK: - Private
}

// Sends a spelling nothing declares.
private struct StrayQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case nowhere

        var selector: Name { "app.nowhere" }

        var offers: [Name] { [] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try question.send(.nowhere)
    }

    // MARK: - Private
}

// Claims it answers without running, and sends something that runs.
private struct ShoutingQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case shout

        var selector: Name { "app.shout" }

        var offers: [Name] { [] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try question.send(.shout)
    }

    // MARK: - Private
}


// Hands two arguments in the order it wrote them, which is not the order the
// callee keeps them in. What the callee answers says which order was kept.
private struct PickingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var offers: [Name] { ["z", "a"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, offering: [.int(9), .int(1)])
    }

    // MARK: - Private
}

// Hands a name the callee declares no parameter under.
private struct MisnamingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var offers: [Name] { ["nowhere"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, offering: [.int(1)])
    }

    // MARK: - Private
}

// Declares it hands one and hands two.
private struct OverhandingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var offers: [Name] { ["z"] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, offering: [.int(9), .int(1)])
    }

    // MARK: - Private
}

private extension Module {
    static let sending = try! Module(
        procedures: [
            "app.twice": Procedure(
                signature: Signature(of: TwiceQuery.self, receiver: .of, returns: .int),
                implementation: .query(TwiceQuery())
            ),
            "app.announce": Procedure(
                signature: Signature(of: AnnounceEffect.self, receiver: .of, returns: .string),
                implementation: .effect(AnnounceEffect())
            )
        ]
    )

    static let strayed = try! Module(
        procedures: [
            "app.stray": Procedure(
                signature: Signature(of: StrayQuery.self, returns: .null),
                implementation: .query(StrayQuery())
            )
        ]
    )

    static let contradicting = try! Module(
        procedures: [
            "app.shouting": Procedure(
                signature: Signature(of: ShoutingQuery.self, returns: .null),
                implementation: .query(ShoutingQuery())
            )
        ]
    )

    // The same procedure under two claims: one says it touches nothing shared and
    // is refused for sending the ticketing procedure, and one says it does.
    static let claims = try! Module(
        procedures: [
            "app.counted": Procedure(
                signature: Signature(of: CountedQuery.self, returns: .int),
                implementation: .query(CountedQuery(isolated: true))
            )
        ]
    )

    static let counting = try! Module(
        procedures: [
            "app.counted": Procedure(
                signature: Signature(of: CountedQuery.self, returns: .int),
                implementation: .query(CountedQuery(isolated: false))
            )
        ]
    )

    // The callee two of the tests above hand arguments to: it answers `z`, so an
    // argument standing at the wrong place shows in the answer.
    static let picked = try! Module(
        procedures: [
            "app.pick": Procedure(
                signature: Signature(
                    parameters: ["a": Parameter(type: .int), "z": Parameter(type: .int)],
                    returns: .int
                ),
                body: [],
                result: .reference([.key("z")])
            )
        ]
    )

    static let picking = try! Module(
        procedures: [
            "app.picking": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(PickingEffect())
            )
        ]
    )

    static let misnaming = try! Module(
        procedures: [
            "app.misnaming": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(MisnamingEffect())
            )
        ]
    )

    static let overhanding = try! Module(
        procedures: [
            "app.overhanding": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(OverhandingEffect())
            )
        ]
    )
}


// Sending two procedures, the second standing at a place nothing before it does.
private struct ScatteredQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case first = 0
        case apart = 5

        var selector: Name {
            switch self {
            case .first:
                return "std.math.plus"

            case .apart:
                return "std.math.minus"
            }
        }

        var offers: [Name] { [] }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) throws -> Value? {
        try question.send(.first)
    }

    // MARK: - Private
}

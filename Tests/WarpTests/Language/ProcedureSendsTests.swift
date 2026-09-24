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
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.twice", arguments: [.literal(.int(2))]))
            )])] + [.sending, .shouting] + Module.standard
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(4))
    }

    @Test("an effect reaches a procedure that runs")
    func anEffectReachesAProcedureThatRuns() async throws {
        // Given
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.announce", arguments: [.literal(.string("hi"))]))
            )])] + [.sending, .shouting] + Module.standard
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .string("HI"))
    }

    @Test("a procedure sending a spelling nothing declares is refused at the build")
    func anUndeclaredSendIsRefused() async {
        // Given / When / Then
        await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [.strayed]
            )
        }
    }

    @Test("a procedure sending another document's private declaration is refused at the build")
    func aSendReachingAPrivateDeclarationIsRefused() async {
        // Given. A document declares `app.hidden` privately, and a procedure the
        // caller brings declares it sends that spelling.
        let document = try! Module(procedures: [
            "app.hidden": Procedure(access: .private, body: [], result: .literal(.int(7))),
            "entry": Procedure(access: .public, body: [], result: .call(Call(selector: "app.reach")))
        ])

        // When / Then
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([document, .reaching] + Module.standard)
        }

        #expect(refusal?.message.contains("is private to the document that declares it") == true)
    }

    @Test("a query sending something that answers only by running is refused")
    func aQuerySendingAnEffectIsRefused() async {
        // Given. `app.shouting` claims it answers without running and sends
        // `app.shout`, which does not
        await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [.contradicting, .shouting]
            )
        }
    }

    @Test("an isolated procedure sending one that keeps state is refused")
    func anIsolatedProcedureSendingSharedStateIsRefused() async {
        // Given / When / Then. `app.counting` says it touches nothing shared
        // and sends `app.ticket`, which answers from a box it keeps between
        // calls
        await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [.claims, .ticketing]
            )
        }
    }

    @Test("a procedure that says it touches shared state may send one that does")
    func aSharedProcedureSendingSharedStateStands() async throws {
        // Given
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.counted"))
            )])] + [.counting, .ticketing]
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
                        signature: Signature(of: TwiceQuery.self, returns: .int),
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

    @Test("what a procedure hands over stands at the callee's first positions")
    func handedArgumentsStandAtTheCalleesPositions() async throws {
        // Given. `app.picking` hands two values, and the callee answers the one
        // standing at its second position
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.picking"))
            )])] + [.picking, .picked]
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(9))
    }

    @Test("a procedure handing more than the callee takes is refused at the build")
    func handingMoreThanTheCalleeTakesIsRefused() async {
        // Given / When / Then. `app.pick` takes two, and a third would stand at
        // a position the callee does not have
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [.overcounting, .picked]
            )
        }

        #expect(refusal?.message.contains("sends 'app.pick' 3 arguments, and it takes 2") == true)
    }

    @Test("a procedure handing fewer than the callee requires is refused at the build")
    func handingFewerThanTheCalleeRequiresIsRefused() async {
        // Given / When / Then. `app.pick` requires both of its parameters, and
        // a send handing one leaves the second off, which every run would refuse
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [.undercounting, .picked]
            )
        }

        #expect(refusal?.message.contains("sends 'app.pick' without z, which it requires") == true)
    }

    @Test("a procedure handing more than it declared it hands is refused when it sends")
    func handingMoreThanDeclaredIsRefused() async throws {
        // Given. How many a Swift body builds is the body's, so this is the one
        // thing about a send the build cannot read
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.overhanding"))
            )])] + [.overhanding, .picked]
        )

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await Executor().run(image)
        }
    }

    @Test("a procedure handing what the callee cannot take is refused at the boundary")
    func aMistypedArgumentIsRefused() async throws {
        // Given. `app.mistyping` hands an int to a procedure whose first
        // parameter is declared string
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.mistyping"))
            )])] + [.mistyping, .spoken]
        )

        // When / Then. The same refusal a call written in a document earns, and
        // it names the parameter rather than the answer
        await #expect(throws: ArgumentError.self) {
            try await Executor().run(image)
        }
    }

    @Test("a value a send hands over is held to the parameter it fills")
    func aHandedNullIsHeldToItsType() async throws {
        // Given. `app.reporting` declares `said: string`, and null is not a
        // string. The same gate an argument a body writes goes through
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "app.nullingToAParameter"))
            )])] + [.nullingToAParameter, .reporting]
        )

        // When / Then
        let refusal = await #expect(throws: ArgumentError.self) {
            try await Executor().run(image)
        }

        #expect(refusal?.message.contains("expected string, got null") == true)
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

        var declared: Parameter { Parameter(name: "of", type: .int) }
    }

    enum Imports: Int, ImportSet {
        case times

        var selector: Name { "std.math.times" }

        var handing: Int { 2 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.times, handing: [question[.of], .int(2)])
    }

    // MARK: - Private
}

// Announcing by sending the procedure that shouts. An effect, so what it sends may
// run too.
private struct AnnounceEffect: Effect {
    enum Parameters: Int, ParameterSet {
        case of

        var declared: Parameter { Parameter(name: "of", type: .string) }
    }

    enum Imports: Int, ImportSet {
        case shout

        var selector: Name { "app.shout" }

        var handing: Int { 1 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.shout, handing: [invocation[.of]])
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
    }

    // MARK: - Property
    let isolated: Bool

    // MARK: - Initializer
    init(isolated: Bool) {
        self.isolated = isolated
    }

    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.ticket)
    }

    // MARK: - Private
}

// Sends a spelling nothing declares.
private struct StrayQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case nowhere

        var selector: Name { "app.nowhere" }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.nowhere)
    }

    // MARK: - Private
}

// Sends a spelling another document declares privately.
private struct ReachingQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case hidden

        var selector: Name { "app.hidden" }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.hidden)
    }

    // MARK: - Private
}

// Claims it answers without running, and sends something that runs.
private struct ShoutingQuery: Query {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case shout

        var selector: Name { "app.shout" }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.shout)
    }

    // MARK: - Private
}

// Hands two arguments, which stand at the callee's first two positions. What
// the callee answers says which one stood second.
private struct PickingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var handing: Int { 2 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, handing: [.int(1), .int(9)])
    }

    // MARK: - Private
}

// Hands more than the callee takes.
private struct OvercountingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var handing: Int { 3 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, handing: [.int(1), .int(2), .int(3)])
    }

    // MARK: - Private
}

// Declares it hands two and hands three.
private struct OverhandingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var handing: Int { 2 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, handing: [.int(9), .int(1), .int(3)])
    }

    // MARK: - Private
}

// Declares it hands one to a procedure that requires two.
private struct UndercountingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case pick

        var selector: Name { "app.pick" }

        var handing: Int { 1 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.pick, handing: [.int(9)])
    }

    // MARK: - Private
}

// Hands an int to a procedure whose first parameter is declared string.
private struct MistypingEffect: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case speak

        var selector: Name { "app.speak" }

        var handing: Int { 1 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.speak, handing: [.int(7)])
    }

    // MARK: - Private
}

// Hands null to a procedure whose first parameter is declared string.
private struct NullingToAParameter: Effect {
    typealias Parameters = NoParameters

    enum Imports: Int, ImportSet {
        case reporting

        var selector: Name { "app.reporting" }

        var handing: Int { 1 }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) async throws -> Value {
        try await invocation.send(.reporting, handing: [.null])
    }

    // MARK: - Private
}

// Declares what it is handed, as a string.
private struct SaidReporter: Effect {
    enum Parameters: Int, ParameterSet {
        case said

        var declared: Parameter { Parameter(name: "said", type: .string) }
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation<Self>) throws -> Value {
        .string("reported")
    }

    // MARK: - Private
}

private extension Module {
    static let sending = try! Module(
        procedures: [
            "app.twice": Procedure(
                signature: Signature(of: TwiceQuery.self, returns: .int),
                implementation: .query(TwiceQuery())
            ),
            "app.announce": Procedure(
                signature: Signature(of: AnnounceEffect.self, returns: .string),
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

    static let reaching = try! Module(
        procedures: [
            "app.reach": Procedure(
                signature: Signature(of: ReachingQuery.self, returns: .int),
                implementation: .query(ReachingQuery())
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

    // The callee three of the tests above hand arguments to: it answers `z`, so an
    // argument standing at the wrong place shows in the answer.
    static let picked = try! Module(
        procedures: [
            "app.pick": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "a", type: .int), Parameter(name: "z", type: .int)],
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

    static let overcounting = try! Module(
        procedures: [
            "app.overcounting": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(OvercountingEffect())
            )
        ]
    )

    static let undercounting = try! Module(
        procedures: [
            "app.undercounting": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(UndercountingEffect())
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

    static let spoken = try! Module(
        procedures: [
            "app.speak": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "said", type: .string)],
                    returns: .string
                ),
                body: [],
                result: .reference([.key("said")])
            )
        ]
    )

    static let mistyping = try! Module(
        procedures: [
            "app.mistyping": Procedure(
                signature: Signature(returns: .string),
                implementation: .effect(MistypingEffect())
            )
        ]
    )

    static let reporting = try! Module(
        procedures: [
            "app.reporting": Procedure(
                signature: Signature(of: SaidReporter.self, returns: .string),
                implementation: .effect(SaidReporter())
            )
        ]
    )

    static let nullingToAParameter = try! Module(
        procedures: [
            "app.nullingToAParameter": Procedure(
                signature: Signature(returns: .string),
                implementation: .effect(NullingToAParameter())
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
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func evaluate(_ question: Question<Self>) async throws -> Value? {
        try await question.send(.first)
    }

    // MARK: - Private
}

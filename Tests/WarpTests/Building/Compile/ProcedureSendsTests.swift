//
//  ProcedureSendsTests.swift
//  WarpTests
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Testing
@testable import Warp
import WarpTestSupport

// What a native procedure sending another procedure answers, and what the build refuses
// before anything runs. A procedure declares the procedures it sends the way it declares
// the arguments it reads, so both are the build's to resolve.
@Suite("A procedure sends a procedure the build resolved")
struct ProcedureSendsTests {
    // Doubling by sending the procedure that multiplies, rather than multiplying here.
    // What it sends is its own declaration, so the build resolves the row and this
    // reads it.
    private struct TwiceQuery: Query {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .int) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        enum Imports: Int, ImportSet {
            case times

            // MARK: - Property
            var selector: Name { "Int.times" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.times, handing: [question[.of], .int(2)])
        }

        // MARK: - Private
    }

    // Announcing by sending the procedure that shouts. An effect, so what it sends may
    // run too.
    private struct AnnounceEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case of

            // MARK: - Property
            var declared: Parameter { Parameter(name: "of", type: .string) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        enum Imports: Int, ImportSet {
            case shout

            // MARK: - Property
            var selector: Name { "App.shout" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
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

            // MARK: - Property
            var selector: Name { "App.ticket" }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        let isolated: Bool

        // MARK: - Initializer
        init(isolated: Bool) {
            self.isolated = isolated
        }

        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.ticket)
        }

        // MARK: - Private
    }

    // Sends a spelling nothing declares.
    private struct StrayQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case nowhere

            // MARK: - Property
            var selector: Name { "App.nowhere" }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.nowhere)
        }

        // MARK: - Private
    }

    // Sends a spelling another document declares privately.
    private struct ReachingQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case hidden

            // MARK: - Property
            var selector: Name { "App.hidden" }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.hidden)
        }

        // MARK: - Private
    }

    // Sends a contract's procedure, which no declaration wears.
    private struct TellingQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case describe

            // MARK: - Property
            var selector: Name { "App.Describable.describe" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
            try await question.send(.describe, handing: [["balance": .int(1)]])
        }

        // MARK: - Private
    }

    // Claims it answers without running, and sends something that runs.
    private struct ShoutingQuery: Query {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case shout

            // MARK: - Property
            var selector: Name { "App.shout" }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func evaluate(_ question: Question<Self>) async throws -> Value {
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

            // MARK: - Property
            var selector: Name { "App.pick" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
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

            // MARK: - Property
            var selector: Name { "App.pick" }

            var handing: Int { 3 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
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

            // MARK: - Property
            var selector: Name { "App.pick" }

            var handing: Int { 2 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
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

            // MARK: - Property
            var selector: Name { "App.pick" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            try await invocation.send(.pick, handing: [.int(9)])
        }

        // MARK: - Private
    }

    // Hands an int to a procedure whose first parameter is declared `String`.
    private struct MistypingEffect: Effect {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case speak

            // MARK: - Property
            var selector: Name { "App.speak" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) async throws -> Value {
            try await invocation.send(.speak, handing: [.int(7)])
        }

        // MARK: - Private
    }

    // Hands null to a procedure whose first parameter is declared `String`.
    private struct NullingEffect: Effect {
        typealias Parameters = NoParameters

        enum Imports: Int, ImportSet {
            case reporting

            // MARK: - Property
            var selector: Name { "App.reporting" }

            var handing: Int { 1 }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
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
    private struct ReportingEffect: Effect {
        enum Parameters: Int, ParameterSet {
            case said

            // MARK: - Property
            var declared: Parameter { Parameter(name: "said", type: .string) }

            // MARK: - Initializer
            // MARK: - Public
            // MARK: - Private
        }

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        func run(_ invocation: Invocation<Self>) throws -> Value {
            .string("reported")
        }

        // MARK: - Private
    }

    // MARK: - Property
    private static let sending = try! Module(
        procedures: [
            "App.twice": Procedure(
                signature: Signature(of: TwiceQuery.self, returns: .int),
                implementation: .query(TwiceQuery())
            ),
            "App.announce": Procedure(
                signature: Signature(of: AnnounceEffect.self, returns: .string),
                implementation: .effect(AnnounceEffect())
            )
        ]
    )

    private static let strayed = try! Module(
        procedures: [
            "App.stray": Procedure(
                signature: Signature(of: StrayQuery.self, returns: .null),
                implementation: .query(StrayQuery())
            )
        ]
    )

    private static let reaching = try! Module(
        procedures: [
            "App.reach": Procedure(
                signature: Signature(of: ReachingQuery.self, returns: .int),
                implementation: .query(ReachingQuery())
            )
        ]
    )

    private static let telling = try! Module(
        procedures: [
            "App.telling": Procedure(
                signature: Signature(of: TellingQuery.self, returns: .string),
                implementation: .query(TellingQuery())
            )
        ]
    )

    // A contract, a type answering it, and the declaration that answers.
    private static let describing = try! Module(
        types: ["Bank.Account": .record(["balance": .int])],
        contracts: [
            "App.Describable": [
                "describe": ContractProcedure(
                    signature: Signature(parameters: [Parameter(name: "of", type: .selfType)], returns: .string),
                    constness: .const,
                    isolation: .isolated
                )
            ]
        ],
        claims: ["Bank.Account": ["App.Describable"]],
        procedures: [
            "Bank.Account.describe": Procedure(
                access: .public,
                signature: Signature(parameters: [Parameter(name: "of", type: .named("Bank.Account"))], returns: .string),
                body: [],
                result: .literal(.string("an account"))
            )
        ]
    )

    private static let contradicting = try! Module(
        procedures: [
            "App.shouting": Procedure(
                signature: Signature(of: ShoutingQuery.self, returns: .null),
                implementation: .query(ShoutingQuery())
            )
        ],
        identity: Identity([0x01])
    )

    // `App.counted` twice: here it says it touches nothing shared and is refused
    // for sending the ticketing procedure, and in `counting` it says it does.
    private static let claims = try! Module(
        procedures: [
            "App.counted": Procedure(
                signature: Signature(of: CountedQuery.self, returns: .int),
                implementation: .query(CountedQuery(isolated: true))
            )
        ]
    )

    private static let counting = try! Module(
        procedures: [
            "App.counted": Procedure(
                signature: Signature(of: CountedQuery.self, returns: .int),
                implementation: .query(CountedQuery(isolated: false))
            )
        ]
    )

    // The callee the handing tests below hand arguments to: it answers `z`, so
    // an argument standing at the wrong place shows in the answer.
    private static let picked = try! Module(
        procedures: [
            "App.pick": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "a", type: .int), Parameter(name: "z", type: .int)],
                    returns: .int
                ),
                body: [],
                result: .reference([.key("z")])
            )
        ]
    )

    private static let pickedInPlace = try! Module(
        procedures: [
            "App.pick": Procedure(
                signature: Signature(parameters: [Parameter(name: "a", type: .inout(.int))], returns: .int),
                body: [],
                result: .reference([.key("a")])
            )
        ]
    )

    private static let picking = try! Module(
        procedures: [
            "App.picking": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(PickingEffect())
            )
        ]
    )

    private static let overcounting = try! Module(
        procedures: [
            "App.overcounting": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(OvercountingEffect())
            )
        ]
    )

    private static let undercounting = try! Module(
        procedures: [
            "App.undercounting": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(UndercountingEffect())
            )
        ]
    )

    private static let overhanding = try! Module(
        procedures: [
            "App.overhanding": Procedure(
                signature: Signature(returns: .int),
                implementation: .effect(OverhandingEffect())
            )
        ]
    )

    private static let spoken = try! Module(
        procedures: [
            "App.speak": Procedure(
                signature: Signature(
                    parameters: [Parameter(name: "said", type: .string)],
                    returns: .string
                ),
                body: [],
                result: .reference([.key("said")])
            )
        ]
    )

    private static let mistyping = try! Module(
        procedures: [
            "App.mistyping": Procedure(
                signature: Signature(returns: .string),
                implementation: .effect(MistypingEffect())
            )
        ]
    )

    private static let reporting = try! Module(
        procedures: [
            "App.reporting": Procedure(
                signature: Signature(of: ReportingEffect.self, returns: .string),
                implementation: .effect(ReportingEffect())
            )
        ]
    )

    private static let nullingToAParameter = try! Module(
        procedures: [
            "App.nullingToAParameter": Procedure(
                signature: Signature(returns: .string),
                implementation: .effect(NullingEffect())
            )
        ]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure answers through the procedure it declared it sends")
    func aProcedureReachesWhatItDeclared() async throws {
        // Given
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.twice", arguments: [.literal(.int(2))]))
            )])] + [Self.sending, .shouting] + Module.standard
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
                result: .call(Call(selector: "App.announce", arguments: [.literal(.string("hi"))]))
            )])] + [Self.sending, .shouting] + Module.standard
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .string("HI"))
    }

    @Test("a procedure sending a spelling nothing declares is refused at the build")
    func anUndeclaredSendIsRefused() async {
        // Given / When / Then
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [Self.strayed]
            )
        } throws: { error in
            error is BuildError
                && "\(error)".contains("sends 'App.nowhere', which no module in this link declares")
        }
    }

    @Test("a procedure sending a contract's procedure is refused at the build")
    func aSendNamingAContractsProcedureIsRefused() async throws {
        // Given. `App.telling` sends `App.Describable.describe`, which the
        // contract declares and no declaration wears
        let describing = try await Builder().compile([Self.describing])

        // When / Then. Built together, and compiled against the contract
        let together = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])]), Self.describing, Self.telling]
                    + Module.standard
            )
        }
        let against = await #expect(throws: BuildError.self) {
            try await Builder().compile([Self.telling], against: describing, supplying: Supplying([Self.telling]))
        }

        for refusal in [together, against] {
            #expect(
                refusal?.message == "sends 'App.Describable.describe', which is a contract's procedure. A send names"
                    + " the declaration it reaches, and which declaration answers a contract's procedure is a"
                    + " call's first argument to say"
            )
        }
    }

    @Test("a procedure sending another document's private declaration is refused at the build")
    func aSendReachingAPrivateDeclarationIsRefused() async throws {
        // Given. A document declares `App.hidden` privately, and a procedure the
        // host brings declares it sends that spelling.
        let document = try Module(procedures: [
            "App.hidden": Procedure(access: .private, body: [], result: .literal(.int(7))),
            "entry": Procedure(access: .public, body: [], result: .call(Call(selector: "App.reach")))
        ])

        // When / Then
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build([document, Self.reaching] + Module.standard)
        }

        #expect(refusal?.message.contains("is private to the document that declares it") == true)
    }

    @Test("a query sending something that answers only by running is refused in its own document")
    func aQuerySendingAnEffectIsRefused() async {
        // Given / When. `App.shouting` claims it answers without running and
        // sends `App.shout`, which does not
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [Self.contradicting, .shouting]
            )
        }

        // Then
        #expect(refusal?.place == Place.procedure("App.shouting", in: .of(Self.contradicting)).part(.imports))
    }

    @Test("an isolated Procedure sending one that keeps state is refused")
    func anIsolatedProcedureSendingSharedStateIsRefused() async {
        // Given / When / Then. `App.counted` says it touches nothing shared
        // and sends `App.ticket`, which answers from a box it keeps between
        // calls
        await #expect {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [Self.claims, .ticketing]
            )
        } throws: { error in
            error is BuildError
                && "\(error)".contains("says it touches no name another body could touch at the same time, and sends 'App.ticket'")
        }
    }

    @Test("an isolated Procedure compiled apart from the stateful one it sends is refused at the build")
    func anIsolatedProcedureCompiledApartIsRefused() async throws {
        // Given. `App.ticket` is compiled on its own
        let ticketing = try await Builder().compile([.ticketing])

        // When / Then. Compiled alone, `App.counted` sends a spelling nothing
        // standing declares, and compiled against `App.ticket` it is held to
        // what that procedure keeps
        let alone = await #expect(throws: BuildError.self) {
            let counted = try await Builder().compile([Self.claims])

            _ = try Builder().link(counted + ticketing, supplying: Supplying([Self.claims, .ticketing]))
        }
        let against = await #expect(throws: BuildError.self) {
            try await Builder().compile([Self.claims], against: ticketing, supplying: Supplying([.ticketing]))
        }

        #expect(alone?.message == "sends 'App.ticket', which no module in this link declares")
        #expect(
            against?.message.contains("says it touches no name another body could touch at the same time, and sends 'App.ticket'")
                == true
        )
    }

    @Test("a query compiled apart from the effect it sends is refused at the build")
    func aQueryCompiledApartIsRefused() async throws {
        // Given. `App.shout` is compiled on its own
        let shouting = try await Builder().compile([.shouting])

        // When / Then. Compiled alone, `App.shouting` sends a spelling nothing
        // standing declares, and compiled against `App.shout` it is held to
        // answering only by running
        let alone = await #expect(throws: BuildError.self) {
            let contradicting = try await Builder().compile([Self.contradicting])

            _ = try Builder().link(contradicting + shouting, supplying: Supplying([Self.contradicting, .shouting]))
        }
        let against = await #expect(throws: BuildError.self) {
            try await Builder().compile([Self.contradicting], against: shouting, supplying: Supplying([.shouting]))
        }

        #expect(alone?.message == "sends 'App.shout', which no module in this link declares")
        #expect(against?.message.contains("answers without running and sends 'App.shout', which answers only by running") == true)
    }

    @Test("a procedure that says it touches shared state may send one that does")
    func aSharedProcedureSendingSharedStateStands() async throws {
        // Given
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.counted"))
            )])] + [Self.counting, .ticketing]
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(1))
    }

    @Test("what a native procedure sends counts in the module's disclosure")
    func nativeSendsAreDisclosed() throws {
        // Given / When / Then. The list is what a host reads to decide what
        // to grant, so a procedure's own sends are in it
        #expect(Self.sending.imports == ["Int.times", "App.shout"])
    }

    @Test("a module claiming a list its procedures contradict is refused")
    func aDriftedDisclosureIsRefused() {
        // Given / When / Then
        #expect {
            try Module(
                imports: [],
                procedures: [
                    "App.twice": Procedure(
                        signature: Signature(of: TwiceQuery.self, returns: .int),
                        implementation: .query(TwiceQuery())
                    )
                ]
            )
        } throws: { error in
            error is ValidationError && "\(error)".contains("uses [\"Int.times\"], which it does not import")
        }
    }

    @Test("what a procedure hands over stands at the callee's first positions")
    func handedArgumentsStandAtTheCalleesPositions() async throws {
        // Given. `App.picking` hands two values, and the callee answers the one
        // standing at its second position
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.picking"))
            )])] + [Self.picking, Self.picked]
        )

        // When
        let answer = try await Executor().run(image)

        // Then
        #expect(answer == .int(9))
    }

    @Test("a procedure handing more than the callee takes is refused at the build")
    func handingMoreThanTheCalleeTakesIsRefused() async {
        // Given / When / Then. `App.pick` takes two, and a third would stand at
        // a position the callee does not have
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [Self.overcounting, Self.picked]
            )
        }

        #expect(refusal?.message.contains("sends 'App.pick' 3 arguments, and it takes 2") == true)
    }

    @Test("a procedure handing fewer than the callee takes is refused at the build")
    func handingFewerThanTheCalleeTakesIsRefused() async {
        // Given / When / Then. `App.pick` takes two, and a send handing one is
        // a count every run would refuse
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])] + [Self.undercounting, Self.picked]
            )
        }

        #expect(refusal?.message.contains("sends 'App.pick' 1 arguments, and it takes 2") == true)
    }

    @Test("a procedure sending one that takes a parameter in place is refused at the build")
    func aSendToAParameterInPlaceIsRefused() async {
        // Given / When / Then. A send hands values, and `App.pick` here takes
        // its one parameter in place
        let refusal = await #expect(throws: BuildError.self) {
            try await Builder().build(
                [try Module(procedures: ["entry": Procedure(access: .public, body: [])])]
                    + [Self.undercounting, Self.pickedInPlace]
            )
        }

        #expect(refusal?.message.contains("sends 'App.pick', which takes 'a' in place, and a send hands values") == true)
    }

    @Test("a procedure handing more than it declared it hands is refused when it sends")
    func handingMoreThanDeclaredIsRefused() async throws {
        // Given. How many a Swift body builds is the body's, so this is the one
        // thing about a send the build cannot read
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.overhanding"))
            )])] + [Self.overhanding, Self.picked]
        )

        // When / Then
        await #expect {
            try await Executor().run(image)
        } throws: { error in
            error is ArgumentError && "\(error)".contains("'App.pick' was given 3 arguments, and it takes 2")
        }
    }

    @Test("a procedure handing what the callee cannot take is refused at the boundary")
    func aMistypedArgumentIsRefused() async throws {
        // Given. `App.mistyping` hands an int to a procedure whose first
        // parameter is declared `String`
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.mistyping"))
            )])] + [Self.mistyping, Self.spoken]
        )

        // When / Then. The same refusal a call written in a document earns, and
        // it names the parameter rather than the answer
        await #expect(throws: ArgumentError.self) {
            try await Executor().run(image)
        }
    }

    @Test("a value a send hands over is held to the parameter it fills")
    func aHandedNullIsHeldToItsType() async throws {
        // Given. `App.reporting` declares `said: String`, and null is not a
        // string. The same gate an argument a body writes goes through
        let image = try await Builder().build(
            [try Module(procedures: ["entry": Procedure(
                access: .public,
                body: [],
                result: .call(Call(selector: "App.nullingToAParameter"))
            )])] + [Self.nullingToAParameter, Self.reporting]
        )

        // When / Then
        let refusal = await #expect(throws: ArgumentError.self) {
            try await Executor().run(image)
        }

        #expect(refusal?.message.contains("expected String, got Null") == true)
    }

    // MARK: - Public
    // MARK: - Private
}

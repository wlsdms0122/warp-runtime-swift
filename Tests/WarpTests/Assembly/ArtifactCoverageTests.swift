//
//  ArtifactCoverageTests.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
import Testing
@testable import Warp

// An artifact naming every kind of thing an artifact can name.
//
// The specification's cases round-trip whole programs, and what they reach is
// what programs happen to be written out of: measured, 55 of the 122 kinds a
// writing can lay down are never among them. `Construct`, `Argument` and
// `LoweredType.Bound` are reached by none of them at all.
//
// A kind the pair disagrees about is a silent one. The writing and the reading
// would each be exhaustive, each be compiled, and the artifact would come back
// as something else. So this stands one of everything up and asks the pair to
// agree, and it holds a distinct value in every field so that two fields
// swapped between the two sides is a difference and not a coincidence.
@Suite("An artifact of one of everything")
struct ArtifactCoverageTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("reads back as the artifact it was written from")
    func everyKindSurvives() throws {
        // Given / When. Written, read, and written again.
        let sut = Self.everything
        let written = try sut.written
        let read = try Compiled(written: written)

        // Then. One artifact is one writing, and a pair that disagreed about
        // any one kind would part here.
        #expect(try read.written == written)
    }

    // MARK: - Public
    // MARK: - Private
    private static let everything: Compiled = {
        Compiled(
            document: Place.Document(identity: Identity([1, 2, 3])),
            types: ["a.one": .any, "a.two": .never, "a.three": everyTypeExpression],
            constraints: ["a.four": [.int, .string]],
            contracts: ["a.five": ["a.six": Signature(receiver: "r", parameters: ["p": parameter], returns: .bool)]],
            claims: ["a.seven": ["a.eight", "a.nine"]],
            leaned: everyPlace,
            declared: ["a.ten", "a.eleven"],
            table: [row(label: "a.ten", body: true), row(label: "a.eleven", body: false)],
            calls: [["a.twelve"], []],
            answers: ["a.ten": everyLoweredType],
            numbering: Numbering(imports: ["a.twelve"], declared: ["a.ten", "a.eleven"], closures: ["a.ten": 2]),
            typeNumbering: try! LoweredTypeNumbering(ordered: ["a.one", "a.two"], memberships: ["a.four"]),
            variables: [(name: "a.thirteen", value: .int(13)), (name: "a.fourteen", value: .string("x"))]
        )
    }()

    private static let parameter = Parameter(
        type: .double,
        candidates: ["one", "two"],
        default: .string("one"),
        description: "what it takes"
    )

    // Every case of `TypeExpression`, each holding something no other holds.
    private static let everyTypeExpression: TypeExpression = .record([
        "any": .any,
        "never": .never,
        "null": .null,
        "bool": .bool,
        "int": .int,
        "double": .double,
        "string": .string,
        "bytes": .bytes,
        "number": .number,
        "whole": .ranged(.whole(from: -2, to: .through(9))),
        "fraction": .ranged(.fraction(from: 0.5, to: .upTo(1.5))),
        "array": .array(.int),
        "dictionary": .dictionary(.string),
        "procedure": .procedure(Signature(returns: .null), .pure, .isolated),
        "variable": .variable(.bool),
        "inout": .inout(.bytes),
        "linear": .linear(.number),
        "consuming": .consuming(.double),
        "borrowing": .borrowing(.string),
        "nullable": .nullable(.int),
        "named": .named("a.one"),
        "parameter": .parameter(name: "T", constraint: "a.four"),
        "reading": .reading(
            of: "a.fifteen",
            path: [
                .key("k", optional: true),
                .index(3, optional: false),
                .indexRef([.key("inner", optional: false)], optional: true)
            ]
        )
    ])

    // Every case of `LoweredType`, the same way.
    private static let everyLoweredType: LoweredType = .record(
        LoweredRecord(
            layout: try! Layout(fields: Self.loweredFields.map(\.0)),
            fields: Self.loweredFields.sorted { one, other in one.0 < other.0 }.map(\.1)
        )
    )

    private static let loweredFields: [(Name, LoweredType)] = [
        ("any", .any),
        ("never", .never),
        ("null", .null),
        ("bool", .bool),
        ("int", .int),
        ("double", .double),
        ("string", .string),
        ("bytes", .bytes),
        ("number", .number),
        ("ranged", .ranged(.whole(from: 1, to: .upTo(4)))),
        ("array", .array(.string)),
        ("dictionary", .dictionary(.bool)),
        ("procedure", .procedure(
            parameters: [(name: "p", type: .int, mustBeGiven: true)],
            returns: .double,
            purity: .pure,
            isolation: .unstated
        )),
        ("variable", .variable(.int)),
        ("inoutish", .inout(.bool)),
        ("nullable", .nullable(.bytes)),
        ("named", .named(2)),
        ("parameterMembership", .parameter(label: "T", bound: .membership(5))),
        ("parameterContract", .parameter(label: "U", bound: .contract("a.five"))),
        ("parameterNone", .parameter(label: "V", bound: nil)),
        ("reading", .reading(of: "a.sixteen", path: [.index(1, optional: true)])),
        ("member", .member(7)),
        ("undeclared", .undeclared(label: "W", refusal: "nothing declares it"))
    ]

    // Every case of `Place.Step`, `Place.Part`, `Place.ConditionHolder` and
    // `Construct`, reached through the one field of an artifact that holds a
    // place.
    private static let everyPlace: [Claim: Place] = {
        let steps: [Place.Step] = [
            .key("written"),
            .index(4),
            .statement(name: "named", at: 2),
            .statement(name: nil, at: 3),
            .landmark("here")
        ]
        + Self.everyPart.map(Place.Step.part)
        + Self.everyConstruct.map(Place.Step.construct)

        return [
            Claim(type: "a.seventeen", contract: "a.five"): Place(steps, in: Place.Document(identity: Identity([9]))),
            Claim(type: "a.eighteen", contract: "a.five"): Place([], in: .assembled)
        ]
    }()

    private static let everyPart: [Place.Part] = [
        .procedures, .constants, .variables, .types, .constraints, .contracts, .satisfies,
        .imports, .parameters, .returns, .body, .result, .receiver, .callee, .arguments,
        .closure, .condition(of: .conditional), .condition(of: .loop), .then, .otherwise, .rescue
    ]

    private static let everyConstruct: [Construct] = [
        .literal, .reference, .array, .record, .closure, .cast, .apply, .block,
        .conditional, .loop, .attempt, .call, .leave(.procedure), .leave(.construct), .leave(.round)
    ]

    private static func row(label: Name, body: Bool) -> Judged {
        Judged(
            label: label,
            signature: Signature(receiver: body ? "self" : nil, parameters: ["p": parameter], returns: .int),
            purity: body ? .pure : .unstated,
            isolation: body ? .unstated : .isolated,
            failing: body ? .these(["a.fail", "b.fail"]) : .unstated,
            sends: [Sent(row: 1, offers: [0, 2])],
            implementation: body
                ? .body(everyOperation, Frame(size: 12, parameters: [0], variables: [(variable: 1, slot: 2)], names: ["p"]))
                : .native(sending: [Native.Send(position: 3, selector: "a.twelve", offers: ["x", "y"])])
        )
    }

    // Every case of `Operation`, `Instruction.Binding`, `Step` and `Argument`.
    private static let everyOperation = Body(
        instructions: [
            Instruction(binding: .bind(0, settling: .int), code: .literal(.int(1)), label: "bind"),
            Instruction(binding: .declare(1, settling: nil), code: .literal(.string("s")), label: "declare"),
            Instruction(
                binding: .assign(Address(slot: 2, steps: everyStep), settling: .bool),
                code: .local(Address(slot: 3, steps: [])),
                label: "assign"
            ),
            Instruction(binding: nil, code: .array([.literal(.null), .literal(.bool(true))]), label: "array"),
            Instruction(binding: nil, code: .record(recordOperation), label: "record"),
            Instruction(binding: nil, code: .closure(1, captures: [(4, 0), (5, 1)]), label: "closure"),
            Instruction(
                binding: nil,
                code: .apply(.local(Address(slot: 6, steps: [])), arguments: [("a", .literal(.int(2)))]),
                label: "apply"
            ),
            Instruction(binding: nil, code: .cast(.literal(.int(3)), as: .string, optional: true), label: "cast"),
            Instruction(binding: nil, code: .block(Body(instructions: [], result: .literal(.int(4)))), label: "block"),
            Instruction(
                binding: nil,
                code: .conditional(
                    .literal(.bool(false)),
                    then: [Instruction(binding: nil, code: .literal(.int(5)), label: "then")],
                    else: [Instruction(binding: nil, code: .literal(.int(6)), label: "else")]
                ),
                label: "conditional"
            ),
            Instruction(
                binding: nil,
                code: .loop(
                    while: .literal(.bool(true)),
                    body: Body(instructions: [], result: nil),
                    round: 7,
                    keeps: 8 ..< 9
                ),
                label: "loop"
            ),
            Instruction(
                binding: nil,
                code: .attempt(
                    Body(instructions: [], result: .literal(.int(7))),
                    rescue: Body(instructions: [], result: .literal(.int(8))),
                    failure: 10
                ),
                label: "attempt"
            ),
            Instruction(binding: nil, code: .call(callOperation), label: "call"),
            Instruction(binding: nil, code: .dispatch(dispatchOperation), label: "dispatch"),
            Instruction(
                binding: nil,
                code: .leave(.construct, target: "away", .literal(.int(9))),
                label: "leave"
            ),
            Instruction(binding: nil, code: .leave(.round, target: nil, nil), label: "leave bare")
        ],
        result: .local(Address(slot: 11, steps: []))
    )

    private static let everyStep: [Step] = [
        .field(0, "f", optional: false),
        .key("k", optional: true),
        .index(2, optional: false),
        .at(Address(slot: 4, steps: []), optional: true)
    ]

    private static let recordOperation = RecordOperation(
        layout: try! Layout(fields: ["x", "y"]),
        fields: [.literal(.int(10)), .literal(.int(11))]
    )

    private static let callOperation = CallOperation(
        procedure: 2,
        receiver: .literal(.int(12)),
        arguments: [.literal(.int(13)), nil],
        handed: [CallOperation.Handed(position: 1, address: Address(slot: 5, steps: []))]
    )

    private static let dispatchOperation = DispatchOperation(
        contract: "a.five",
        procedure: "a.six",
        receiver: .literal(.int(14)),
        arguments: [
            "byValue": .value(.literal(.int(15))),
            "byReference": .reference(Address(slot: 6, steps: []))
        ],
        calls: ["a.nineteen": callOperation]
    )
}

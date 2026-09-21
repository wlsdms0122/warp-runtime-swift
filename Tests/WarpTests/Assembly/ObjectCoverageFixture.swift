//
//  ObjectCoverageFixture.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
@testable import Warp

// An object holding one of every kind a writing can lay down.
//
// It stands apart from the cases that read it because two of them do: one asks
// whether the writing and the reading agree about every kind, and one bends
// every field of it in turn. A fixture named by two suites is a fixture, not a
// suite's private.
enum ObjectCoverageFixture {
    static let everything: Compiled = {
        // Through the door a reading goes through, so the fixture cannot stand
        // up an object the reading would refuse.
        try! Compiled(
            document: Place.Document(identity: Identity([1, 2, 3])),
            types: ["a.one": .any, "a.two": .never, "a.three": everyTypeExpression],
            constraints: ["a.four": [.int, .string]],
            contracts: ["a.five": ["a.six": ContractProcedure(signature: Signature(receiver: "r", parameters: ["p": parameter], returns: .bool), constness: .const, isolation: .isolated)]],
            claims: ["a.seven": ["a.eight", "a.nine"]],
            leaned: everyPlace,
            declared: ["a.eleven", "a.ten"],
            constants: ["a.sixteen"],
            // Two declarations and the two closures their bodies lifted, which
            // is the order a document numbers its rows in.
            table: [
                try row(label: "a.eleven", body: true),
                try row(label: "a.ten", body: false),
                try lifted(label: "a.eleven"),
                try lifted(label: "a.eleven")
            ],
            answers: ["a.eleven": everyLoweredType],
            // The two closures behind the spellings belong to the declaration whose
            // body stands them up, which is the one with a body.
            numbering: Numbering(
                sends: ["a.twelve"],
                declared: ["a.eleven", "a.ten"],
                closures: ["a.eleven": 2]
            ),
            typeNumbering: try! LoweredTypeNumbering(ordered: ["a.one", "a.two"], memberships: ["a.four"]),
            // One of every kind of value, and a closure standing by what it is
            // spelled by, holding one of everything.
            judging: [
                (name: "a.fifteen", value: .procedure(everyValueClosure)),
                (name: "a.fourteen", value: .string("x")),
                (name: "a.thirteen", value: .int(13))
            ],
            // In byte order, which is the order a writing lays a set down in.
            dependencies: [Fingerprint([0x01, 0x02]), Fingerprint([0x03])]
        )
    }()

    // A closure a fold settled, standing by its writing alone, whose one
    // captured cell holds every kind of value there is.
    static let everyValueClosure = Closure(
        writer: Closure.Writer(document: .written(Identity([1, 2, 3])), name: "a.eleven"),
        nth: 1,
        linked: nil,
        captured: [
            (
                slot: 0,
                cell: .value(
                    .array([
                        .null,
                        .bool(true),
                        .int(1),
                        .double(1.5),
                        .string("s"),
                        .bytes([1, 2]),
                        .record(Record(name: "a.three", ["b": .int(2), "a": .int(1)])),
                        .record(Record(name: nil, ["c": .null])),
                        .dictionary(Value.Dictionary(ordered: [(name: "k", value: .int(3))])),
                        .procedure(Closure(writer: Closure.Writer(document: .written(Identity([4])), name: "a.ten"), nth: 0, linked: nil, captured: []))
                    ])
                )
            )
        ]
    )

    static let parameter = Parameter(
        type: .double,
        candidates: ["one", "two"],
        default: .string("one"),
        description: "what it takes"
    )

    // Every case of `TypeExpression`, each holding something no other holds.
    static let everyTypeExpression: TypeExpression = .record([
        "any": .any,
        "never": .never,
        "null": .null,
        "bool": .bool,
        "int": .int,
        "double": .double,
        "string": .string,
        "whole": .ranged(.whole(from: -2, to: .through(9))),
        "fraction": .ranged(.fraction(from: 0.5, to: .upTo(1.5))),
        "array": .array(.int),
        "dictionary": .dictionary(.string),
        "procedure": .procedure(Signature(returns: .null), .const, .isolated),
        "variable": .variable(.bool),
        "inout": .inout(.string),
        "linear": .linear(.int),
        "consuming": .consuming(.double),
        "borrowing": .borrowing(.string),
        "nullable": .nullable(.int),
        "named": .named("a.one"),
        "parameter": .parameter(name: "T", constraints: ["a.four"]),
        "composition": .composition(["a.five", "a.four"]),
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
    static let everyLoweredType: LoweredType = .record(
        LoweredRecord(
            layout: try! Layout(fields: Self.loweredFields.map(\.0)),
            fields: Self.loweredFields.sorted { one, other in one.0 < other.0 }.map(\.1)
        )
    )

    static let loweredFields: [(Name, LoweredType)] = [
        ("any", .any),
        ("never", .never),
        ("null", .null),
        ("bool", .bool),
        ("int", .int),
        ("double", .double),
        ("string", .string),
        ("ranged", .ranged(.whole(from: 1, to: .upTo(4)))),
        ("array", .array(.string)),
        ("dictionary", .dictionary(.bool)),
        ("procedure", .procedure(
            parameters: [LoweredParameter(name: "p", type: .int, defaulted: false)],
            returns: .double,
            constness: .const,
            isolation: .unstated
        )),
        ("variable", .variable(.int)),
        ("inoutish", .inout(.bool)),
        ("nullable", .nullable(.string)),
        ("named", .named(2)),
        ("parameterMembership", .parameter(label: "T", bounds: [.membership(5)])),
        ("parameterContract", .parameter(label: "U", bounds: [.contract("a.five")])),
        ("parameterNone", .parameter(label: "V", bounds: [])),
        ("reading", .reading(of: "a.sixteen", path: [.index(1, optional: true)])),
        ("composition", .composition([.membership(7), .contract("a.five")])),
        ("undeclaredBound", .undeclared(label: "W", because: .noBoundNamed("a.thirteen"))),
        ("undeclaredType", .undeclared(label: "X", because: .noTypeNamed("a.fourteen"))),
        ("undeclaredCycle", .undeclared(label: "Y", because: .namesItself))
    ]

    // Every case of `Place.Step`, `Place.Part`, `Place.ConditionHolder` and
    // `Construct`, reached through the one field of an object that holds a
    // place.
    static let everyPlace: [Claim: Place] = {
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
            Claim(type: "a.seventeen", contract: "a.five"): Place(steps, in: Place.Document(identity: Identity([1, 2, 3]))),
            Claim(type: "a.eighteen", contract: "a.five"): Place([], in: .assembled)
        ]
    }()

    static let everyPart: [Place.Part] = [
        .procedures, .constants, .variables, .types, .constraints, .contracts, .satisfies,
        .imports, .parameters, .returns, .body, .result, .receiver, .callee, .arguments,
        .closure, .condition(of: .conditional), .condition(of: .loop), .then, .otherwise, .rescue
    ]

    static let everyConstruct: [Construct] = [
        .literal, .reference, .array, .record, .closure, .cast, .apply, .block,
        .conditional, .loop, .attempt, .call, .leave(.procedure), .leave(.construct), .leave(.round)
    ]

    // A row a closure literal was lifted into, whose frame holds what the
    // body that stood it up takes into it.
    static func lifted(label: Name) throws -> Judged {
        try Judged(
            label: label,
            signature: Signature(returns: .int),
            access: .internal,
            constness: .unstated,
            isolation: .unstated,
            failing: .unstated,
            sends: [],
            judging: .body(
                Body(instructions: [], result: .literal(.int(0))),
                Frame(size: 2, parameters: [], variables: [], captures: [0, 1], names: ["c0", "c1"])
            )
        )
    }

    static func row(label: Name, body: Bool) throws -> Judged {
        try Judged(
            label: label,
            signature: Signature(receiver: body ? "p" : nil, parameters: ["p": parameter], returns: .int),
            access: .internal,
            constness: body ? .const : .unstated,
            isolation: body ? .unstated : .isolated,
            failing: body ? .these(["a.fail", "b.fail"]) : .unstated,
            sends: body ? [] : [Sent(row: 1, handing: [0, 2])],
            judging: body
                ? .body(
                    everyOperation,
                    Frame(
                        size: 12,
                        parameters: [0],
                        variables: [(variable: 1, slot: 2)],
                        captures: [],
                        names: (0 ..< 12).map { at in Name(normal: "s\(at)") }
                    )
                )
                : .native(sending: [Native.Send(position: 3, selector: "a.twelve", handing: ["x", "y"])])
        )
    }

    // Every case of `Operation`, `Instruction.Binding`, `Step` and `Argument`.
    static let everyOperation = Body(
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
            // The number is a reference of this document, and the closures
            // stand behind the spellings: one import and two declarations, so
            // the first closure is three.
            Instruction(binding: nil, code: .closure(3, captures: [(4, 0), (5, 1)]), label: "closure"),
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

    static let everyStep: [Step] = [
        .field(0, "f", optional: false),
        .key("k", optional: true),
        .index(2, optional: false),
        .at(Address(slot: 4, steps: []), optional: true)
    ]

    static let recordOperation = RecordOperation(
        layout: try! Layout(fields: ["x", "y"]),
        fields: [.literal(.int(10)), .literal(.int(11))]
    )

    // Reaching the one name this document sends rather than one it declares,
    // so what the call hands over is the link's to judge.
    static let callOperation = CallOperation(
        procedure: 0,
        receiver: .literal(.int(12)),
        arguments: [.literal(.int(13)), nil],
        handed: [CallOperation.Handed(position: 1, address: Address(slot: 5, steps: []))]
    )

    static let dispatchOperation = DispatchOperation(
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

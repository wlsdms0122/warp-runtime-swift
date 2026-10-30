//
//  ObjectCoverageFixture.swift
//  WarpTests
//
//  Created by JSilver on 9/13/26.
//

import Foundation
@testable import Warp

// An object holding one of every kind a writing can lay down.
enum ObjectCoverageFixture {
    static let everything: Compiled = {
        // Through the door a reading goes through, so the fixture cannot stand
        // up an object the reading would refuse.
        try! Compiled(
            document: Place.Document(identity: Identity([1, 2, 3])),
            types: ["a.one": .alias(.any), "a.two": .alias(.never), "a.three": structOfEveryTypeExpression],
            // A contract asking a type it bounds and one it does not, and a
            // procedure.
            contracts: [
                "a.five": Contract(
                    procedures: [
                        "a.six": Signature(
                            parameters: [Parameter(name: "r", type: .selfType), parameter],
                            returns: .bool,
                            failing: .these(["a_nineteen", "a_twenty"]),
                            constness: .const
                        )
                    ],
                    types: ["Item", "Key"],
                    bounds: ["Key": ["a.four"]]
                )
            ],
            // A bare head and one applying its type, with a type parameter
            // bounded and one not.
            claims: [
                "a.seven": ["a.eight", "a.nine"],
                Head(
                    "a.three",
                    arguments: [.parameter(name: "T"), .array(.parameter(name: "U"))],
                    bounds: ["T": ["a.five", "a.six"]]
                ): ["a.five"]
            ],
            // A member is a row the document declares, under its type's name
            // and its own.
            members: ["a": ["ten"]],
            typeMembers: ["a.seven": ["Item": .int, "Key": .string]],
            importedClaims: [ClaimPair("b.one", "b.two"), ClaimPair("b.one", "b.three")],
            // Two declarations and the two closures their bodies lifted, which
            // is the order a document numbers its rows in.
            rows: [
                try row(label: "a.eleven", body: true),
                try row(label: "a.ten", body: false)
            ],
            lifted: [
                try lifted(label: "a.eleven"),
                try lifted(label: "a.eleven")
            ],
            constants: ["a.sixteen"],
            // The two closures behind the spellings belong to the declaration whose
            // body stands them up, which is the one with a body.
            numbering: Numbering(
                sends: ["a.twelve"],
                declared: ["a.eleven", "a.ten"],
                closures: [.procedure("a.eleven"): 2]
            ),
            typeNumbering: LoweredTypeNumbering(types: ["a.one", "a.two"]),
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

    // A closure a fold made, standing by its writing alone and holding the
    // types its writer's parameters were filled with, whose one captured
    // cell holds every kind of value there is, a closure and a value held
    // beside a type among them, one of those as a dictionary's key.
    static let everyValueClosure = Closure(
        writer: Closure.Writer(document: .written(Identity([1, 2, 3])), declaration: .procedure("a.eleven")),
        nth: 1,
        resolution: .spelled(types: ["T": .int, "U": .array(.string)]),
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
                        .struct(Struct(name: "a.three", ["b": .int(2), "a": .int(1)])),
                        .dictionary(Value.Dictionary(ordered: [(key: "k", value: .int(3))])),
                        .existential(Existential(.int(4), resolution: .spelled(.optional(.int)))),
                        .dictionary(
                            Value.Dictionary(
                                ordered: [(key: .existential(Existential("e", resolution: .spelled(.named("a.one")))), value: .int(5))]
                            )
                        ),
                        .procedure(Closure(writer: Closure.Writer(document: .written(Identity([4])), declaration: .procedure("a.ten")), nth: 0, resolution: .spelled(types: [:]), captured: []))
                    ])
                )
            )
        ]
    )

    static let parameter = Parameter(name: "p", type: .double)

    // Every case of `TypeExpression`, each holding something no other holds,
    // as the fields of a declared struct.
    static let structOfEveryTypeExpression: TypeDeclaration = .struct([
        "any": .any,
        "never": .never,
        "null": .null,
        "Bool": .bool,
        "Int": .int,
        "Double": .double,
        "String": .string,
        "array": .array(.int),
        "dictionary": .dictionary(key: .string, value: .string),
        "procedure": .procedure(ProcedureType(returns: .null, failing: .anything), .const, .isolated),
        "variable": .variable(.bool),
        "inout": .inout(.string),
        "optional": .optional(.int),
        "named": .named("a.one"),
        "parameter": .parameter(name: "T"),
        "associatedType": .associatedType(AssociatedType("Item", of: "T")),
        "composition": .composition(["a.five", "a.four"])
    ])

    // Every case of `LoweredType` an object writes, each holding something
    // no other holds, as the parameters of a procedure type.
    static let everyLoweredType: LoweredType = .procedure(
        LoweredProcedureType(parameters: Self.loweredTypes, returns: .optional(.double), failing: .anything),
        constness: .unstated,
        isolation: .isolated
    )

    static let loweredTypes: [LoweredType] = [
        .any,
        .never,
        .null,
        .bool,
        .int,
        .double,
        .string,
        .array(.string),
        .dictionary(key: .string, value: .bool),
        .procedure(
            LoweredProcedureType(parameters: [.int], returns: .double, failing: .these(["aborted"])),
            constness: .const,
            isolation: .unstated
        ),
        .variable(.int),
        .inout(.bool),
        .optional(.string),
        .named(2),
        .parameter(label: "U", bounds: ["a.five"]),
        .parameter(label: "V", bounds: []),
        .composition(["a.five", "a.four"])
    ]

    // Every case of `Operation`, `Instruction.Binding`, `Step` and `Argument`.
    static let everyOperation = LoweredBody(
        instructions: [
            Instruction(binding: .bind(0), code: .literal(.int(1)), label: "bind"),
            Instruction(binding: .declare(1), code: .literal(.string("s")), label: "declare"),
            Instruction(
                binding: .assign(Address(slot: 2, steps: everyStep)),
                code: .local(Address(slot: 3, steps: [], promoted: true)),
                label: "assign"
            ),
            Instruction(binding: nil, code: .array([.literal(.null), .literal(.bool(true))]), label: "array"),
            Instruction(binding: nil, code: .struct(structOperation), label: "struct"),
            // The number is a reference of this document, and the closures
            // stand behind the spellings: one import and two declarations, so
            // the first closure is three.
            Instruction(binding: nil, code: .closure(3, captures: [(4, 0), (5, 1)]), label: "closure"),
            Instruction(
                binding: nil,
                code: .apply(
                    .local(Address(slot: 6, steps: [])),
                    arguments: [.value(.literal(.int(2))), .reference(Address(slot: 6, steps: []))]
                ),
                label: "apply"
            ),
            Instruction(binding: nil, code: .cast(.literal(.int(3)), as: .string, optional: true), label: "cast"),
            Instruction(binding: nil, code: .cast(.literal(.int(3)), as: everyLoweredType, optional: false), label: "cast"),
            Instruction(
                binding: nil,
                code: .coerced(.literal(.int(3)), .held(.int, in: .composition(["Hashable"]))),
                label: "held"
            ),
            Instruction(binding: nil, code: .coerced(.literal(.int(3)), .dropped), label: "dropped"),
            Instruction(
                binding: nil,
                code: .coerced(.literal(.null), .wrapped(.dropped, steps: [.element, .key, .value])),
                label: "wrapped"
            ),
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
                    body: [Instruction(binding: nil, code: .literal(.int(4)), label: "round")],
                    round: 7
                ),
                label: "loop"
            ),
            Instruction(
                binding: nil,
                code: .try(
                    [Instruction(binding: nil, code: .literal(.int(7)), label: "attempted")],
                    catch: [Instruction(binding: nil, code: .literal(.int(8)), label: "rescued")],
                    failure: 10
                ),
                label: "try"
            ),
            Instruction(
                binding: nil,
                code: .unwrap(
                    .literal(.int(9)),
                    then: [Instruction(binding: nil, code: .literal(.int(10)), label: "some")],
                    else: [Instruction(binding: nil, code: .literal(.int(11)), label: "none")],
                    payload: 9
                ),
                label: "unwrap"
            ),
            Instruction(
                binding: .bind(9),
                code: .unwrap(
                    .literal(.null),
                    then: nil,
                    else: [Instruction(binding: nil, code: .leave(.procedure(nil)), label: "left")],
                    payload: nil
                ),
                label: "unwrap guarding"
            ),
            Instruction(binding: nil, code: .call(callOperation), label: "call"),
            Instruction(binding: nil, code: .dispatch(dispatchOperation), label: "dispatch"),
            Instruction(binding: nil, code: .leave(.loop("away")), label: "leave"),
            Instruction(binding: nil, code: .leave(.round(nil)), label: "leave bare"),
            Instruction(binding: nil, code: .leave(.procedure(.local(Address(slot: 11, steps: [])))), label: "return")
        ]
    )

    static let everyStep: [Step] = [
        .field(0, "f", optional: false),
        .name("k", optional: true),
        .index(2, optional: false),
        .at(Address(slot: 4, steps: []), optional: true, coercion: nil),
        .at(Address(slot: 5, steps: []), optional: false, coercion: .held(.int, in: .composition(["Hashable"]))),
        .at(Address(slot: 6, steps: []), optional: false, coercion: .dropped),
        .at(Address(slot: 7, steps: []), optional: false, coercion: .wrapped(nil, steps: [])),
        .at(Address(slot: 8, steps: []), optional: false, coercion: .wrapped(.dropped, steps: [.value]))
    ]

    static let structOperation = StructOperation(
        layout: Layout(name: "a.four", ordered: ["x", "y"]),
        fields: [.literal(.int(10)), .literal(.int(11))]
    )

    // Reaching the one name this document sends rather than one it declares,
    // so what the call hands over is the link's to judge.
    static let callOperation = CallOperation(
        placed: PlacedCall(
            procedure: 0,
            arguments: [.literal(.int(12)), .literal(.int(13)), nil],
            handed: [PlacedCall.Handed(position: 2, address: Address(slot: 5, steps: []))]
        ),
        types: [.string]
    )

    static let dispatchOperation = DispatchOperation(
        contract: "a.five",
        procedure: "a.six",
        types: [.int, .int, .inout(.string)],
        first: .value(.literal(.int(14))),
        arguments: [
            .value(.literal(.int(15))),
            .reference(Address(slot: 6, steps: []))
        ],
        calls: ["a.nineteen": callOperation.placed]
    )

    // A row a closure literal was lifted into, whose frame holds what the
    // body that stood it up takes into it, and whose return type is a type
    // parameter the procedure around it holds to two contracts.
    static func lifted(label: Name) throws -> Judged {
        try Judged(
            label: label,
            signature: Signature(returns: .parameter(name: "T"), failing: .anything, bounds: ["T": ["a.five", "a.four"]]),
            access: .internal,
            judging: .body(
                LoweredBody(instructions: [Instruction(binding: nil, code: .leave(.procedure(.literal(.int(0)))), label: "return")]),
                Frame(size: 2, parameters: [], variables: [], captures: [0, 1], names: ["c0", "c1"])
            )
        )
    }

    static func row(label: Name, body: Bool) throws -> Judged {
        try Judged(
            label: label,
            signature: Signature(
                parameters: [parameter],
                returns: .int,
                failing: body ? .these(["a_fail", "b_fail"]) : .anything,
                constness: body ? .const : .unstated,
                isolation: body ? .unstated : .isolated,
                sameTypes: body ? ["T.Item": .string] : [:]
            ),
            access: .internal,
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
                : .native(sending: [Native.Send(position: 0, selector: "a.twelve", handing: 2)])
        )
    }
}

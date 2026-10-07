//
//  Module+Foundation.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    // The contracts and the byte type the other bundles mention, declared
    // once where every bundle can name them, and the types the language names
    // answering them: what a number, an ordering and a count are for `Int`,
    // `Double`, `String`, `Array` and `Dictionary`. A document calling a
    // contract's procedure stands behind this one, so what answers stands
    // before it.
    static let foundation: [Module] = [
        Module(
            unchecked: Draft(
                description: "The shared ground: what counts as a number, what orders, and what has a count.",
                types: [
                    // One element of bytes. A whole number a range refines, not a kind
                    // of its own. Declared here so `bytes` and `Array<Standard.Byte>` can say
                    // they are the same thing in one vocabulary.
                    "Standard.Byte": .byteElement
                ],
                contracts: [
                    // What arithmetic is asked of: two of one kind, answered in
                    // that kind, and a quotient that is a fraction whatever the
                    // kind.
                    "Standard.Numeric": [
                        "plus": .operation(answering: .selfType),
                        "minus": .operation(answering: .selfType),
                        "times": .operation(answering: .selfType),
                        "remainder": .operation(answering: .selfType),
                        "dividedBy": .operation(answering: .double)
                    ],
                    // What orders two of one kind.
                    "Standard.Comparable": [
                        "lessThan": .operation(answering: .bool)
                    ],
                    // What has a count.
                    "Standard.Collection": [
                        "count": ContractProcedure(
                            signature: Signature(parameters: [Parameter(name: "collection", type: .selfType)], returns: .int),
                            constness: .const,
                            isolation: .isolated
                        )
                    ]
                ],
                claims: [
                    "Array": ["Standard.Collection"],
                    "Dictionary": ["Standard.Collection"],
                    "Double": ["Standard.Comparable", "Standard.Numeric"],
                    "Int": ["Standard.Comparable", "Standard.Numeric"],
                    "String": ["Standard.Collection", "Standard.Comparable"]
                ],
                procedures: arithmetic(of: "Int", as: .int)
                    .merging(arithmetic(of: "Double", as: .double)) { first, _ in first }
                    .merging(ordering(of: ["Int": .int, "Double": .double, "String": .string])) { first, _ in first }
                    .merging(counting(of: ["Array": .array(.any), "Dictionary": .dictionary(.any), "String": .string])) { first, _ in first }
            ),
            builtin: true
        )
    ]

    // What `Standard.Numeric` asks, answered for one kind of number: two of
    // the kind, answering the kind, and a quotient answering a fraction.
    private static func arithmetic(of name: String, as kind: TypeExpression) -> [Name: Procedure] {
        [
            Name(normal: "\(name).plus"): .witness(PlusQuery(answering: "\(name).plus"), taking: kind, returns: kind, description: "The sum."),
            Name(normal: "\(name).minus"): .witness(
                MinusQuery(answering: "\(name).minus"),
                taking: kind,
                returns: kind,
                description: "The difference."
            ),
            Name(normal: "\(name).times"): .witness(TimesQuery(answering: "\(name).times"), taking: kind, returns: kind, description: "The product."),
            Name(normal: "\(name).remainder"): .witness(
                RemainderQuery(answering: "\(name).remainder"),
                taking: kind,
                returns: kind,
                description: "What is left of a division truncated toward zero."
            ),
            Name(normal: "\(name).dividedBy"): .witness(
                DividedByQuery(answering: "\(name).dividedBy"),
                taking: kind,
                returns: .double,
                description: "The quotient, which is not generally whole."
            )
        ]
    }

    // What `Standard.Comparable` asks, answered for each kind that orders.
    private static func ordering(of kinds: [String: TypeExpression]) -> [Name: Procedure] {
        kinds.reduce(into: [:]) { procedures, entry in
            procedures[Name(normal: "\(entry.key).lessThan")] = .witness(
                LessThanQuery(answering: "\(entry.key).lessThan"),
                taking: entry.value,
                returns: .bool,
                description: "Whether one orders before the other."
            )
        }
    }

    // What `Standard.Collection` asks, answered for each kind that has a
    // count: the elements of a list, bytes included, the entries of a map,
    // a record's fields included, and the characters of text as a person
    // reads them.
    private static func counting(of kinds: [String: TypeExpression]) -> [Name: Procedure] {
        kinds.reduce(into: [:]) { procedures, entry in
            procedures[Name(normal: "\(entry.key).count")] = .witness(
                CountQuery(answering: "\(entry.key).count"),
                taking: entry.value,
                returns: .int,
                description: "How many."
            )
        }
    }
}

//
//  Module+SharedGround.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    // One declaration answering a contract's procedure for a type the
    // language names, under the spelling a claim holds it to: the type's
    // name and the procedure's, with a dot between them.
    private struct Witness {
        // MARK: - Property
        let type: Name
        let contract: Name
        let name: Name
        let procedure: Procedure

        // MARK: - Initializer
        init(_ type: Name, answering contract: Name, _ asked: String, by declaring: (String) -> Procedure) {
            let spelling = "\(type.spelling).\(asked)"

            self.type = type
            self.contract = contract
            self.name = Name(normal: spelling)
            self.procedure = declaring(spelling)
        }

        // MARK: - Public
        // MARK: - Private
    }

    // The contracts this module declares, by the names a claim writes.
    private enum ContractSpelling {
        static let numeric: Name = "Standard.Numeric"
        static let comparable: Name = "Standard.Comparable"
        static let collection: Name = "Standard.Collection"
    }

    // The contracts the other bundles mention, declared once where every
    // bundle can name them, and the types the language names answering them:
    // what a number, an ordering and a count are for `Int`, `Double`,
    // `String`, `Array` and `Dictionary`. A document calling a contract's
    // procedure stands behind this one, so what answers stands before it.
    static let sharedGround: [Module] = [
        Module(
            unchecked: Draft(
                description: "The shared ground: what counts as a number, what orders, and what has a count.",
                contracts: [
                    // What arithmetic is asked of: two of one type, answered in
                    // that type, and a quotient that is a fraction whatever the
                    // type.
                    ContractSpelling.numeric: [
                        "plus": .operation(answering: .selfType),
                        "minus": .operation(answering: .selfType),
                        "times": .operation(answering: .selfType),
                        "remainder": .operation(answering: .selfType),
                        "dividedBy": .operation(answering: .double)
                    ],
                    // What orders two of one type.
                    ContractSpelling.comparable: [
                        "lessThan": .operation(answering: .bool)
                    ],
                    // What has a count.
                    ContractSpelling.collection: [
                        "count": ContractProcedure(
                            signature: Signature(parameters: [Parameter(name: "collection", type: .selfType)], returns: .int),
                            constness: .const,
                            isolation: .isolated
                        )
                    ]
                ],
                claims: witnesses.reduce(into: [Name: Set<Name>]()) { claims, witness in
                    claims[witness.type, default: []].insert(witness.contract)
                },
                procedures: Dictionary(uniqueKeysWithValues: witnesses.map { witness in (witness.name, witness.procedure) })
            ),
            builtin: true
        )
    ]

    // Every declaration answering a contract here: arithmetic for the two
    // numbers, an ordering for them and for text, and a count for a list, a
    // map and text. The claims are read off the same list, so a claim and
    // what backs it are one fact.
    private static let witnesses: [Witness] =
        [(TypeSpelling.int, TypeExpression.int), (TypeSpelling.double, .double)].flatMap { name, type in
            arithmetic(of: name, as: type)
        }
        + [(TypeSpelling.int, TypeExpression.int), (TypeSpelling.double, .double), (TypeSpelling.string, .string)].map { name, type in
            ordering(of: name, as: type)
        }
        + [
            (TypeSpelling.array, TypeExpression.array(.any), [:]),
            (TypeSpelling.dictionary, .dictionary(key: .parameter(name: "Key"), value: .any), ["Key": [TypeSpelling.hashable]]),
            (TypeSpelling.string, .string, [:])
        ].map { name, type, bounds in
            counting(of: name, as: type, bounds: bounds)
        }

    // What `Standard.Numeric` asks, answered for one type of number: two of
    // the type, answering the type, and a quotient answering a fraction.
    private static func arithmetic(of name: Name, as type: TypeExpression) -> [Witness] {
        [
            Witness(name, answering: ContractSpelling.numeric, "plus") { spelling in
                .witness(PlusQuery(answering: spelling), taking: type, returns: type, description: "The sum.")
            },
            Witness(name, answering: ContractSpelling.numeric, "minus") { spelling in
                .witness(MinusQuery(answering: spelling), taking: type, returns: type, description: "The difference.")
            },
            Witness(name, answering: ContractSpelling.numeric, "times") { spelling in
                .witness(TimesQuery(answering: spelling), taking: type, returns: type, description: "The product.")
            },
            Witness(name, answering: ContractSpelling.numeric, "remainder") { spelling in
                .witness(
                    RemainderQuery(answering: spelling),
                    taking: type,
                    returns: type,
                    description: "What is left of a division truncated toward zero."
                )
            },
            Witness(name, answering: ContractSpelling.numeric, "dividedBy") { spelling in
                .witness(
                    DividedByQuery(answering: spelling),
                    taking: type,
                    returns: .double,
                    description: "The quotient, which is not generally whole."
                )
            }
        ]
    }

    // What `Standard.Comparable` asks, answered for one type that orders.
    private static func ordering(of name: Name, as type: TypeExpression) -> Witness {
        Witness(name, answering: ContractSpelling.comparable, "lessThan") { spelling in
            .witness(
                LessThanQuery(answering: spelling),
                taking: type,
                returns: .bool,
                description: "Whether one orders before the other."
            )
        }
    }

    // What `Standard.Collection` asks, answered for one type that has a
    // count: the elements of a list, bytes included, the entries of a map,
    // and the characters of text as a person reads them.
    private static func counting(of name: Name, as type: TypeExpression, bounds: [Name: Set<Name>]) -> Witness {
        Witness(name, answering: ContractSpelling.collection, "count") { spelling in
            .witness(CountQuery(answering: spelling), taking: type, returns: .int, bounds: bounds, description: "How many.")
        }
    }
}

//
//  Module+SharedGround.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    // One member satisfying a contract's procedure for a type the language
    // names: the member of the procedure's name, under the spelling a call
    // writes, the type's name and the member's with a dot between them.
    private struct Witness {
        // MARK: - Property
        let type: Name
        let contract: Name
        let member: Name
        let procedure: Procedure

        var name: Name { member.spelled(under: type) }

        // MARK: - Initializer
        init(_ type: Name, conformingTo contract: Name, _ asked: String, by declaring: (String) -> Procedure) {
            self.type = type
            self.contract = contract
            self.member = Name(normal: asked)
            self.procedure = declaring(member.spelled(under: type).spelling)
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
    // bundle can name them, and the types the language names conforming to
    // them: what a number, an ordering and a count are for `Int`, `Double`,
    // `String`, `Array` and `Dictionary`. A document calling a contract's
    // procedure stands behind this one, so what conforms to them stands before
    // it.
    static let sharedGround: [Module] = [
        Module(
            unchecked: Draft(
                contracts: [
                    // What arithmetic is asked of: two of one type, returning
                    // that type, and a quotient that is a `Double` whatever the
                    // type.
                    ContractSpelling.numeric: [
                        "plus": .operation(returning: .selfType),
                        "minus": .operation(returning: .selfType),
                        "times": .operation(returning: .selfType),
                        "remainder": .operation(returning: .selfType),
                        "dividedBy": .operation(returning: .double)
                    ],
                    // What orders two of one type.
                    ContractSpelling.comparable: [
                        "lessThan": .operation(returning: .bool)
                    ],
                    // What has a count.
                    ContractSpelling.collection: [
                        "count": Signature(
                            parameters: [Parameter(name: "collection", type: .selfType)],
                            returns: .int,
                            constness: .const,
                            isolation: .isolated
                        )
                    ]
                ],
                claims: witnesses.reduce(into: [Head: Set<Name>]()) { claims, witness in
                    claims[Head(witness.type), default: []].insert(witness.contract)
                },
                members: witnesses.reduce(into: [Head: Set<Name>]()) { members, witness in
                    members[Head(witness.type), default: []].insert(witness.member)
                },
                procedures: Dictionary(uniqueKeysWithValues: witnesses.map { witness in (witness.name, witness.procedure) })
            ),
            builtin: true
        )
    ]

    // Every declaration satisfying a contract here: arithmetic for the two
    // numbers, an ordering for them and for strings, and a count for a list, a
    // dictionary and a string. The claims are read off the same list, so a claim and
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

    // What `Standard.Numeric` asks, satisfied for one type of number: two of
    // the type, returning the type, and a quotient returning a `Double`.
    private static func arithmetic(of name: Name, as type: TypeExpression) -> [Witness] {
        [
            Witness(name, conformingTo: ContractSpelling.numeric, "plus") { spelling in
                .witness(PlusQuery(implementing: spelling), taking: type, returns: type)
            },
            Witness(name, conformingTo: ContractSpelling.numeric, "minus") { spelling in
                .witness(MinusQuery(implementing: spelling), taking: type, returns: type)
            },
            Witness(name, conformingTo: ContractSpelling.numeric, "times") { spelling in
                .witness(TimesQuery(implementing: spelling), taking: type, returns: type)
            },
            Witness(name, conformingTo: ContractSpelling.numeric, "remainder") { spelling in
                .witness(RemainderQuery(implementing: spelling), taking: type, returns: type)
            },
            Witness(name, conformingTo: ContractSpelling.numeric, "dividedBy") { spelling in
                .witness(DividedByQuery(implementing: spelling), taking: type, returns: .double)
            }
        ]
    }

    // What `Standard.Comparable` asks, satisfied for one type that orders.
    private static func ordering(of name: Name, as type: TypeExpression) -> Witness {
        Witness(name, conformingTo: ContractSpelling.comparable, "lessThan") { spelling in
            .witness(LessThanQuery(implementing: spelling), taking: type, returns: .bool)
        }
    }

    // What `Standard.Collection` asks, satisfied for one type that has a
    // count: the elements of a list, bytes included, the entries of a dictionary,
    // and the characters of a string as a person reads them.
    private static func counting(of name: Name, as type: TypeExpression, bounds: [Name: Set<Name>]) -> Witness {
        Witness(name, conformingTo: ContractSpelling.collection, "count") { spelling in
            .witness(CountQuery(implementing: spelling), taking: type, returns: .int, bounds: bounds)
        }
    }
}

//
//  Module+Collection.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let collection = try! Module(
        namespace: "std.collection",
        description: "Words about arrays and objects. A string counts and contains too.",
        procedures: [
            "count": Procedure(
                description: "How many, for a shape that has a count.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .int
                ),
                implementation: .query(CountQuery())
            ),
            "contains": Procedure(
                description: "Whether a string or an array holds a value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .any),
                        "value": Parameter(type: .any)
                    ],
                    returns: .bool
                ),
                implementation: .query(ContainsQuery())
            ),
            "first": Procedure(
                description: "The first element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element")))
                    ],
                    returns: .variable(name: "Element")
                ),
                implementation: .query(SequenceQuery(.first))
            ),
            "last": Procedure(
                description: "The last element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element")))
                    ],
                    returns: .variable(name: "Element")
                ),
                implementation: .query(SequenceQuery(.last))
            ),
            "reversed": Procedure(
                description: "The elements back to front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element")))
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(SequenceQuery(.reversed))
            ),
            "appending": Procedure(
                description: "The elements with one more at the end.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element"))),
                        "value": Parameter(type: .variable(name: "Element"))
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.appending))
            ),
            "prepending": Procedure(
                description: "The elements with one more at the front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element"))),
                        "value": Parameter(type: .variable(name: "Element"))
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.prepending))
            ),
            "dropFirst": Procedure(
                description: "The elements after the first.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element")))
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.dropFirst))
            ),
            "dropLast": Procedure(
                description: "The elements before the last.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element")))
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.dropLast))
            ),
            "sorted": Procedure(
                description: "The elements in order, for numbers or for strings.",
                // Bounded by the shared ground's `Comparable`: ordering is one
                // question wherever it is asked, so the membership that answers
                // it for `lessThan` answers it here.
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(
                            type: .array(.variable(name: "Element", constraint: "std.Comparable"))
                        )
                    ],
                    returns: .array(.variable(name: "Element", constraint: "std.Comparable"))
                ),
                implementation: .query(BuildingQuery(.sorted))
            ),
            "map": Procedure(
                description: "Each element answered by a procedure, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .variable(name: "Element"))],
                                    returns: .variable(name: "Answer")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.variable(name: "Answer"))
                ),
                implementation: .query(WalkingQuery(.map))
            ),
            "filter": Procedure(
                description: "The elements a procedure answers true for.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .variable(name: "Element"))],
                                    returns: .bool
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.variable(name: "Element"))
                ),
                implementation: .query(WalkingQuery(.filter))
            ),
            "reduce": Procedure(
                description: "The elements folded into one, starting from a value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.variable(name: "Element"))),
                        "from": Parameter(type: .variable(name: "Carried")),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: [
                                        "carried": Parameter(type: .variable(name: "Carried")),
                                        "item": Parameter(type: .variable(name: "Element"))
                                    ],
                                    returns: .variable(name: "Carried")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .variable(name: "Carried")
                ),
                implementation: .query(WalkingQuery(.reduce))
            ),
            "keys": Procedure(
                description: "The names an object holds, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.any))
                    ],
                    returns: .array(.string)
                ),
                implementation: .query(MappingQuery(.keys))
            ),
            "values": Procedure(
                description: "What an object holds, by its names in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.variable(name: "Entry")))
                    ],
                    returns: .array(.variable(name: "Entry"))
                ),
                implementation: .query(MappingQuery(.values))
            ),
            "setting": Procedure(
                description: "The object with one name bound to another value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .object(.any)),
                        "key": Parameter(type: .string),
                        "value": Parameter(type: .any)
                    ],
                    returns: .object(.any)
                ),
                implementation: .query(MappingQuery(.setting))
            )
        ]
    )
}

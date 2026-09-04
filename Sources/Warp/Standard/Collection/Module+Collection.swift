//
//  Module+Collection.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

public extension Module {
    static let collection = try! Module(
        description: "Words about arrays and records. A string counts and contains too.",
        procedures: [
            "std.collection.append": Procedure(
                description: "Writes one element onto the end of the array a variable"
                    + " holds, in place.",
                signature: Signature(
                    receiver: "to",
                    parameters: [
                        "to": Parameter(type: .inout(.array(.parameter(name: "Element")))),
                        "value": Parameter(type: .parameter(name: "Element"))
                    ],
                    returns: .null
                ),
                implementation: .effect(AppendingEffect())
            ),
            "std.collection.count": Procedure(
                description: "How many, for a shape that has a count.",
                signature: Signature(
                    receiver: "of",
                    parameters: ["of": Parameter(type: .any)],
                    returns: .int
                ),
                implementation: .query(CountQuery())
            ),
            "std.collection.contains": Procedure(
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
            "std.collection.first": Procedure(
                description: "The first element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element")))
                    ],
                    returns: .parameter(name: "Element")
                ),
                implementation: .query(SequenceQuery(.first))
            ),
            "std.collection.last": Procedure(
                description: "The last element, or nothing.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element")))
                    ],
                    returns: .parameter(name: "Element")
                ),
                implementation: .query(SequenceQuery(.last))
            ),
            "std.collection.reversed": Procedure(
                description: "The elements back to front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element")))
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(SequenceQuery(.reversed))
            ),
            "std.collection.appending": Procedure(
                description: "The elements with one more at the end.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element"))),
                        "value": Parameter(type: .parameter(name: "Element"))
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.appending))
            ),
            "std.collection.prepending": Procedure(
                description: "The elements with one more at the front.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element"))),
                        "value": Parameter(type: .parameter(name: "Element"))
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.prepending))
            ),
            "std.collection.dropFirst": Procedure(
                description: "The elements after the first.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element")))
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.dropFirst))
            ),
            "std.collection.dropLast": Procedure(
                description: "The elements before the last.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element")))
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(BuildingQuery(.dropLast))
            ),
            "std.collection.sorted": Procedure(
                description: "The elements in order, for numbers or for strings.",
                // Bounded by the shared ground's `Comparable`: ordering is one
                // question wherever it is asked, so the membership that answers
                // it for `lessThan` answers it here.
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(
                            type: .array(.parameter(name: "Element", constraint: "std.Comparable"))
                        )
                    ],
                    returns: .array(.parameter(name: "Element", constraint: "std.Comparable"))
                ),
                implementation: .query(BuildingQuery(.sorted))
            ),
            "std.collection.map": Procedure(
                description: "Each element answered by a procedure, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .parameter(name: "Element"))],
                                    returns: .parameter(name: "Answer")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.parameter(name: "Answer"))
                ),
                implementation: .query(WalkingQuery(.map))
            ),
            "std.collection.filter": Procedure(
                description: "The elements a procedure answers true for.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element"))),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: ["item": Parameter(type: .parameter(name: "Element"))],
                                    returns: .bool
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(WalkingQuery(.filter))
            ),
            "std.collection.reduce": Procedure(
                description: "The elements folded into one, starting from a value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .array(.parameter(name: "Element"))),
                        "from": Parameter(type: .parameter(name: "Carried")),
                        "value": Parameter(
                            type: .procedure(
                                Signature(
                                    parameters: [
                                        "carried": Parameter(type: .parameter(name: "Carried")),
                                        "item": Parameter(type: .parameter(name: "Element"))
                                    ],
                                    returns: .parameter(name: "Carried")
                                ),
                                .pure
                            )
                        )
                    ],
                    returns: .parameter(name: "Carried")
                ),
                implementation: .query(WalkingQuery(.reduce))
            ),
            "std.collection.keys": Procedure(
                description: "The names a record holds, in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .dictionary(.any))
                    ],
                    returns: .array(.string)
                ),
                implementation: .query(MappingQuery(.keys))
            ),
            "std.collection.values": Procedure(
                description: "What a record holds, by its names in order.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .dictionary(.parameter(name: "Entry")))
                    ],
                    returns: .array(.parameter(name: "Entry"))
                ),
                implementation: .query(MappingQuery(.values))
            ),
            "std.collection.setting": Procedure(
                description: "The record with one name bound to another value.",
                signature: Signature(
                    receiver: "of",
                    parameters: [
                        "of": Parameter(type: .dictionary(.any)),
                        "key": Parameter(type: .string),
                        "value": Parameter(type: .any)
                    ],
                    returns: .dictionary(.any)
                ),
                implementation: .query(MappingQuery(.setting))
            )
        ]
    )
}

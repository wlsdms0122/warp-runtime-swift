//
//  Module+Collection.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let collection = try! Module(
        description: "Words about arrays and records. A string counts and contains too.",
        procedures: [
            "std.collection.append": Procedure(
                description: "Writes one element onto the end of the array a variable"
                    + " holds, in place.",
                signature: Signature(of: AppendEffect.self, receiver: .to, returns: .null),
                implementation: .effect(AppendEffect())
            ),
            "std.collection.count": Procedure(
                description: "How many, for a shape that has a count.",
                signature: Signature(of: CountQuery.self, receiver: .of, returns: .int),
                implementation: .query(CountQuery())
            ),
            "std.collection.contains": Procedure(
                description: "Whether a string or an array holds a value.",
                signature: Signature(of: ContainsQuery.self, receiver: .of, returns: .bool),
                implementation: .query(ContainsQuery())
            ),
            "std.collection.first": Procedure(
                description: "The first element, or nothing.",
                signature: Signature(
                    of: FirstQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "Element")
                ),
                implementation: .query(FirstQuery())
            ),
            "std.collection.last": Procedure(
                description: "The last element, or nothing.",
                signature: Signature(
                    of: LastQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "Element")
                ),
                implementation: .query(LastQuery())
            ),
            "std.collection.reversed": Procedure(
                description: "The elements back to front.",
                signature: Signature(
                    of: ReversedQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(ReversedQuery())
            ),
            "std.collection.appending": Procedure(
                description: "The elements with one more at the end.",
                signature: Signature(
                    of: AppendingQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(AppendingQuery())
            ),
            "std.collection.prepending": Procedure(
                description: "The elements with one more at the front.",
                signature: Signature(
                    of: PrependingQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(PrependingQuery())
            ),
            "std.collection.dropFirst": Procedure(
                description: "The elements after the first.",
                signature: Signature(
                    of: DropFirstQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(DropFirstQuery())
            ),
            "std.collection.dropLast": Procedure(
                description: "The elements before the last.",
                signature: Signature(
                    of: DropLastQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(DropLastQuery())
            ),
            "std.collection.sorted": Procedure(
                description: "The elements in order, for numbers or for strings.",
                signature: Signature(
                    of: SortedQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element", constraint: "std.Comparable"))
                ),
                implementation: .query(SortedQuery())
            ),
            "std.collection.map": Procedure(
                description: "Each element answered by a procedure, in order.",
                signature: Signature(
                    of: MapQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Answer"))
                ),
                implementation: .query(MapQuery())
            ),
            "std.collection.filter": Procedure(
                description: "The elements a procedure answers true for.",
                signature: Signature(
                    of: FilterQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(FilterQuery())
            ),
            "std.collection.reduce": Procedure(
                description: "The elements folded into one, starting from a value.",
                signature: Signature(
                    of: ReduceQuery.self,
                    receiver: .of,
                    returns: .parameter(name: "Carried")
                ),
                implementation: .query(ReduceQuery())
            ),
            "std.collection.keys": Procedure(
                description: "The names a record holds, in order.",
                signature: Signature(
                    of: KeysQuery.self,
                    receiver: .of,
                    returns: .array(.string)
                ),
                implementation: .query(KeysQuery())
            ),
            "std.collection.values": Procedure(
                description: "What a record holds, by its names in order.",
                signature: Signature(
                    of: ValuesQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Entry"))
                ),
                implementation: .query(ValuesQuery())
            ),
            "std.collection.setting": Procedure(
                description: "The record with one name bound to another value.",
                signature: Signature(
                    of: SettingQuery.self,
                    receiver: .of,
                    returns: .dictionary(.any)
                ),
                implementation: .query(SettingQuery())
            )
        ]
    )
}

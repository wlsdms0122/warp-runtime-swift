//
//  Module+Collection.swift
//  WarpStandard
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

public extension Module {
    static let collection = bundled(nativeCollection, with: "collection")

    private static let nativeCollection = try! Module(
        description: "Procedures about arrays and records. A string counts and contains too.",
        procedures: [
            "std.collection.count": Procedure(
                description: "How many, for a type that has a count.",
                signature: Signature(of: CountQuery.self, receiver: .of, returns: .int),
                implementation: .query(CountQuery())
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
            "std.collection.gathering": Procedure(
                description: "The receiver's own elements, at the positions given.",
                signature: Signature(
                    of: GatheringQuery.self,
                    receiver: .of,
                    returns: .array(.parameter(name: "Element"))
                ),
                implementation: .query(GatheringQuery())
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
            "std.collection.setting": Procedure(
                description: "The record with one name bound to another value.",
                signature: Signature(
                    of: SettingQuery.self,
                    receiver: .of,
                    returns: .dictionary(.any)
                ),
                implementation: .query(SettingQuery())
            )
        ],
        builtin: true
    )
}

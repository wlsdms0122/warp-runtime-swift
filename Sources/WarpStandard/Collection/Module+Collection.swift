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

    private static let nativeCollection = Module(
        unchecked: Draft(
            description: "Counting, appending, gathering and the names of a record.",
            procedures: [
                "Standard.Collection.count": Procedure(
                    description: "How many, of what Standard.Collection admits.",
                    signature: Signature(of: CountQuery.self, returns: .int),
                    implementation: .query(CountQuery())
                ),
                "Standard.Collection.appending": Procedure(
                    description: "The elements with one more at the end.",
                    signature: Signature(
                        of: AppendingQuery.self,
                        returns: .array(.parameter(name: "Element"))
                    ),
                    implementation: .query(AppendingQuery())
                ),
                "Standard.Collection.gathering": Procedure(
                    description: "The collection's own elements, at the positions given.",
                    signature: Signature(
                        of: GatheringQuery.self,
                        returns: .array(.parameter(name: "Element"))
                    ),
                    implementation: .query(GatheringQuery())
                ),
                "Standard.Collection.keys": Procedure(
                    description: "The names a record holds, in order.",
                    signature: Signature(
                        of: KeysQuery.self,
                        returns: .array(.string)
                    ),
                    implementation: .query(KeysQuery())
                ),
                "Standard.Collection.setting": Procedure(
                    description: "The record with one name bound to another value.",
                    signature: Signature(
                        of: SettingQuery.self,
                        returns: .dictionary(.any)
                    ),
                    implementation: .query(SettingQuery())
                )
            ]
        ),
        builtin: true
    )
}

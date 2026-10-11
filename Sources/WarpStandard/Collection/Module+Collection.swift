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
            description: "Appending, gathering, and the names a map holds.",
            procedures: [
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
                    description: "The names a map holds, in order.",
                    signature: Signature(
                        of: KeysQuery.self,
                        returns: .array(.string)
                    ),
                    implementation: .query(KeysQuery())
                ),
                "Standard.Collection.setting": Procedure(
                    description: "The map with one name bound to another value.",
                    signature: Signature(
                        of: SettingQuery.self,
                        returns: .dictionary(key: .string, value: .parameter(name: "Value"))
                    ),
                    implementation: .query(SettingQuery())
                )
            ]
        ),
        builtin: true
    )
}

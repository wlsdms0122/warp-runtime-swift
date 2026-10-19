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
            description: "Appending, gathering, and the keys a map holds.",
            procedures: [
                "Standard.Collection.appending": Procedure(
                    description: "The elements with one more at the end.",
                    signature: Signature(
                        of: AppendingQuery.self,
                        returns: .array(.parameter(name: "Element")),
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(AppendingQuery())
                ),
                "Standard.Collection.gathering": Procedure(
                    description: "The collection's own elements, at the positions given.",
                    signature: Signature(
                        of: GatheringQuery.self,
                        returns: .array(.parameter(name: "Element")),
                        constness: .const,
                        isolation: .isolated
                    ),
                    implementation: .query(GatheringQuery())
                ),
                "Standard.Collection.keys": Procedure(
                    description: "The keys a map holds, in its key order.",
                    signature: Signature(
                        of: KeysQuery.self,
                        returns: .array(key),
                        constness: .const,
                        isolation: .isolated,
                        bounds: keyed
                    ),
                    implementation: .query(KeysQuery())
                ),
                "Standard.Collection.setting": Procedure(
                    description: "The map with one key bound to another value.",
                    signature: Signature(
                        of: SettingQuery.self,
                        returns: .dictionary(key: key, value: .parameter(name: "Value")),
                        constness: .const,
                        isolation: .isolated,
                        bounds: keyed
                    ),
                    implementation: .query(SettingQuery())
                )
            ]
        ),
        builtin: true
    )

    // A map's key, one type the call fills from the map, held to what a key
    // of any map answers.
    private static let key = TypeExpression.parameter(name: "Key")

    private static let keyed: [Name: Set<Name>] = ["Key": [TypeSpelling.hashable]]
}

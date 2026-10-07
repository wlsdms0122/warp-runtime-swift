//
//  Module+Foundation.swift
//  WarpStandard
//
//  Created by JSilver on 8/23/26.
//

import Foundation
import Warp

public extension Module {
    // The memberships and the byte type the other bundles' signatures mention,
    // declared once where every bundle can name them. It declares no
    // procedures.
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
                constraints: [
                    // What arithmetic ranges over.
                    "Standard.Numeric": [.int, .double],
                    // What may stand left and right of an ordering. Numbers among
                    // themselves, and strings among themselves.
                    "Standard.Comparable": [.int, .double, .string],
                    // What has a count: text, a list (bytes included, being one in a
                    // compact spelling) and a map (a record included, being one
                    // under a layout).
                    "Standard.Collection": [.string, .array(.any), .dictionary(.any)]
                ],
                procedures: [:]
            ),
            builtin: true
        )
    ]
}

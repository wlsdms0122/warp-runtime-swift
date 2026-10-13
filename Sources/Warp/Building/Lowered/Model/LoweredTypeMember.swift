//
//  LoweredTypeMember.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// A type member as the build reads it: the values of its type it is given
// for, as the head lowers, nil where it is given for every value of a type
// taking no parameters, and the type it is there, written in the head's own
// type parameters. What fills the head's parameters fills the type.
struct LoweredTypeMember: Sendable {
    // MARK: - Property
    let head: LoweredType?
    let type: LoweredType

    // The associated types of the head's type parameters the type names, by label,
    // which what fills those parameters decides.
    let associatedTypes: [Name: (of: Name, name: Name)]

    // What the head holds its type parameters to, which is what bounds what
    // those associated types stand on.
    let bounds: [Name: Set<Name>]

    // MARK: - Initializer
    // `head` is what the member was given under, applied to its type's own
    // parameters where it is bare.
    init(_ member: TypeExpression, under head: Head, in table: LoweredTypeTable) {
        self.head = head.lowered(in: table)
        self.type = member.lowered(in: table, bounds: head.bounds)
        self.associatedTypes = member.associatedTypes
        self.bounds = head.bounds
    }

    // MARK: - Public
    // MARK: - Private
}

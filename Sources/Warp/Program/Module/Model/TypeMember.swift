//
//  TypeMember.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// A type a document gives a type under a name: the head it gives it under,
// the name, and the type it is there, written in the head's own type
// parameters, or a struct's where its declaration gives it. A contract asking
// a type under that name is answered for the type by this, and a type
// parameter the type fills reads it as its member, `some T.Item`.
public struct TypeMember: Sendable, Equatable {
    // MARK: - Property
    public let head: Head
    public let name: Name
    public let type: TypeExpression

    // The spelling one type member of a type takes: the type's name and its
    // own, with a dot between them. One type gives one member under a name.
    public var spelling: Name { name.spelled(under: head.type) }

    // MARK: - Initializer
    public init(head: Head, name: Name, type: TypeExpression) {
        self.head = head
        self.name = name
        self.type = type
    }

    // MARK: - Public
    // The type members a table gives each head, one each.
    static func listed(_ members: [Head: [Name: TypeExpression]]) -> [TypeMember] {
        members.sorted { $0.key < $1.key }.flatMap { head, types in
            types.sorted { $0.key < $1.key }.map { name, type in TypeMember(head: head, name: name, type: type) }
        }
    }

    // MARK: - Private
}

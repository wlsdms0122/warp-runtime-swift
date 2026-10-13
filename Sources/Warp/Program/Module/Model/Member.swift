//
//  Member.swift
//  Warp
//
//  Created by JSilver on 10/13/26.
//

import Foundation

// A procedure a document gives a type: the head it gives it under, and the
// name it has there. A call reaches it by the type's name and its own with a
// dot between them, and a contract's procedure is answered for the type by
// the member of that name.
public struct Member: Sendable, Hashable {
    // MARK: - Property
    public let head: Head
    public let name: Name

    public var type: Name { head.type }

    public var spelling: Name { name.spelled(under: head.type) }

    // MARK: - Initializer
    public init(head: Head, name: Name) {
        self.head = head
        self.name = name
    }

    // MARK: - Public
    // The members a table gives each head, by the spelling a call writes.
    static func spelled(_ members: [Head: Set<Name>]) -> [Name: Member] {
        members.reduce(into: [:]) { spelled, entry in
            for name in entry.value {
                let member = Member(head: entry.key, name: name)

                spelled[member.spelling] = member
            }
        }
    }

    // MARK: - Private
}

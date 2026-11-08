//
//  AssociatedType.swift
//  Warp
//
//  Created by JSilver on 10/22/26.
//

import Foundation

// The type a type gives under a name a contract asks, followed from a type
// parameter or `Self`: `T.Item` is what fills `T` gives under `Item`, and
// `T.Item.Key` what that gives under `Key`. Its label is that spelling, the
// key `bounds` and `sameTypes` write it under and the name of the type
// parameter it lowers to. A type parameter's name and a member's are each
// one identifier, so a label is cut at every dot, here and nowhere else.
public struct AssociatedType: Sendable, Hashable {
    // MARK: - Property
    // The type parameter, or `Self`.
    public let base: Name

    // The names asked from the base on, one or more, the last being this
    // one's own.
    public let members: [Name]

    var label: Name {
        Name(normal: ([base] + members).map(\.spelling).joined(separator: "."))
    }

    var name: Name {
        members[members.count - 1]
    }

    // The label of what this stands on: the base, or the associated type
    // one member shorter.
    var owner: Name {
        owning?.label ?? base
    }

    // The associated type this stands on, where it stands on one.
    var owning: AssociatedType? {
        guard members.count > 1 else { return nil }

        return AssociatedType(base: base, members: Array(members.dropLast()))
    }

    // This one and each one it stands on, by label.
    var chain: [Name: AssociatedType] {
        var found: [Name: AssociatedType] = [label: self]
        var next = self

        while let owning = next.owning {
            found[owning.label] = owning
            next = owning
        }

        return found
    }

    // MARK: - Initializer
    // `name` asked of what `owner` labels: a type parameter, `Self`, or
    // another associated type.
    public init(_ name: Name, of owner: Name) {
        let cut = Self.cut(owner)

        self.init(base: cut[0], members: cut.dropFirst() + [name])
    }

    // The associated type a label writes, or nil where it writes no dot.
    public init?(label: Name) {
        let cut = Self.cut(label)

        guard cut.count > 1 else { return nil }

        self.init(base: cut[0], members: Array(cut.dropFirst()))
    }

    // `members` asked from `base` on, one or more.
    package init(base: Name, members: [Name]) {
        self.base = base
        self.members = members
    }

    // MARK: - Public
    // The type parameter a key of `bounds` or `sameTypes` stands on: the
    // base of the associated type it labels, or the key itself.
    static func base(of key: Name) -> Name {
        AssociatedType(label: key)?.base ?? key
    }

    // MARK: - Private
    private static func cut(_ label: Name) -> [Name] {
        label.spelling.split(separator: ".", omittingEmptySubsequences: false).map { part in Name(normal: String(part)) }
    }
}

//
//  Layout.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// Where a record's fields are: the name it settled to, where it has one, and
// the field names in the order the values stand. The order is the language's,
// not a maker's — ascending by the names' bytes — so a layout built by a link,
// a reader or a host is the same layout for the same fields.
//
// A name is part of the layout, so `Account` and `Vault` are two layouts over
// one set of fields. What a field holds is not: `{title: string}` and
// `{title: int}` are one layout under two shapes.
public struct Layout: Sendable, Hashable {
    // MARK: - Property
    public let name: Name?

    // In ascending byte order, as `Name`'s `<` orders them.
    public let fields: [Name]

    // MARK: - Initializer
    public init(name: Name? = nil, fields: [Name]) {
        self.name = name
        self.fields = fields.sorted()

        precondition(
            zip(self.fields, self.fields.dropFirst()).allSatisfy { one, other in one < other },
            "a layout names each field once"
        )
    }

    // MARK: - Public
    // Where a field stands, or nil where the layout does not name it. A binary
    // search over the names' bytes.
    public func position(of field: Name) -> Int? {
        let (position, found) = place(of: field)

        return found ? position : nil
    }

    // MARK: - Private
    // Where a name is, or where it would go: the first position whose name
    // does not precede it, and whether the name there is it.
    private func place(of field: Name) -> (Int, Bool) {
        var low = 0
        var high = fields.count

        while low < high {
            let middle = (low + high) / 2

            if fields[middle] < field {
                low = middle + 1
            } else {
                high = middle
            }
        }

        return (low, low < fields.count && fields[low] == field)
    }
}

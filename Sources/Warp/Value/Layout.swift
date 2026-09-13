//
//  Layout.swift
//  Warp
//
//  Created by JSilver on 9/5/26.
//

import Foundation

// Where a record's fields are: the name it settled to, where it has one, and
// the field names in the order the values stand. The order is the language's,
// not a maker's (ascending by the names' bytes) so a layout built by a link, a
// reader or a host is the same layout for the same fields.
//
// A name is part of the layout, so `Account` and `Vault` are two layouts over
// one set of fields. What a field holds is not: `{title: string}` and
// `{title: int}` are one layout under two types.
//
// Inside a link a name is a row of the lowered type table; outside one it is a
// spelling, which is why a reader and a host may write one. A slot that
// declares a type proves it: a value arriving there under another name is
// refused. A slot that declares nothing proves nothing, so a name travelling
// through `any` is the spelling it was written as.
public struct Layout: Sendable, Hashable {
    // MARK: - Property
    public let name: Name?

    // In ascending byte order, as `Name`'s `<` orders them.
    public let fields: [Name]

    // MARK: - Initializer
    // Fields in any order, none of which repeats, under no name: a name says
    // a declaration, and a declaration is the link's. `Value.holding(_:named:)`
    // carries one a document wrote, and `Image.settling(_:as:)` one the link
    // declared.
    public init(fields: [Name]) throws {
        let sorted = fields.sorted()

        if let repeated = zip(sorted, sorted.dropFirst()).first(where: { one, other in one == other }) {
            throw ValueRefused("a layout names '\(repeated.0)' twice")
        }

        self.name = nil
        self.fields = sorted
    }

    // Fields already in order, where that is a claim about what was handed
    // rather than something to put right. A reading that sorted them would
    // pair them with values it read somewhere else.
    init(name: Name?, judging fields: [Name]) throws {
        guard Name.ordered(fields) else {
            throw ValueRefused("a layout's fields are not in name order")
        }

        self.init(name: name, ordered: fields)
    }

    // The inner door: names already in order, none repeating.
    init(name: Name?, ordered fields: [Name]) {
        precondition(Name.ordered(fields), "a layout's fields are ordered by name")

        self.name = name
        self.fields = fields
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

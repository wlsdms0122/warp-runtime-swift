//
//  Projection.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// One step of a path with every index read, which is what a hold keeps and a
// write walks: a struct's field by the place the build put it at or by its
// name where the build laid out no struct, and what a list or a map holds at a
// value, an element by position and an entry by key. The spelling beside a
// field is what a sentence calls it.
enum Projection: Sendable {
    case field(Int, Name)
    case name(Name)
    case index(Value)

    // MARK: - Property
    // How the step reads back, as the author wrote it.
    var spelled: PathSegment {
        switch self {
        case let .field(_, name), let .name(name): .name(name)
        case let .index(index): .index(index)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

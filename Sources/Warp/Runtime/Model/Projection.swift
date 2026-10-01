//
//  Projection.swift
//  Warp
//
//  Created by JSilver on 9/18/26.
//

import Foundation

// One step of a path with every index read, which is what a hold keeps and a
// write walks: a record's field by the place the build put it at, a
// dictionary's entry by name, an array's element by position. The spelling
// beside a field is what a sentence calls it.
enum Projection: Sendable {
    case field(Int, Name)
    case key(Name)
    case index(Int)

    // MARK: - Property
    // How the step reads back, as the author wrote it.
    var spelled: PathSegment {
        switch self {
        case let .field(_, name), let .key(name): .key(name)
        case let .index(index): .index(index)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

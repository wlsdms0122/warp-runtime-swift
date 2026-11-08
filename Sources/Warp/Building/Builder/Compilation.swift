//
//  Compilation.swift
//  Warp
//
//  Created by JSilver on 11/4/26.
//

import Foundation

// How a document handed to a compile came to stand compiled: read back from
// the object the host cached for it, or compiled. Only what was compiled is
// news to the host's cache.
public enum Compilation: Sendable {
    case read(Compiled)
    case compiled(Compiled)

    // MARK: - Property
    public var object: Compiled {
        switch self {
        case let .read(object), let .compiled(object): object
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

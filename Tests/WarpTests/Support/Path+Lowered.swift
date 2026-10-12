//
//  Path+Lowered.swift
//  WarpTests
//
//  Created by JSilver on 10/12/26.
//

import Foundation
@testable import Warp

extension Path {
    // This path placed with no layout proved: every dot read by its name, and
    // an index the run reads a path of its own.
    var lowered: LoweredPath {
        LoweredPath(segments.map { segment in
            switch segment {
            case let .name(name, optional):
                return .name(name, optional: optional)

            case let .index(index, optional):
                return .index(index, optional: optional)

            case let .indexRef(inner, optional):
                return .at(inner.lowered, optional: optional)
            }
        })
    }
}

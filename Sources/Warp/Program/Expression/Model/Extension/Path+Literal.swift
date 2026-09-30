//
//  Path+Literal.swift
//  Warp
//
//  Created by JSilver on 9/27/26.
//

import Foundation

// Writing a path in Swift, segment by segment.
extension Path: ExpressibleByArrayLiteral {
    public init(arrayLiteral segments: PathSegment...) {
        self.init(segments)
    }
}

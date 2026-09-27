//
//  Array+Statement.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension [Statement] {
    // Whether every way through this sequence leaves. A sequence leaves when
    // one of its statements always leaves, because nothing after that one runs.
    public var alwaysLeaves: Bool {
        contains { statement in statement.expression.alwaysLeaves }
    }
}

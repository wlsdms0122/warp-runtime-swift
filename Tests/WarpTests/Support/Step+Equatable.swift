//
//  Step+Equatable.swift
//  WarpTests
//
//  Created by JSilver on 9/27/26.
//

import Foundation
@testable import Warp

extension Step: Equatable {
    public static func == (lhs: Step, rhs: Step) -> Bool {
        switch (lhs, rhs) {
        case let (.field(mine, myName, myMark), .field(theirs, theirName, theirMark)):
            return mine == theirs && myName == theirName && myMark == theirMark

        case let (.key(mine, myMark), .key(theirs, theirMark)):
            return mine == theirs && myMark == theirMark

        case let (.index(mine, myMark), .index(theirs, theirMark)):
            return mine == theirs && myMark == theirMark

        case let (.at(mine, myMark), .at(theirs, theirMark)):
            return mine.slot == theirs.slot && mine.steps == theirs.steps && myMark == theirMark

        default:
            return false
        }
    }
}

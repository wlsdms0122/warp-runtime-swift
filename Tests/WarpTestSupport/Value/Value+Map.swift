//
//  Value+Map.swift
//  WarpTestSupport
//
//  Created by JSilver on 10/12/26.
//

import Foundation
import Warp

// A map a test reads by its keys, the way a document's mapping or an answer
// keyed by names is read, and nil for any other kind.
public extension Value {
    var map: Value.Dictionary? {
        guard case let .dictionary(map) = self else { return nil }

        return map
    }
}

//
//  Value+DictionaryValue.swift
//  WarpTestSupport
//
//  Created by JSilver on 10/12/26.
//

import Foundation
import Warp

// A dictionary a test reads by its keys, the way a document's mapping or a return
// value keyed by names is read, and nil for any other kind.
public extension Value {
    var dictionaryValue: Value.Dictionary? {
        guard case let .dictionary(dictionary) = self else { return nil }

        return dictionary
    }
}

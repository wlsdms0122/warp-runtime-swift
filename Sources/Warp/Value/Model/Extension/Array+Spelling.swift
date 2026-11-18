//
//  Array+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/30/26.
//

import Foundation

public extension [UInt8] {
    // The one spelling a document writes bytes in, and every writer of them
    // reads this one spelling: the text encoding that a reader takes back, and
    // the rendering `text` gives. A reader holds it to lowercase and two digits
    // a byte.
    //
    // The `x` and the quotes belong to the position, not to the digits: the
    // encoding and the rendering write `x"…"` around this.
    var spelling: String {
        map { byte in String(format: "%02x", byte) }.joined()
    }
}

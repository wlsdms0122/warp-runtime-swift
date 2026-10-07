//
//  Array+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/30/26.
//

import Foundation

public extension [UInt8] {
    // The one spelling a document writes bytes in, and every writer of them
    // reads this one answer: the text encoding that a reader takes back, and
    // the rendering `text` gives. A reader holds it to lowercase and two digits
    // a byte.
    //
    // The `x` and the quotes belong to the position, not to the digits: the
    // encoding writes `x"…"` around this, and a rendering in a carrier's
    // position writes no digits at all. Bytes are `Array<Standard.Byte>` there.
    var spelling: String {
        map { byte in String(format: "%02x", byte) }.joined()
    }
}

//
//  Bytes+Spelling.swift
//  Warp
//
//  Created by JSilver on 8/30/26.
//

import Foundation

public extension [UInt8] {
    // The one spelling a document writes bytes in, and every writer of them
    // reads this one answer. The text encoding that a reader takes back, and
    // the rendering a template shows. Beside `Double.spelling` for the same
    // reason: a spelling written twice is a spelling that can drift, and a
    // reader holds this one to lowercase and two digits a byte.
    //
    // The `x` and the quotes belong to the position, not to the digits: the
    // encoding writes `x"…"` around this, and a rendering in a carrier's
    // position writes no digits at all. Bytes are `array<byte>` there.
    var spelling: String {
        map { byte in String(format: "%02x", byte) }.joined()
    }
}

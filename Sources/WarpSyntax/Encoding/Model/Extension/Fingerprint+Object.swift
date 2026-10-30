//
//  Fingerprint+Object.swift
//  WarpSyntax
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

// Which compiled document a compiled document is: the digest of the object's
// one canonical binary writing. An object records what it was compiled
// against as those objects' fingerprints, so two objects agree here only if
// everything they lean on agrees too.
public extension Fingerprint {
    // Worked out from the object every time it is wanted; nothing stores it.
    static func of(_ object: Value) throws -> Fingerprint {
        Fingerprint(SHA256().digest(of: try BinaryEncoding().data(from: object)))
    }
}

//
//  Fingerprint+Object.swift
//  WarpSyntax
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

// Working out which compiled document a compiled document is.
//
// Here and not beside the language for the reason an identity is here: the
// answer is about bytes, and an object has exactly one canonical binary
// writing already. A second implementation gets this right by getting the wire
// right, and there is nothing to sort twice or agree about twice.
//
// It is a function of the whole object, which is what makes it enough on its
// own. An object records what it was compiled against as the fingerprints of
// those objects, so a fingerprint taken here already stands for everything
// behind it as well: two objects agree here only if what they were compiled
// from and everything they lean on agree too.
public extension Fingerprint {
    // Nothing is stored and nothing is claimed. Worked out from the object
    // every time it is wanted, which is what makes it impossible for anybody to
    // record it wrongly.
    static func of(_ object: Value) throws -> Fingerprint {
        Fingerprint(SHA256.digest(of: try BinaryEncoding.data(from: object)))
    }
}

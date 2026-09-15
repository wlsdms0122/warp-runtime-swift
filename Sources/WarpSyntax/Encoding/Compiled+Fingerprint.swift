//
//  Compiled+Fingerprint.swift
//  WarpSyntax
//
//  Created by JSilver on 9/16/26.
//

import Foundation
import Warp

public extension Compiled {
    // The same artifact, knowing what it is.
    //
    // Nothing where it has no writing. What a fingerprint is taken of is the
    // bytes, so an artifact that cannot be written down is one there is nothing
    // to take, and a document compiled against it records leaning on nothing it
    // can name.
    func fingerprinted() throws -> Compiled {
        guard let written else { return self }

        return fingerprinted(try Fingerprint.of(written))
    }
}

//
//  Value+NestingBound.swift
//  Warp
//
//  Created by JSilver on 10/20/26.
//

import Foundation

extension Value {
    // How deep a written tree may nest: a document, and every tree an object
    // writes as the entries of a table. The bound is exact: a reading takes a
    // tree within it and refuses the first level past it.
    public static let nestingBound = 128
}

//
//  ScannedSegment.swift
//  WarpSyntax
//
//  Created by JSilver on 10/20/26.
//

import Foundation
import Warp

// A segment as the scan over a path's text meets it: read whole, or the
// text of the path an index refers to, read a level deeper once the scan is
// done.
enum ScannedSegment {
    case read(PathSegment)
    case reference(String, optional: Bool)
}

//
//  Module+Optional.swift
//  WarpStandard
//
//  Created by JSilver on 10/23/26.
//

import Foundation
import Warp

public extension Module {
    // What an Optional's payload is, or what a closure returns in its place.
    // Written in Warp from `unwrap` alone, so the bundle has no half the host
    // implements and is its written document.
    static let optional: [Module] = library["optional"].map { document in [document] } ?? []
}

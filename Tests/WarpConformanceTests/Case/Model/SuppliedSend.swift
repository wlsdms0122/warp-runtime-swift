//
//  SuppliedSend.swift
//  WarpConformanceTests
//
//  Created by JSilver on 11/8/26.
//

import Foundation
import Warp

// One send a procedure a case asks for declares: the spelling the case wrote
// under `sends`, where it stands among them, and what it hands, which is
// what the declaration it reaches takes.
struct SuppliedSend: Hashable, Sendable {
    // MARK: - Property
    let selector: Name
    let position: Int
    let handing: Int

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

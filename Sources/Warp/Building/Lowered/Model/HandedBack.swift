//
//  HandedBack.swift
//  Warp
//
//  Created by JSilver on 10/3/26.
//

import Foundation

// A variable a call handed in place at a slot naming a type parameter, judged
// once the call is over against what the caller holds it as. The callee
// wrote it as its own parameter, which says nothing of what filled it.
struct HandedBack: Sendable {
    // MARK: - Property
    let address: Address
    let against: LoweredType

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

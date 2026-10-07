//
//  HandedOn.swift
//  Warp
//
//  Created by JSilver on 10/7/26.
//

import Foundation

// An argument a call of a value hands on, judged against what the slot
// holding the value reads at its position before the value's own
// declaration takes it. The declaration may read less than the slot does,
// so what the build held the argument to is held at the run here: a value
// read as `Any` or as a contract crosses into the slot's type, and a record
// literal written there takes the name it reads.
struct HandedOn: Sendable {
    // MARK: - Property
    let position: Int
    let against: LoweredType

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

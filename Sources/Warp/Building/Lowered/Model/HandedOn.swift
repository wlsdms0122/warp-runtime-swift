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
// so what the slot reads that the build did not prove of the argument, a
// range above all, is judged at the run here.
struct HandedOn: Sendable {
    // MARK: - Property
    let position: Int
    let against: LoweredType

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

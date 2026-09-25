//
//  Address+Standing.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Address {
    func stand(in standing: inout Body.Standing) {
        standing.stand(on: slot)
        steps.forEach { step in step.stand(in: &standing) }
    }
}

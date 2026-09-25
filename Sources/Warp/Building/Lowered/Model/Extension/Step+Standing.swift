//
//  Step+Standing.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Step {
    func stand(in standing: inout Body.Standing) {
        guard case let .at(address, _) = self else { return }

        address.stand(in: &standing)
    }
}

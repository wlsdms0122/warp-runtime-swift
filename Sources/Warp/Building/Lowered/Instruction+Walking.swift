//
//  Instruction+Walking.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

extension Instruction {
    @discardableResult
    func walk(_ visit: (Body.Node) -> Bool) -> Bool {
        visit(.instruction(self)) && code.walk(visit)
    }
}

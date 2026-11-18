//
//  Arm.swift
//  Warp
//
//  Created by JSilver on 11/1/26.
//

import Foundation

// What a switch runs for one case: the fields of the case it binds, each
// under the name it is read by, and the body that reads them.
package struct Arm: Sendable {
    // MARK: - Property
    // The field the case carries, beside the name it binds.
    package let binds: [Name: Name]
    package let then: Body

    // The names the arm introduces for its `then`.
    var bound: Set<Name> { Set(binds.values) }

    // MARK: - Initializer
    package init(binds: [Name: Name] = [:], then: Body) {
        self.binds = binds
        self.then = then
    }

    // MARK: - Public
    // MARK: - Private
}

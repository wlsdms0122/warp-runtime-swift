//
//  Image+Folding.swift
//  WarpTests
//
//  Created by JSilver on 10/1/26.
//

import Foundation
@testable import Warp

extension Image {
    // A fold against this image, the bindings standing as constants beside
    // it, through the door a compile folds by.
    func folding(_ bindings: [Name: Value]) -> Folding {
        Folding(
            constants: bindings,
            origin: 0,
            in: .relocated(linked, rows: rows, naming: naming),
            answering: [:],
            through: [],
            loweredTypes: loweredTypes
        )
    }
}

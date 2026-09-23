//
//  ArrayReceiver.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The one array a reading takes. It takes nothing else, which is what makes
// `items.first` reachable from a path.
enum ArrayReceiver: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .array(.parameter(name: "Element"))) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

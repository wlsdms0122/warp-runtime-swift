//
//  ChainReceiver.swift
//  WarpStandard
//
//  Created by JSilver on 9/7/26.
//

import Foundation
import Warp

// The links a connective is handed: procedures rather than values, so a link
// the answer does not need goes unasked.
enum ChainReceiver: Int, ParameterSet {
    case of

    // MARK: - Property
    var name: Name { "of" }

    var declared: Parameter { Parameter(type: .array(.procedure(nil, .const))) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

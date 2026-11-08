//
//  RedeemParameters.swift
//  warpx
//

import Foundation
import Warp

enum RedeemParameters: Int, ParameterSet {
    case of

    // MARK: - Property
    var declared: Parameter { Parameter(name: "of", type: .named("Host.Ticket")) }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

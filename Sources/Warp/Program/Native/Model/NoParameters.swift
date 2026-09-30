//
//  NoParameters.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// A procedure that declares nothing. Its one case is never reached, which is what
// having no parameters means.
public enum NoParameters: Int, ParameterSet {
    case none

    // MARK: - Property
    public static var allCases: [NoParameters] { [] }

    public var declared: Parameter { Parameter(name: "") }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

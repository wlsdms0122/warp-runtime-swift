//
//  NoParameters.swift
//  Warp
//
//  Created by JSilver on 9/7/26.
//

import Foundation

// A procedure that declares nothing: a set with no member.
public enum NoParameters: ParameterSet {
    // MARK: - Property
    public var declared: Parameter {
        switch self {}
    }

    public var position: Int {
        switch self {}
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

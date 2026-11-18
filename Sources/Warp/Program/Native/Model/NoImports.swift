//
//  NoImports.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// A procedure that sends nothing: a set with no member.
public enum NoImports: ImportSet {
    // MARK: - Property
    public var selector: Name {
        switch self {}
    }

    public var position: Int {
        switch self {}
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

//
//  NoImports.swift
//  Warp
//
//  Created by JSilver on 9/25/26.
//

import Foundation

// A procedure that sends nothing. Its one case is never reached, which is what
// sending nothing means.
public enum NoImports: Int, ImportSet {
    case none

    public static var allCases: [NoImports] { [] }

    public var selector: Name { "" }
}
